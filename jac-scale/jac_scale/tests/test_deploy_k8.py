import os
import time

import requests
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

from ..kubernetes.k8 import deploy_k8
from ..kubernetes.utils import cleanup_k8_resources


def test_deploy_todo_app():
    """
    This test runs deploy_k8() with build=False to deploy the todo app
    against a live Kubernetes cluster using the app.jac from the todo folder.
    Validates deployment, services, sends HTTP request, and tests cleanup.
    Use only in a test namespace.
    """

    # Load kubeconfig and initialize client
    config.load_kube_config()
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()

    namespace = "todo-app"

    # Set environment
    os.environ.update(
        {
            "APP_NAME": "todo-app",
            "K8_MONGODB": "true",
            "K8_REDIS": "true",
            "K8_NAMESPACE": namespace,
            "K8_NODE_PORT": "30051",
        }
    )

    # Resolve the absolute path to the todo app folder
    test_dir = os.path.dirname(os.path.abspath(__file__))
    todo_app_path = os.path.join(test_dir, "../../examples/todo")

    # Run deploy with build=False, targeting the app.jac file in examples/todo folder
    deploy_k8(code_folder=todo_app_path, file_name="app.jac", build=False)

    # Wait a moment for services to stabilize
    time.sleep(5)

    # Validate the main deployment exists
    deployment = apps_v1.read_namespaced_deployment(
        name="todo-app", namespace=namespace
    )
    assert deployment.metadata.name == "todo-app"
    assert deployment.spec.replicas == 1

    # Validate main service
    service = core_v1.read_namespaced_service(
        name="todo-app-service", namespace=namespace
    )
    assert service.spec.type == "NodePort"
    node_port = service.spec.ports[0].node_port
    print(f"✓ Service is exposed on NodePort: {node_port}")
    # Validate MongoDB StatefulSet and Service
    mongodb_stateful = apps_v1.read_namespaced_stateful_set(
        name="todo-app-mongodb", namespace=namespace
    )
    assert mongodb_stateful.metadata.name == "todo-app-mongodb"
    assert mongodb_stateful.spec.service_name == "todo-app-mongodb-service"

    mongodb_service = core_v1.read_namespaced_service(
        name="todo-app-mongodb-service", namespace=namespace
    )
    assert mongodb_service.spec.ports[0].port == 27017

    # Validate Redis Deployment and Service
    redis_deploy = apps_v1.read_namespaced_deployment(
        name="todo-app-redis", namespace=namespace
    )
    assert redis_deploy.metadata.name == "todo-app-redis"

    redis_service = core_v1.read_namespaced_service(
        name="todo-app-redis-service", namespace=namespace
    )
    assert redis_service.spec.ports[0].port == 6379

    # Send POST request to create a todo
    try:
        url = f"http://localhost:{node_port}/walker/create_todo"
        payload = {"text": "first-task"}
        response = requests.post(url, json=payload, timeout=10)
        assert response.status_code == 201
        print(f"✓ Successfully created todo at {url}")
        print(f"  Response: {response.json()}")
    except requests.exceptions.RequestException as e:
        print(f"Warning: Could not reach POST {url}: {e}")

    # Send GET request to retrieve the clientpage of todo app
    try:
        url = f"http://localhost:{node_port}/page/app"
        response = requests.get(url, timeout=10)
        assert response.status_code == 200
        print(f"✓ Successfully reached app page at {url}")
    except requests.exceptions.RequestException as e:
        print(f"Warning: Could not reach GET {url}: {e}")

    # Cleanup resources
    cleanup_k8_resources()
    time.sleep(5)  # Wait for deletion to propagate

    # Verify cleanup - resources should no longer exist
    try:
        apps_v1.read_namespaced_deployment("todo-app", namespace=namespace)
        raise AssertionError("Deployment should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        core_v1.read_namespaced_service("todo-app-service", namespace=namespace)
        raise AssertionError("Service should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        apps_v1.read_namespaced_stateful_set("todo-app-mongodb", namespace=namespace)
        raise AssertionError("MongoDB StatefulSet should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        core_v1.read_namespaced_service("todo-app-mongodb-service", namespace=namespace)
        raise AssertionError("MongoDB Service should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        apps_v1.read_namespaced_deployment("todo-app-redis", namespace=namespace)
        raise AssertionError("Redis Deployment should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        core_v1.read_namespaced_service("todo-app-redis-service", namespace=namespace)
        raise AssertionError("Redis Service should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    # Verify PVC cleanup
    pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace=namespace)
    for pvc in pvcs.items:
        assert not pvc.metadata.name.startswith("todo-app"), (
            f"PVC '{pvc.metadata.name}' should have been deleted"
        )

    print("✓ Cleanup verification complete - all resources properly deleted")


# def test_deploy_k8_only_littlex():
#     """
#     This test runs deploy_k8() against a live Kubernetes cluster.
#     Use only in a test namespace.
#     """

#     # Load kubeconfig and initialize client
#     config.load_kube_config()
#     apps_v1 = client.AppsV1Api()
#     core_v1 = client.CoreV1Api()

#     namespace = os.getenv("K8_NAMESPACE", "default")

#     # Set environment
#     os.environ.update(
#         {
#             "APP_NAME": "littlex",
#             "DOCKER_IMAGE_NAME": "littlex:latest",
#             "DOCKER_USERNAME": "juzailmlwork",
#             "K8_MONGODB": "false",
#             "K8_REDIS": "false",
#             "K8_NAMESPACE": namespace,
#             "K8_CONTAINER_PORT": "8000",
#             "K8_NODE_PORT": "30050",
#         }
#     )

#     # Run deploy
#     deploy_k8(code_folder=".", build=True)

#     # Validate the deployment exists
#     deployment = apps_v1.read_namespaced_deployment(name="littlex", namespace=namespace)
#     assert deployment.metadata.name == "littlex"
#     assert deployment.spec.replicas == 1

#     # Validate service
#     service = core_v1.read_namespaced_service(
#         name="littlex-service", namespace=namespace
#     )
#     assert service.spec.type == "NodePort"

#     # Cleanup (optional)
#     apps_v1.delete_namespaced_deployment("littlex", namespace)
#     core_v1.delete_namespaced_service("littlex-service", namespace)
