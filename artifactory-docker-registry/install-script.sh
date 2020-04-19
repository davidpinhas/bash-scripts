#!/bin/bash

## Verify root

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "WARN: Not Sudo user. Please run as root."
    exit
fi

## Environment Variables

s2=$(sleep 2)
s4=$(sleep 4)
PreReq="sudo curl dnf"
ip=$(ifconfig | sed -En 's/127.0.0.1//;s/.*inet (addr:)?(([0-9]*\.){3}[0-9]*).*/\2/p' | grep -v 172)

## Introduction

echo "
###################################################################"
echo "### Welcome to Artifactory Docker Registry configuration script ###"
echo "###################################################################"
echo "This script will install Artifactory and configure it as a Docker registry.

Important Note - Running this script will delete all Docker containers associated 
with the Artifactory service, including Nginx and PostgreSQL. 
Using the script on a new GCP instance is preferable.

Suupported Operating Systems:
Ubuntu 16.04 LTS
Ubuntu 18.04 LTS
CentOS 7
CentOS 8

Select your preferences from the options below to initialize the installation process.
This script support installation of Artifactory versions 6.15.0 and above, due to the 
Docker Manifest V2 Schema 2 Support that was introduced in version 6.15.0.
The installation process may take several minutes, patience is required."

############################
###### Menu Selection ######
############################

## Verify database - Derby (Default), option for PostgreSQL

echo "
Select database preference:"
menu_database ()
{
select database; do
if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $# ];
then
echo "INFO: The selected database is $database"
break;
else
echo "WARN: Wrong selection: Select any number from 1-$#"
fi
done
}
database_type=('Derby' 'PostgreSQL')
menu_database "${database_type[@]}"

## Verify Standalone or HA installation

if [ "$database" = "PostgreSQL" ]; then
echo "
Select Standalone or High-Availability installation preference:"
menu_ha_standalone ()                                       
{
select ha_sa; do
if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $# ];
then
echo "INFO: The selected installation preference is $ha_sa"
break;
else
echo "WARN: Wrong selection: Select any number from 1-$#"
fi
done
}
ha_sa_pick=('Standalone' 'HA')
menu_ha_standalone "${ha_sa_pick[@]}"
else
  echo "INFO: Setting up Standalone installation"
  export ha_sa="Standalone"
fi

## Check Docker Access Method

if [ "$ha_sa" != "HA" ]; then
  echo "
Select Docker Access Method preference:"
  menu_access_method ()                                       
  {
  select access_method; do
  if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $# ];
  then
  echo "INFO: The selected Docker Access Method is $access_method"
  break;
  else
  echo "WARN: Wrong selection: Select any number from 1-$#"
  fi
  done
  }
  access_method_pick=('Repository Path' 'Sub-Domain')
  menu_access_method "${access_method_pick[@]}"
else
  echo "INFO: Picking High Availability will set Sub-Domain access method by default"
fi

## Get license

if [ "$ha_sa" = "Standalone" ] || [ "$ha_sa" = "HA" ]; then
  echo "Provide the License Key:"
  echo "After copying the license, write the sign '~' at the end of the license and press Enter"
  read  -d "~" LICENSE
  export INPUT="$LICENSE"
  
  if [ "$ha_sa" = "HA" ] && [ "$ha_sa" != "Standalone" ]; then
    echo "Provide the a second License Key:"
    echo "After copying the license, write the sign '~' at the end of the license and press Enter"
    read  -d "~" LICENSE2
    export INPUT2="$LICENSE2"
  fi
fi

while true;
do
    read -r -p "
Do you want to choose a specific Artifactory version? Y(es)/N(o):" response   
    if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
    then
        echo "Provide the desired Artifactory version, for example '6.15.2':"
        read ART_VERSION
        echo "Installing version $ART_VERSION"
        break
    else
        export ART_VERSION="6.18.1"
        echo "Installing version $ART_VERSION."
        break
    fi
done

