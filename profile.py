""" EC Profile
Instructions:
TODO
"""

import time

# Import the Portal object.
import geni.portal as portal
# Import the ProtoGENI library.
import geni.rspec.pg as rspec

# Profile Configuration Constants
IMAGE = 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD'
WORKER_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cudevopsfall2018-PG0:ElasticContainerTestbed.node-1'
STORAGE = "10GB"
# Based on how IPs are created below, NUM_WORKERS must be < 10
NUM_WORKERS = 3
BANDWIDTH = 10000000

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

# Initial setup
nodes = []
lan = request.LAN()
lan.bandwidth = BANDWIDTH

# Create controller node
node = request.RawPC("GCM")
node.disk_image = IMAGE
node.hardware_type = params.nodeType
nodes.append(node)

# Add controller interface
iface = node.addInterface("if1")
iface.addAddress(rspec.IPv4Address("192.168.6.10", "255.255.255.0"))
lan.addInterface(iface)

# Create 3 worker nodes
for i in range(1,NUM_WORKERS + 1):
  # Create node
  name = "node-{}".format(i)
  node = request.RawPC(name)
  node.disk_image = WORKER_IMAGE
  node.hardware_type = params.nodeType
  nodes.append(node)
  
  # Add interface
  iface = node.addInterface("if1")
  iface.addAddress(rspec.IPv4Address("192.168.6.{}".format(10 - i), "255.255.255.0"))
  lan.addInterface(iface)
  
  # Add extra storage space
  bs = node.Blockstore(name + "-bs", "/mydata")
  bs.size = STORAGE
  bs.placement = "any"

pc.printRequestRSpec()
