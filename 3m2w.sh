#!/bin/bash

# SERVER NFS (only in manager1)
docker run -d --privileged --name nfs-server --net host huggla/nfs4-alpine


# CLIENT NFS (in each node)
for node in manager1 manager2 manager3 worker1 worker2
do
    ssh -o "StrictHostKeyChecking no" root@$node "bash -c 'PATH=/usr/local/bin:$PATH ; docker run -d --privileged --name nfs-client --pid=host --restart=unless-stopped -e SERVER=manager1:/ -e MOUNT=/nfs-share vipconsult/moby-nfs-mount;'" ||:
done


# DIRECTORIES (in manager1)
mkdir -p /nfs-share/conf # migasfree settings
mkdir -p /nfs-share/dump # dump posgresql database
mkdir -p /nfs-share/public # migafree static files
mkdir -p /nfs-share/keys # migasfree keys
mkdir -p /data # postgresql database


# BUILD IMAGE migasfree/db
cd db
make build
cd ..


# BUILD IMAGE migasfree/server
cd server
make build
cd ..


# COPY migasfree/server image to others nodes
docker save migasfree/server:master | bzip2 -c > migasfree.server.img
for node in manager2 manager3 worker1 worker2
do
   cat migasfree.server.img | ssh -o "StrictHostKeyChecking no" root@$node 'bunzip2 | /usr/local/bin/docker load'
done


# DEPLOYMENT
. variables
docker deploy --compose-file 3m2w.yml M
