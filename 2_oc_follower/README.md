# 2_oc_follower

Installation & configuration scripts for a Conjur Followers in OpenShift.

These scripts assume no direct access to the Conjur Master host.

Contents:
 - deploy-configs/ - directory of deployment manifests.
 - build/seed-fetcher - builds seed-fetcher image for Follower init container
 - start - deploys and configures Followers.
 - stop - deletes deployed Followers, services, routes.
 - kill_project.sh - destroys Follower project.
 - 0_check_dependencies.sh - checks that all necessary environment vars are set.
 - 1_prepare_conjur_namespace.sh - creates new Follower project and cluster role.
 - 2_init_follower_authn.sh - initializes cluster config secrets in Conjur master
 - 3_prepare_docker_images.sh - pushes appliance and CLI image to OpenShift registry.
 - 4_deploy_conjur_followers.sh - deploys Follower pods and Route.
 - _update_follower_cert.sh - reissues Follower certificate with Route as a SAN DNS entry and creates new Folower seed file. REQUIRES DOCKER ACCESS TO CONJUR MASTER.
 - _configure_followers.sh - explicit initialization of Followers
 - get_cert_REST.sh - retrieves Conjur server cert from designaged host/port via REST call (openssl)
 - var_value_add_REST.sh - initializes Conjur variable via REST call
