# Image Setup

## GCM Node

Below are instructions for creating an ECM Node image:
* Start with an Ubuntu 18.04 image (```urn:publicid:IDN+emulab.net+image+emulab-ops//UBUNTU18-64-STD```)
* Add your [GitHub ssh key](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent) 
to the node & ssh agent (don't worry, your home directory won't be saved so your ssh private key won't be included in the final image)
* Run the ```gcm_install.sh``` script
* Use Cloudlab to create the image!

## Worker Node

TODO
