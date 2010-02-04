#!/usr/local/bin/pike -Mlib/

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

#ifdef DISABLE_THREADS
#undef ENABLE_THREADS
constant threads = 0;
#else
#define ENABLE_THREADS
constant threads = 10;
#endif
constant snaplen = 68;
constant options =
  ({
    ({ "interface", Getopt.HAS_ARG, ({ "-i", "--interface" }) }),
    ({ "logfile", Getopt.HAS_ARG, ({ "-l", "--log-file" }) }),
    ({ "filter", Getopt.HAS_ARG, ({ "-f", "--filter" }) }),
    ({ "snaplen", Getopt.HAS_ARG, ({ "-s", "--snaplen" }) }),
    ({ "help", Getopt.NO_ARG, ({ "-h", "--help" }) }),
    ({ "threads", Getopt.HAS_ARG, ({ "-t", "--threads" }) }),
  });

array flow_setup_times = ({});

int main(int argc, array argv) {

  mapping args = (mapping)Getopt.find_all_options(argv, options, 0);

  if (args->help) {
    werror("No help for you. Sorry.\n\n");
    return 1;
  }
  if (!args->interface) {
    werror("You must specify an interface to listen on.\n\n");
    return 1;
  }
  if (args->threads)
    args->threads = (int)args->threads;
  if (args->snaplen)
    args->snaplen = (int)args->snaplen;

#ifdef ENABLE_THREADS
  if ((!args->threads) || (args->threads == 0))
    args->threads = threads;
#endif

  //object queue = Thread.Fifo(2000);
  object queue = Thread.Fifo(args->threads);
  //object queue = Thread.Queue();


  object fe = IP.Flow.Engine();
#ifdef ENABLE_THREADS
  write("Culvert %d.%d-%s started with %d worker threads.\n\n", Culvert.MAJOR, Culvert.MINOR, Culvert.BRANCH, args->threads);
#else
  write("Culvert %d.%d-%s started.\n\n", Culvert.MAJOR, Culvert.MINOR, Culvert.BRANCH);
#endif
  //if (!args->nodns) 
    //fe->set_new_flow_cb(precache_dns, queue);
  if (args->logfile) {
    object logfile = Stdio.File(args->logfile, "cwa");
    fe->set_expired_flow_cb(log, queue, logfile, !args->nodns);
  }
  else
    fe->set_expired_flow_cb(time_tcp_session);
  //fe->set_flow_statechange_cb(lambda(mixed f, int o, int n) { write("%s\n", f->english(!args->nodns,1)); } );

  object cap = Public.Network.Pcap.Pcap();
  cap->set_capture_length(args->snaplen||snaplen);
  cap->set_capture_timeout(10);
  mixed err = catch(cap->open_live(args->interface));
  if (err) {
    werror("Unable to open packet capture interface:\n");
    array tmp = (err[0] / ":")[1..];
    werror("%{%s%}\n", tmp);
    return 1;
  }
  if (args->filter)
    cap->set_filter(args->filter);
  else 
    // We can only decode TCP and UDP flows at the moment anyway.
    cap->set_filter("tcp");
  cap->set_promisc(1);
  if (args->threads) {
    for (int i=0; i < args->threads; i++) {
      Thread.thread_create(dequeue, queue);
    }
    Thread.thread_create(dispatch, cap, queue, fe);
  }
  else {
    werror("Can't run with no threads, for now.\n\n");
    return 1;
    dispatch(cap,queue,fe);
  }

  return -1;
}

void dispatch(object cap, object queue, object fe) {
  while(1) {
  //for (int i; i < 10; i++) {
    mixed c = cap->next();
    if (mappingp(c)) {
      queue->write(({ desplat, fe, c }));
    }
  }
}

void dequeue(object queue) {
  while(1) {
    mixed c = queue->read();
    if (sizeof(c) > 1)
      c[0](@c[1..]);
    else
      c[0]();
  }
}

void precache_dns(object flow, object queue) {
#ifdef ENABLE_THREADS  
  queue->write(({ IP.Flow.DNSCache->lookup_ip,(string)flow->src }));
  queue->write(({ IP.Flow.DNSCache->lookup_ip,(string)flow->dst }));
#else
  catch(IP.Flow.DNSCache->lookup_ip((string)flow->src));
  catch(IP.Flow.DNSCache->lookup_ip((string)flow->dst));
#endif
}

void log(object flow, object queue, object logfile, int dns) {
#ifdef ENABLE_THREADS
  queue->write(({ lambda() { catch(logfile->write("%s\n", flow->english(dns, 1))); } }));
  queue->write(({ lambda() { time_tcp_session(flow); }}));
#else
  catch(logfile->write("%s\n", flow->english(dns, 1)));
  time_tcp_session(flow);
#endif
}

void desplat(object fe, mixed ... args) {
  object frame = Ethernet.Packet(args[0]->data);
  if (frame->type->name() == "IPv4") {
    object packet;
    mixed err = catch(packet = IP.v4.Packet(frame->data, 1));
    if (err)
      write("%O\n", err);
    else {
      if (packet->protocol->name() == "IPv6") {
	object sixtofour;
	mixed err = catch(sixtofour = IP.v6.Packet(packet->data, 1));
	if (err)
	  write("%O\n", err);
	fe->packet(sixtofour);
      }
      else 
	fe->packet(packet);
    }
  }
  else if (frame->type->name() == "IPv6") {
    object packet;
    mixed err = catch(packet = IP.v6.Packet(frame->data, 1));
    if (err)
      write("%O\n", err);
    else
      fe->packet(packet);
  }
}

void time_tcp_session(object flow) {
  if (sizeof(flow->conversation) > 1) {
    float first = flow->conversation[0]->time;
    float second = flow->conversation[1]->time;
    float setup_time = second - first;
    flow_setup_times += ({ setup_time });
    if (sizeof(flow_setup_times) == 1) {
      setup_time_report();
    }
  }
}

void setup_time_report() {
  write("Average flow setup time %fms.\n", (`+(@flow_setup_times)/sizeof(flow_setup_times)) * 100);
  call_out(setup_time_report, 10);
}
