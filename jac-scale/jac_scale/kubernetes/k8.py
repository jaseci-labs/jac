"""File covering k8 automation."""

import os
import subprocess
import time

from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

from .database.mongo import mongo_db
from .database.redis import redis_db
from .utils import (
    check_k8_status,
    delete_if_exists,
    ensure_namespace_exists,
    load_env_variables,
)


def deploy_k8(code_folder: str, file_name: str = "none", build: bool = False) -> None:
    """Deploy jac application to k8."""
    app_name = os.getenv("APP_NAME", "jaseci")
    image_name = os.getenv("DOCKER_IMAGE_NAME", f"{app_name}:latest")
    namespace = os.getenv("K8_NAMESPACE", "default")
    container_port = int(os.getenv("K8_CONTAINER_PORT", "8000"))
    node_port = int(os.getenv("K8_NODE_PORT", "30001"))
    docker_username = os.getenv("DOCKER_USERNAME", "juzailmlwork")
    repository_name = f"{docker_username}/{image_name}"
    mongodb_enabled = os.getenv("K8_MONGODB", "false").lower() == "true"
    redis_enabled = os.getenv("K8_REDIS", "false").lower() == "true"
    if not build:
        repository_name = "python:3.12-slim"
    # -------------------
    # Kubernetes setup
    # -------------------

    # Load the kubeconfig from default location (~/.kube/config)
    config.load_kube_config()
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()

    check_k8_status()
    ensure_namespace_exists(namespace)
    env_list = load_env_variables(code_folder)
    # -------------------
    # Define MongoDB deployment/service (if needed)
    # -------------------
    init_containers = []

    if mongodb_enabled:
        mongodb_name = f"{app_name}-mongodb"
        mongodb_service_name = f"{mongodb_name}-service"
        mongodb_deployment, mongodb_service = mongo_db(app_name, env_list)
        init_containers.append(
            {
                "name": "wait-for-mongodb",
                "image": "busybox",
                "command": [
                    "sh",
                    "-c",
                    f"until nc -z {app_name}-mongodb-service 27017; do echo waiting for mongodb; sleep 3; done",
                ],
            }
        )

    if redis_enabled:
        redis_name = f"{app_name}-redis"
        redis_service_name = f"{redis_name}-service"
        redis_deployment, redis_service = redis_db(app_name, env_list)
        init_containers.append(
            {
                "name": "wait-for-redis",
                "image": "busybox",
                "command": [
                    "sh",
                    "-c",
                    f"until nc -z {app_name}-redis-service 6379; do echo waiting for redis; sleep 3; done",
                ],
            }
        )

    container_config = {
        "name": app_name,
        "image": repository_name,
        "ports": [{"containerPort": container_port}],
        "env": env_list,
    }

    if not build:
        container_config["command"] = ["sleep", "infinity"]
    deployment = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": app_name},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": app_name}},
            "template": {
                "metadata": {"labels": {"app": app_name}},
                "spec": {
                    "initContainers": init_containers,
                    "containers": [container_config],
                },
            },
        },
    }

    # -------------------
    # Define Service for Jaseci-app
    # -------------------
    service = {
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {"name": f"{app_name}-service"},
        "spec": {
            "selector": {"app": app_name},
            "ports": [
                {
                    "protocol": "TCP",
                    "port": container_port,
                    "targetPort": container_port,
                    "nodePort": node_port,
                }
            ],
            "type": "NodePort",
        },
    }

    # -------------------
    # Cleanup old resources
    # -------------------
    delete_if_exists(
        apps_v1.delete_namespaced_deployment, app_name, namespace, "Deployment"
    )
    delete_if_exists(
        core_v1.delete_namespaced_service, f"{app_name}-service", namespace, "Service"
    )
    time.sleep(5)

    # -------------------
    # Deploy MongoDB (if enabled)
    # -------------------
    if mongodb_enabled:
        print("Checking MongoDB status...")

        try:
            apps_v1.read_namespaced_stateful_set(name=mongodb_name, namespace=namespace)
            print(
                f"MongoDB StatefulSet '{mongodb_name}' already exists, skipping creation."
            )
        except ApiException as e:
            if e.status == 404:
                print(
                    f"MongoDB StatefulSet '{mongodb_name}' not found. Creating new one..."
                )
                apps_v1.create_namespaced_stateful_set(
                    namespace=namespace, body=mongodb_deployment
                )
                print(f"MongoDB StatefulSet '{mongodb_name}' created.")
            else:
                raise

        try:
            core_v1.read_namespaced_service(
                name=mongodb_service_name, namespace=namespace
            )
            print(
                f"MongoDB Service '{mongodb_service_name}' already exists, skipping creation."
            )
        except ApiException as e:
            if e.status == 404:
                print(
                    f"MongoDB Service '{mongodb_service_name}' not found. Creating new one..."
                )
                core_v1.create_namespaced_service(
                    namespace=namespace, body=mongodb_service
                )
                print(f"MongoDB Service '{mongodb_service_name}' created.")
            else:
                raise

        print(f"MongoDB deployed and ready (service: '{mongodb_service_name}')")

    # -------------------
    # Deploy Redis (if enabled)
    # -------------------
    if redis_enabled:
        print("Checking Redis status...")

        try:
            apps_v1.read_namespaced_deployment(name=redis_name, namespace=namespace)
            print(f"Redis Deployment '{redis_name}' already exists, skipping creation.")
        except ApiException as e:
            if e.status == 404:
                print(f"Redis Deployment '{redis_name}' not found. Creating new one...")
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=redis_deployment
                )
                print(f"Redis Deployment '{redis_name}' created.")
            else:
                raise

        try:
            core_v1.read_namespaced_service(
                name=redis_service_name, namespace=namespace
            )
            print(
                f"Redis Service '{redis_service_name}' already exists, skipping creation."
            )
        except ApiException as e:
            if e.status == 404:
                print(
                    f"Redis Service '{redis_service_name}' not found. Creating new one..."
                )
                core_v1.create_namespaced_service(
                    namespace=namespace, body=redis_service
                )
                print(f"Redis Service '{redis_service_name}' created.")
            else:
                raise

        print(f"Redis deployed and ready (service: '{redis_service_name}')")

    print("Deploying Jaseci-app app...")
    apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment)
    core_v1.create_namespaced_service(namespace=namespace, body=service)
    if not build:
        pod_name = None
        for _ in range(60):
            pods = core_v1.list_namespaced_pod(
                namespace, label_selector=f"app={app_name}"
            )
            if pods.items and pods.items[0].status.phase == "Running":
                pod_name = pods.items[0].metadata.name
                break
            time.sleep(3)

        if not pod_name:
            raise RuntimeError("Pod did not become ready in time.")

        # print(f"Pod '{pod_name}' is running. Copying project folder...")
        subprocess.run(
            ["kubectl", "cp", f"{code_folder}", f"{pod_name}:/app", "-n", namespace],
            check=True,
        )

        # --- Build command dynamically ---
        exec_parts = ["cd /app"]

        # Check if requirements.txt exists locally
        requirements_path = os.path.join(code_folder, "requirements.txt")
        if os.path.exists(requirements_path):
            exec_parts.append(
                "pip install --no-cache-dir --progress-bar off -r requirements.txt >/tmp/pip_install.log 2>&1"
            )

        # Always add the Jaseci serve command
        exec_parts.append(f"nohup bash -c 'jac serve {file_name} > server.log 2>&1 &'")

        # Combine all parts into one shell command
        exec_command = " && ".join(exec_parts)

        subprocess.run(
            [
                "kubectl",
                "exec",
                pod_name,
                "-n",
                namespace,
                "--",
                "bash",
                "-c",
                exec_command,
            ],
            check=True,
        )

    print(f"Deployment complete! Access Jaseci-app at http://localhost:{node_port}")
