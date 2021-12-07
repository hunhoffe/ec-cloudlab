# ESCRA Setup

For each worker node, you'll need 3 terminal windows
For the GCM node, you'll also need 3 terminal windows

### Setup Logging on Worker Nodes
In one of the worker terminals for each worker run:
```
dmesg -wH
```

In a second of the worker terminals for each worker run:
```
cd /mydata/ec/Distributed-Containers/third_party/cadvisor
./cadvisor
```

### Run EC Agents on Worker Nodes

In the third worker terminal of each worker run:
```
cd /mydata/ec/Distributed-Containers/EC-Agent/
```

Use an editor to open ```main.go``` and set the constant variable INTERFACE to match the interface of the private IP of the node.

Then, run the EC-Agent:
```
go run main.go 
```

### Setup and start GCM on GCM Node

In the first GCM node terminal, run:
```
cd ~/Distributed-Containers/ec_gcm
./ec_gcm tests/app_def.json
```

The file ```app_def.json```, in this case, does not configure a specific application but rather the cluster settings (e.g., IP addresses of all nodes).

### Run GCM Deployer on GCM Node

In the second GCM node terminal, select a json file representing your application. Then run the below, replacing the file in the second command with the application file:
```
cd ~/Distributed-Containers/ec_deployer
go run main.go -f <app_deploy_file>.json
```

What matters in the json file is the name of the namespace; the file for containing yaml files can be empty.

#### Debugging GCM Deployer
If you get a "no revision" or github error, try the following.

Run this:
```
go env -w GO111MODULE=on
```

Try this:
```
git config --global --add url."git@github.com:".insteadOf "https://github.com/"
```

Ensure your GitHub SSH key is properly configured by running this test:
```
ssh -o "StrictHostKeyChecking no" -T git@github.com
```
