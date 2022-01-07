# Image Setup

## CloudLab Experiment Creation

The following scripts/instructions assume the node is configured with extra storage for docker images mounted at /mydata.
IP addresses should be configured as follows:
* GCM with 192.168.6.1
* Node1 with 192.168.6.2
* Node2 with 192.168.6.3
* Node3 with 192.168.6.4
* and so on...

## GCM Node

Below are instructions for creating an ECM Node image:
* Start with an Ubuntu 18.04 image (```urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD```)
* Run the ```gcm_install.sh``` script. You may need to press the 'enter' key a few times while it runs.
* Use vim or similar to edit ```/etc/environment```. Add ```/usr/local/go/bin``` to ```PATH```.
* Use Cloudlab to create the image!

## Worker Node

* Start with an Ubuntu 18.04 image (```urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD```) in the ```small-lan``` experiment with all default settings
* Add your [GitHub ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) 
to the node & ssh agent (don't worry, your home directory won't be saved so your ssh private key won't be included in the final image)
* Run the ```ecnode_install.sh``` script. This will install dependencies, compile the kernel, and install the kernel
* Reboot the node
* Run the ```install_modules.sh``` script. This will compile and install the kernel modules in a way that is persistent
* Use vim or similar to edit ```/etc/environment```. Add ```/usr/local/go/bin``` to ```PATH```.
* Use Cloudlab to create the image!

## Support for Additional Architectures

* Create a worker node image as described above using the hardware type desired
* Add the image (as value) and the node hardware type (as key) to the ```NODE_IMAGES``` dictionary in ```profile.py```
