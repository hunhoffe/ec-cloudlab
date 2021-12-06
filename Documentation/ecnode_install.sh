#!/bin/bash
set -x

EC_BRANCH="ftr-serverless"

# Check access to github
if ssh -o "StrictHostKeyChecking no" -T git@github.com 2>&1 | grep -q "You've successfully authenticated"; then
  echo "Verified SSH access to git."
else
  echo "ERROR: Please initialized your github ssh key before proceeding."
  exit -1
fi

# Install docker (https://docs.docker.com/engine/install/ubuntu/)
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
# Set to use cgroupdriver
echo -e '{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
sudo docker run hello-world | grep "Hello from Docker!" || (echo "ERROR: Docker installation failed, exiting." && exit -1)

# Install Kubernetes
sudo apt-get update
sudo curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo 'deb http://apt.kubernetes.io/ kubernetes-xenial main' | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
# Set to use private IP
sudo sed -i.bak "s/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml/KUBELET_CONFIG_ARGS=--config=\/var\/lib\/kubelet\/config\.yaml --node-ip=REPLACE_ME_WITH_IP/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
sudo swapoff -a

# Install Go
curl -O https://storage.googleapis.com/golang/go1.14.4.linux-amd64.tar.gz
tar -xvf go1.14.4.linux-amd64.tar.gz
sudo mv go /usr/local

echo 'export GOPATH=$HOME/go' | sudo tee -a ~/.profile
echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' | sudo tee -a ~/.profile
echo 'PATH="$PATH:/usr/local/go/bin"' | sudo tee -a /etc/environment
source ~/.profile
go version

# Install gRPC Go
export GO111MODULE=on
go get github.com/golang/protobuf/protoc-gen-go
export PATH="$PATH:$(go env GOPATH)/bin"
cd ~
source ~/.profile

# For building the kernel
cp -v /boot/config-$(uname -r) .config
sudo apt-get install -y build-essential libncurses-dev bison flex libssl-dev libelf-dev

# Mount ECKernel
sudo mkfs.ext4 /dev/sda4
sudo mkdir /mnt/ECKernel
sudo mount /dev/sda4 /mnt/ECKernel
sudo chown -R $USER:root /mnt/ECKernel

# Install EC-Agent
git clone git@github.com:gregcusack/Distributed-Containers.git /mnt/ECKernel/Distributed-Containers
cd /mnt/ECKernel/Distributed-Containers
git checkout --track origin/$EC_BRANCH
git submodule update --init --remote -- EC-4.20.16/
cd EC-4.20.16

# Scriptable replacement for make menuconfig
cp -v /boot/config-$(uname -r) .config
sudo make olddefconfig

# Fix certificate issue
sudo sed -i.bak 's/CONFIG_SYSTEM_TRUSTED_KEYS="debian\/canonical-certs.pem"/CONFIG_SYSTEM_TRUSTED_KEYS=""/g' .config

# Make & install kernel
sudo make -j$(nproc) && sudo make -j$(nproc) modules_install && sudo make -j$(nproc) install
