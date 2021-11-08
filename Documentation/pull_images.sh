#!/bin/bash

IMAGE_DIR=/home/ec/k8s-images

# Create persistent directory for images
sudo mkdir $IMAGE_DIR
sudo chgrp ecuser $IMAGE_DIR
sudo chmod -R g+rw $IMAGE_DIR

# Iterate through necessary kubeadm images
sudo kubeadm config images list | while read line
do
       # Pull the image, this will save in /mydata/docker -> but this isn't image persistent
       sudo docker pull $line

       # Remove image repo prefix (which messes with file creation) and leave just image name & version
       echo $line
       IMAGE_NAME=${line##*/}
       echo $IMAGE_NAME

       # Save the image locally in $IMAGE_DIR, since this is image persistent. 
       sudo docker save $line -o $IMAGE_DIR/$IMAGE_NAME.tar
done
