#!/bin/bash

# Set wsk properties
wsk property set --apihost 192.168.6.1:31001
wsk property set --auth 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP

# Install serverlessbench dependencies
# From: https://github.com/SJTU-IPADS/ServerlessBench/tree/master/Testcase4-Application-breakdown
sudo apt-get install maven nodejs jq\
                     gcc-7 g++-7 protobuf-compiler libprotobuf-dev \
                     libcrypto++-dev libcap-dev \
                     libncurses5-dev libboost-dev libssl-dev autopoint help2man \
                     libhiredis-dev texinfo automake libtool pkg-config python3-boto3

# Clone the serverlessbench repo
cd ~
git clone https://github.com/SJTU-IPADS/ServerlessBench.git

# Set directory location
# From: https://github.com/SJTU-IPADS/ServerlessBench/tree/master/Testcase4-Application-breakdown
export TESTCASE4_HOME=~/ServerlessBench/Testcase4-Application-breakdown
echo 'export TESTCASE4_HOME=~/ServerlessBench/Testcase4-Application-breakdown' | sudo tee -a ~/.bashrc
