#!/bin/bash

MNT_DIR="/mnt/ECKernel"
DST_DIR="/lib/modules/4.20.16DC+/kernel/drivers/pci"

sudo mount /dev/sda4 $MNT_DIR
 
echo "MAKING AND INSERTING cgroup_connection...\n\n"
cd $MNT_DIR/Distributed-Containers/EC-4.20.16/ec_modules/cgroup_connection/KERN_SRC/
sudo make
sudo cp cgroup_connection.ko $DST_DIR/cgroup_connection.ko
sudo insmod $DST_DIR/cgroup_connection.ko
echo cgroup_connection | sudo tee -a /etc/modules > /dev/null

echo "MAKING AND INSERTING increase_mem_cgroup_margin...\n\n"
cd $MNT_DIR/Distributed-Containers/EC-4.20.16/ec_modules/increase_mem_cgroup_margin/
sudo make
sudo cp increase_memcg_margin.ko $DST_DIR/increase_memcg_margin.ko
sudo insmod $DST_DIR/increase_memcg_margin.ko
echo increase_memcg_margin | sudo tee -a /etc/modules > /dev/null

echo "MAKING AND INSERTING resize_max_mem...\n\n"
cd $MNT_DIR/Distributed-Containers/EC-4.20.16/ec_modules/resize_max_mem/
sudo make
sudo cp resize_max_mem.ko $DST_DIR/resize_max_mem.ko
sudo insmod $DST_DIR/resize_max_mem.ko
echo resize_max_mem | sudo tee -a /etc/modules > /dev/null

echo "MAKING AND INSERTING resize_quota..\n\n"
cd $MNT_DIR/Distributed-Containers/EC-4.20.16/ec_modules/resize_quota/KERN_SRC/
sudo make
sudo cp resize_quota.ko $DST_DIR/resize_quota.ko
sudo insmod $DST_DIR/resize_quota.ko
echo resize_quota | sudo tee -a /etc/modules > /dev/null

echo "MAKING AND INSERTING read_quota...\n\n"
cd $MNT_DIR/Distributed-Containers/EC-4.20.16/ec_modules/read_quota/KERN_SRC/
sudo make
sudo cp read_quota.ko $DST_DIR/read_quota.ko
sudo insmod $DST_DIR/read_quota.ko
echo read_quota | sudo tee -a /etc/modules > /dev/null

echo "MAKING AND INSERTING get_parent_cgid...\n\n"
cd $MNT_DIR/Distributed-Containers/EC-4.20.16/ec_modules/get_parent_cgid/KERN_SRC/
sudo make
sudo cp get_parent_cgid.ko $DST_DIR/get_parent_cgid.ko
sudo insmod $DST_DIR/get_parent_cgid.ko
echo get_parent_cgid | sudo tee -a /etc/modules > /dev/null

sudo depmod
