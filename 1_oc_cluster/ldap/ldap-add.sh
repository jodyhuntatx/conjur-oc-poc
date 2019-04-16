#!/bin/bash -e
if [[ "$1" == "" ]]; then
  echo "Usage: $0 <file-to-add>"
  exit -1
fi
docker cp $1 ldap:/
set -x
docker exec -it ldap-server bash -c "ldapadd -x -D cn=admin,dc=example,dc=org -w admin -f $1"
