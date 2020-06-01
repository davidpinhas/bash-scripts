# Artifactory Docker Registry configuration script
This repository provides a script to install and configure Artifactory Standalone/High Availability as a Docker registry, using Sub-Domain or Repository Path access methods.<br/>

### To use the script, apply executable permissions to the file

```
$ chmod +x install-script.sh
```

## Menu Selections

Database:
* Derby
* PostgreSQL

Installation Type:
* Standalone
* High Availability

Access Method:
* Repository Path
* Sub-Domain

### Notes and Support

This script supports installation of Artifactory versions 6.15.0 and above, due to the support blocking Schema 1 requests that was introduced in [version 6.15.0](https://www.jfrog.com/confluence/display/RTF6X/Release+Notes#ReleaseNotes-Artifactory6.15).<br/>
Important Note - Running this script will delete all Docker containers associated with the Artifactory service, including Nginx and PostgreSQL. Using the script on a new GCP instance is preferable.<br/>

#### System requirements:

4 CPU Cores<br/>
8GB Memory<br/>
25GB Image size<br/>

#### Suupported Operating Systems:<br/>
Ubuntu 16.04 LTS<br/>
Ubuntu 18.04 LTS<br/>
CentOS 7<br/>
CentOS 8<br/>
