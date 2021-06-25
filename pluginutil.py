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


  Pass this script to wsadmin the following way to run one of the sub-options

   1. copy this script to $WAS_HOME/bin
   2. ./wsadmin.sh -lang jython [-user ... -password  ...] -f pluginutil.py -- list|genproprestart|restart|generate|propagate|propagateKeyring webserver-name [webserver-node-name]

"""

import sys
import time
import os
import re


def usage():
  print "Usage: genpropall|restart|generate|propagate|propagateKeyring webserver-name [webserver-node-name] "
  sys.exit(1)

def main():
  if len(sys.argv) <=  1:
    usage()

  OP = sys.argv[0]
  if OP == "list":
    print AdminTask.listServers('[-serverType WEB_SERVER ]')
    return 0
  
  if len(sys.argv) < 2:
    usage()
  
  WEBSERVER=sys.argv[1]
  DMGRROOT=os.environ['CONFIG_ROOT']
  CELL = wsadminlib.getNameFromId(AdminConfig.list("Cell"))
  NODE=""

  # If the webserver name is unique, we can determine the node
  if len(sys.argv) == 2:
    servers = BetterAdminTask.listServers('WEB_SERVER')
    nodematches = [s for s in servers if s.name == WEBSERVER]
    if len(nodematches) == 1:
       NODE = nodematches[0].node
    elif len(nodematches) > 1:
      print "Too many matches for webservername, specify a node on the command line " + nodematches
      sys.exit(1)
    else: 
      print "No matches for webservername"
      sys.exit(1)

  if NODE == "": 
    NODE=sys.argv[2]

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
  
class wsadminlib:
  @staticmethod
  def splitlines(s):
    rv = [s]
    if '\r' in s:
      rv = s.split('\r\n')
    elif '\n' in s:
      rv = s.split('\n')
    if rv[-1] == '':
      rv = rv[:-1]
    return rv
  @staticmethod
  def getNameFromId(obj_id):
    name = obj_id
    ix = obj_id.find('(')
    if ix != -1 :
        name = obj_id[0:ix]
    return name
  @staticmethod
  def showAttribute(id, attrname):
    return AdminConfig.showAttribute(id, attrname)

class Server:
   def __init__(self,name, node, t):
      self.name = name
      self.node = node
      self.t = t
   def __str__(self):
     return self.name + "," + self.node + "," + self.t
   def __repr__(self):
    return str(self)

class BetterAdminTask:
  @staticmethod
  def list(objectType, pattern):
    wsadminlib.splitlines(AdminConfig.list(objectType, pattern))
  @staticmethod
  def listServers(t):
    rv = []
    servers = AdminTask.listServers('[-serverType %s]' % t)
    lines = wsadminlib.splitlines(servers)
    for server in lines:
      m = re.search('^(.+)\\(cells/[^/]+/nodes/([^/]+).*', server)
      if m is not None:
        rv.append(Server(m.group(1), m.group(2), t))
      else: 
        print server + " did not match"
    return rv

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
  args = '[%s %s %s]' %(cell, node, webserver)
  status = AdminControl.invoke(mbean, 'ping', args)
  print "WebServer %s is %s" % (webserver, status)

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

 
if __name__ == "__main__":
    main()

