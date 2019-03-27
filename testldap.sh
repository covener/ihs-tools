#!/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This script uses ldapsearch on z/OS to validate an LDAP user in a way similar to
# Apache/IHS authentication would.

# Specify the equivalent of AuthLDAPBindDN/password here.

LDAPSEARCH="ldapsearch -Dcn=serverid -w whatever"
#LDAPSEARCH=ldapsearch

if [ $# -ne 3 ]; then
  echo "$0 AuthLDAPURL web-username ldap-password";
  exit 1
fi

URL=$1
IN_CN=$2
IN_PASS=$3

# https://stackoverflow.com/questions/6174220/parse-url-in-shell-script
parse_url() {
  eval $(echo "$1" | sed -e "s#^\(\(.*\)://\)\?\(\([^:@]*\)\(:\(.*\)\)\?@\)\?\([^/?]*\)\(/\(.*\)\)\?#${PREFIX:-URL_}SCHEME='\2' ${PREFIX:-URL_}USER='\4' ${PREFIX:-URL_}PASSWORD='\6' ${PREFIX:-URL_}HOST='\7' ${PREFIX:-URL_}PORT='\8'  ${PREFIX:-URL_}PATH='\9'#")
}

PREFIX="URL_" parse_url "$URL"

BASEDN=`echo $URL_PATH | awk -F'?' '{ print $1}'`
ATTR=`echo $URL_PATH | awk -F'?' '{ print $2}'`
SCOPE=`echo $URL_PATH | awk -F'?' '{ print $3}'`
HOST=`echo $URL_HOST | awk -F':' '{print $1}'`
PORT=`echo $URL_HOST | awk -F':' '{print $2}'`
if [ -z $PORT ]; then
  PORT=389
fi

echo "$URL_SCHEME://$URL_USER:$URL_PASSWORD@$URL_HOST/$URL_PATH"


echo "TEST1: Checking for unique DN belonging to $IN_CN under base $BASEDN"
echo "  cmd: $LDAPSEARCH -h $HOST -p $PORT -b $BASEDN -s $SCOPE $ATTR=$IN_CN dn"
OUT=`$LDAPSEARCH -h $HOST -p $PORT -b $BASEDN -s $SCOPE $ATTR=$IN_CN dn`
OUT_COUNT=`echo $OUT|wc -l|sed -e 's/ *//g'`
if [ $OUT_COUNT != "1" ]; then
  echo  " NOK: Got $OUT_COUNT results for DN lookup, something is fishy"
else
  echo "  OK: DN lookup got 1 result: '$OUT'"
fi

echo "TEST2: Checking login with retrieved DN=$OUT"
echo "  cmd: ldapsearch -D$OUT -w$IN_PASS -h $HOST -p $PORT -b $BASEDN -s $SCOPE $ATTR=$IN_CN dn"
OUT2=`ldapsearch -D$OUT -w$IN_PASS -h $HOST -p $PORT -b $BASEDN -s $SCOPE $ATTR=$IN_CN dn`
if [ $? -ne 0 ]; then
  echo "  NOK: ldapsearch w/ users credentials failed with rc $?: '$OUT2'"
  exit 1
fi

OUT2_COUNT=`echo $OUT2|wc -l|sed -e 's/ *//g'`
if [ $OUT_COUNT != "1" ]; then
  echo  "  NOK: Got $OUT_COUNT results for DN lookup unser users creds, something is fishy: $OUT2"
else
  echo "  OK: DN lookup with user creds returned 1 result: '$OUT2'"
fi
