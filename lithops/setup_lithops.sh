#!/bin/bash

set +x 

LITHOPS_CONFIG="/local/repository/lithops/lithops-config.yaml"

# Setup openwhisk endpoints
wsk property set --apihost 192.168.6.1:31001
wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP

# Start the redis service
kubectl apply -f redis-master.yaml

# Update pip
python3 -m pip install --upgrade pip

# Install lithops
pip3 install lithops

# Needed to fix some versioning issue
pip3 install requests

# Extract redis IP
REDIS_IP=$(kubectl get services | grep redis | awk '{print $3}')
echo "Extracted redis IP is: $REDIS_IP"

# Fill in redis service IP in lithops-config.yaml
sed -i.bak "s/REPLACE_ME_WITH_IP/$REDIS_IP/g" $LITHOPS_CONFIG

# Export lithops necessary config
export LITHOPS_CONFIG_FILE=$LITHOPS_CONFIG
echo 'export LITHOPS_CONFIG_FILE=$LITHOPS_CONFIG' | sudo tee -a ~/.bashrc
