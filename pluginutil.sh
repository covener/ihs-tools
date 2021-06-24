#!/bin/bash 

# Wrapper to invoke the PluginCfgGenerator mbean from a dmgr to generate plugin-cfg.xml, propagate plugin-cfg.xml,
# and propagate plugin-key.kdb

# This script must live in $WAS_HOME/bin

binDir=`dirname $0`
. $binDir/setupCmdLine.sh

if [ $# -lt 1 ]; then
  echo "$0 list [ ... wsadmin args ]"
  echo "$0 generate|propagate|propagateKeyring webserver-name webserver-node-name [ ... wsadmin args ]"
  echo "$0 ping|stop|start|restart webserver-name webserver-node-name [ ... wsadmin args ]"
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

if [[ ! $@ == *'-password'* ]];  then
    echo "Checking wsadmin access"
    echo "print ''" | ${WAS_HOME}/bin/wsadmin.sh -lang jython "$@" | grep WASX7246E > /dev/null
    if [ $? -eq 0 ]; then
      echo "$0 You must setup soap.client.props or pass -user ... -password ... to this command"
      exit 1
    fi
fi

echo "Requesting mbean op: $OP"

case $OP in 
   ping|stop|start)
(${WAS_HOME}/bin/wsadmin.sh -lang jython "$@" | sed -e 's/wsadmin>//g') <<ENDHEREDOC
mbean = AdminControl.queryNames("WebSphere:*,process=dmgr,type=WebServer")
args = '[$WAS_CELL $NODE $WEBSERVER]'
print AdminControl.invoke(mbean, '$OP', args)
ENDHEREDOC
;;
   restart)
(${WAS_HOME}/bin/wsadmin.sh -lang jython "$@" | sed -e 's/wsadmin>//g') <<ENDHEREDOC
import time
mbean = AdminControl.queryNames("WebSphere:*,process=dmgr,type=WebServer")
args = '[$WAS_CELL $NODE $WEBSERVER]'
status = AdminControl.invoke(mbean, 'ping', args)

print "$WEBSERVER is %s" % (status)

if status == "RUNNING":
    print "Stopping $WEBSERVER"
    AdminControl.invoke(mbean, 'stop', args)

print "Waiting for $WEBSERVER to stop"
for i in range(10):
    if status == "STOPPED":
        print "$WEBSERVER is stopped, starting"
        AdminControl.invoke(mbean, 'start', args)
        break
    status = AdminControl.invoke(mbean, 'ping', args)
    sleep(i)
else:
   print "Timed out stopping $WEBSERVER"

status = AdminControl.invoke(mbean, 'ping', args)
for i in range(10):
    sleep(i)
    status = AdminControl.invoke(mbean, 'ping', args)
    if status == "STARTED":
        print "$WEBSERVER is started"
        break
else:
   print "Timed out starting $WEBSERVER"
ENDHEREDOC
;;

   *)
(${WAS_HOME}/bin/wsadmin.sh -lang jython "$@" | sed -e 's/wsadmin>//g') <<ENDHEREDOC
mbean = AdminControl.queryNames("WebSphere:*,process=dmgr,type=PluginCfgGenerator")
args = '[%s/config %s %s %s %s]' % ('$USER_INSTALL_ROOT', '$WAS_CELL', '$NODE', '$WEBSERVER', "false" if "$OP" == "generate" else "")
types = '[java.lang.String java.lang.String java.lang.String java.lang.String %s]' % ("java.lang.Boolean" if "$OP" == "generate" else "")
result = AdminControl.invoke(mbean, '$OP', args, types)
AdminConfig.save()
ENDHEREDOC
;;
esac
echo "Done"
