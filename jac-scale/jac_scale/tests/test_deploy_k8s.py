"""Tests for Kubernetes deployment using new factory-based architecture."""

import base64
import os
import time
from pathlib import Path
from typing import Any

import requests
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

from ..abstractions.config.app_config import AppConfig
from ..config_loader import JacScaleConfig, get_scale_config
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


def test_deploy_all_in_one():
    """
    Test deployment using the new factory-based architecture.
    Deploys the all-in-one app found in jac client examples against a live Kubernetes cluster.
    Validates deployment, services, sends HTTP request, and tests cleanup.
    """

    # Load kubeconfig and initialize client
    config.load_kube_config()
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()

    namespace = "all-in-one"
    app_name = namespace

    # Set environment (including test secret for [plugins.scale.secrets])
    test_secret_value = "test-secret-value-12345"
    os.environ.update(
        {
            "APP_NAME": app_name,
            "K8s_NAMESPACE": namespace,
            "TEST_SECRET_KEY": test_secret_value,
        }
    )

    # Resolve the absolute path to the todo app folder
    test_dir = os.path.dirname(os.path.abspath(__file__))
    todo_app_path = os.path.join(
        test_dir, "../../../jac-client/jac_client/examples/all-in-one"
    )

    # Get configuration
    scale_config = get_scale_config()
    target_config = scale_config.get_kubernetes_config()
    target_config["app_name"] = app_name
    target_config["namespace"] = namespace
    target_config["node_port"] = 30001

    # Create logger
    logger = UtilityFactory.create_logger("standard")

    # Create deployment target using factory
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    )

    # Load secrets from the app's [plugins.scale.secrets] (not CWD)
    app_scale_config = JacScaleConfig(Path(os.path.normpath(todo_app_path)))
    deployment_target.secrets = app_scale_config.get_secrets_config()

    # Create app config
    # Use experimental=True to install from repo (PyPI packages may not be available)
    app_config = AppConfig(
        code_folder=todo_app_path,
        file_name="main.jac",
        build=False,
        experimental=True,
    )

    # Deploy using new architecture
    result = deployment_target.deploy(app_config)
    result = deployment_target.deploy(app_config)
    details = result.details
    assert len(details) == 8
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

    # Validate K8s Secret was created with correct data
    secret = core_v1.read_namespaced_secret(
        name=f"{app_name}-secrets", namespace=namespace
    )
    assert secret.metadata.name == f"{app_name}-secrets"
    # stringData is stored as base64 data by K8s; decode to verify
    secret_value = base64.b64decode(secret.data["TEST_SECRET_KEY"]).decode()
    assert secret_value == test_secret_value
    print(f"✓ K8s Secret '{app_name}-secrets' created with correct data")

    # Validate envFrom.secretRef is in the container spec
    deployment = apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace)
    container = deployment.spec.template.spec.containers[0]
    assert container.env_from is not None, "envFrom should be set on container"
    secret_refs = [
        ef.secret_ref.name for ef in container.env_from if ef.secret_ref is not None
    ]
    assert f"{app_name}-secrets" in secret_refs
    print(f"✓ Container has envFrom.secretRef for '{app_name}-secrets'")

    # Test get_status
    status = deployment_target.get_status(app_name)
    assert status is not None
    assert status.replicas >= 0
    print(
        f"✓ Deployment status: {status.status.value}, replicas: {status.replicas}/{status.ready_replicas}"
    )

    # Send POST request to create a todo (with retry for 503)
    url = f"http://localhost:{node_port}/walker/create_todo"
    payload = {"text": "first-task"}
    response = _request_with_retry("POST", url, json=payload, timeout=10)
    assert response.status_code == 200
    print(f"✓ Successfully created todo at {url}")
    print(f"  Response: {response.json()}")

    url = f"http://localhost:{node_port}/cl/app"
    response = _request_with_retry("GET", url, timeout=100)
    print(f"Response status code for app page: {response.status_code}")
    assert response.status_code == 200
    print(f"✓ Successfully reached app page at {url}")

    # Cleanup using new architecture
    deployment_target.destroy(app_name)

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

    # Verify K8s Secret cleanup
    try:
        core_v1.read_namespaced_secret(f"{app_name}-secrets", namespace=namespace)
        raise AssertionError("K8s Secret should have been deleted")
    except ApiException as e:
        assert e.status == 404, f"Expected 404, got {e.status}"

    # Verify PVC cleanup
    pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace=namespace)
    for pvc in pvcs.items:
        assert not pvc.metadata.name.startswith(app_name), (
            f"PVC '{pvc.metadata.name}' should have been deleted"
        )

    print("✓ Cleanup verification complete - all resources properly deleted")


def test_early_exit():
    """
    Test deployment using the new factory-based architecture.
    Deploys the all-in-one app found in jac client examples against a live Kubernetes cluster.
    Validates deployment, services, sends HTTP request, and tests cleanup.
    """

    # Load kubeconfig and initialize client
    config.load_kube_config()

    namespace = "early-exit"
    app_name = namespace

    # Set environment
    os.environ.update({"APP_NAME": app_name, "K8s_NAMESPACE": namespace})

    # Resolve the absolute path to the todo app folder
    test_dir = os.path.dirname(os.path.abspath(__file__))
    todo_app_path = os.path.join(test_dir, "../../examples/early-exit")

    # Get configuration
    scale_config = get_scale_config()
    target_config = scale_config.get_kubernetes_config()
    target_config["app_name"] = app_name
    target_config["namespace"] = namespace
    target_config["node_port"] = 30002

    # Create logger
    logger = UtilityFactory.create_logger("standard")

    # Create deployment target using factory
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    )

    # Create app config
    # Use experimental=True to install from repo (PyPI packages may not be available)
    app_config = AppConfig(
        code_folder=todo_app_path,
        file_name="app_err.jac",
        build=False,
        experimental=True,
    )

    # Deploy using new architecture
    result = deployment_target.deploy(app_config)
    details = result.details
    print(f"Deployment result: {details}")
    assert "health_check_of_deployment" not in details
    assert len(details) == 7
    assert result.success is False


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
