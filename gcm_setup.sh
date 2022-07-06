#!/bin/bash

INSTALL_DIR=/mydata
EC_BRANCH="main"
EC_GCM_BRANCH="main"

# Check and see if github SSH key is set up for current user
echo "Checking SSH access to github"
if ssh -o "StrictHostKeyChecking no" -T git@github.com 2>&1 | grep -q "You've successfully authenticated"; then
  echo "Verified SSH access to git."
else
  echo "ERROR: Please initialized your github ssh key before proceeding."
  exit -1
fi

# Setup openwhisk endpoints
wsk property set --apihost 192.168.6.1:31001
wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP

# Make sure to use SSH instead of HTTPS for GitHub-based submodules
git config --global --add url."git@github.com:".insteadOf "https://github.com/"

# Setup Go Paths
echo "Setting up Go paths"
echo 'export GOPATH=$HOME/go' | sudo tee -a ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' | sudo tee -a ~/.bashrc
echo 'export GO111MODULE=on' | sudo tee -a ~/.bashrc
source ~/.bashrc

# EC Deployer assumes location for kube config
cp /home/ec/.kube/config ~/.kube/config

# Setup Mount Directory Contents
echo "Cloning contents into $INSTALL_DIR/ec"
sudo mkdir $INSTALL_DIR/ec
sudo chown $USER $INSTALL_DIR/ec
sudo chmod u+rwx $INSTALL_DIR/ec
cd $INSTALL_DIR/ec
git clone git@github.com:gregcusack/Distributed-Containers.git
cd Distributed-Containers
git checkout --track origin/$EC_BRANCH
git submodule update --init --remote -- ec_gcm/
git submodule update --init --remote -- ec_deployer/
git submodule update --init --remote -- third_party/DeathStarBench/
git submodule update --init -- third_party/spdlog/
cd third_party/spdlog
echo "Building spdlog..."
mkdir build && cd build
cmake .. && make -j && sudo make install

# Compile GCM
# the ldconfig is necessary after installing grpc. I should have done this in the gcm image creation, but oh well.
sudo ldconfig
cd $INSTALL_DIR/ec/Distributed-Containers/ec_gcm
git checkout --track origin/$EC_GCM_BRANCH
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/gcc-8 -DCMAKE_CXX_COMPILER=/usr/bin/g++-8 .
make -j20
cd $INSTALL_DIR
