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
GCM_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cudevopsfall2018-PG0:ec-github.GCM'
#GCM_IMAGE = 'urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD'
NODE_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cu-bison-lab-PG0:ec-node'
STORAGE = 10
NODE_TYPE = 'c6220'
# Based on how IPs are created below, NUM_WORKERS must be < 10

BANDWIDTH = 10000000

# Set up parameters
pc = portal.Context()
'''
pc.defineParameter("nodeType", 
                   "Node Hardware Type",
                   portal.ParameterType.NODETYPE, 
                   "c6220",
                   longDescription="A specific hardware type to use for all nodes. This profile has primarily been tested with c6220 and c8220 nodes.")
'''
pc.defineParameter("nodeCount", 
                   "Number of worker nodes",
                   portal.ParameterType.INTEGER, 
                   3,
                   longDescription="Number of worker (non-GCM) nodes in the experiment. It is recommended that at least 3 be used.")
pd.defineParameter("gcmExtraStorage",
                   "GB extra storage on GCM node (choose 0 < n < 100)",
                   portal.ParameterType.INTEGER,
                   DEFAULT_STORAGE,
                   longDescription="Amount of extra storage in GB mounted at /mydata on the GCM Node. This will be used for docker images as well as general purpose storage.")
pd.defineParameter("nodeExtraStorage",
                   "GB extra storage per node (choose 0 < n < 100)",
                   portal.ParameterType.INTEGER,
                   DEFAULT_STORAGE,
                   longDescription="Amount of extra storage in GB mounted at /mydata on the worker nodes. This will be used for docker images as well as general purpose storage.")
pc.defineParameter("startKubernetes",
                   "Create Kubernetes cluster",
                   portal.ParameterType.BOOLEAN,
                   True,
                   longDescription="Create a Kubernetes cluster using default image setup")
pc.defineParameter("deployOpenWhisk",
                   "Deploy OpenWhisk",
                   portal.ParameterType.BOOLEAN,
                   True,
                   longDescription="Use helm to deploy OpenWhisk.")
params = pc.bindParameters()

# Verify parameters
if params.nodeCount > 10:
    perr = portal.ParameterWarning("The way IPs are generated for workers only allows up to 10",['nodeCount'])
    pc.reportError(perr)
if params.nodeCount < 0:
    perr = portal.ParameterWarning("Negative number of worker nodes selected",['nodeCount'])
    pc.reportError(perr)
if not params.startKubernetes and params.deployOpenWhisk:
    perr = portal.ParameterWarning("The Kubernetes Cluster must be created in order to deploy OpenWhisk",['startKubernetes'])
    pc.reportError(perr)
if params.gcmExtraStorage < 0 || params.gcmExtraStorage > 100:
    perr = portal.ParameterWarning("GCM extra storage out of bounds, must be > 0 and < 100.",['gcmExtraStorage'])
    pc.reportError(perr)
if params.nodeExtraStorage < 0 || params.nodeExtraStorage > 100:
    perr = portal.ParameterWarning("Node extra storage out of bounds, must be > 0 and < 100.",['nodeExtraStorage'])
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
node.hardware_type = NODE_TYPE

# Add extra storage space
bs = node.Blockstore("GCM-bs", "/mydata")
bs.size = str(params.gcmExtraStorage) + "GB"
bs.placement = "any"

nodes.append(node)

# Add controller interface
iface = node.addInterface("if1")
iface.addAddress(rspec.IPv4Address("192.168.6.10", "255.255.255.0"))
lan.addInterface(iface)

# Creat worker nodes
for i in range(1,params.nodeCount + 1):
  # Create node
  name = "node-{}".format(i)
  node = request.RawPC(name)
  node.disk_image = NODE_IMAGE
  node.hardware_type = NODE_TYPE
  nodes.append(node)
  
  # Add interface
  iface = node.addInterface("if1")
  iface.addAddress(rspec.IPv4Address("192.168.6.{}".format(10 - i), "255.255.255.0"))
  lan.addInterface(iface)
  
  # Add extra storage space
  bs = node.Blockstore(name + "-bs", "/mydata")
  bs.size = str(params.nodeExtraStorage) + "GB"
  bs.placement = "any"

# Run start script on worker nodes
for i, node in enumerate(nodes[1:]):
  node.addService(rspec.Execute(shell="bash", command="/local/repository/start.sh secondary 192.168.6.{} true > /local/repository/start.log &".format(
      9 - i, params.startKubernetes)))

# Run start script on GCM
nodes[0].addService(rspec.Execute(shell="bash", command="/local/repository/start.sh primary 192.168.6.10 {} {} {} {} > /home/ec/start.log".format(
    params.nodeCount, params.startKubernetes, params.deployOpenWhisk, params.nodeCount)))

pc.printRequestRSpec()
