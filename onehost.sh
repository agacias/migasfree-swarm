#!/bin/bash


# DIRECTORIES
mkdir -p /nfs-share/conf # migasfree settings
mkdir -p /nfs-share/dump # dump posgresql database
mkdir -p /nfs-share/public # migafree static files
mkdir -p /nfs-share/keys # migasfree keys
mkdir -p /data # postgresql database


# BUILD IMAGE migasfree/db
cd migasfree-swarm
cd db
make build
cd ..


# BUILD IMAGE migasfree/server
cd server
make build
cd ..


# DEPLOYMENT
. variables
docker deploy --compose-file onehost.yml M
