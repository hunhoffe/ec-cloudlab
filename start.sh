#!/bin/bash

set -x

BASE_IP="192.168.6."
ESCRA_INTERFACE="escra"
SECONDARY_PORT=3000
INSTALL_DIR=/home/ec
NUM_MIN_ARGS=3
PRIMARY_ARG="primary"
SECONDARY_ARG="secondary"
NUM_PRIMARY_ARGS=6
USAGE=$'Usage:\n\t./start.sh secondary <node_ip> <start_kubernetes>\n\t./start.sh primary <node_ip> <num_core> <start_kubernetes> <deploy_openwhisk> <num_invokers>'

configure_docker_storage() {
    printf "%s: %s\n" "$(date +"%T.%N")" "Configuring docker storage"
    sudo mkdir /mydata/docker
    echo -e '{
        "exec-opts": ["native.cgroupdriver=systemd"],
        "log-driver": "json-file",
        "log-opts": {
            "max-size": "100m"
        },
        "storage-driver": "overlay2",
        "data-root": "/mydata/docker"
    }' | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker || (echo "ERROR: Docker installation failed, exiting." && exit -1)
    sudo docker run hello-world | grep "Hello from Docker!" || (echo "ERROR: Docker installation failed, exiting." && exit -1)
    printf "%s: %s\n" "$(date +"%T.%N")" "Configured docker storage to use mountpoint"
}

disable_swap() {
    # Turn swap off and comment out swap line in /etc/fstab
    sudo swapoff -a
    if [ $? -eq 0 ]; then   
        printf "%s: %s\n" "$(date +"%T.%N")" "Turned off swap"
    else
        echo "***Error: Failed to turn off swap, which is necessary for Kubernetes"
        exit -1
    fi
    sudo sed -i.bak 's/UUID=.*swap/# &/' /etc/fstab
}

setup_secondary() {
    # Takes IP address as argument
    # Source: https://docs.rackspace.com/support/how-to/identifying-network-interfaces-on-linux/
    INTERFACE=$(ip -4 -o a | grep "$1" | cut -d ' ' -f 2,7 | cut -d '/' -f 1 | cut -d ' ' -f 1)
    sudo ip link set dev $INTERFACE down
    sudo ip link set $INTERFACE name $ESCRA_INTERFACE
    sudo ip link set dev $ESCRA_INTERFACE up
  
    # Openwhisk build dependencies
    sudo apt update
    sudo apt install -y nodejs npm default-jre
    sudo apt install -y default-jdk

    # clone openwhisk fork, switch to branch with modified code
    cd ~
    git clone https://github.com/hunhoffe/openwhisk.git
    cd openwhisk
    git checkout --track origin/escra

    # compile what is needed and create + tag the docker image for the controller
    sudo bin/wskdev controller -b
    sudo docker tag whisk/controller whisk/controller:vcpu2
    sudo bin/wskdev invoker -b
    sudo docker tag whisk/invoker whisk/invoker:vcpu2
  
    coproc nc { nc -l $1 $SECONDARY_PORT; }

    printf "%s: %s\n" "$(date +"%T.%N")" "Waiting for command to join kubernetes cluster, nc pid is $nc_PID"
    while true; do
        printf "%s: %s\n" "$(date +"%T.%N")" "Waiting for command to join kubernetes cluster, nc pid is $nc_PID"
        read -r -u${nc[0]} cmd
        case $cmd in
            *"kube"*)
                MY_CMD=$cmd
                break 
                ;;
            *)
	    	printf "%s: %s\n" "$(date +"%T.%N")" "Read: $cmd"
                ;;
        esac
	if [ -z "$nc_PID" ]
	then
	    printf "%s: %s\n" "$(date +"%T.%N")" "Restarting listener via netcat..."
	    coproc nc { nc -l $1 $SECONDARY_PORT; }
	fi
    done

    # Remove forward slash, since original command was on two lines
    MY_CMD=$(echo sudo $MY_CMD | sed 's/\\//')

    printf "%s: %s\n" "$(date +"%T.%N")" "Command to execute is: $MY_CMD"

    # run command to join kubernetes cluster
    eval $MY_CMD
    printf "%s: %s\n" "$(date +"%T.%N")" "Done!"
}

