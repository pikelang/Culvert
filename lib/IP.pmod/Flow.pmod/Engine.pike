/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is IP.v4 Public Module.
 *
 * The Initial Developer of the Original Code is
 * James Harton, <james@mashd.cc>.
 * Portions created by the Initial Developer are Copyright (C) 2005-2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * ***** END LICENSE BLOCK ***** */

static object _mutex = Thread.Mutex();
#define LOCK object __key = _mutex->lock(1)
#define UNLOCK destruct(__key)

#define LOG_TICK 30

static object _flows;
static int _max;
static int _drop;
static int _exp_count;
static function __flow_new_cb, __flow_exp_cb, __flow_log_cb, __flow_state_cb;
static void|array __flow_new_cb_data, __flow_exp_cb_data, __flow_log_cb_data, __flow_state_cb_data;
static int _total_bytes;
static int _total_packets;
static int _total_flows;

void create(void|int _max) {
  //flows = Locking.Mapping();
  flows = FlowContainer();
  max = _max;
}

void packet(object ip) {
  total_packets++;
  total_bytes += ip->len;
  string proto;
  if (ip->protocol)
    proto = ip->protocol->name();
  else if (ip->next_header)
    proto = ip->next_header->name();
  switch (proto) {
    case "TCP":
      tcp(ip);
      break;
    case "UDP":
      udp(ip);
      break;
    case "ICMP":
      icmp(ip);
      break;
    case "ICMPv6":
      icmp6(ip);
      break;
  }
}

void set_new_flow_cb(function cb, void|mixed ... data) {
  _flow_new_cb = cb;
  if (data)
    _flow_new_cb_data = data;
}

void set_expired_flow_cb(function cb, void|mixed ... data) {
  _flow_exp_cb = cb;
  if (data)
    _flow_exp_cb_data = data;
}

void set_log_flow_cb(function cb, void|mixed ... data) {
  _flow_log_cb = cb;
  if (data)
    _flow_log_cb_data = data;
#ifdef ENABLE_THREADS
  Thread.thread_create(lambda() { while(1) { sleep(LOG_TICK); log_cb(); } });
#else
  call_out(lambda() { log_cb(); call_out(this_function, 30); }, 30);
#endif
}

void set_flow_statechange_cb(function cb, void|mixed ... data) {
  _flow_state_cb = cb;
  if (data)
    _flow_state_cb_data = data;
}

static void tcp(object ip) {
  object tcp = IP.Protocol.TCP.Packet(ip->data);
  string _hash = hash(ip, tcp);
  if (flows->get(_hash))
    flows->get(_hash)->next(ip, tcp);
  else {
    object flow = IP.Protocol.TCP.Flow(ip, tcp, _hash, exp_cb, state_cb);
    add_flow(_hash, flow);
    //flow->hash(_hash);
    //flow->expire_cb(exp_cb);
    //flow->state_cb(state_cb);
  }
}

static void udp(object ip) {
  object udp = IP.Protocol.UDP.Packet(ip->data);
  string _hash = hash(ip, udp);
  if (flows->get(_hash))
    flows->get(_hash)->next(ip, udp);
  else {
    object flow = IP.Protocol.UDP.Flow(ip, udp, _hash, exp_cb, state_cb);
    add_flow(_hash, flow);
    //flow->hash(_hash);
    //flow->expire_cb(exp_cb);
    //flow->state_cb(state_cb);
  }
}

static void icmp(object ip) {}

static void icmp6(object ip) {}

void add_flow(string hash, object flow) {
  if (max) {
    if (sizeof(flows) < max) {
      flows->set(hash, flow);
      new_cb(hash);
      total_flows++;
    }
    else 
      drop++;
  }
  else {
    flows->set(hash, flow);
    new_cb(hash);
    total_flows++;
  }
}

static void new_cb(mixed hash) {
  if (_flow_new_cb)
    catch(_flow_new_cb(flows->get(hash), @_flow_new_cb_data));
}

static void exp_cb(mixed hash) {
  if (flows->get(hash)) {
    if (_flow_exp_cb)
      catch(_flow_exp_cb(flows->get(hash), @_flow_exp_cb_data));
    exp_count++;
    destruct(flows[hash]);
    flows->rm(hash);
  }
  if (exp_count > sizeof(flows) / 20) {
    // If we've expired > 5% of flows then manually run the GC
    gc();
    exp_count = 0;
  }
}

static void log_cb() {
  if (_flow_log_cb)
    catch(_flow_log_cb(@_flow_log_cb_data));
}

static void state_cb(mixed hash, int oldstate, int newstate) {
  if (_flow_state_cb)
    catch(_flow_state_cb(flows->get(hash), oldstate, newstate, @_flow_state_cb_data));
}


