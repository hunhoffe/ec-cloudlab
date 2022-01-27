#!/bin/bash
set -x

INSTALL_DIR=/mydata
EC_BRANCH="ftr-serverless"

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
echo 'export GOPATH=$HOME/go' | sudo tee -a ~/.bashrc
echo 'export PATH=$PATH:$GOPATH/bin' | sudo tee -a ~/.bashrc
echo 'export GO111MODULE=on' | sudo tee -a ~/.bashrc
source ~/.bashrc

# Setup EC-related repos
sudo mkdir $INSTALL_DIR/ec
sudo chown $USER $INSTALL_DIR/ec
sudo chmod u+rwx $INSTALL_DIR/ec
git clone git@github.com:gregcusack/Distributed-Containers.git $INSTALL_DIR/ec/Distributed-Containers
cd $INSTALL_DIR/ec/Distributed-Containers
git checkout --track origin/$EC_BRANCH
git submodule update --init --remote -- EC-Agent/
git submodule update --init --remote -- third_party/DeathStarBench/
git submodule update --init -- third_party/cadvisor/
cd third_party/cadvisor
make build

# Install Autopilot monitoring script dependencies
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository -y ppa:deadsnakes/ppa
sudo apt install -y python3.7
sudo -H python3.7 -m pip install --upgrade pip
sudo -H python3.7 -m pip install numpy
sudo -H pip3 install --ignore-installed PyYAML
sudo -H python3.7 -m pip install kubernetes
sudo -H python3.7 -m pip install --upgrade requests

# Clone and setup Autopilot monitoring scripts
cd ~
git clone git@github.com:goodarzysepideh/Autopilot.git
cd Autopilot
git checkout --track origin/read-only-look-for-new-pods