echo "
#####################################################
## All done!                                       ##
## Grab a cup of tea, this may take a few minutes. ##
#####################################################"
$s2

## Check OS

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    RESULT="$OS $VER"

elif type lsb_release >/dev/null 2>&1; then
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
    RESULT= "$OS $VER"
fi

## Installing Preresiquites

echo "
Checking preresiquites..."
if [ "$RESULT" = "Ubuntu 18.04" ] || [ "$RESULT" = "Ubuntu 16.04" ]; then
    for pkg in $PreReq; do
        if dpkg --get-selections | grep -q "^$pkg[[:space:]]*install$" >/dev/null 2>&1; then
            echo -e "INFO: $pkg is already installed"
        else
            apt-get -qq install $pkg >/dev/null 2>&1
            echo "INFO: Successfully installed $pkg"
        fi
    done

elif [ "$RESULT" = "CentOS Linux 7" ] || [ "$RESULT" = "CentOS Linux 8" ]; then
    rpm -qa >/dev/null 2>&1 | grep -qw $PreReq >/dev/null 2>&1 || yum -y install $PreReq >/dev/null 2>&1
fi

## Docker directories, daemon.json and /etc/hosts file checkup

grep "127.0.0.1 localhost artifactory docker-virtual.artifactory docker-local.artifactory" /etc/hosts || echo "127.0.0.1 localhost artifactory docker-virtual.artifactory docker-local.artifactory" >> /etc/hosts

if [ -d /etc/docker ]; then
  echo "INFO: The '/etc/docker' directory already exists"
else
  echo "INFO: Path '/etc/docker' doesn't exist, creating path."
  sudo mkdir /etc/docker
fi

if [ "$ha_sa" = "HA" ] || [ "$access_method" = "Sub-Domain" ]; then
  sudo cat <<EOF > /etc/docker/daemon.json
{
  "insecure-registries" : ["docker-virtual.artifactory"]
}
EOF

elif [ "$access_method" = "Repository Path" ]; then
  sudo cat <<EOF > /etc/docker/daemon.json
{
  "insecure-registries" : ["$ip:8081"]
}
EOF
fi

## Installing Docker client and Docker-Compose

if [ "$RESULT" = "Ubuntu 18.04" ]; then
    echo "
#################################
### Ubuntu 18.04 Installation ###
#################################
"
    if ! [ -x "$(command -v docker)" ]; then
      echo 'INFO: Docker not installed. Installing Docker client.' >&2
      sudo apt update
      sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
      sudo apt update
      apt-cache policy docker-ce
      sudo apt install docker-ce -y
    else
      echo "Docker client already installed."
    fi

    if ! [ -x "$(command -v docker-compose)" ]; then
      echo 'INFO: Docker-Compose not installed. Installing Docker-Compose.' >&2
      sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose && $s2
      sudo chmod +x /usr/local/bin/docker-compose
    else
      echo "Docker-Compose already installed."
    fi

elif [ "$RESULT" = "Ubuntu 16.04" ]; then
    echo "
#################################"
    echo "### Ubuntu 16.04 Installation ###"
    echo "#################################
    "

    if ! [ -x "$(command -v docker)" ]; then
      echo 'INFO: Docker not installed. Installing Docker client.' >&2
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
      sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
      sudo apt-get update
      sudo apt-cache policy docker-ce
      sudo apt-get install docker-ce -y
    else
      echo "Docker client already installed."
    fi

    if ! [ -x "$(command -v docker-compose)" ]; then
      echo 'INFO: Docker-Compose not installed. Installing Docker-Compose.' >&2
      sudo curl -L https://github.com/docker/compose/releases/download/1.18.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      docker-compose --version
    else
      echo "Docker-Compose already installed."
    fi

elif [ "$RESULT" = "CentOS Linux 7" ] || [ "$RESULT" = "CentOS Linux 8" ]; then
    echo "
