import os

# import time
from kubernetes import client, config

# from kubernetes.client.exceptions import ApiException
from ..k8 import deploy_k8

# from ..utils import cleanup_k8_resources
# import pytest


def test_deploy_k8_only_littlex():
    """
    This test runs deploy_k8() against a live Kubernetes cluster.
    Use only in a test namespace.
    """

    # Load kubeconfig and initialize client
    config.load_kube_config()
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()

    namespace = os.getenv("K8_NAMESPACE", "default")

    # Set environment
    os.environ.update(
        {
            "APP_NAME": "littlex",
            "DOCKER_IMAGE_NAME": "littlex:latest",
            "DOCKER_USERNAME": "juzailmlwork",
            "K8_MONGODB": "false",
            "K8_REDIS": "false",
            "K8_NAMESPACE": namespace,
            "K8_CONTAINER_PORT": "8000",
            "K8_NODE_PORT": "30050",
        }
    )

    # Run deploy
    deploy_k8(code_folder=".", build=True)

    # Validate the deployment exists
    deployment = apps_v1.read_namespaced_deployment(name="littlex", namespace=namespace)
    assert deployment.metadata.name == "littlex"
    assert deployment.spec.replicas == 1

    # Validate service
    service = core_v1.read_namespaced_service(
        name="littlex-service", namespace=namespace
    )
    assert service.spec.type == "NodePort"

    # Cleanup (optional)
    apps_v1.delete_namespaced_deployment("littlex", namespace)
    core_v1.delete_namespaced_service("littlex-service", namespace)


# def test_deploy_k8_with_mongodb_and_redis():
#     """
#     Integration test that runs deploy_k8() with MongoDB and Redis enabled
#     against a live Kubernetes cluster.
#     Use only in a test namespace.
#     """

#     # Load kubeconfig and initialize client
#     config.load_kube_config()
#     apps_v1 = client.AppsV1Api()
#     core_v1 = client.CoreV1Api()

#     namespace = os.getenv("K8_NAMESPACE", "default")

#     # Set environment for MongoDB + Redis test
#     os.environ.update(
#         {
#             "APP_NAME": "littlex",
#             "DOCKER_IMAGE_NAME": "littlex:latest",
#             "DOCKER_USERNAME": "juzailmlwork",
#             "K8_MONGODB": "true",
#             "K8_REDIS": "true",
#             "K8_NAMESPACE": namespace,
#             "K8_CONTAINER_PORT": "8000",
#             "K8_NODE_PORT": "30051",  # Different port to avoid conflict
#         }
#     )

#     # Run deploy
#     deploy_k8(code_folder=".", build=True)

#     # --- Validate main deployment ---
#     deployment = apps_v1.read_namespaced_deployment(name="littlex", namespace=namespace)
#     assert deployment.metadata.name == "littlex"
#     assert deployment.spec.replicas == 1

#     # --- Validate app service ---
#     service = core_v1.read_namespaced_service(
#         name="littlex-service", namespace=namespace
#     )
#     assert service.spec.type == "NodePort"

#     # --- Validate MongoDB StatefulSet and Service ---
#     mongodb_stateful = apps_v1.read_namespaced_stateful_set(
#         name="littlex-mongodb", namespace=namespace
#     )
#     assert mongodb_stateful.spec.service_name == "littlex-mongodb-service"

#     mongodb_service = core_v1.read_namespaced_service(
#         name="littlex-mongodb-service", namespace=namespace
#     )
#     assert mongodb_service.spec.ports[0].port == 27017

#     # --- Validate Redis Deployment and Service ---
#     redis_deploy = apps_v1.read_namespaced_deployment(
#         name="littlex-redis", namespace=namespace
#     )
#     assert redis_deploy.metadata.name == "littlex-redis"

#     redis_service = core_v1.read_namespaced_service(
#         name="littlex-redis-service", namespace=namespace
#     )
#     assert redis_service.spec.ports[0].port == 6379

#     # Cleanup after test (optional)
#     apps_v1.delete_namespaced_deployment("littlex", namespace)
#     apps_v1.delete_namespaced_deployment("littlex-redis", namespace)
#     apps_v1.delete_namespaced_stateful_set("littlex-mongodb", namespace)
#     core_v1.delete_namespaced_service("littlex-service", namespace)
#     core_v1.delete_namespaced_service("littlex-redis-service", namespace)
#     core_v1.delete_namespaced_service("littlex-mongodb-service", namespace)


# def test_deploy_k8_with_mongodb_and_redis_different_namespace():
#     """
#     Integration test that runs deploy_k8() with MongoDB and Redis enabled
#     against a live Kubernetes cluster.
#     Use only in a test namespace.
#     """

#     # Load kubeconfig and initialize client
#     config.load_kube_config()
#     apps_v1 = client.AppsV1Api()
#     core_v1 = client.CoreV1Api()

#     namespace = "mock-test"

