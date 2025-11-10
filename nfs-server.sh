#!/bin/bash
apt install -y nfs-kernel-server
systemctl start nfs-server
systemctl enable nfs-server
mkdir /shared
chmod 777 /shared/
echo "/shared 172.16.*(rw,sync)" > /etc/experts
sytemctl restart nfs-server
ec2-metadata -o | cut -d ' ' -f 2 > /shared/list.txt
chmod 777 /shared/list.txt
