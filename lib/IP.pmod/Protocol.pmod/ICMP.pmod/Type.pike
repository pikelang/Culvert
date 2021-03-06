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
static int __type;
static mapping types = ([
    0 : "ECHOREP",
    3 : "DESTUNREACH",
    4 : "SOURCEQUENCH",
    5 : "REDIRECT",
    6 : "ALTHOST",
    8 : "ECHOREQ",
    9 : "RA",
    10 : "RS",
    11 : "TTLEX",
    12 : "PARAMPROB",
    13 : "TIMEREQ",
    14 : "TIMEREP",
    15 : "INFOREQ",
    16 : "INFOREP",
    17 : "ADDRMASKREQ",
    18 : "ADDRMASKREP",
    30 : "TRACERT",
    31 : "CONVERR",
    32 : "MOBHOSTREDIR",
    33 : "IPV6WHEREAREYOU",
    34 : "IPV6IAMHERE",
    35 : "MOBREGREQ",
    36 : "MOBREGREP",
    37 : "DOMAINREQ",
    38 : "DOMAINREP",
    39 : "SKIP",
    40 : "PHOTURIS",
    41 : "EXTMOB",
  ]);

void create(int|string type) {
  if (intp(type))
    _type = type;
  else if (stringp(type)) {
    mapping tmp = mkmapping(values(types), indices(types));
    if (tmp[type])
      _type = tmp[type];
  }
}

int numeric() {
  return _type;
}

string hex() {
  return sprintf("0x%0:4x", _type);
}

void|string name() {
  if (types[_type])
    return types[_type];
  else
    return "UNKNOWN";
}

string _sprintf() {
  return sprintf("IP.Protocol.ICMP.Type(%O)", name());
}

static int `_type() {
  return __type;
}

static int `_type=(int x) {
  LOCK;
  return __type = x;
}
