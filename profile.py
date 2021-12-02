""" EC Profile
Instructions:
Once all nodes have startup state 'finished', your experiment is ready (this may take >10 minutes). 
To download EC-specific github repos, install your github ssh key at all nodes. 
On the GCM run the gcm_setup.py script. On the workers run the node_setup.py script.
If you suspect something has gone wrong with the experiment, the first place to look is in the start.log file in /local/repository or /home/ec.
"""

import time

# Import the Portal object.
import geni.portal as portal
# Import the ProtoGENI library.
import geni.rspec.pg as rspec

# Profile Configuration Constants
GCM_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cudevopsfall2018-PG0:ec-github.GCM'
#NODE_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cu-bison-lab-PG0:ec-node'
NODE_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+cudevopsfall2018-PG0:ec-node-srvrlss'
DEFAULT_STORAGE = 10
NODE_TYPE = 'c6220'
# Based on how IPs are created below, NUM_WORKERS must be < 10

BANDWIDTH = 10000000

# Set up parameters
pc = portal.Context()
pc.defineParameter("nodeType", 
                   "Node Hardware Type (only c6220 supported)",
                   portal.ParameterType.STRING, 
                   NODE_TYPE,
                   legalValues=[NODE_TYPE],
                   longDescription="A specific hardware type to use for all nodes. TODO: add support for c8220 nodes.")
pc.defineParameter("nodeCount", 
                   "Number of worker nodes",
                   portal.ParameterType.INTEGER, 
                   3,
                   min=1,
                   max=9,
                   longDescription="Number of worker (non-GCM) nodes in the experiment. It is recommended that at least 3 be used.")
pc.defineParameter("gcmExtraStorage",
                   "GB extra storage on GCM node",
                   portal.ParameterType.INTEGER,
                   DEFAULT_STORAGE,
                   min=10,
                   max=100,
                   longDescription="Amount of extra storage in GB mounted at /mydata on the GCM Node. This will be used for docker images as well as general purpose storage.")
pc.defineParameter("nodeExtraStorage",
                   "GB extra storage per node",
                   portal.ParameterType.INTEGER,
                   DEFAULT_STORAGE,
                   min=10,
                   max=100,
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
if not params.startKubernetes and params.deployOpenWhisk:
    perr = portal.ParameterWarning("The Kubernetes Cluster must be created in order to deploy OpenWhisk",['startKubernetes'])
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
  node.hardware_type = params.nodeType
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
