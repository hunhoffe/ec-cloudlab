#!/bin/bash

INSTALL_DIR=~
EC_BRANCH="ftr-serverless"

# Check and see if github SSH key is set up for current user
echo "Checking SSH access to github"
if ssh -o "StrictHostKeyChecking no" -T git@github.com 2>&1 | grep -q "You've successfully authenticated"; then
  echo "Verified SSH access to git."
else
  echo "ERROR: Please initialized your github ssh key before proceeding."
  exit -1
fi

# Setup openwhisk endpoints
wsk property set --apihost 192.168.6.10:31001
wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP

# Setup go paths
echo "Setting up Go paths"
echo 'export GOPATH=$HOME/go' | sudo tee -a ~/.profile
echo 'export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin' | sudo tee -a ~/.profile
echo 'export GO111MODULE=on' | sudo tee -a ~/.profile
source ~/.profile

# EC Deployer assumes location for kube config
cp /home/ec/.kube/config ~/.kube/config

# Setup Mount Directory Contents
echo "Cloning contents into $INSTALL_DIR"
cd $INSTALL_DIR
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
cd $INSTALL_DIR

# Compile GCM
# the ldconfig is necessary after installing grpc. I should have done this in the gcm image creation, but oh well.
sudo ldconfig
cd $INSTALL_DIR/Distributed-Containers/ec_gcm 
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/gcc-8 -DCMAKE_CXX_COMPILER=/usr/bin/g++-8 .
make -j20
cd $INSTALL_DIR
