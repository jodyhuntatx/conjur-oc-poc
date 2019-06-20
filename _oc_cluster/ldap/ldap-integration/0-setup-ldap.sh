#!/bin/bash -ex
set -o pipefail

source ../utils.sh

LDAP_ADMIN_PASSWORD=admin

test_ldap_connect() {
    docker exec -it ldap bash -c "ldapsearch -x -h localhost -b dc=example,dc=org -D cn=admin,dc=example,dc=org -w admin '(objectClass=user)'"
}

main() {
  docker run -d \
    --name ldap \
    --label role=ldap_server \
    --restart always \
    -p "389:389" \
    -p "636:636" \
    osixia/openldap:1.1.7

  conjur_cli_pod=$(get_conjur_cli_pod_name)
  $cli cp ./ldap-sync-config.yml $conjur_cli_pod:/policy/
  $cli exec $conjur_cli_pod -- conjur policy load root /policy/ldap-sync-config.yml
  $cli exec $conjur_cli_pod -- conjur variable values add conjur/ldap-sync/bind-password/default $LDAP_ADMIN_PASSWORD


  for i in {1..60}; do
    if ! test_ldap_connect; then
        echo "Waiting for OpenLDAP to start"
     else
        break
    fi
    sleep 1
  done

                # hopefully prevent intermittent failures
  sleep 2
                        # load demo groups & users from mounted file
  ./ldap-add.sh ldap-bootstrap.ldif
}

main "$@"
