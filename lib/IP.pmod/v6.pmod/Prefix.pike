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
 * The Original Code is IP.v6 Public Module.
 *
 * The Initial Developer of the Original Code is
 * James Harton, <james@mashd.cc>.
 * Portions created by the Initial Developer are Copyright (C) 2005-2009
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *   Bill Welliver <hww3@riverweb.com>.
 *
 * ***** END LICENSE BLOCK ***** */

//! This module describes an IP prefix, ie a network/netmask pair.


static object _mutex = Thread.Mutex();
#define LOCK object __key = _mutex->lock(1)
#define UNLOCK destruct(__key)
static object _ip;
static object _mask;
static int _len;
static inherit "helpers";

//! Clone the IP.v6.Prefix module.
//!
//! @param prefix
//!    The IP prefix in the CIDR format (ie x.x.x.x/m)
//!
void create(string prefix) {
  string _ip, _mask;
  _ip = (prefix / "/")[0];
  _mask = (prefix / "/")[1];
  ip = IP.v6.Address(_ip);
  if (sizeof(_mask / ".") == 1) {
    len = (int)_mask;
    mask = IP.v6.Address(lengthtoint((int)_mask));
  }
  else {
    mask = IP.v6.Address(_mask);
    len = masktolength(mask);
  }
}

IP.v6.Address eui_64(int|string mac) {
  if (len != 64) 
    throw(Error.Generic("Can only generate EUI-64 address for a 64 bit prefix."));
  if (intp(mac))
    mac = sprintf("%:012x", mac);
  mac = lower_case((mac / ":") * "");
  if (sizeof(array_sscanf(mac, "%{%1x%}")[0]) != 12)
    throw(Error.Generic("Not a valid 48 bit MAC address."));
  mac = mac[0..5] + "fffe" + mac[6..11];
  int e64;
  sscanf(mac, "%16x", e64);
  e64 = e64 ^ 0x0200000000000000;
  return IP.v6.Address((int)network() + e64);
}

static IP.v6.Address `ip() {
  return _ip;
}

static IP.v6.Address `ip=(IP.v6.Address x) {
  LOCK;
  return _ip = x;
}

static IP.v6.Address `mask() {
  return _mask;
}

static IP.v6.Address `mask=(IP.v6.Address x) {
  LOCK;
  return _mask = x;
}

static int `len() {
  return _len;
}

static int `len=(int x) {
  LOCK;
  return _len = x;
}

string _sprintf() {
  return sprintf("IP.v6.Prefix(\"%s/%d\")", (string)network(), len);
}

void|string cast(string type) {
  switch(type) {
  case "string":
    return sprintf("%s/%d", (string)ip, len);
  }
}

//! Get the network address of this prefix.
IP.v6.Address network() {
  return IP.v6.Address(::network((int)ip, (int)mask));
}

//! Get the highest address of this prefix.
IP.v6.Address highest() {
  return IP.v6.Address(::highest((int)ip, (int)mask));
}

//! Get the length of this prefix (ie, number of "on" bits in the mask).
int(0..128) length() {
  return len;
}

//! Get the address space available within this prefix.
int space() {
  // like sizeof() we need to add one.
  return ((int)highest() - (int)network()) + 1;
}

//! Return the reverse zones for this prefix.
array reverse() {
  // calculate all the reverse zones for a given network prefix.
  int boundary = length() % 16 == 0 && length() != 0 ? length() / 4 - 1 : length() / 4;
  int divisor = (boundary + 1) *4;
  int count = ((int)highest() - (int)network()) / (1 << 128-divisor);
  //write("boundary = %d\ndivisor= %d\ncount = %d\n", boundary, divisor, count);
  array res = ({});
  for (int i = 0; i <= count; i++) {
    object baseaddr = IP.v6.Address((int)network() + ((1<<128-divisor)*i));
    array octets = (sprintf("%:032x", (int)baseaddr) / "")[0..boundary];
    res += ({ sprintf("%{%s.%}ip6.arpa", predef::reverse(octets)) });
  }
  return res;
}

//! Test if an IP address is inside this prefix.
//! Returns 1 if true, 0 otherwise.
//!
//! @param test
//!    The IP address to test.
//!
int(0..1) contains(IP.v6.Address|IP.v6.Prefix test) {
  if (test->network)
    return (test->network() >= network() && test->highest() <= highest());
  else
    return (test >= network() && test <= highest());
}

int(0..1) `==(IP.v6.Prefix test) {
  return (test->network() == network() && test->highest() == highest());
}

int(0..1) `<(IP.v6.Prefix test) {
  return (test->network() > network() && test->highest() < highest());
}

int(0..1) `<=(IP.v6.Prefix test) {
  return (test->network() >= network() && test->highest() <= highest());
}

int(0..1) `>(IP.v6.Prefix test) {
  return (test->network() < network() && test->highest() > highest());
}

int(0..1) `>=(IP.v6.Prefix test) {
  return (test->network() <= network() && test->highest() >= highest());
}
