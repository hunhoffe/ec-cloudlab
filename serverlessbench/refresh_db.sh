#!/bin/bash

set -x

INSTALL_DIR="$HOME"
TEST_PATH="$INSTALL_DIR/ServerlessBench/Testcase4-Application-breakdown"
CONFIG_FILE="local.env"
BASE_DIR="/local/repository/serverlessbench"
COUCHDB_CONFIG="$BASE_DIR/couchdb-config.yaml"

# Get COUCHDB_* values from config file
source $TEST_PATH/$CONFIG_FILE

# Remove old database deployment
helm uninstall $COUCHDB_NAME
sleep 30

# Create couchdb deployment
# Instructions from: https://artifacthub.io/packages/helm/couchdb/couchdb#configuration
helm install $COUCHDB_NAME --set createAdminSecret=false --set couchdbConfig.couchdb.uuid=decafbaddecafbaddecafbaddecafbad couchdb/couchdb -f $COUCHDB_CONFIG
sleep 30

# Finish deployment setup
echo $COUCHDB_PASSWORD | kubectl exec --namespace default -it $COUCHDB_NAME-couchdb-0 -c couchdb -- \
    curl -s \
    http://127.0.0.1:5984/_cluster_setup \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"action": "finish_cluster"}' \
    -u admin 

# Set COUCHDB_IP address in config file (delete old IP first)
COUCHDB_IP=$(kubectl get services | grep "svc-couchdb" | awk '{print $3}')
sed -i '/COUCHDB_IP/d' $TEST_PATH/$CONFIG_FILE
echo "COUCHDB_IP=$COUCHDB_IP" | sudo tee -a $TEST_PATH/$CONFIG_FILE

# Create an image and couch db log database
curl -X PUT http://$COUCHDB_USERNAME:$COUCHDB_PASSWORD@$COUCHDB_IP:$COUCHDB_PORT/$COUCHDB_LOGDB
curl -X PUT http://$COUCHDB_USERNAME:$COUCHDB_PASSWORD@$COUCHDB_IP:$COUCHDB_PORT/$IMAGE_DATABASE
