#!/bin/bash
TOKENS=$(curl -u<USER>:<PASSWORD> "http://localhost:8081/artifactory/api/security/token" |grep jfds -a3 |grep token_id |sed 's/"token_id"//g'|sed 's/://g' |sed 's/"//g'|sed 's/^ *//g'|sed 's/,//g')
 for token in $TOKENS; do
     curl -u<USER>:<PASSWORD> "http://localhost:8081/artifactory/api/security/token/revoke" -d "token_id=$token"
done

