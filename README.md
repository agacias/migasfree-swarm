SERVIDOR NFS (EN UN NODO)
-------------------------
docker run -d --privileged --name nfs-server --net host huggla/nfs4-alpine



CLIENTE NFS (EN CADA NODO)
--------------------------
docker run -d --privileged --name nfs-client --pid=host --restart=unless-stopped -e SERVER=10.0.45.3:/ -e MOUNT=/nfs-share vipconsult/moby-nfs-mount














deployment
==========
mkdir /nfs-share/conf
mkdir /nfs-share/dump
mkdir /nfs-share/public
mkdir /nfs-share/keys

. variables
docker deploy --compose-file docker-compose.yml M


docker stack ps M

docker service logs M_nfs
docker service update --detach=false M_nfs




PDTE. en container postgresql
=============================
/etc/postgresql/9.5/main/pg_hda.conf -> host all all 10.255.0.0/16 trust
