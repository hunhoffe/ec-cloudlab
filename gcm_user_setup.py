#!/bin/bash

# Check and see if github SSH key is set up for current user
echo "Checking SSH access to github"
if ssh -o "StrictHostKeyChecking no" -T git@github.com 2>&1 | grep -q "You've successfully authenticated"; then
  echo "Verified SSH access to git."
else
  echo "ERROR: Please initialized your github ssh key before proceeding."
  exit -1
fi

# Setup Go Paths
INSTALL_DIR=~

echo "Setting up Go paths"
echo "export GOROOT=/usr/local/go" | sudo tee -a ~/.profile
echo "export GOPATH=$HOME/go" | sudo tee -a ~/.profile
echo "export PATH=$GOPATH/bin:$GOROOT/bin:$PATH" | sudo tee -a ~/.profile
echo 'export GO111MODULE=on' | sudo tee -a ~/.profile
source ~/.profile

# Setup Mount Directory Contents
echo "Cloning contents into $INSTALL_DIR"
cd $INSTALL_DIR
git clone git@github.com:gregcusack/Distributed-Containers.git
cd Distributed-Containers
git submodule update --init -- ec_gcm/
git submodule update --init -- ec_deployer/
cd ec_deployer
git checkout bug-mem-ONLY
cd ..
git submodule update --init -- third_party/DeathStarBench/
cd third_party/DeathStarBench
git checkout k8s-support
cd ../..
git submodule update --init -- third_party/spdlog/
cd third_party/spdlog
echo "Building spdlog..."
mkdir build && cd build
cmake .. && make -j && sudo make install
cd $INSTALL_DIR

# Compile GCM
cd $INSTALL_DIR/Distributed-Containers/ec_gcm 
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/bin/gcc-8 -DCMAKE_CXX_COMPILER=/usr/bin/g++-8 .
make -j20
cd $INSTALL_DIR
