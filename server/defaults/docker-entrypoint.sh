#!/bin/bash

set -e

function end()
{
   echo "END CONTAINER: $HOSTNAME"
   rm -rf /etc/migasfree-server/.init-server || :
}
trap end EXIT


function set_TZ {
    if [ -z "$TZ" ]; then
      TZ="Europe/Madrid"
    fi
    # /etc/timezone for TZ setting
    ln -fs /usr/share/zoneinfo/$TZ /etc/localtime || :
}


function get_migasfree_setting()
{
    echo -n $(DJANGO_SETTINGS_MODULE=migasfree.settings.production python -c "from django.conf import settings; print settings.$1")
}


# owner resource user
function owner()
{
    if [ ! -f "$1" -a ! -d "$1" ]
    then
        mkdir -p "$1"
    fi

    _OWNER=$(stat -c %U "$1" 2>/dev/null)
    if [ "$_OWNER" != "$2" ]
    then
        chown -R $2:$2 "$1"
    fi
}


# Nginx configuration
function create_nginx_config
{
    python - << EOF
from django.conf import settings
_CONFIG_NGINX = """

server {
    listen 80;
    server_name $FQDN $HOST localhost 127.0.0.1;
    client_max_body_size 500M;

    location /static {
        alias %(static_root)s;
    }
    location /repo {
        alias %(repo)s;
        autoindex on;
    }
    location /repo/errors/ {
        deny all;
        return 404;
    }
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header X-Forwarded-Host \$server_name;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header REMOTE_ADDR \$remote_addr;
        proxy_connect_timeout 10;
        proxy_send_timeout 600;
        proxy_read_timeout 600;
    }
}
""" % {'static_root': settings.STATIC_ROOT, 'repo': settings.MIGASFREE_PUBLIC_DIR}
target = open('/etc/nginx/sites-available/migasfree.conf', 'w')
target.write(_CONFIG_NGINX)
target.close()
EOF
ln -sf  /etc/nginx/sites-available/migasfree.conf  /etc/nginx/sites-enabled/migasfree.conf
rm /etc/nginx/sites-available/default &> /dev/null || :
}

function set_nginx_server_permissions()
{
    _USER=www-data
    # owner for repositories
    _REPO_PATH=$(get_migasfree_setting MIGASFREE_PUBLIC_DIR)
    owner $_REPO_PATH $_USER
    # owner for keys
    _KEYS_PATH=$(get_migasfree_setting MIGASFREE_KEYS_DIR)
    owner $_KEYS_PATH $_USER
    chmod 700 $_KEYS_PATH
    # owner for migasfree.log
    _TMP_DIR=$(get_migasfree_setting MIGASFREE_TMP_DIR)
    touch "$_TMP_DIR/migasfree.log"
    owner "$_TMP_DIR/migasfree.log" $_USER
}


function nginx_init
{

    create_nginx_config

    python -c "import django; django.setup(); from migasfree.server.secure import create_server_keys; create_server_keys()"

    /etc/init.d/nginx start
    set_nginx_server_permissions
}




function is_db_exists()
{

    _HOST=$(get_migasfree_setting "DATABASES['default']['HOST']")
    _PORT=$(get_migasfree_setting "DATABASES['default']['PORT']")
    _USER=$(get_migasfree_setting "DATABASES['default']['USER']")
    _NAME=$(get_migasfree_setting "DATABASES['default']['NAME']")
    _RESULT=$(psql -h $_HOST -p $_PORT -U $_USER -tAc "SELECT 1 from pg_database WHERE datname='$_NAME'" 2>/dev/null )
    _CODE=$?
    if [ "$_RESULT" = "1" ] ; then
        test 0 -eq 0
    elif [ $_CODE = 2 ] && [ -z "$_RESULT" ] ; then
        echo "Database does not exist"
        test 1 -eq 0
    else
        exit 1
    fi
    }


function is_user_exists()
{
    _HOST=$(get_migasfree_setting "DATABASES['default']['HOST']")
    _PORT=$(get_migasfree_setting "DATABASES['default']['PORT']")
    _USER=$(get_migasfree_setting "DATABASES['default']['USER']")
    _RESULT=$(psql -h $_HOST -p $_PORT -U postgres -tAc "SELECT 1 FROM pg_roles WHERE rolname='$_USER';" )
    if [ $? = 0 ]
    then
       test "$_RESULT" = "1"
    else
       exit 1
    fi
}


function create_user()
{
    _HOST=$(get_migasfree_setting "DATABASES['default']['HOST']")
    _PORT=$(get_migasfree_setting "DATABASES['default']['PORT']")
    _USER=$(get_migasfree_setting "DATABASES['default']['USER']")
    _PASSWORD=$(get_migasfree_setting "DATABASES['default']['PASSWORD']")
    psql -h $_HOST -p $_PORT -U postgres -tAc "CREATE USER $_USER WITH CREATEDB ENCRYPTED PASSWORD '$_PASSWORD';"
}

function create_database()
{
    _HOST=$(get_migasfree_setting "DATABASES['default']['HOST']")
    _PORT=$(get_migasfree_setting "DATABASES['default']['PORT']")
    _NAME=$(get_migasfree_setting "DATABASES['default']['NAME']")
    _USER=$(get_migasfree_setting "DATABASES['default']['USER']")
    psql -h $_HOST -p $_PORT -U postgres -tAc "CREATE DATABASE $_NAME WITH OWNER = $_USER ENCODING='UTF8';"
}


function set_circus_numprocesses() {
    sed -ri "s/^#?(numprocesses\s*=\s*)\S+/\1$(nproc)/" "/etc/circus/circusd.ini"
}


function wait_postgresql {
    _HOST=$(get_migasfree_setting "DATABASES['default']['HOST']")
    _PORT=$(get_migasfree_setting "DATABASES['default']['PORT']")
    echo "Waiting Postgresql in $_HOST:$_PORT ... "
    until psql -h $_HOST -p $_PORT -U postgres -c '\l' &>/dev/null
    do
      sleep 1
    done
}


function wait_nginx {
    echo "Waiting ngnix ... "
    while true
    do
        STATUS=$(curl --write-out %{http_code} --silent --output /dev/null $FQDN/admin/login/) || :
        if [ $STATUS = 200 ]
        then
            break
        fi
        sleep 1
    done
}


function wait_server {
    echo "Waiting  others servers ..."
    while [ -f  /etc/migasfree-server/.init-server ] ; do
      sleep 1
    done
    touch /etc/migasfree-server/.init-server
}



function migasfree_init
{

    wait_server

    wait_postgresql

    is_user_exists || create_user

    is_db_exists && echo yes | cat - | django-admin migrate --fake-initial || (
        create_database
        django-admin migrate
        python - << EOF
import django
django.setup()
from migasfree.server.fixtures import create_initial_data, sequence_reset
create_initial_data()
sequence_reset()
EOF
    )

    nginx_init

}


echo "INIT CONTAINER: $HOSTNAME"
set_TZ
migasfree_init


echo "Starting circus"
set_circus_numprocesses
circusd --daemon /etc/circus/circusd.ini
circusctl status

if [ "$PORT" = "80" ] || [ "$PORT" = "" ]
then
    _URL=http://$FQDN
else
    _URL=http://$FQDN:$PORT
fi

wait_nginx

echo "
        Container: $HOSTNAME
        Time zome: $TZ  $(date)
        Processes: $(nproc)

               -------O--
              \\         o \\
               \\           \\
                \\           \\
                  -----------

        $_URL is running.
"



rm /etc/migasfree-server/.init-server

while :
do
    sleep 5
done
