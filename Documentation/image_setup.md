# Image Setup

## CloudLab Experiment Creation

The following scripts/instructions assume the node is configured with extra storage for docker images mounted at /mydata.
IP addresses should be configured as follows:
* GCM with 192.168.6.10
* Node1 with 192.168.6.9
* Node2 with 192.168.6.8
* Node3 with 192.168.6.7
* and so on...
* Maximum of 8 worker nodes, e.g., script stops working after 192.168.6.1.

## GCM Node

Below are instructions for creating an ECM Node image:
* Start with an Ubuntu 18.04 image (```urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD```)
* Run the ```gcm_install.sh``` script. You may need to press the 'enter' key a few times while it runs.
* Run the ```pull_images.sh``` script. This pulls the images needed by ```kubeadm``` and saves them in ```/home/ec/k8s-images```. This fixed an intermittent image pull bug I had when running ```kubadm init``` in the start script of the GCM node .
* Use Cloudlab to create the image!

## Worker Node

* Start with an Ubuntu 18.04 image (```urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD```)
* Add your [GitHub ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) 
to the node & ssh agent (don't worry, your home directory won't be saved so your ssh private key won't be included in the final image)
* Run the ```ecnode_install.sh``` script. You may need to press the 'enter' key a few times while it runs.
* Create the kernel config:
  ```
  cd /mnt/ECKernel/Distributed-Containers/EC-4.20.16
  sudo make menuconfig
  ```
* Change CONFIG_SYSTEM_TRUSTED_KEYS to "" to avoid a [certificate error](https://unix.stackexchange.com/questions/293642/attempting-to-compile-kernel-yields-a-certification-error)
* Compile the kernel
  ```
  sudo make -j20
  sudo make -j20 modules_install
  sudo make -j20 install
  sudo reboot
  ```
* Use Cloudlab to create the image!