###########################"
    echo "### CentOS Installation ###"
    echo "###########################
    "
    if ! [ -x "$(command -v docker)" ]; then
      echo 'INFO: Docker not installed. Installing Docker client.' >&2
      sudo yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm 
      sudo yum check-update
      sudo yum -y install yum-utils device-mapper-persistent-data lvm2
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum -y install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
      sudo yum -y install docker-ce docker-ce-cli containerd.io
      sudo systemctl start docker > /dev/null 2>&1
      sudo systemctl enable docker > /dev/null 2>&1
      sudo usermod -aG docker $USER
    else
      echo "Docker client already installed."
    fi

    if ! [ -x "$(command -v docker-compose)" ]; then
      echo 'INFO: Docker-Compose not installed. Installing Docker-Compose.' >&2
      sudo curl -L "https://github.com/docker/compose/releases/download/1.25.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
      sudo chmod +x /usr/local/bin/docker-compose
      sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose
      docker-compose --version
    else
      echo "Docker-Compose already installed."
    fi
fi

## Remove Docker containers

if [ "$(docker ps -q -f name=artifactory)" ]; then
    echo "INFO: Artifactory container already up, removing container."
    docker rm -f artifactory-node1 artifactory-node2 artifactory >/dev/null 2>&1
fi

if [ "$(docker ps -q -f name=nginx)" ]; then
    echo "INFO: Nginx container already up, removing container."
    docker rm -f nginx >/dev/null 2>&1
fi

if [ "$(docker ps -q -f name=postgresql)" ]; then
    echo "INFO: PostgreSQL container already up, removing container."
    docker rm -f postgresql >/dev/null 2>&1
fi

## Preparing license files and data directories

if [ "$ha_sa" = "HA" ]; then
  sudo rm -rf /data
  sudo mkdir -p /data/artifactory/node1/etc /data/artifactory/node2 /data/nginx /data/postgresql /data/artifactory/ha /data/artifactory/backup
  sudo chmod -R 777 /data/artifactory /data/artifactory/node1 /data/artifactory/node2 /data/nginx /data/postgresql /data/artifactory/ha /data/artifactory/backup
  cat <<EOF > /data/artifactory/node1/etc/artifactory.cluster.license
$INPUT

$INPUT2
EOF

elif [ "$ha_sa" = "Standalone" ]; then
  sudo rm -rf /data
  sudo mkdir -p /data/artifactory/etc /data/nginx /data/postgresql /data/artifactory/artifactory_extra_conf
  sudo chmod -R 777 /data/artifactory /data/nginx /data/postgresql
  cat <<EOF > /data/artifactory/etc/artifactory.lic
$INPUT
EOF
fi

####################################
##### Docker-Compose YAML file #####
####################################

## Remove previous YAML file

if [ -f artifactory.yml ]; then
    echo "INFO: artifactory.yml file already exists. Deleting and creating a new one."
    sudo rm artifactory.yml
fi

## Create YAML file

cat <<EOF > artifactory.yml
version: '2'
services:
EOF

##################
### PostgreSQL ###
##################

if [ "$database" = "PostgreSQL" ]; then
  echo "  postgresql:
    image: docker.bintray.io/postgres:9.6.11
    container_name: postgresql
    ports:
     - 5432:5432
    environment:
     - POSTGRES_DB=artifactory
     # The following must match the DB_USER and DB_PASSWORD values passed to Artifactory
     - POSTGRES_USER=artifactory
     - POSTGRES_PASSWORD=password
    volumes:
     - /data/postgresql:/var/lib/postgresql/data
    restart: always
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000" >> artifactory.yml
fi 

##############################
### Standalone Artifactory ###
##############################