setup_primary() {
    # initialize k8 primary node
    printf "%s: %s\n" "$(date +"%T.%N")" "Starting Kubernetes... (this can take several minutes)... "
    sudo kubeadm init --apiserver-advertise-address=$1 2>&1 > $INSTALL_DIR/k8s_install.log
    if [ $? -eq 0 ]; then
        printf "%s: %s\n" "$(date +"%T.%N")" "Done! Output in $INSTALL_DIR/k8s_install.log"
    else
        echo ""
        echo "***Error: Error when running kubeadm init command. Check log found in $INSTALL_DIR/k8s_install.log."
        exit 1
    fi
    
    # Set config in group accessible, persistent location
    sudo mkdir $INSTALL_DIR/.kube
    sudo cp /etc/kubernetes/admin.conf $INSTALL_DIR/.kube/config
    sudo chown -R $(id -u):$(id -g) $INSTALL_DIR/.kube
    sudo chmod -R g+rw $INSTALL_DIR/.kube/config
    export KUBECONFIG=$INSTALL_DIR/.kube/config
    echo "KUBECONFIG=$INSTALL_DIR/.kube/config" | sudo tee -a /etc/environment

    sudo sysctl net.bridge.bridge-nf-call-iptables=1
    export kubever=$(kubectl version | base64 | tr -d '\n')
    kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$kubever"

    # wait until all pods are started except 2 (the DNS pods)
    NUM_PENDING=$(kubectl get pods -o wide --all-namespaces 2>&1 | grep Pending | wc -l)
    NUM_RUNNING=$(kubectl get pods -o wide --all-namespaces 2>&1 | grep Running | wc -l)
    printf "%s: %s\n" "$(date +"%T.%N")" "> Waiting for pods to start up: "
    while [ "$NUM_PENDING" -ne 2 ] && [ "$NUM_RUNNING" -ne 5 ]
    do
        sleep 1
        printf "."
        NUM_PENDING=$(kubectl get pods -o wide --all-namespaces 2>&1 | grep Pending | wc -l)
        NUM_RUNNING=$(kubectl get pods -o wide --all-namespaces 2>&1 | grep Running | wc -l)
    done
    printf "%s: %s\n" "$(date +"%T.%N")" "Done!"
}

add_cluster_nodes() {
    REMOTE_CMD=$(tail -n 2 $INSTALL_DIR/k8s_install.log)
    printf "%s: %s\n" "$(date +"%T.%N")" "Remote command is: $REMOTE_CMD"

    CLUSTER_NODES=$(($1+1))
    echo "Cluster nodes expected: $CLUSTER_NODES"
    NUM_REGISTERED=$(kubectl get nodes | tail -n +2 | wc -l)
    NUM_REGISTERED=$(($1-NUM_REGISTERED+1))
    echo "Waiting for $NUM_REGISTERED/$CLUSTER_NODES nodes..."
    counter=0
    while [ "$NUM_REGISTERED" -ne 0 ]
    do 
	sleep 2
        printf "%s: %s\n" "$(date +"%T.%N")" "Registering nodes, attempt #$counter, num left=$NUM_REGISTERED expected=$CLUSTER_NODES"
        for (( i=2; i<=$CLUSTER_NODES; i++ ))
        do
            SECONDARY_IP=$BASE_IP$i
            echo $SECONDARY_IP
            exec 3<>/dev/tcp/$SECONDARY_IP/$SECONDARY_PORT
            echo $REMOTE_CMD 1>&3
            exec 3<&-
        done
	counter=$((counter+1))
        NUM_REGISTERED=$(kubectl get nodes | tail -n +2 | wc -l)
	echo "Counted $NUM_REGISTERED/$CLUSTER_NODES nodes"
        NUM_REGISTERED=$(($1-NUM_REGISTERED+1)) 
    done

    printf "%s: %s\n" "$(date +"%T.%N")" "Waiting for all nodes to have status of 'Ready': "
    NUM_READY=$(kubectl get nodes | tail -n +2 | grep " Ready " | wc -l)
    NUM_READY=$((CLUSTER_NODES-NUM_READY))
    while [ "$NUM_READY" -ne 0 ]
    do
        sleep 1
        printf "."
        NUM_READY=$(kubectl get nodes | tail -n +2 | grep " Ready " | wc -l)
        NUM_READY=$((CLUSTER_NODES-NUM_READY))
    done
    printf "%s: %s\n" "$(date +"%T.%N")" "Done!"
}

