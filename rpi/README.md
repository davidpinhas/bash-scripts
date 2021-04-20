# **RPi Configuration with Artifactory Script**

## **Description**

This repository's main goal is to configure a fresh Raspberry Pi with JFrog Artifactory Cloud for Home Automation (using [Home Assistant](https://www.home-assistant.io/)) and additional services.

## **System Configuration**

Download the Raspbian OS from the official RPi site - [Operating system images – Raspberry Pi.
](https://www.raspberrypi.org/software/operating-systems/)After downloading, make a bootable USB with the ISO, using [balenaEtcher,](https://www.balena.io/etcher/) and install it on a 32GB SD card.
In case you are using the Argon M.2 case, follow the steps in the following Wiki page - [PI4-CASE-ARGON-ONE-M.2 - Waveshare Wiki](https://www.waveshare.com/wiki/PI4-CASE-ARGON-ONE-M.2).

The script requires you to provide your Artifactory's instance admin credentials, along with the server name – **Only Artifactory Cloud instances are supported**.

The Artifactory Virtual repository should be named "raspbian" and aggregate 3 Remote repositories with the following URLs:
- http://archive.ubuntu.com/ubuntu/
- http://mirrordirector.raspbian.org/raspbian/
- http://raspbian.raspberrypi.org/raspbian/

The installation of the script **pi-art-init.sh** will perform the following:

- Request Artifactory credentials
- Configure the PIP client with Artifactory
- Configure a static IP Ethernet/Wireless (this will overwrite the /etc/dhcpcd.conf file)
- Setting the Artifactory repository (overwriting the /etc/apt/sources.list to **go only through Artifactory** )
- Updating and upgrading the system
- Installing the Docker client and configuring it with the **Pi** user
- Installing ZSH and Oh-My-Zsh

Make sure the system has installed ZSH/Oh-My-Zsh and **both root and pi users password is changed** :
```
curl https://raw.githubusercontent.com/davidpinhas/bash-scripts/master/rpi/pi-art-init.sh -O
sudo bash pi-art-init.sh
```
**Warning**: This script was tested with RPi 2/4/Zero WH.

## **Home Assistant Supervisor**

### **Configuration** :

Run the following command for starting the HA Docker container:
```
docker run --init -d --name="home-assistant" -e "TZ=Asia/Jerusalem" -v /Users/pi/homeassistant:/config -p 8123:8123 homeassistant/home-assistant:stable
```
Running the HA Supervisor Docker container:
```
bash supervised-installer.sh -m raspberrypi4
```
Configure Home assistant Supervisor services:
```
$ system cat pi-hassio-apparmor.service
 [Unit]
 Description=Hass.io AppArmor
 Wants=hassio-supervisor.service
 Before=docker.service hassio-supervisor.service

 [Service]
 Type=oneshot
 RemainAfterExit=true
 ExecStart=/usr/sbin/hassio-apparmor

 [Install]
 WantedBy=multi-user.target
```
```
$ system cat pi-hassio-supervisor.service
 [Unit]
 Description=Hass.io supervisor
 Requires=docker.service
 After=docker.service dbus.socket

 [Service]
 Type=simple
 Restart=always
 RestartSec=5s
 ExecStartPre=-/usr/bin/docker stop hassio\_supervisor
 ExecStart=/usr/sbin/hassio-supervisor
 ExecStop=-/usr/bin/docker stop hassio\_supervisor

 [Install]
 WantedBy=multi-user.target
```
- Hacs - [Installation | HACS](https://hacs.xyz/docs/installation/installation)
- Node-RED - [hassio-addons/addon-node-red](https://github.com/hassio-addons/addon-node-red/blob/main/node-red/DOCS.md)
- Animated Backgrounds - [Villhellm/lovelace-animated-background](https://github.com/Villhellm/lovelace-animated-background)

### **Sources:**

GitHub page - [davidpinhas/supervised-installer](https://github.com/davidpinhas/supervised-installer)

### **Equipment:**

- [Raspberry Pi 4 8GB RAM](https://piitel.co.il/shop/raspberry-pi-4/)
- [Argon M.2 Case](https://piitel.co.il/shop/argon-one-m-2-case-for-raspberry-pi-4/)
- [SSD](https://ksp.co.il/web/item/55594)
- Type-C 20V charger

The links above are designated for Israeli consumers.
