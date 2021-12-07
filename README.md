# CloudLab profile for deploying EC Research Project

The goal of this repo is to create a CloudLab profile that allows for one-click creation of a stable research environment for the EC project. General information for what on CloudLab profiles created via GitHub repo can be found in the example repo [here](https://github.com/emulab/my-profile) or in the CloudLab [manual](https://docs.cloudlab.us/cloudlab-manual.html).

## User Information

Create a CloudLab experiment using the escra profile. It has been testsed using c6220 nodes.

On each node, a copy of this repo is available at:
```
    /local/repository
```

### GCM Node

Installation specific material is found at ```/home/ec```, including the log from the start script that runs during experiment initialization. EC-specific repositories are downloaded manually using the ```gcm_setup.sh``` script and saved to your home directory.

After logging in for the first time, run the ```/local/repository/gcm_setup.sh``` script. In addition to setting some user-specific environment variables, this script will clone ESCRA-related repos to your home directory and also compile ```spdlog``` and ```ec_gcm```.  

#### GCM Node - OpenWhisk

To see information on OpenWhisk pods, make sure to specify the namespace as openwhisk. To remove OpenWhisk,
run the following commands:
```
    $ cd /home/ec/openwhisk-deploy-kube
    $ helm uninstall owdev -n openwhisk
```
After the helm uninstall, there may be orphan action containers which should be removed via ```kubectl```.

The OpenWhisk that is deployed is configured by the values in ```/home/ec/openwhisk-deploy-kube/mycluster.yaml```, and is 
identical to the one found [here](mycluster.yaml), except populated with the number of invokers and the IP of the primary node.

To restart OpenWhisk, for instance to deploy after modifying the ```mycluster.yaml``` file, run the following helm command:
```
    $ cd /home/ec/openwhisk-deploy-kube
    $ helm install owdev ./helm/openwhisk -n openwhisk -f mycluster.yaml
```

### Worker Nodes

The log from the start script is found in ```/local/repository/start.log```. EC-specific repositories are downloaded manually using the ```node_setup.sh``` script and saved to ```/mydata/ec```.

The EC kernel modules have been installed such as to be reloaded automatically upon reboot. The modules have been placed in ```/lib/modules/4.20.16DC+/kernel/drivers/pci```. To update a module, use ```rmmod``` to remove it. Replace the ```<module_name.ko>``` file in ```/lib/modules/4.20.16DC+/kernel/drivers/pci```, and then use ```insmod``` to insert it. Then, run ```depmod```. Alternatively, for just an update, you can simply replace the file and reboot and node. If you want to remove a module entirely or change the name of the ```.ko``` file, you'll also need to edit the ```/etc/modules``` file to reflect the changes. Optionally, reboot the machine and use ```lsmod``` to ensure your changes are persistent.

### Running ESCRA

Follow the profile instructions to run the GCM and node setup scripts.

Additional instructions found [here](documentation/escra_setup.md).
