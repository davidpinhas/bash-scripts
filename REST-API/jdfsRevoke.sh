#!/bin/bash
input="/path/to/txt/file"
serverURL=http://localhost:8081/artifactory
while IFS= read -r line
do
  echo "$line"
  curl -uadmin:password -XPOST "$serverURL/api/security/token/revoke" -d "token_id=$line"
done < "$input"
