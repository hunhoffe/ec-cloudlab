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
GCM_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cudevopsfall2018-PG0:ec-gcm'
# GCM_IMAGE = 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD'
NODE_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cu-bison-lab-PG0:ec-node'
STORAGE = "10GB"
# Based on how IPs are created below, NUM_WORKERS must be < 10

BANDWIDTH = 10000000

# Set up parameters
pc = portal.Context()
pc.defineParameter("nodeType", 
                   "Node Hardware Type",
                   portal.ParameterType.NODETYPE, 
                   "c6220",
                   longDescription="A specific hardware type to use for all nodes. This profile has primarily been tested with c6220 and c8220 nodes.")
pc.defineParameter("nodeCount", 
                   "Number of worker (non-GCM) nodes in the experiment. It is recommended that at least 3 be used.",
                   portal.ParameterType.INTEGER, 
                   3)
params = pc.bindParameters()

# Verify parameters
if params.nodeCount > 10:
    perr = portal.ParameterWarning("The way IPs are generated for workers only allows up to 10",['nodeCount'])
    pc.reportError(perr)
elif params.nodeCount < 0:
    perr = portal.ParameterWarning("Negative number of worker nodes selected",['nodeCount'])
    pc.reportError(perr)

pc.verifyParameters()
request = pc.makeRequestRSpec()

# Initial setup
nodes = []
lan = request.LAN()
lan.bandwidth = BANDWIDTH

# Create controller node
node = request.RawPC("GCM")
node.disk_image = GCM_IMAGE
node.hardware_type = params.nodeType

# Add extra storage space
bs = node.Blockstore("GCM-bs", "/mydata")
bs.size = STORAGE
bs.placement = "any"

nodes.append(node)

# Add controller interface
iface = node.addInterface("if1")
iface.addAddress(rspec.IPv4Address("192.168.6.10", "255.255.255.0"))
lan.addInterface(iface)

# Create 3 worker nodes
for i in range(1,params.nodeCount + 1):
  # Create node
  name = "node-{}".format(i)
  node = request.RawPC(name)
  node.disk_image = NODE_IMAGE
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