#     # Set environment for MongoDB + Redis test
#     os.environ.update(
#         {
#             "APP_NAME": "littlex",
#             "DOCKER_IMAGE_NAME": "littlex:latest",
#             "DOCKER_USERNAME": "juzailmlwork",
#             "K8_MONGODB": "true",
#             "K8_REDIS": "true",
#             "K8_NAMESPACE": namespace,
#             "K8_CONTAINER_PORT": "8000",
#             "K8_NODE_PORT": "30051",
#         }
#     )

#     # Run deploy
#     deploy_k8(code_folder=".", build=True)

#     # # Wait for resources to be ready
#     # time.sleep(30)

#     # --- Validate main deployment ---
#     deployment = apps_v1.read_namespaced_deployment(name="littlex", namespace=namespace)
#     assert deployment.metadata.name == "littlex"
#     assert deployment.spec.replicas == 1

#     # --- Validate app service ---
#     service = core_v1.read_namespaced_service(
#         name="littlex-service", namespace=namespace
#     )
#     assert service.spec.type == "NodePort"

#     # --- Validate MongoDB StatefulSet and Service ---
#     mongodb_stateful = apps_v1.read_namespaced_stateful_set(
#         name="littlex-mongodb", namespace=namespace
#     )
#     assert mongodb_stateful.spec.service_name == "littlex-mongodb-service"

#     mongodb_service = core_v1.read_namespaced_service(
#         name="littlex-mongodb-service", namespace=namespace
#     )
#     assert mongodb_service.spec.ports[0].port == 27017

#     # --- Validate Redis Deployment and Service ---
#     redis_deploy = apps_v1.read_namespaced_deployment(
#         name="littlex-redis", namespace=namespace
#     )
#     assert redis_deploy.metadata.name == "littlex-redis"

#     redis_service = core_v1.read_namespaced_service(
#         name="littlex-redis-service", namespace=namespace
#     )
#     assert redis_service.spec.ports[0].port == 6379

#     # Cleanup after test (optional)
#     apps_v1.delete_namespaced_deployment("littlex", namespace)
#     apps_v1.delete_namespaced_deployment("littlex-redis", namespace)
#     apps_v1.delete_namespaced_stateful_set("littlex-mongodb", namespace)
#     core_v1.delete_namespaced_service("littlex-service", namespace)
#     core_v1.delete_namespaced_service("littlex-redis-service", namespace)
#     core_v1.delete_namespaced_service("littlex-mongodb-service", namespace)


# def test_deploy_and_cleanup_k8_resources():
#     """Test deploy_k8() with MongoDB and Redis, then cleanup_k8_resources()."""

#     config.load_kube_config()
#     apps_v1 = client.AppsV1Api()
#     core_v1 = client.CoreV1Api()
#     namespace = "default"

#     os.environ.update(
#         {
#             "APP_NAME": "littlex",
#             "DOCKER_IMAGE_NAME": "littlex:latest",
#             "DOCKER_USERNAME": "juzailmlwork",
#             "K8_MONGODB": "true",
#             "K8_REDIS": "true",
#             "K8_NAMESPACE": namespace,
#             "K8_CONTAINER_PORT": "8000",
#             "K8_NODE_PORT": "30051",
#         }
#     )

#     # Deploy resources
#     deploy_k8(code_folder=".", build=True, testing=True)
#     # ------------------
#     # Assert resources exist
#     # ------------------
#     deployment = apps_v1.read_namespaced_deployment("littlex", namespace)
#     assert deployment.metadata.name == "littlex"

#     service = core_v1.read_namespaced_service("littlex-service", namespace)
#     assert service.spec.type == "NodePort"

#     mongodb_stateful = apps_v1.read_namespaced_stateful_set(
#         "littlex-mongodb", namespace
#     )
#     assert mongodb_stateful.spec.service_name == "littlex-mongodb-service"

#     redis_deploy = apps_v1.read_namespaced_deployment("littlex-redis", namespace)
#     assert redis_deploy.metadata.name == "littlex-redis"

#     # ------------------
#     # Cleanup
#     # ------------------
#     cleanup_k8_resources()
#     time.sleep(5)  # small delay to allow deletion to propagate

#     # ------------------
#     # Assert resources no longer exist
#     # ------------------
#     with pytest.raises(ApiException):
#         apps_v1.read_namespaced_deployment("littlex", namespace)
#     with pytest.raises(ApiException):
#         core_v1.read_namespaced_service("littlex-service", namespace)
#     with pytest.raises(ApiException):
#         apps_v1.read_namespaced_stateful_set("littlex-mongodb", namespace)
#     with pytest.raises(ApiException):
#         apps_v1.read_namespaced_deployment("littlex-redis", namespace)
#     with pytest.raises(ApiException):
#         core_v1.read_namespaced_service("littlex-redis-service", namespace)
#     with pytest.raises(ApiException):
#         core_v1.read_namespaced_service("littlex-mongodb-service", namespace)