if [ "$ha_sa" = "Standalone" ]; then
  echo "  artifactory:
    image: docker.bintray.io/jfrog/artifactory-pro:$ART_VERSION
    container_name: artifactory
    ports:
     - 8081:8081
    volumes:
     - /data/artifactory:/var/opt/jfrog/artifactory
     - /data/artifactory/artifactory_extra_conf:/artifactory_extra_conf
    restart: always
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000" >> artifactory.yml

  if [ "$database" = "PostgreSQL" ]; then
    echo "    depends_on:
     - postgresql
    links:
     - postgresql
    environment:
     - DB_TYPE=postgresql
     - DB_USER=artifactory
     - DB_PASSWORD=${POSTGRES_PSWRD}" >> artifactory.yml
  fi

  if [ "$access_method" = "Sub-Domain" ]; then
    echo "  nginx:
      image: docker.bintray.io/jfrog/nginx-artifactory-pro:$ART_VERSION
      container_name: nginx
      ports:
      - 80:80
      - 443:443
      depends_on:
      - artifactory
      links:
      - artifactory
      volumes:
      - /data/nginx:/var/opt/jfrog/nginx
      environment:
      - ART_BASE_URL=http://artifactory:8081/artifactory
      - SSL=true
      # Set SKIP_AUTO_UPDATE_CONFIG=true to disable auto loading of NGINX conf
      #- SKIP_AUTO_UPDATE_CONFIG=true
      restart: always" >> artifactory.yml
  fi

fi

#####################################
### High Availability Artifactory ###
#####################################

if [ "$ha_sa" = "HA" ]; then
  if [ "$ha_sa" = "HA" ] && [ "$database" = "PostgreSQL" ]; then
    echo "  artifactory-node1:
    image: docker.bintray.io/jfrog/artifactory-pro:$ART_VERSION
    container_name: artifactory-node1
    ports:
    - 8081:8081
    volumes:
    - /data/artifactory/node1:/var/opt/jfrog/artifactory
    - /data/artifactory/ha:/var/opt/jfrog/artifactory-ha
    - /data/artifactory/backup:/var/opt/jfrog/artifactory-backup
    restart: always
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000
    environment:
    - ARTIFACTORY_MASTER_KEY=FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    - HA_IS_PRIMARY=true
    - HA_DATA_DIR=/var/opt/jfrog/artifactory-ha
    - HA_BACKUP_DIR=/var/opt/jfrog/artifactory-backup
    - HA_MEMBERSHIP_PORT=10017
    - DB_TYPE=postgresql
    - DB_USER=artifactory
    - DB_PASSWORD=password
    depends_on:
    - postgresql
    links:
    - postgresql
  artifactory-node2:
    image: docker.bintray.io/jfrog/artifactory-pro:$ART_VERSION
    container_name: artifactory-node2
    ports:
    - 8082:8081
    volumes:
    - /data/artifactory/node2:/var/opt/jfrog/artifactory
    - /data/artifactory/ha:/var/opt/jfrog/artifactory-ha
    - /data/artifactory/backup:/var/opt/jfrog/artifactory-backup
    restart: always
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000
    environment:
    - ARTIFACTORY_MASTER_KEY=FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
    - HA_IS_PRIMARY=false
    - HA_DATA_DIR=/var/opt/jfrog/artifactory-ha
    - HA_BACKUP_DIR=/var/opt/jfrog/artifactory-backup
    - HA_MEMBERSHIP_PORT=10017
    - DB_TYPE=postgresql
    - DB_USER=artifactory
    - DB_PASSWORD=password
    depends_on:
    - postgresql
    - artifactory-node1
    links:
    - postgresql
    - artifactory-node1
  nginx:
    image: docker.bintray.io/jfrog/nginx-artifactory-pro:$ART_VERSION
    container_name: nginx
    ports:
     - 80:80
     - 443:443
    volumes:
     - /data/nginx:/var/opt/jfrog/nginx
    restart: always
    ulimits:
      nproc: 65535
      nofile:
        soft: 32000
        hard: 40000
    depends_on:
     - artifactory-node1
     - artifactory-node2
    links:
     - artifactory-node1
     - artifactory-node2
    environment:
     - ART_BASE_URL=http://artifactory-node1:8081/artifactory
     - SSL=true" >> artifactory.yml
  fi
