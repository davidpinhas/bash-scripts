#!/bin/bash
## Verify root

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "WARN: Not Sudo user. Please run as root."
    exit
fi

#Usage: ./network-test.sh example@gmail.com password
# start=$(date +%s.%N)
start=`date +%s`

username=$1
password=$2
SERVER=$3
if [ -z "$username" ]; then echo "No username provided, add the parameters as follows: $./network-test.sh username password server"; exit 1; fi
if [ -z "$password" ]; then echo "No password entered, add the parameters as follows: $./network-test.sh username server"; exit 1; fi
if [ -z "$SERVER" ]; then echo "No server entered, add the parameters as follows: $./network-test.sh username server"; exit 1; fi

## Ping tests
echo "################################
Pinging Artifactory
################################
"
for i in {1..5}; do 
    time curl -u"$1":"$2" "https://$3.jfrog.io/artifactory/api/system/ping" ; done


end=`date +%s`
runtime=$((end-start))

# duration=$(echo "$(date +%s.%N) - $start" | bc)
# execution_time="printf '%.2f seconds' $duration"
echo "
################################
Test Duration: $runtime Seconds
################################"

### TODO ###
# Download speed test
# Upload speed test
# Connectivity to Xray
# test LDAP connection
