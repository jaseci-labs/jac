"""File covering k8 automation."""

import os
import time
from typing import Any

from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

from .database.mongo import mongo_db
from .database.redis import redis_db
from .utils import (
    check_deployment_status,
    check_k8_status,
    create_or_update_configmap,
    create_tarball,
    delete_if_exists,
    ensure_namespace_exists,
    load_env_variables,
)


def deploy_k8(
    code_folder: str,
    file_name: str = "none",
    build: bool = False,
    testing: bool = False,
) -> None:
    """Deploy jac application to k8."""
    app_name = os.getenv("APP_NAME", "jaseci")
    image_name = os.getenv("DOCKER_IMAGE_NAME", f"{app_name}:latest")
    namespace = os.getenv("K8_NAMESPACE", "default")
    container_port = int(os.getenv("K8_CONTAINER_PORT", "8000"))
    node_port = int(os.getenv("K8_NODE_PORT", "30001"))
    docker_username = os.getenv("DOCKER_USERNAME", "juzailmlwork")
    repository_name = f"{docker_username}/{image_name}"
    mongodb_enabled = os.getenv("K8_MONGODB", "true").lower() == "true"
    redis_enabled = os.getenv("K8_REDIS", "true").lower() == "true"
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
    init_containers: list[dict[str, Any]] = []
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

    volumes = []
    container_config = {
        "name": app_name,
        "image": repository_name,
        "ports": [{"containerPort": container_port}],
        "env": env_list,
    }
    if not build:
        # container_config["command"] = ["sleep", "infinity"]
        build_container = {
            "name": "build-app",
            "image": "python:3.12-slim",
            "command": [
                "sh",
                "-c",
                "mkdir -p /app && tar -xzf /code/jaseci-code.tar.gz -C /app",
            ],
            "volumeMounts": [
                {"name": "app-code", "mountPath": "/app"},
                {"name": "code-source", "mountPath": "/code"},
            ],
        }
        volumes = [
            {"name": "app-code", "emptyDir": {}},
            {
                "name": "code-source",
                "configMap": {
                    "name": "jaseci-code",
                    "items": [
                        {"key": "jaseci-code.tar.gz", "path": "jaseci-code.tar.gz"}
                    ],
                },
            },
        ]
        init_containers.append(build_container)
        if "requirements.txt" in os.listdir(code_folder):
            print("requirements.txt exists")
            install_part = (
                f"pip install -r /app/requirements.txt && jac serve {file_name}"
            )
        else:
            install_part = f"jac serve {file_name} "

        command = [
            "bash",
            "-c",
            "export DEBIAN_FRONTEND=noninteractive && "
            "apt-get update && apt-get install -y git npm nodejs && "
            "git clone --branch fix-mongodb-pvc-issue --single-branch --depth 1 "
            "https://github.com/juzailmlwork/jaseci.git && "
            "cd ./jaseci && "
            "git submodule update --init --recursive && "
            "cd ../ && "
            "pip install pluggy && "
            "pip install -e ./jaseci/jac && "
            "pip install -e  ./jaseci/jac-scale && "
            "pip install -e ./jaseci/jac-client && "
            # "rm -rf ./jaseci && "
            "cd ../ && "
            "jac create_jac_app client_app && "
            "cp -r ./app/* ./client_app && "
            "cd ./client_app && "
            f"{install_part}",
        ]

        container_config = {
            "name": app_name,
            "image": "python:3.12-slim",
            "command": command,
            "workingDir": "/app",
            "volumeMounts": [{"name": "app-code", "mountPath": "/app"}],
            "ports": [{"containerPort": container_port}],
            "env": env_list,
        }
        create_tarball(code_folder, "jaseci-code.tar.gz")
        create_or_update_configmap(namespace, "jaseci-code", "jaseci-code.tar.gz")
        os.remove("jaseci-code.tar.gz")

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

    deployment = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": app_name, "labels": {"app": app_name}},
        "spec": {
            "replicas": 1,
            "selector": {"matchLabels": {"app": app_name}},
            "template": {
                "metadata": {"labels": {"app": app_name}},
                "spec": {
                    "initContainers": init_containers,
                    "containers": [container_config],
                    "volumes": volumes,
                },
            },
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
        except ApiException as e:
            if e.status == 404:
                apps_v1.create_namespaced_stateful_set(
                    namespace=namespace, body=mongodb_deployment
                )
            else:
                raise

        try:
            core_v1.read_namespaced_service(
                name=mongodb_service_name, namespace=namespace
            )
        except ApiException as e:
            if e.status == 404:
                core_v1.create_namespaced_service(
                    namespace=namespace, body=mongodb_service
                )
            else:
                raise

    # -------------------
    # Deploy Redis (if enabled)
    # -------------------
    if redis_enabled:
        print("Checking Redis status...")

        try:
            apps_v1.read_namespaced_deployment(name=redis_name, namespace=namespace)
        except ApiException as e:
            if e.status == 404:
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=redis_deployment
                )
            else:
                raise

        try:
            core_v1.read_namespaced_service(
                name=redis_service_name, namespace=namespace
            )
        except ApiException as e:
            if e.status == 404:
                core_v1.create_namespaced_service(
                    namespace=namespace, body=redis_service
                )
            else:
                raise

    print("Deploying Jaseci-app app...")
    apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment)
    core_v1.create_namespaced_service(namespace=namespace, body=service)

    path = "/walkers" if testing else "/docs"
    if check_deployment_status(node_port, path):
        print(f"Deployment complete! Access Jaseci-app at http://localhost:{node_port}")
    else:
        print("Deployment failed or service not responding.")
