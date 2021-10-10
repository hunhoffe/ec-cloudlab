""" EC Profile
Instructions:
TODO
"""

import time

# Import the Portal object.
import geni.portal as portal
# Import the ProtoGENI library.
import geni.rspec.pg as rspec

# Set up parameters
pc = portal.Context()
pc.defineParameter("nodeType", 
                   "Node Hardware Type",
                   portal.ParameterType.NODETYPE, 
                   "c6220",
                   longDescription="A specific hardware type to use for all nodes. This profile has primarily been tested with c6220 and c8220 nodes.")
params = pc.bindParameters()
pc.verifyParameters()
request = pc.makeRequestRSpec()

IMAGE = 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD'

nodes = []
lan = request.LAN()
lan.bandwidth = 10000000

# Create controller node
node = request.RawPC("GCM")
node.disk_image = IMAGE
node.hardware_type = params.nodeType
iface = node.addInterface("if1")
iface.addAddress(rspec.IPv4Address("192.168.6.10", "255.255.255.0"))
lan.addInterface(iface)
nodes.append(node)

# Create 3 worker nodes
for i in range(1,4):
  node = request.RawPC("node-" + str(i))
  node.disk_image = IMAGE
  node.hardware_type = params.nodeType
  iface = node.addInterface("if1")
  iface.addAddress(rspec.IPv4Address("192.168.6." + str(10 - i), "255.255.255.0"))
  lan.addInterface(iface)
  nodes.append(node)

pc.printRequestRSpec()