fi

sudo chown artifactory: /data/artifactory 
sudo docker-compose -f artifactory.yml up -d --remove-orphans
sudo systemctl restart docker >/dev/null 2>&1
$s4

## Install license and Configure Docker repositories

echo "
#########################################"
echo "### Preparing the Artifactory Service ###"
echo "#########################################
"

echo "INFO: Waiting for the Artifactory container to start, this will take 60 seconds." && sleep 60

#####################################
##### Nginx configuration file  #####
#####################################

## Removing old Nginx conf file if HA is true

if [ "$ha_sa" = "HA" ]; then
  if [ -f /data/nginx/conf.d/artifactory.conf ]; then
    echo "INFO: The artifactory.conf file for Nginx already exists. Deleting and creating a new one."
    sudo rm /data/nginx/conf.d/artifactory.conf
  fi

## Create a new Nginx conf file if HA is true

  echo "## add HA entries when ha is configure
upstream artifactory {
    server 172.18.0.3:8081;
    server 172.18.0.4:8081;
}" > /data/nginx/conf.d/artifactory.conf

## Removing old Nginx conf file if Standalone or Sub-Domain is true

elif [ "$ha_sa" = "Standalone" ] && [ "$ha_sa" = "Sub-Domain" ]; then
  if [ ! -f /data/nginx/conf.d/artifactory.conf ]; then
    echo "INFO: Creating a new one artifactory.conf file"
  else
    echo "INFO: The artifactory.conf file for Nginx already exists. Deleting and creating a new one."
    sudo rm /data/nginx/conf.d/artifactory.conf
  fi
  sudo touch /data/nginx/conf.d/artifactory.conf  ## Creating Nginx conf file
fi

## Append if HA or Sub-Domain is true

if [ "$ha_sa" = "HA" ] || [ "$ha_sa" = "Sub-Domain" ]; then
cat <<'EOF' >> /data/nginx/conf.d/artifactory.conf 
## add ssl entries when https has been set in config
ssl_protocols TLSv1 TLSv1.1 TLSv1.2 TLSv1.3;
ssl_certificate      /var/opt/jfrog/nginx/ssl/example.crt;
ssl_certificate_key  /var/opt/jfrog/nginx/ssl/example.key;
ssl_session_cache shared:SSL:1m;
ssl_prefer_server_ciphers   on;
## server configuration
server {
    listen 443 ssl;
    listen 80 ;
    listen 8081 ;
    server_name ~(?<repo>.+)\.artifactory artifactory;

    if ($http_x_forwarded_proto = '') {
        set $http_x_forwarded_proto  $scheme;
    }
    ## Application specific logs
    ## access_log /var/log/nginx/artifactory-access.log timing;
    ## error_log /var/log/nginx/artifactory-error.log;
    rewrite ^/$ /artifactory/webapp/ redirect;
    rewrite ^/artifactory/?(/webapp)?$ /artifactory/webapp/ redirect;
    rewrite ^/(v1|v2)/(.*) /artifactory/api/docker/$repo/$1/$2;
    chunked_transfer_encoding on;
    client_max_body_size 0;
    location /artifactory/ {
    proxy_read_timeout  2400s;
    proxy_pass_header   Server;
    proxy_cookie_path   ~*^/.* /;
    if ( $request_uri ~ ^/artifactory/(.*)$ ) {
        proxy_pass          http://artifactory/artifactory/$1;
    }
    proxy_pass          http://artifactory/artifactory/;
    proxy_next_upstream http_503 non_idempotent;
    proxy_set_header    X-Artifactory-Override-Base-Url $http_x_forwarded_proto://$host:$server_port/artifactory;
    proxy_set_header    X-Forwarded-Port  $server_port;
    proxy_set_header    X-Forwarded-Proto $http_x_forwarded_proto;
    proxy_set_header    Host              $http_host;
    proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
    }
}
EOF
fi

