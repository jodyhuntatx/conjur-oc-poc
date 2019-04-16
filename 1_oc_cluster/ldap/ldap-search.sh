#!/bin/bash -e
if [[ "$1" == "" ]]; then
  echo "Usage: $0 <search-filter>"
  echo "    e.g. \"$0 uid=alice\""
  exit -1
fi
set -x
docker exec -it ldap-server bash -c "ldapsearch -x -h localhost -b dc=example,dc=org -D cn=admin,dc=example,dc=org -w ldapsecret -L $1"