prepare_for_openwhisk() {

    kubectl create namespace openwhisk
    if [ $? -ne 0 ]; then
        echo "***Error: Failed to create openwhisk namespace"
        exit 1
    fi
    printf "%s: %s\n" "$(date +"%T.%N")" "Created openwhisk namespace in Kubernetes."
    
    # Iterate over each node and set the openwhisk role
    # From https://superuser.com/questions/284187/bash-iterating-over-lines-in-a-variable
    NODE_NAMES=$(kubectl get nodes -o name | grep "node-")
    while IFS= read -r line; do
      printf "%s: %s\n" "$(date +"%T.%N")" "Labelled ${line:5} as openwhisk invoker node"
      kubectl label nodes ${line:5} openwhisk-role=invoker
      if [ $? -ne 0 ]; then
        echo "***Error: Failed to set openwhisk role to invoker on ${line:5}."
        exit -1
      fi
    done <<< "$NODE_NAMES"
    NODE_NAMES=$(kubectl get nodes -o name | grep "ow-")
    while IFS= read -r line; do
      printf "%s: %s\n" "$(date +"%T.%N")" "Labelled ${line:5} as openwhisk core node"
      kubectl label nodes ${line:5} openwhisk-role=core
      if [ $? -ne 0 ]; then
        echo "***Error: Failed to set openwhisk role to invoker on ${line:5}."
        exit -1
      fi
    done <<< "$NODE_NAMES"
    printf "%s: %s\n" "$(date +"%T.%N")" "Labelled nodes as invoker or core nodes."
    
    cp /local/repository/myruntimes.json $INSTALL_DIR/openwhisk-deploy-kube/helm/openwhisk/myruntimes.json
    
    cp /local/repository/mycluster.yaml $INSTALL_DIR/openwhisk-deploy-kube/mycluster.yaml
    sed -i.bak "s/REPLACE_ME_WITH_IP/$1/g" $INSTALL_DIR/openwhisk-deploy-kube/mycluster.yaml
    sed -i.bak "s/REPLACE_ME_WITH_COUNT/$3/g" $INSTALL_DIR/openwhisk-deploy-kube/mycluster.yaml
    printf "%s: %s\n" "$(date +"%T.%N")" "Added primary node IP and num invokers to $INSTALL_DIR/openwhisk-deploy-kube/mycluster.yaml"
}

deploy_openwhisk() {
    
    # For whatever reason, it takes a while for the node labels to take effect. Waiting ensures
    # openwhisk-role=core and openwhisk-role=invoker are followed.
    sleep 2m
    
    # Deploy openwhisk via helm
    cd $INSTALL_DIR/openwhisk-deploy-kube
    printf "%s: %s\n" "$(date +"%T.%N")" "About to deploy OpenWhisk via Helm... "
    helm install owdev ./helm/openwhisk -n openwhisk -f mycluster.yaml 2>&1 > $INSTALL_DIR/helm_install.log
    
    if [ $? -eq 0 ]; then
        printf "%s: %s\n" "$(date +"%T.%N")" "Ran helm command to deploy OpenWhisk"
    else
        echo ""
        echo "***Error: Helm install error. Please check $INSTALL_DIR/helm_install.log."
        exit 1
    fi
    cd $INSTALL_DIR

    # Monitor pods until openwhisk is fully deployed
    sudo kubectl get pods -n openwhisk
    printf "%s: %s\n" "$(date +"%T.%N")" "Waiting for OpenWhisk to complete deploying (this can take several minutes): "
    DEPLOY_COMPLETE=$(kubectl get pods -n openwhisk | grep owdev-install-packages | grep Completed | wc -l)
    while [ "$DEPLOY_COMPLETE" -ne 1 ]
    do
        sleep 2
        DEPLOY_COMPLETE=$(kubectl get pods -n openwhisk | grep owdev-install-packages | grep Completed | wc -l)
    done
    printf "%s: %s\n" "$(date +"%T.%N")" "OpenWhisk deployed!"
    wsk property set --apihost $1:31001
    wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
}

