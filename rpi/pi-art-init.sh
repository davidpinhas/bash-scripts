#!/bin/bash
# Usage: ./pi-init.sh example@gmail.com password server
# Verify root
if [[ $(/usr/bin/id -u) -ne 0 ]]; then
echo "WARN: Not Sudo user. Please run as root."
    exit
fi

# Variables
start=$(date +%s.%N)
echo "Enter your Artifactory user name: "
read username
echo "Enter you user name API Key: "
read password
echo "Enter you Artifactory Cloud server name: "
read artifactory_url

echo "
###################################
## Initialization Script Started ##
###################################"
# Preparing directories and files
echo "INFO: Preparing environment"
if [ ! -d /etc/pip ]; then mkdir -p /etc/pip >/dev/null 2>&1; fi
if [ ! -d /etc/vim ]; then mkdir -p /etc/vim >/dev/null 2>&1; fi
if [ ! -d /etc/apt/auth.conf.d ]; then sudo mkdir -p /etc/apt/auth.conf.d >/dev/null 2>&1; fi
if [ -d "/etc/apt/sources.list" ]; then rm -Rf /etc/apt/sources.list; fi
if [ -d "/etc/apt/sources.list.d/raspi.list" ]; then rm -Rf /etc/apt/sources.list.d/raspi.list; fi
if [ -d "/etc/apt/auth.conf.d/artifactory.conf" ]; then rm -Rf /etc/apt/auth.conf.d/artifactory.conf; fi
sudo echo "machine $artifactory_url.jfrog.io login $username password $password" >> /etc/apt/auth.conf.d/artifactory.conf

# Configure /etc/apt/sources.list with Artifactory
echo "INFO: Creating configuration files"
sudo cat <<EOF > /etc/apt/sources.list
deb [trusted=yes] https://$artifactory_url.jfrog.io/artifactory/raspbian buster main contrib non-free rpi
EOF
# Create /etc/vim/.vimrc
sudo cat <<EOF > /etc/vim/.vimrc
set paste
set number
EOF
# Create /etc/pip/pip.conf
sudo cat <<EOF > /etc/pip/pip.conf
[global]
index-url = https://$username:$password@$artifactory_url.jfrog.io/artifactory/api/pypi/pypi/simple
EOF
# Create .pypirc
sudo cat <<EOF > /root/.pypirc
[distutils]
index-servers = local
[local]
repository: https://$artifactory_url.jfrog.io/artifactory/api/pypi/pypi
username: $username
password: $password
EOF

# Configure static IP
read -p "Are you connected to Wifi or Ethernet? (w/e)" we
case $we in
    [Ww]* ) sudo cat <<EOF > /etc/dhcpcd.conf
interface wlan0
EOF
;;
    [Ee]* ) sudo cat <<EOF > /etc/dhcpcd.conf
interface eth0
EOF
;;
        * ) echo "Please answer yes or no.";;
esac

read -p "Do you wish to configure a static IP? (y/n)" yn
case $yn in
    [Yy]* ) echo "Enter the desired IP address: "
        read ip_addr
        echo "Enter the router IP: "
        read ip_addr_router
        sudo cat <<EOF >> /etc/dhcpcd.conf
        static ip_address=$ip_addr/24
        static routers=$ip_addr_router
        static domain_name_servers=1.1.1.1 1.0.0.1
EOF
;;
    [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
esac

# Update APT repositories and install packages
echo "INFO: Updating APT repositories"
sudo apt-get update -y
echo "
#########################
## Installing Packages ##
#########################"
sudo apt-get install -y tree vim git bluetooth python3-pip i2c-tools locate zsh-syntax-highlighting zsh bc -o Acquire::ForceIPv4=true >/dev/null 2>&1
sudo apt-get install -y tree vim git bluetooth python3-pip i2c-tools locate zsh-syntax-highlighting zsh bc -o Acquire::ForceIPv4=true
yes | sudo sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" >/dev/null 2>&1
sudo chsh -s /bin/zsh
echo "
#####################
## Script Finished ##
#####################
All Done, the system will automatically reboot!!

To change the ZSH theme, run this command:
$ sed -e 's/robbyrussell/avit/g' /root/.zshrc

In order for the static IP configuration to take affect, a restart to the system is required.

Don't forget to change your password!!!!!
$ passwd"
duration=$(echo "$(date +%s.%N) - $start" | bc)
execution_time=`printf "%.2f seconds" $duration`
echo "
#####################################
Script Execution Time: $execution_time
#####################################"
reboot now
