#!/bin/bash
#Artifactory license

#Setting environment variables
#export MASTER_KEY=$(openssl rand -hex 32)
#export JOIN_KEY=$(openssl rand -hex 32)
#export JFROG_URL=$(kubectl describe svc artifactory-ha-nginx | grep Ingress | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b")
export GCP_EXTERNAL_IP=$(curl -H "Metadata-Flavor: Google" http://169.254.169.254/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip)
sudo rm -rf values.yaml
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
#Artifactory installation
echo "Provide the License Key:"
echo "After copying the license, write the sign '~' at the end of the license and press Enter"
read  -d "~" LICENSE
export INPUT="$LICENSE"
echo "Provide the a second License Key:"
echo "After copying the license, write the sign '~' at the end of the license and press Enter"
read  -d "~" LICENSE2
export INPUT2="$LICENSE2"
echo "Provide the a third License Key:"
echo "After copying the license, write the sign '~' at the end of the license and press Enter"
read  -d "~" LICENSE3
export INPUT3="$LICENSE3"
cat <<EOF > art.lic
$INPUT

$INPUT2

$INPUT3
EOF

# Installing Docker client
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
apt-cache policy docker-ce
sudo apt install docker-ce -y
# Installing Helm client
wget https://get.helm.sh/helm-v3.2.0-linux-amd64.tar.gz
tar xvf helm-v3.2.0-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/
rm helm-v3.2.0-linux-amd64.tar.gz
rm -rf linux-amd64
# Installing kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl
curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.18.0/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin/kubectl
# Installing Minikube
echo virtualbox-ext-pack virtualbox-ext-pack/license select true | sudo debconf-set-selections
sudo apt install virtualbox virtualbox-ext-pack -y
wget https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
chmod +x minikube-linux-amd64
sudo mv minikube-linux-amd64 /usr/local/bin/minikube
helm repo add jfrog https://charts.jfrog.io # Adding JFrog helm repo
helm repo update
minikube start --cpus 6 --memory 10240 --kubernetes-version='v1.16.4' --driver=none # Starting Minikube
minikube addons enable ingress

kubectl create secret generic artifactory-cluster-license --from-file=art.lic
helm install artifactory-ha -f service.yaml -f values.yaml --set artifactory.license.secret=artifactory-cluster-license,artifactory.license.dataKey=art.lic --set nginx.service.type=NodePort jfrog/artifactory-ha
grep "$GCP_EXTERNAL_IP artifactory.org" /etc/hosts || echo "$GCP_EXTERNAL_IP artifactory.org" >> /etc/hosts

echo "
Awesome mister guy/gal, everything should work in a few minutes.
All you need to do is edit your local machine's '/etc/hosts' file and add the machine IP:
$GCP_EXTERNAL_IP artifactory.org

Now you can access artifactory.org from your local machine :)
"

#Xray installation
#helm install xray --set xray.joinKey=${JOIN_KEY} --set xray.jfrogUrl=${JFROG_URL} jfrog/xray
