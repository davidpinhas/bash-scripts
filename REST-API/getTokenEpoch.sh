#!/bin/bash
RESULTS=$(curl -u<USER>:<PASSWORD> "http://localhost:8081/artifactory/api/security/token" -H "Content-Type: application/x-www-form-urlencoded")
TOKEN=$(curl -u<USER>:<PASSWORD> "http://localhost:8081/artifactory/api/security/token" -H "Content-Type: application/x-www-form-urlencoded"| grep -A 2 "expiry")
EPOCH=$(curl -u<USER>:<PASSWORD> "http://localhost:8081/artifactory/api/security/token" -H "Content-Type: application/x-www-form-urlencoded" | jq '.tokens | .[].expiry')
expiry=$(curl -u<USER>:<PASSWORD> "http://localhost:8081/artifactory/api/security/token" -H "Content-Type: application/x-www-form-urlencoded"| grep "expiry" |sed 's/"expiry"//g'|sed 's/://g' |sed 's/,//g'|sed 's/^ *//g')
#echo $EPOCH
ARRAY=()
ARRAY+=("$EPOCH")
CRON=1576422927
#for i in "${!ARRAY[@]}" ; do ARRAY[$i]="${ARRAY[$i]:-other}"; done
#echo ${ARRAY[@]/$delete}
#for i in "${!ARRAY[@]}"
#do
#  ARRAY[$i]="${ARRAY[$i]:-other}"
#done

echo $EPOCH
echo $expiry
#for host in ${ARRAY2[@]}; do
#array1=( "${ARRAY[@]/$host}" )
#done

#echo "The new list of elements in array1 are: ${ARRAY[@]}"

