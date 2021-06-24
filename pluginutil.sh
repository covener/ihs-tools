#!/bin/bash 

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

# Wrapper to invoke the PluginCfgGenerator mbean from a dmgr to generate plugin-cfg.xml, propagate plugin-cfg.xml,
# and propagate plugin-key.kdb
# This script must live in $WAS_HOME/bin

set -e
binDir=`dirname $0`
. $binDir/setupCmdLine.sh

if [ $# -lt 1 ]; then
  echo "$0 list [ ... wsadmin args ]"
  echo "$0 generate|propagate|propagateKeyring webserver-name webserver-node-name [ ... wsadmin args ]"
  exit 1
fi

OP=$1
if [ $OP = "list" ]; then
(${WAS_HOME}/bin/wsadmin.sh -lang jython -conntype NONE "$@" | sed -e 's/wsadmin>//')<<ENDHEREDOC1
print ""
print AdminTask.listServers('[-serverType WEB_SERVER ]')
ENDHEREDOC1
exit
fi

if [ $# -lt 3 ]; then
  echo "$0 list [ ... wsadmin args ]"
  echo "$0 generate|propagate|propagateKeyring webserver-name webserver-node-name [ ... wsadmin args ]"
  exit 1
fi

WEBSERVER=$2
NODE=$3

shift 3

# Check that the user didn't need to pass credentials as supplicant args, e.g. no soap.client.props

echo "print ''" | ${WAS_HOME}/bin/wsadmin.sh -lang jython "$@" | grep WASX7246E > /dev/null
if [ $? -eq 0 ]; then
  echo "$0 You must setup soap.client.props or pass -user ... -password ... to this command"
  exit 1
fi

(${WAS_HOME}/bin/wsadmin.sh -lang jython "$@" | sed -e 's/wsadmin>//') <<ENDHEREDOC
mbean = AdminControl.queryNames("WebSphere:*,process=dmgr,type=PluginCfgGenerator")
args = '[%s/config %s %s %s %s]' % ('$USER_INSTALL_ROOT', '$WAS_CELL', '$NODE', '$WEBSERVER', "false" if "$OP" == "generate" else "")
types = '[java.lang.String java.lang.String java.lang.String java.lang.String %s]' % ("java.lang.Boolean" if "$OP" == "generate" else "")
result = AdminControl.invoke(mbean, '$OP', args, types)
AdminConfig.save()
ENDHEREDOC

