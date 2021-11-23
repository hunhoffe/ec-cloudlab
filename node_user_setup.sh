#!/bin/bash
set -x

INSTALL_DIR=~

# Check and see if github SSH key is set up for current user
echo "Checking SSH access to github"
if ssh -o "StrictHostKeyChecking no" -T git@github.com 2>&1 | grep -q "You've successfully authenticated"; then
  echo "Verified SSH access to git."
else
  echo "ERROR: Please initialized your github ssh key before proceeding."
  exit -1
fi

# Setup Go Paths
echo "Setting up Go paths"
echo "export GOROOT=/usr/local/go" | sudo tee -a ~/.profile
echo "export GOPATH=$HOME/go" | sudo tee -a ~/.profile
echo "export PATH=$GOPATH/bin:$GOROOT/bin:$PATH" | sudo tee -a ~/.profile
echo 'export GO111MODULE=on' | sudo tee -a ~/.profile
source ~/.profile

# Setup Mount Directory Contents
git clone git@github.com:gregcusack/Distributed-Containers.git $INSTALL_DIR/Distributed-Containers
cd $INSTALL_DIR/Distributed-Containers
git submodule update --init -- EC-Agent/
git submodule update --init -- third_party/cadvisor/
cd third_party/cadvisor
make build
cd ../..
git submodule update --init -- third_party/DeathStarBench/
cd third_party/DeathStarBench
git checkout k8s-support
cd ~