string hash(object ip, object p) {
  string a, b, c, d, f;
  if (ip->next_header) {
    // v6
    if (ip->src < ip->dst) {
      a = sprintf("[%s]", (string)ip->src);
      b = sprintf("[%s]", (string)ip->dst);
      if (p->src_port) {
	c = (string)p->src_port;
	d = (string)p->dst_port;
      }
      else if (p->code) {
	c = (string)p->code;
	d = (string)p->code;
      }
    }
    else {
      b = sprintf("[%s]", (string)ip->src);
      a = sprintf("[%s]", (string)ip->dst);
      if (p->src_port) {
	d = (string)p->src_port;
	c = (string)p->dst_port;
      }
      else if (p->code) {
	d = (string)p->code;
	c = (string)p->code;
      }
    }
  }
  else {
    if (ip->src < ip->dst) {
      a = (string)ip->src;
      b = (string)ip->dst;
      if (p->src_port) {
	c = (string)p->src_port;
	d = (string)p->dst_port;
      }
      else if (p->code) {
	c = (string)p->code;
	d = (string)p->code;
      }
    }
    else {
      b = (string)ip->src;
      a = (string)ip->dst;
      if (p->src_port) {
	d = (string)p->src_port;
	c = (string)p->dst_port;
      }
      else if (p->code) {
	d = (string)p->code;
	c = (string)p->code;
      }
    }
  }
  if (ip->protocol)
    f = ip->protocol->name();
  else if (ip->next_header)
    f = ip->next_header->name();
  else
    f = "UNKNOWN";
  return sprintf("%s %s:%s %s:%s", f, a, c, b, d);
}

object `flows() {
  return _flows;
}

object `flows=(object x) {
  LOCK;
  return _flows = x;
}

int `max() {
  return _max;
}

int `max=(int x) {
  LOCK;
  return _max = x;
}

int `drop() {
  return _drop;
}

int `drop=(int x) {
  LOCK;
  return _drop = x;
}

int `exp_count() {
  return _exp_count;
}

int `exp_count=(int x) {
  LOCK;
  return _exp_count = x;
}

static function `_flow_new_cb() {
  return __flow_new_cb;
}

static function `_flow_new_cb=(function x) {
  LOCK;
  return __flow_new_cb = x;
}

static void|array `_flow_new_cb_data() {
  return __flow_new_cb_data;
}

static void|array `_flow_new_cb_data=(void|array x) {
  return __flow_new_cb_data = x;
}

static function `_flow_exp_cb() {
  return __flow_exp_cb;
}

static function `_flow_exp_cb=(function x) {
  LOCK;
  return __flow_exp_cb = x;
}

static void|array `_flow_exp_cb_data() {
  return __flow_exp_cb_data;
}

static void|array `_flow_exp_cb_data=(void|array x) {
  return __flow_exp_cb_data = x;
}

static function `_flow_log_cb() {
  return __flow_log_cb;
}

static function `_flow_log_cb=(function x) {
  LOCK;
  return __flow_log_cb = x;
}

static void|array `_flow_log_cb_data() {
  return __flow_log_cb_data;
}

static void|array `_flow_log_cb_data=(void|array x) {
  return __flow_log_cb_data = x;
}

static function `_flow_state_cb() {
  return __flow_state_cb;
}

static function `_flow_state_cb=(function x) {
  LOCK;
  return __flow_state_cb = x;
}

static void|array `_flow_state_cb_data() {
  return __flow_state_cb_data;
}

static void|array `_flow_state_cb_data=(void|array x) {
  return __flow_state_cb_data = x;
}

int `total_bytes() {
  return _total_bytes;
}

int `total_bytes=(int x) {
  LOCK;
  return _total_bytes = x;
}

int `total_packets() {
  return _total_packets;
}

int `total_packets=(int x) {
  LOCK;
  return _total_packets = x;
}

int `total_flows() {
  return _total_flows;
}

int `total_flows=(int x) {
  LOCK;
  return _total_flows = x;
}

int `current_flows() {
  return sizeof(flows);
}

int `max_flows() {
  return flows->max;
}

class FlowContainer {

  static mapping flows = ([]);
  static object _mutex = Thread.Mutex();
  static int _max;

  mixed set(mixed idx, mixed val) {
    LOCK;
    flows[idx] = val;
    UNLOCK;
    if (sizeof(flows) > max)
      max = sizeof(flows);
    return val;
  }

  mixed get(mixed idx) {
    return flows[idx];
  }

  void rm(mixed idx) {
    LOCK;
    m_delete(flows, idx);
  }

  int _sizeof() {
    return sizeof(flows);
  }

  array _values() {
    return values(flows);
  }

  int `max() {
    return _max;
  }

  int `max=(int x) {
    LOCK;
    return _max = x;
  }

  mixed cast(string type) {
    switch (type) {
      case "array":
	return values(flows);
      case "int":
	return _sizeof();
    }
  }

}
