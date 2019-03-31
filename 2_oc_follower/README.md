# conjur-oc-poc/2_oc_follower

Install & configuration scripts for a Conjur Followers in OpenShift.

Contents:

 - 0_check_dependencies.sh - checks that all necessary environment vars are set.
 - 1_prepare_conjur_namespace.sh - creates new Follower project and cluster role.
 - 2_prepare_docker_images.sh - pushes appliance and CLI image to OpenShift registry.
 - 3_deploy_conjur_followers.sh - deploys Follower pods and Route.
 - 4_update_follower_cert.sh - reissues Follower certificate with Route as a SAN DNS entry and creates new Folower seed file. REQUIRES DOCKER ACCESS TO CONJUR MASTER.
 - 5_configure_followers.sh - configures Followers.
 - deploy-configs/ - directory of deployment manifests.
 - kill_project.sh - destroys Follower project.
 - start - deploys and configures Followers.
 - stop - deletes deployed Followers, services, routes.
