# ServerlessBench

On the GCM, run:
```
cd /local/repository/serverlessbench
./setup_serverlessbench.sh
```

On all worker nodes, run (NOTE - this requires you to interactively ```docker login```):
```
cd /local/repository/serverlessbench
./setup_worker.sh
```

Then, setup to run image-process:
```
cd ~/ServerlessBench/Testcase4-Application-breakdown
./deploy --image-process
```
