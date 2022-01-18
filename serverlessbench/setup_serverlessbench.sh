#!/bin/bash

INSTALL_DIR=~
TEST_PATH="$INSTALL_DIR/ServerlessBench/Testcase4-Application-breakdown"
CONFIG_FILE="local.env"
BASE_DIR="/local/repository/serverlessbench"
COUCHDB_CONFIG="$BASE_DIR/couchdb-config.yaml"

# Set wsk properties
wsk property set --apihost 192.168.6.1:31001
wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP

# Install ServerlessBench dependencies
# From: https://github.com/SJTU-IPADS/ServerlessBench/tree/master/Testcase4-Application-breakdown
sudo apt update
sudo apt-get install -y maven nodejs jq\
                     gcc-7 g++-7 protobuf-compiler libprotobuf-dev \
                     libcrypto++-dev libcap-dev \
                     libncurses5-dev libboost-dev libssl-dev autopoint help2man \
                     libhiredis-dev texinfo automake libtool pkg-config python3-boto3

# Clone the serverlessbench repo
cd $INSTALL_DIR
git clone https://github.com/hunhoffe/ServerlessBench.git

# Create local config file
cp $BASE_DIR/$CONFIG_FILE $TEST_PATH/$CONFIG_FILE

# Set test location to config
# From: https://github.com/SJTU-IPADS/ServerlessBench/tree/master/Testcase4-Application-breakdown
echo "TESTCASE4_HOME=$TEST_PATH" | sudo tee -a $TEST_PATH/$CONFIG_FILE

# Get COUCHDB_* values from config file
source $TEST_PATH/$CONFIG_FILE

# Create couchdb deployment
# Instructions from: https://artifacthub.io/packages/helm/couchdb/couchdb#configuration
kubectl create secret generic $COUCHDB_NAME-couchdb --from-literal=adminUsername=$COUCHDB_USERNAME --from-literal=adminPassword=$COUCHDB_PASSWORD --from-literal=cookieAuthSecret=secret
helm repo add couchdb https://apache.github.io/couchdb-helm
helm install $COUCHDB_NAME --set createAdminSecret=false --set couchdbConfig.couchdb.uuid=decafbaddecafbaddecafbaddecafbad couchdb/couchdb -f $COUCHDB_CONFIG

# Wait for it to deploy
sleep 90

# Finish deployment setup
echo $COUCHDB_PASSWORD | kubectl exec --namespace default -it $COUCHDB_NAME-couchdb-0 -c couchdb -- \
    curl -s \
    http://127.0.0.1:5984/_cluster_setup \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"action": "finish_cluster"}' \
    -u admin 

# Set COUCHDB_IP address in config file
COUCHDB_IP=$(kubectl get services | grep "svc-couchdb" | awk '{print $3}')
echo "COUCHDB_IP=$COUCHDB_IP" | sudo tee -a $TEST_PATH/$CONFIG_FILE

# Create an image and couch db log database and set environment variable in bashrc
curl -X PUT http://$COUCHDB_USERNAME:$COUCHDB_PASSWORD@$COUCHDB_IP:$COUCHDB_PORT/$COUCHDB_LOGDB
curl -X PUT http://$COUCHDB_USERNAME:$COUCHDB_PASSWORD@$COUCHDB_IP:$COUCHDB_PORT/$IMAGE_DATABASE
