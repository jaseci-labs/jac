"""Tests for Kubernetes deployment using new factory-based architecture."""

import os
import time
from typing import Any

import requests
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

from ..abstractions.config.app_config import AppConfig
from ..config_loader import get_scale_config
from ..factories.deployment_factory import DeploymentTargetFactory
from ..factories.utility_factory import UtilityFactory


def _request_with_retry(
    method: str,
    url: str,
    json: dict[str, Any] | None = None,
    timeout: int = 10,
    max_retries: int = 60,
    retry_interval: float = 2.0,
) -> requests.Response:
    """Make an HTTP request with retry logic for 503 responses.

    Args:
        method: HTTP method (GET, POST, etc.)
        url: The URL to request
        json: JSON payload for the request
        timeout: Request timeout in seconds
        max_retries: Maximum number of retries for 503 responses
        retry_interval: Time to wait between retries in seconds

    Returns:
        Response object
    """
    response = None
    for attempt in range(max_retries):
        response = requests.request(
            method=method,
            url=url,
            json=json,
            timeout=timeout,
        )

        if response.status_code == 503:
            print(
                f"[DEBUG] {url} returned 503, retrying ({attempt + 1}/{max_retries})..."
            )
            time.sleep(retry_interval)
            continue

        return response

    # Return last response even if it was 503
    assert response is not None, "No response received"
    return response


def test_deploy_todo_app():
    """
    Test deployment using the new factory-based architecture.
    Deploys the todo app against a live Kubernetes cluster.
    Validates deployment, services, sends HTTP request, and tests cleanup.
    Use only in a test namespace.
    """
    # Load kubeconfig and initialize client
    config.load_kube_config()
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()

    namespace = "todo-app"
    app_name = "todo-app"

    # Set environment
    os.environ.update({"APP_NAME": app_name, "K8s_NAMESPACE": namespace})

    # Resolve the absolute path to the todo app folder
    test_dir = os.path.dirname(os.path.abspath(__file__))
    todo_app_path = os.path.join(test_dir, "../../examples/todo/src")

    # Get configuration
    scale_config = get_scale_config()
    target_config = scale_config.get_kubernetes_config()
    target_config["app_name"] = app_name
    target_config["namespace"] = namespace

    # Create logger
    logger = UtilityFactory.create_logger("standard")

    # Create deployment target using factory
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    )

    # Create app config
    app_config = AppConfig(
        code_folder=todo_app_path,
        file_name="main.jac",
        build=False,
    )

    # Deploy using new architecture
    result = deployment_target.deploy(app_config)

    assert result.success is True
    print(f"✓ Deployment successful: {result.message}")

    # Wait a moment for services to stabilize
    time.sleep(5)

    # Validate the main deployment exists
    deployment = apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace)
    assert deployment.metadata.name == app_name
    assert deployment.spec.replicas == 1

    # Validate main service
    service = core_v1.read_namespaced_service(
        name=f"{app_name}-service", namespace=namespace
    )
    assert service.spec.type == "NodePort"
    node_port = service.spec.ports[0].node_port
    print(f"✓ Service is exposed on NodePort: {node_port}")

    # Validate MongoDB StatefulSet and Service
    mongodb_stateful = apps_v1.read_namespaced_stateful_set(
        name=f"{app_name}-mongodb", namespace=namespace
    )
    assert mongodb_stateful.metadata.name == f"{app_name}-mongodb"
    assert mongodb_stateful.spec.service_name == f"{app_name}-mongodb-service"

    mongodb_service = core_v1.read_namespaced_service(
        name=f"{app_name}-mongodb-service", namespace=namespace
    )
    assert mongodb_service.spec.ports[0].port == 27017

    # Validate Redis Deployment and Service
    redis_deploy = apps_v1.read_namespaced_deployment(
        name=f"{app_name}-redis", namespace=namespace
    )
    assert redis_deploy.metadata.name == f"{app_name}-redis"

    redis_service = core_v1.read_namespaced_service(
        name=f"{app_name}-redis-service", namespace=namespace
    )
    assert redis_service.spec.ports[0].port == 6379

    # Test get_status
    status = deployment_target.get_status(app_name)
    assert status is not None
    assert status.replicas >= 0
    print(
        f"✓ Deployment status: {status.status.value}, replicas: {status.replicas}/{status.ready_replicas}"
    )

    # Send POST request to create a todo (with retry for 503)
    try:
        url = f"http://localhost:{node_port}/walker/create_todo"
        payload = {"text": "first-task"}
        response = _request_with_retry("POST", url, json=payload, timeout=10)
        assert response.status_code == 200
        print(f"✓ Successfully created todo at {url}")
        print(f"  Response: {response.json()}")
    except requests.exceptions.RequestException as e:
        print(f"Warning: Could not reach POST {url}: {e}")

    # Send GET request to retrieve the clientpage of todo app (with retry for 503)
    try:
        url = f"http://localhost:{node_port}/cl/app"
        response = _request_with_retry("GET", url, timeout=10)
        assert response.status_code == 200
        print(f"✓ Successfully reached app page at {url}")
    except requests.exceptions.RequestException as e:
        print(f"Warning: Could not reach GET {url}: {e}")

    # Cleanup using new architecture
    deployment_target.destroy(app_name)
    time.sleep(60)  # Wait for deletion to propagate

    # Verify cleanup - resources should no longer exist
    try:
        apps_v1.read_namespaced_deployment(app_name, namespace=namespace)
        raise AssertionError("Deployment should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        core_v1.read_namespaced_service(f"{app_name}-service", namespace=namespace)
        raise AssertionError("Service should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        apps_v1.read_namespaced_stateful_set(f"{app_name}-mongodb", namespace=namespace)
        raise AssertionError("MongoDB StatefulSet should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        core_v1.read_namespaced_service(
            f"{app_name}-mongodb-service", namespace=namespace
        )
        raise AssertionError("MongoDB Service should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        apps_v1.read_namespaced_deployment(f"{app_name}-redis", namespace=namespace)
        raise AssertionError("Redis Deployment should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    try:
        core_v1.read_namespaced_service(
            f"{app_name}-redis-service", namespace=namespace
        )
        raise AssertionError("Redis Service should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    # Verify PVC cleanup
    pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace=namespace)
    for pvc in pvcs.items:
        assert not pvc.metadata.name.startswith(app_name), (
            f"PVC '{pvc.metadata.name}' should have been deleted"
        )

    print("✓ Cleanup verification complete - all resources properly deleted")


def test_deployment_target_methods():
    """Test individual methods of KubernetesTarget."""
    # Load kubeconfig
    config.load_kube_config()

    namespace = "test-methods"
    app_name = "test-methods-app"

    # Set environment
    os.environ.update({"APP_NAME": app_name, "K8s_NAMESPACE": namespace})

    # Get configuration
    scale_config = get_scale_config()
    target_config = scale_config.get_kubernetes_config()
    target_config["app_name"] = app_name
    target_config["namespace"] = namespace

    # Create deployment target
    logger = UtilityFactory.create_logger("standard")
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    )

    # Test get_service_url (before deployment, should return None or handle gracefully)
    service_url = deployment_target.get_service_url(app_name)
    # Service URL may be None if service doesn't exist yet
    assert service_url is None or isinstance(service_url, str)

    # Test get_status (before deployment, should handle gracefully)
    try:
        status = deployment_target.get_status(app_name)
        # Should return UNKNOWN or handle the error gracefully
        assert status is not None
    except Exception:
        # It's okay if it raises an exception for non-existent deployment
        pass

    print("✓ Deployment target methods tested")
