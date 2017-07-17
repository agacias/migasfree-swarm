migasfree-swarm
===============


3 managers and 2 workers
------------------------

Run a migasfree server in a swarm cluster only for testing purposes.
It uses play-with-docker.com and you have 4 hours for testing.

Deployment:

- Access to [play-with-docker.com](play-with-docker.com)

- Click in the *wrench* icon

- Select *3 managers and 2 workers*

- In *manager1* run:

    git clone https://github.com/agacias/migasfree-swarm.git
    
    cd migasfree-swarm
    
    ./3m2w.sh

- Click in port *80*

- Optionally you can modify the *variables* and *3m2w.yml* files and run:

    . variables
    
    docker deploy --compose-file 3m2w.yml M


In manager1 is allocated a NFS server (for share files beetween nodes) and the
postgresql database. In the others 4 nodes is allocated 1 migasfree-server in
each one (deploy in mode global)


One host
--------

- In one host with docker installed run (can be [play-with-docker.com](play-with-docker.com) too *adding new instance*):


    git clone https://github.com/agacias/migasfree-swarm.git
    
    cd migasfree-swarm
    
    ./onehost.sh

- Optionally you can modify the *variables* and *onehost.yml* files and run:

    . variables
    
    docker deploy --compose-file onehost.yml M

In this case only is created one container with *database* and other with *migasfree server*


Persintence
-----------
The directories for persistence are:

- /data (postgresql data)

- /nfs-share/conf (migasfree-server configuration)

- /nfs-share/public (migasfree-server static files)

- /nfs-share/dump (dump of database)

- /nfs-share/keys (migasfree-server keys)


Links
-----
[migasfree](http://migasfree.org)

[play-with-docker.com](http://play-with-docker.com)

[docker](https://docs.docker.com/)

[swarm](https://docs.docker.com/engine/swarm/)