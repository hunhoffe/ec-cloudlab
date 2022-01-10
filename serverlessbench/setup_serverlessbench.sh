#!/bin/bash

# Set wsk properties
wsk property set --apihost 192.168.6.1:31001
wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP

# Install serverlessbench dependencies
# From: https://github.com/SJTU-IPADS/ServerlessBench/tree/master/Testcase4-Application-breakdown
sudo apt-get install -y maven nodejs jq\
                     gcc-7 g++-7 protobuf-compiler libprotobuf-dev \
                     libcrypto++-dev libcap-dev \
                     libncurses5-dev libboost-dev libssl-dev autopoint help2man \
                     libhiredis-dev texinfo automake libtool pkg-config python3-boto3

# Clone the serverlessbench repo
cd ~
git clone https://github.com/hunhoffe/ServerlessBench.git

# Necessary to run docker without sudo
CURRENT_USER=$(whoami)
sudo gpasswd -a $CURRENT_USER docker

# Set directory location
# From: https://github.com/SJTU-IPADS/ServerlessBench/tree/master/Testcase4-Application-breakdown
export TESTCASE4_HOME=~/ServerlessBench/Testcase4-Application-breakdown
echo 'export TESTCASE4_HOME=~/ServerlessBench/Testcase4-Application-breakdown' | sudo tee -a ~/.bashrc

# Create couchdb deployment
# Instructions from: https://artifacthub.io/packages/helm/couchdb/couchdb#configuration
cd ~
kubectl create secret generic my-db-couchdb --from-literal=adminUsername=admin --from-literal=adminPassword=password --from-literal=cookieAuthSecret=secret
helm repo add couchdb https://apache.github.io/couchdb-helm
helm install my-db --set createAdminSecret=false --set couchdbConfig.couchdb.uuid=decafbaddecafbaddecafbaddecafbad couchdb/couchdb
sleep 30

kubectl get services | grep 

# Set environment variables in bashrc
echo "export COUCHDB_USERNAME=admin" | sudo tee -a ~/.bashrc
echo "export COUCHDB_PASSWORD=password" | sudo tee -a ~/.bashrc
COUCHDB_IP=$(kubectl get services | grep "svc-couchdb" | awk '{print $3}')
echo "export COUCHDB_IP=$COUCHDB_IP" | sudo tee -a ~/.bashrc
echo "export COUCHDB_PORT=5984" | sudo tee -a ~/.bashrc
