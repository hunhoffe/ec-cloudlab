# Exploring how to Use Lithops

I'm going to try to run Lithops with OpenWhisk as a backend, and redis as the storage backend. 
First, I created an experiment of this profile in CloudLab with 3 worker nodes and 2 OpenWhisk nodes.

## Install a Redis Master Pod

Note: this isn't secure (password hardcoded in!!) and also not production worthy (just one node!!).

Create a ```redis-master.yaml``` config file:
```
---
apiVersion: apps/v1  # API version
kind: Deployment
metadata:
  name: redis-master # Unique name for the deployment
  labels:
    app: redis       # Labels to be applied to this deployment
spec:
  selector:
    matchLabels:     # This deployment applies to the Pods matching these labels
      app: redis
      role: master
      tier: backend
  replicas: 1        # Run a single pod in the deployment
  template:          # Template for the pods that will be created by this deployment
    metadata:
      labels:        # Labels to be applied to the Pods in this deployment
        app: redis
        role: master
        tier: backend
    spec:            # Spec for the container which will be run inside the Pod.
      containers:
      - name: redis
        image: redis
        imagePullPolicy: Always
        args: ["--requirepass", "password"]
        ports:
        - containerPort: 6379
          name: redis
        env:
        - name: MASTER
          value: "true"

---
apiVersion: v1
kind: Service        # Type of Kubernetes resource
metadata:
  name: redis-master # Name of the Kubernetes resource
  labels:            # Labels that will be applied to this resource
    app: redis
    role: master
    tier: backend
spec:
  ports:
  - port: 6379       # Map incoming connections on port 6379 to the target port 6379 of the Pod
    targetPort: 6379
  selector:          # Map any Pod with the specified labels to this service
    app: redis
    role: master
    tier: backend
```

Install with:
```
$ sudo kubectl apply -f redis-master.yaml
```

Wait until the redis-master pod is in the running state with:
```
$ sudo kubectl get pods
```

## Install Lithops

Some instructions found [here](https://github.com/lithops-cloud/lithops)

First, we need to install update pip3:

```
python3 -m pip install --upgrade pip
```

Next, install Lithops:
```
pip3 install lithops
```

We need to create a config file for lithops, we'll call it ```lithops-config.yaml```:
```
lithops: 
    storage: redis
    backend: openwhisk

openwhisk:
    endpoint    : http://<TODO:IP>:<TODO:PORT>
    namespace   : guest
    api_key     : 23bc46b1-71f6-4ed5-8c54-816aa4f8c502:123zO3xZCLrMN6v2BKK1dXYFpXlPkccOFqm12CdAsMgRU4VrNZ9lyGVCGuMDGIwP
    insecure    : True

redis:
    host: <TODO>
    port: 6379
    password: password
```

I followed instructions for OpenWhisk [here](https://lithops-cloud.github.io/docs/source/compute_config/openwhisk.html) 
and redis [here](https://lithops-cloud.github.io/docs/source/storage_config/redis.html) to fill in these values. 

Specifically, to get OpenWhisk values I used:
```
$ wsk -i property get --all
```

And for redis: 
```
$ sudo kubectl get services
```
And I used the ```CLUSTER-IP``` to fill in the host value in the ```lithops-config.yaml``` file.


Once all of the TODOs in the ```lithops-config.yaml``` file is filled out, you have to create an environment variable pointing to that file:
```
$ export LITHOPS_CONFIG_FILE=/local/repository/lithops/lithops-config.yaml
```

To remove versioning issues with urllib3 and (some other library I can't remember) run the following command:
```
pip3 install requests
```

From the lithops docs, I'll try to test with this the following file ```lithops_function_test.py```:
```
import lithops

def hello_world(name):
    return 'Hello {}!'.format(name)

if __name__ == '__main__':
    fexec = lithops.FunctionExecutor()
    fexec.call_async(hello_world, 'World')
    print(fexec.get_result())
```

Run with:
```
$ python3 lithops_test.py
```

