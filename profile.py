""" ESCRA on CloudLab
Instructions:
Once all nodes have startup state 'finished', your experiment is ready (this may take >10 minutes). 
To download EC-specific github repos, install your github ssh key at all nodes. 
On the GCM run the gcm_setup.py script. On the workers run the node_setup.py script. 
On both, you'll need to run "source ~/.bashrc" (just once) to populate environment variables.
If you suspect something has gone awry, the first place to look is in the start.log file in /local/repository.
"""

import time

# Import the Portal object.
import geni.portal as portal
# Import the ProtoGENI library.
import geni.rspec.pg as rspec

# Profile Configuration Constants
GCM_IMAGE = 'urn:publicid:IDN+apt.emulab.net+image+escra-PG0:ec-gcm:5'
NODE_IMAGES = {
  'c6220': 'urn:publicid:IDN+apt.emulab.net+image+escra-PG0:ec-node-c6220:0',
  'c220g5': 'urn:publicid:IDN+wisc.cloudlab.us+image+escra-PG0:ec-node-c220g5:0',
  'c220g2': 'urn:publicid:IDN+wisc.cloudlab.us+image+escra-PG0:ec-node-c220g2:0',
  'rs620': 'urn:publicid:IDN+cloudlab.umass.edu+image+escra-PG0:ec-node-rs620:0',
}
BANDWIDTH = 10000000

# Set up parameters
pc = portal.Context()
pc.defineParameter("nodeType", 
                   "Node Hardware Type",
                   portal.ParameterType.STRING, 
                   NODE_IMAGES.keys()[0],
                   legalValues=NODE_IMAGES.keys(),
                   longDescription="A specific hardware type to use for all nodes.")
pc.defineParameter("workerCount", 
                   "Number of ESCRA worker nodes",
                   portal.ParameterType.INTEGER, 
                   3,
                   min=1,
                   max=9,
                   longDescription="Number of worker (non-GCM) nodes in the experiment. It is recommended that at least 3 be used.")
pc.defineParameter("owNodes", 
                   "Number of OpenWhisk infrastructure nodes",
                   portal.ParameterType.INTEGER, 
                   0,
                   min=0,
                   max=9,
                   longDescription="Number of nodes to run OpenWhisk infrastructure on. If zero, OpenWhisk will NOT be deployed. If >1 OpenWhisk will be deployed")

# Below two options copy/pasted directly from small-lan experiment on CloudLab
# Optional ephemeral blockstore
pc.defineParameter("tempFileSystemSize", 
                   "Temporary Filesystem Size",
                   portal.ParameterType.INTEGER, 
                   0,
                   advanced=True,
                   longDescription="The size in GB of a temporary file system to mount on each of your " +
                   "nodes. Temporary means that they are deleted when your experiment is terminated. " +
                   "The images provided by the system have small root partitions, so use this option " +
                   "if you expect you will need more space to build your software packages or store " +
                   "temporary files. 0 GB indicates maximum size.")
pc.defineParameter("startKubernetes",
                   "Create Kubernetes cluster",
                   portal.ParameterType.BOOLEAN,
                   True,
                   advanced=True,
                   longDescription="Create a Kubernetes cluster using default image setup")
params = pc.bindParameters()

# Verify parameters
if params.tempFileSystemSize < 0 or params.tempFileSystemSize > 200:
    pc.reportError(portal.ParameterError("Please specify a size greater then zero and " +
                                         "less then 200GB", ["tempFileSystemSize"]))
if not params.startKubernetes and params.owCound > 0:
    perr = portal.ParameterWarning("The Kubernetes Cluster must be created in order to deploy OpenWhisk",['startKubernetes'])
    pc.reportError(perr)
if params.owNodes + params.workerCount >= 9:
    perr = portal.ParameterWarning("The total number of worker nodes (workerCount + owNodes) must be less than 10", ["owNodes"])
    pc.reportError(perr)
pc.verifyParameters()
request = pc.makeRequestRSpec()

def add_blockstore(node, name):
  bs = node.Blockstore(name + "-bs", "/mydata")
  bs.size = str(params.tempFileSystemSize) + "GB"
  bs.placement = "any"

def create_worker(name, nodes):
  # Create node
  node = request.RawPC(name)
  node.disk_image = NODE_IMAGES.get(params.nodeType)
  node.hardware_type = params.nodeType
  
  # Add interface
  iface = node.addInterface("if1")
  iface.addAddress(rspec.IPv4Address("192.168.6.{}".format(1 + len(nodes)), "255.255.255.0"))
  lan.addInterface(iface)
  
  # Add extra storage space
  add_blockstore(node, name + "-bs")
  
  # Add to node list
  nodes.append(node)

# Initial setup
nodes = []
lan = request.LAN()
lan.bandwidth = BANDWIDTH

# Create controller node
node = request.RawPC("GCM")
node.disk_image = GCM_IMAGE
node.hardware_type = params.nodeType
add_blockstore(node, "GCM-bs")

nodes.append(node)

# Add controller interface
iface = node.addInterface("if1")
iface.addAddress(rspec.IPv4Address("192.168.6.1", "255.255.255.0"))
lan.addInterface(iface)

# Create worker nodes, starting with index at 1 to get node-1, node-2, ...
for i in range(1, params.workerCount + 1):
  # Create node
  name = "node-{}".format(i)
  create_worker(name, nodes)

# Create openwhisk worker nodes, starting with index at 1 to get ow-1, ow-2, ...
for i in range(1, params.owNodes + 1):
  # Create node
  name = "ow-{}".format(i)
  create_worker(name, nodes)

# Run start script on worker nodes; first node in list is GCM so ignore that node here
for i, node in enumerate(nodes[1:]):
  node.addService(rspec.Execute(shell="bash", command="/local/repository/start.sh secondary 192.168.6.{} {} 2>&1 > /local/repository/start.log &".format(
      i + 2, params.startKubernetes)))
  
# Run start script on GCM
nodes[0].addService(rspec.Execute(shell="bash", command="/local/repository/start.sh primary 192.168.6.1 {} {} {} {} 2>&1 > /local/repository/start.log".format(
    params.workerCount + params.owNodes, params.startKubernetes, params.owNodes > 0, params.owNodes)))

pc.printRequestRSpec()
