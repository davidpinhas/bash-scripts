#!/bin/bash

# Verify root

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
  echo "WARN: Not Sudo user. Please run as root."
  exit
fi

#Setting environment variables
#export MASTER_KEY=$(openssl rand -hex 32)
#export JOIN_KEY=$(openssl rand -hex 32)
#export JFROG_URL=$(kubectl describe svc artifactory-ha-nginx | grep Ingress | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
export GCP_EXTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)

echo "
###############################################
### Minikube environment preperation script ###
###############################################

This script will prepare a Kubernetes environemnt and deploy an Artifactory HA cluster.
The script works on Ubuntu 18.04 GCP VMs.

To deploy Artifactory HA cluster, please provide 3 Artifactory licenses.
Important Note - All three Artifactory licenses must be the same type (E+, Enterprise, etc..)"

echo "
Do you wish to prepare a Kubernetes cluster or prepare a cluster and deploy Artifactory HA:"
menu_init ()
{
select init; do
if [ 1 -le "$REPLY" ] && [ "$REPLY" -le $# ];
then
echo "INFO: We are going to $init"
break;
else
echo "WARN: Wrong selection: Select any number from 1-$#"
fi
done
}
init_type=('Prepare a Kubernetes environment' 'Prepare and deploy Artifactory HA')
menu_init "${init_type[@]}"

# Creating values.yaml file
echo "INFO: Creating values.yaml file."
cat <<EOF > values.yaml

artifactory:

  masterKey: 35f0080184a500d3166ee437c14676e05e816d3a52e7fe455cbb49cfddf421dd
  joinKey: ebb72037fe50e46f1688d6bed9e97d2c798e13bfb87c1627d4f40bc5bd53cc65

  persistence:
    enabled: true

  extraEnvironmentVariables:
   - name: SERVER_XML_ARTIFACTORY_MAX_THREADS
     value: "100"
   - name: DB_POOL_MAX_ACTIVE
     value: "110"

  service:
    pool: all

postgresql:
  postgresqlPassword: "password"
  postgresqlExtendedConf:
    maxConnections: "350"
EOF

# Create Nginx and Ingress service.yaml file

echo "INFO: Creating service.yaml file."
cat <<EOF > service.yaml
nginx:
  service:
    annotations:
      service.beta.kubernetes.io/aws-load-balancer-internal: "true"
      service.beta.kubernetes.io/aws-load-balancer-connection-idle-timeout: "60"
      service.beta.kubernetes.io/aws-load-balancer-type: nlb
    #  rollme: '{{ randAlphaNum 5 | quote }}'

ingress:
  enabled: true
  defaultBackend:
    enabled: true
  # Used to create an Ingress record.

  labels:
  # traffic-type: external
    traffic-type: internal
  tls:
  # Secrets must be manually created in the namespace.
    - secretName: self-secret
      hosts:
        - artifactory.org
EOF

# Retrieving Artifactory licenses
if [ "$init" = "Prepare and deploy Artifactory HA" ]; then
echo "Provide the License Key:"
echo "After copying the license, write the sign '~' at the end of the license and press Enter
"
read  -d "~" LICENSE
export INPUT="$LICENSE"
echo "
Provide the a second License Key:"
echo "After copying the license, write the sign '~' at the end of the license and press Enter
"
read  -d "~" LICENSE2
export INPUT2="$LICENSE2"
echo "
Provide the a third License Key:"
echo "After copying the license, write the sign '~' at the end of the license and press Enter
"
read  -d "~" LICENSE3
export INPUT3="$LICENSE3"

# Create art.lic file with the provided licenses

echo "

INFO: Creating art.lic file."
cat <<EOF > art.lic
  $INPUT

  $INPUT2

  $INPUT3
EOF
fi

echo "
############################################
### Preparing the Kubernetes environment ###
############################################"

# Installing Docker client

if ! [ -x "$(command -v docker)" ]; then
  echo '
INFO: Docker not installed. Installing Docker client.' >&2
  sudo apt update > /dev/null 2>&1
  sudo apt install apt-transport-https ca-certificates curl software-properties-common -y > /dev/null 2>&1
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - > /dev/null 2>&1
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" > /dev/null 2>&1
  sudo apt update > /dev/null 2>&1
  apt-cache policy docker-ce > /dev/null 2>&1
  sudo apt install docker-ce -y > /dev/null 2>&1
else
  echo "

Docker client already installed."
fi

# Installing Helm client

if ! [ -x "$(command -v helm)" ]; then
  echo 'INFO: Helm not installed. Installing Helm.' >&2
  wget https://get.helm.sh/helm-v3.2.0-linux-amd64.tar.gz > /dev/null 2>&1
  tar xvf helm-v3.2.0-linux-amd64.tar.gz > /dev/null 2>&1
  sudo mv linux-amd64/helm /usr/local/bin/ > /dev/null 2>&1
  rm helm-v3.2.0-linux-amd64.tar.gz > /dev/null 2>&1
  rm -rf linux-amd64 > /dev/null 2>&1
else
  echo "Helm already installed."
fi

# Installing kubectl

if ! [ -x "$(command -v kubectl)" ]; then
  echo 'INFO: kubectl not installed. Installing kubectl.' >&2
  curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl > /dev/null 2>&1
  curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl > /dev/null 2>&1
  chmod +x ./kubectl > /dev/null 2>&1
  sudo mv ./kubectl /usr/local/bin/kubectl > /dev/null 2>&1
else
  echo "kubectl already installed."
fi

# Installing Minikube

if ! [ -x "$(command -v minikube)" ]; then
  echo 'INFO: Minikube not installed. Installing Minikube.' >&2
  echo virtualbox-ext-pack virtualbox-ext-pack/license select true | sudo debconf-set-selections
  sudo apt install virtualbox virtualbox-ext-pack -y > /dev/null 2>&1
  wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 > /dev/null 2>&1
  chmod +x minikube-linux-amd64 > /dev/null 2>&1
  sudo mv minikube-linux-amd64 /usr/local/bin/minikube > /dev/null 2>&1
  helm repo add jfrog https://charts.jfrog.io > /dev/null 2>&1 # Adding JFrog helm repo
  helm repo update > /dev/null 2>&1
  echo "INFO: Starting Minikube"
  minikube start --cpus 6 --memory 10240 --kubernetes-version='v1.16.4' --driver=none > /dev/null 2>&1 # Starting Minikube
  sleep 5
  minikube addons enable ingress > /dev/null 2>&1
else
  echo "Minikube already installed."
fi

if [ "$init" = "Prepare and deploy Artifactory HA" ]; then
  echo "
#######################################
### Deploying Artifactory HA on K8s ###
#######################################
"
  echo "INFO: Creating a secret."
  kubectl create secret generic artifactory-cluster-license --from-file=art.lic # Creating a secret using the art.lic file
  sleep 30
  echo "INFO: Deploying Artifactory HA.
"
  helm install artifactory-ha -f service.yaml -f values.yaml --set artifactory.license.secret=artifactory-cluster-license,artifactory.license.dataKey=art.lic --set nginx.service.type=NodePort jfrog/artifactory-ha

  grep "$GCP_EXTERNAL_IP artifactory.org" /etc/hosts > /dev/null 2>&1 || echo "$GCP_EXTERNAL_IP artifactory.org" >> /etc/hosts # Adding External GCP IP Address to /etc/hosts

  echo "
The deployment has finished successfuly, the cluster will start in 4 minutes.."
  sleep 240

  echo "
##################################
### Deployment was successful! ###
##################################

Awesome mister guy/gal, everything should work in a few minutes.
Now that the cluster is up, you may edit your local machine's '/etc/hosts' file and add the machine IP:

$GCP_EXTERNAL_IP artifactory.org

Now you can access http://artifactory.org from your local machine :)
"
fi

if ! [ -d k8s-files ]; then
  sudo mkdir k8s-files
fi

mv service.yaml k8s-files/
mv values.yaml k8s-files/

if [ -f art.lic ]; then
  mv art.lic k8s-files/
fi

if [ "$init" = "Prepare a Kubernetes environment" ]; then
  echo "
############################################
### Your Kubernetes environemnt is ready! ###
############################################
"
fi