if [ "$ha_sa" = "HA" ] || [ "$access_method" = "Sub-Domain" ]; then ## Restart Nginx container if HA or Sub-Domain is true
  sudo docker restart nginx > /dev/null 2>&1
  echo "INFO: Preparing Nginx service, sleeping for 50 secs more..."
  sleep 50
  if [ "$ha_sa" = "HA" ]; then ## Restart 'artifactory-node2' if HA is true
  sudo docker restart artifactory-node2 > /dev/null 2>&1
  echo "INFO: Restarting second HA node to retrieve license"
  fi
fi
if [ "$ha_sa" = "Standalone" ]; then
  echo "INFO: Waiting for Artifactory to install the license key"
  sleep 20
  echo "INFO: Uploaded first license to Artifactory successfully."
  sleep 5

fi

## Create Docker repositories JSON files

echo "INFO: Setting up Docker repositories"
echo "INFO: Creating JSON files."

## Local

cat <<EOF > local.json
{
    "key": "docker-local",
    "rclass" : "local",
    "packageType": "docker",
    "repoLayoutRef" : "simple-default",
    "snapshotVersionBehavior": "unique",
    "suppressPomConsistencyChecks": true
}
EOF

## Remote

cat <<EOF > remote.json
{
    "key": "docker-remote",
    "rclass" : "remote",
    "packageType": "docker",
    "url" : "https://registry-1.docker.io/",
    "externalDependenciesEnabled": false,
    "repoLayoutRef" : "simple-default",
    "suppressPomConsistencyChecks": true,
    "externalDependenciesEnabled": true,
    "externalDependenciesPatterns": [ "**" ],
    "blockMismatchingMimeTypes": true,
    "enableTokenAuthentication": true,
    "contentSynchronisation": {
      "enabled": false,
      "statistics": {
          "enabled": false
      },
      "properties": {
          "enabled": false
      },
      "source": {
          "originAbsenceDetection": false
      }
    }
}
EOF

## Virtual

cat <<EOF > virtual.json
{
    "key": "docker-virtual",
    "rclass": "virtual",
    "packageType": "docker",
    "repositories": ["docker-remote", "docker-local"],
    "externalDependenciesEnabled": false,
    "defaultDeploymentRepo": "docker-local",
    "repoLayoutRef" : "simple-default"
}
EOF

## Creating the Docker repositories in Artifactory

echo "INFO: Uploading JSON files to Artifactory."
sleep 15
curl -uadmin:password -XPUT "http://localhost:8081/artifactory/api/repositories/docker-local" -H "Content-Type: application/json" -T local.json 
curl -uadmin:password -XPUT "http://localhost:8081/artifactory/api/repositories/docker-remote" -H "Content-Type: application/json" -T remote.json
curl -uadmin:password -XPUT "http://localhost:8081/artifactory/api/repositories/docker-virtual" -H "Content-Type: application/json" -T virtual.json

## Clean Unnecessary Files

sudo rm -rf remote.json local.json virtual.json license.json artifactory.yml
unset INPUT
unset INPUT2

## Ending message if Sub-Domain or HA are true

if [ "$access_method" = "Sub-Domain" ]|| [ "$ha_sa" = "HA" ] ; then
  echo "
###########################################
### Installation finished successfully! ###
###########################################

Artifactory $ART_VERSION has been configured as a Docker registry using Sub-Domain access method.

To login use 'docker login docker-virtual.artifactory' with the default Artifactory credentials. 
To pull, follow the example below: 

docker pull docker-virtual.artifactory/nginx:latest
"

## Ending message if Repository Path is true

elif [ "$access_method" = "Repository Path" ] ; then
echo "
###########################################
### Installation finished successfully! ###
###########################################

Artifactory $ART_VERSION has been configured as a Docker registry using Repository Path access method.

To login use 'docker login $ip:8081' with the default Artifactory credentials. 
To pull, follow the example below:

docker pull $ip:8081/docker-virtual/nginx:latest
"
fi
