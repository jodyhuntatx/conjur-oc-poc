# 3_oc_app

Install & configuration scripts for a simple application in OpenShift.

Contents:
 - deploy-configs/ - deployment manifests.
 - policy/ - policy templates and instantiated policies for app identities and permissions
 - test-app/ - Dockerfile and build artifacts for test application.
 - start - deploys application pods and runs apps for secrets retrieval demo.
 - stop - deletes all deployed artifacts.
 - kill_project.sh - destroys project.
 - 0_check_dependencies.sh - checks necessary environment vars are set.
 - 1_create_test_app_namespace.sh - creates app project.
 - 2_store_conjur_cert.sh - retrieves Follower cert and stores in config map.
 - 3_build_and_push_containers.sh - builds app image, pushes app image and authenticator images to registry.
 - 4_load_policies.sh - loads app identity and permissions policies, initializes test variables.
 - 5_deploy_test_app.sh - deploys 2 app pods with authenticator configured as init container and sidecar.
 - 6_verify_authentication.sh - runs apps in pods to demonstrate secrets retrieval.
 - exec-into-app.sh - script to exec into app container. Takes 'side' or 'init' as argument to specify container to exec into.
 - load_policy_REST.sh - script to load policy files w/ REST API.
 - var_value_add_REST.sh - script to initialize variables w/ REST API.
