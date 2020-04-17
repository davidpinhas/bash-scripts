#!/bin/bash
         COUNTER=1
         until [  $COUNTER -gt 5000 ]; do
curl -u<USER>:<PASSWORD> -XPOST "http://localhost:8081/artifactory/api/security/token" -d "username=<test-user>'$COUNTER'" -d "scope=member-of-groups:readers"
             let COUNTER+=1
         done
