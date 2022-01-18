#! /bin/bash

docker login

# Pull images needed for image-process benchmark
sudo docker image pull openwhisk/java8action
sudo docker image pull dplsming/java8action-imagemagic-profile
