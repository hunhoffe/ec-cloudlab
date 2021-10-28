#!/bin/bash
set -x

# Unlike home directories, this directory will be included in the image
INSTALL_DIR=/home/ec

# Group to use so others can get access to the INSTALL_DIR
EC_GROUP=ecuser

#Private IP of the GCM node
PRIVATE_IP=192.168.6.10

# Check access to github
if ssh -o "StrictHostKeyChecking no" -T git@github.com 2>&1 | grep -q "You've successfully authenticated"; then
  echo "Verified SSH access to git."
else
  echo "ERROR: Please initialized your github ssh key before proceeding."
  exit -1
fi

# Install Cmake
version=3.16
build=2
mkdir ~/temp
cd ~/temp
wget https://cmake.org/files/v$version/cmake-$version.$build.tar.gz
tar -xzvf cmake-$version.$build.tar.gz
cd cmake-$version.$build/ 
sudo ./bootstrap
sudo make -j10
sudo make install

sudo apt-get update
sudo apt-get install -y g++ git libboost-atomic-dev libboost-thread-dev libboost-system-dev libboost-date-time-dev libboost-regex-dev libboost-filesystem-dev libboost-random-dev libboost-chrono-dev libboost-serialization-dev libwebsocketpp-dev openssl libssl-dev ninja-build
cd ~

# Install docker
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Install Kubernetes
sudo apt-get update && sudo apt-get install -y apt-transport-https
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl

# Install gcc-8
sudo add-apt-repository ppa:ubuntu-toolchain-r/test
sudo apt-get update
sudo apt-get install -y gcc-8 g++-8

# Install go
curl -O https://storage.googleapis.com/golang/go1.14.4.linux-amd64.tar.gz
tar -xvf go1.14.4.linux-amd64.tar.gz
sudo mv go /usr/local
go version

# Install Python3
sudo add-apt-repository ppa:deadsnakes/ppa
sudo apt update -y
sudo apt install -y python3.7
sudo apt install -y python3-pip
python3.7 -m pip install --upgrade pip
python3.7 -m pip install asyncio
python3.7 -m pip install aiohttp

# Install libmemcached
sudo apt install -y luarocks
sudo luarocks install luasocket
sudo apt install -y libmemcached-dev

# Download and install the OpenWhisk CLI
wget https://github.com/apache/openwhisk-cli/releases/download/latest/OpenWhisk_CLI-latest-linux-386.tgz
tar -xvf OpenWhisk_CLI-latest-linux-386.tgz
sudo mv wsk /usr/local/bin/wsk

# Download and install helm
curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
chmod 700 get_helm.sh
sudo ./get_helm.sh

# Create ecuser group so $INSTALL_DIR can be accessible to everyone
sudo groupadd $EC_GROUP
sudo mkdir $INSTALL_DIR
sudo chgrp -R $EC_GROUP $INSTALL_DIR
sudo chmod -R o+rw $INSTALL_DIR

# Prepare for Kubernetes - set extra storage for docker
# Set cgroups driver
echo -e '{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "data-root": "/mydata/docker"
}' | sudo tee /etc/docker/daemon.json

# Tell Kubernetes to use private cloudlab IP
sudo sed -i.bak "s/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml --node-ip=192\.168\.6\.10/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf

# Persist Kubernetes/docker settings
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl restart kubelet

# Set config in group accessible, persistent location
sudo cp -i /etc/kubernetes/admin.conf $INSTALL_DIR/.kube/config
sudo chown $(id -u):$EC_GROUP $INSTALL_DIRE/.kube/config
sudo cp /etc/kubernetes/admin.conf $INSTALL_DIR
sudo chown $(id -u):$EC_GROUP $INSTALL_DIR/admin.conf
export KUBECONFIG=$INSTALL_DIR/admin.conf
echo "KUBECONFIG=$INSTALL_DIR/admin.conf" | sudo tee -a /etc/environment

# Download openwhisk-deploy-kube repo
sudo git clone https://github.com/apache/openwhisk-deploy-kube.git $INSTALL_DIR/openwhisk-deploy-kube
cd $INSTALL_DIR

# Install casablanca
git clone git@github.com:microsoft/cpprestsdk.git casablanca
cd casablanca
mkdir build.debug
cd build.debug
cmake -G Ninja .. -DCMAKE_BUILD_TYPE=Debug
ninja
sudo ninja install
cd $INSTALL_DIR

# Install Protobuf
git clone https://github.com/protocolbuffers/protobuf.git
cd protobuf
git submodule update --init --recursive
./autogen.sh
./configure
make -j12
make -j12 check
sudo make -j12 install
sudo ldconfig
cd $INSTALL_DIR

# Install GRPC C++
sudo apt-get install -y build-essential autoconf libtool pkg-config
git clone --recurse-submodules -b v1.28.1 https://github.com/grpc/grpc
cd grpc
mkdir -p cmake/build
cd cmake/build

cmake ../.. -DgRPC_INSTALL=ON                \
              -DCMAKE_BUILD_TYPE=Release       \
              -DgRPC_PROTOBUF_PROVIDER=package \
              -DgRPC_SSL_PROVIDER=package \
              -DBUILD_SHARED_LIBS=ON \
              -DCMAKE_INSTALL_PREFIX=/usr/local
make -j20
sudo make install
cd $INSTALL_DIR
