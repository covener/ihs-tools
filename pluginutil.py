"""
   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.


  Pass this script to wsadmin the following way, substituting a list of webserver IP addresses as the final argument:

   1. copy this script to $WAS_HOME/bin
   2. ./wsadmin.sh -lang jython [-user ... -password  ...] -f pluginutil.py -- genproprestart|restart|generate|propagate|propagateKeyring webserver-name webserver-node-name

"""

import sys
import time

def getNameFromId(obj_id):
    """Returns the name from a wsadmin object id string.

    For example, returns PAP_1 from the following id:
    PAP_1(cells/ding6Cell01|coregroupbridge.xml#PeerAccessPoint_1157676511879)

    Returns the original id string if a left parenthesis is not found.
    """
    # print "getNameFromId: Entry. obj_id=" + obj_id
    name = obj_id
    ix = obj_id.find('(')
    # print "getNameFromId: ix=%d" % (ix)
    if ix != -1 :
        name = obj_id[0:ix]

    # print "getNameFromId: Exit. name=" + name
    return name

def PluginCfgGenerator(dmgrroot, cell, node, webserver, op):
  mbean = AdminControl.queryNames("WebSphere:*,process=dmgr,type=PluginCfgGenerator")
  if op == "generate":
    args = '[%s %s %s %s %s]' % (dmgrroot, cell, node, webserver, "false")
    types = '[java.lang.String java.lang.String java.lang.String java.lang.String java.lang.Boolean]'
  else:
    args = '[%s %s %s %s]' % (dmgrroot, cell, node, webserver)
    types = '[java.lang.String java.lang.String java.lang.String java.lang.String]'

  result = AdminControl.invoke(mbean, op, args, types)
  AdminConfig.save()

def webserver_restart(dmgrroot, cell, node, webserver):
  mbean = AdminControl.queryNames("WebSphere:*,process=dmgr,type=WebServer")
  args = '[%s %s %s]' %(CELL, NODE, WEBSERVER)
  status = AdminControl.invoke(mbean, 'ping', args)
  print "WebServer %s is %s" % (WEBSERVER, status)

  if status == "RUNNING":
    print "Stopping"
    AdminControl.invoke(mbean, 'stop', args)
    status = AdminControl.invoke(mbean, 'ping', args)
    if status != "STOPPED":
      print "Waiting for webserver to stop, status is %s" % status
    for i in range(10):
      if status == "STOPPED":
        print "WebServer is stopped"
        break
        status = AdminControl.invoke(mbean, 'ping', args)
        sleep(i)
  if status != "STOPPED":
    print "Failed to stop WebServer, status is %s" % status

  print "Starting"
  AdminControl.invoke(mbean, 'start', args)
  for i in range(10):
    status = AdminControl.invoke(mbean, 'ping', args)
    if status == "RUNNING":
      print "WebServer is started"
      break
    sleep(i)
  if status != "RUNNING":
    print "Failed to start WebServer"
  print "WebServer status is %s" % status

def main():
  if len(sys.argv) <=  1:
    print "Usage: restart|generate|propagate|propagateKeyring dmgr-config webserver-name webserver-node-name " % (sys.argv[0])

OP = sys.argv[0]
print OP
if OP == "list":
  print AdminTask.listServers('[-serverType WEB_SERVER ]')
  sys.exit(0)


print sys.argv
if len(sys.argv) <  4:
  print "Usage:  %s genpropall|restart|generate|propagate|propagateKeyring dmgr-config webserver-name webserver-node-name " % (sys.argv[0])
  sys.exit(1)

DMGRROOT=sys.argv[1]
WEBSERVER=sys.argv[2]
NODE=sys.argv[3]

CELL = getNameFromId(AdminConfig.list("Cell"))

if OP == "restart":
  webserver_restart(DMGRROOT, CELL, NODE, WEBSERVER)
elif OP == "generate" or OP == "propagate" or OP == "propagateKeyring":
  PluginCfgGenerator(DMGRROOT, CELL, NODE, WEBSERVER, OP)
elif OP == "genproprestart":
  print "Generate"
  PluginCfgGenerator(DMGRROOT, CELL, NODE, WEBSERVER, "generate")
  print "Propagate"
  PluginCfgGenerator(DMGRROOT, CELL, NODE, WEBSERVER, "propagate")
  print "Propagate Keyring"
  PluginCfgGenerator(DMGRROOT, CELL, NODE, WEBSERVER, "propagateKeyring")
  print "Restart"
  webserver_restart(DMGRROOT, CELL, NODE, WEBSERVER)
else: 
  print "Unknown operation %s" %(OP)