# Start by recording the arguments
printf "%s: args=(" "$(date +"%T.%N")"
for var in "$@"
do
    printf "'%s' " "$var"
done
printf ")\n"

# Check the min number of arguments
if [ $# -lt $NUM_MIN_ARGS ]; then
    echo "***Error: Expected at least $NUM_MIN_ARGS arguments."
    echo "$USAGE"
    exit -1
fi

# Check to make sure the first argument is as expected
if [ $1 != $PRIMARY_ARG -a $1 != $SECONDARY_ARG ] ; then
    echo "***Error: First arg should be '$PRIMARY_ARG' or '$SECONDARY_ARG'"
    echo "$USAGE"
    exit -1
fi

# Kubernetes does not support swap, so we must disable it
disable_swap

# Use mountpoint (if it exists) to set up additional docker image storage
if test -d "/mydata"; then
    configure_docker_storage
fi

# Add all users to docker group
for FILE in /users/*; do
    CURRENT_USER=${FILE##*/}
    sudo gpasswd -a $CURRENT_USER docker
done

# Use second argument (node IP) to replace filler in kubeadm configuration, and restart the daemon
sudo sed -i.bak "s/REPLACE_ME_WITH_IP/$2/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo systemctl daemon-reload
sudo systemctl restart kubelet

# At this point, a secondary node is fully configured until it is time for the node to join the cluster.
if [ $1 == $SECONDARY_ARG ] ; then

    # Exit early if we don't need to start Kubernetes
    if [ "$3" == "False" ]; then
        printf "%s: %s\n" "$(date +"%T.%N")" "Start Kubernetes is $3, done!"
        exit 0
    fi
    setup_secondary $2
    exit 0
fi

# Check the min number of arguments
if [ $# -ne $NUM_PRIMARY_ARGS ]; then
    echo "***Error: Expected at least $NUM_PRIMARY_ARGS arguments."
    echo "$USAGE"
    exit -1
fi

# Fix permissions in /home/ec on the GCM node
MY_USER=($USER)
echo $MY_USER
sudo chown -R $MY_USER: /home/ec/

# Exit early if we don't need to start Kubernetes
if [ "$4" = "False" ]; then
    printf "%s: %s\n" "$(date +"%T.%N")" "Start Kubernetes is $4, done!"
    exit 0
fi

# Finish setting up the primary node
# Argument is node_ip
setup_primary $2

# Coordinate master to add nodes to the kubernetes cluster
# Argument is number of nodes
add_cluster_nodes $3

# Exit early if we don't need to deploy OpenWhisk
if [ "$5" = "False" ]; then
    printf "%s: %s\n" "$(date +"%T.%N")" "Deploy Openwhisk is $4, done!"
    exit 0
fi

# Exit early if num invokers exceeds number of nodes
if [ $3 -lt $6 ] ; then
    printf "%s: %s\n" "$(date +"%T.%N")" "Error - number of invokers exceeds number of nodes."
    exit -1
fi

# Prepare cluster to deploy OpenWhisk, takes IP and node num and num core
prepare_for_openwhisk $2 $3 $6

# Deploy OpenWhisk via Helm
deploy_openwhisk $2
