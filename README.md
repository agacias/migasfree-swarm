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


