"""File covering k8 automation."""

import os
import time
from typing import Callable

from kubernetes import client, config
from kubernetes.client.exceptions import ApiException


def deploy_k8() -> None:
    """Deploy jac application to k8."""
    app_name = os.getenv("APP_NAME", "jaseci")
    image_name = os.getenv("DOCKER_IMAGE_NAME", f"{app_name}:latest")
    namespace = os.getenv("K8_NAMESPACE", "default")
    container_port = int(os.getenv("K8_CONTAINER_PORT", "8000"))
    node_port = int(os.getenv("K8_NODE_PORT", "30001"))
    docker_username = os.getenv("DOCKER_USERNAME", "juzailmlwork")
    repository_name = f"{docker_username}/{image_name}"
    mongodb_enabled = os.getenv("MONGODB", "false").lower() == "true"

    # -------------------
    # Kubernetes setup
    # -------------------
    config.load_kube_config()
    apps_v1 = client.AppsV1Api()
    core_v1 = client.CoreV1Api()

    # -------------------
    # Define MongoDB deployment/service (if needed)
    # -------------------
    mongodb_name = f"{app_name}-mongodb"
    mongodb_port = 27017
    mongodb_service_name = f"{mongodb_name}-service"

    if mongodb_enabled:
        mongodb_deployment = {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {"name": mongodb_name},
            "spec": {
                "replicas": 1,
                "selector": {"matchLabels": {"app": mongodb_name}},
                "template": {
                    "metadata": {"labels": {"app": mongodb_name}},
                    "spec": {
                        "containers": [
                            {
                                "name": "mongodb",
                                "image": "mongo:6.0",
                                "ports": [{"containerPort": mongodb_port}],
                                "env": [
                                    {
                                        "name": "MONGO_INITDB_ROOT_USERNAME",
                                        "value": "admin",
                                    },
                                    {
                                        "name": "MONGO_INITDB_ROOT_PASSWORD",
                                        "value": "password",
                                    },
                                ],
                                "volumeMounts": [
                                    {"name": "mongo-data", "mountPath": "/data/db"}
                                ],
                            }
                        ],
                        "volumes": [{"name": "mongo-data", "emptyDir": {}}],
                    },
                },
            },
        }

        mongodb_service = {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {"name": mongodb_service_name},
            "spec": {
                "selector": {"app": mongodb_name},
                "ports": [
                    {
                        "protocol": "TCP",
                        "port": mongodb_port,
                        "targetPort": mongodb_port,
                    }
                ],
                "type": "ClusterIP",
            },
        }

    # -------------------
    # Define Jaseci-app Deployment
    # -------------------
    env_vars = []
    if mongodb_enabled:
        env_vars.append(
            {
                "name": "MONGODB_URI",
                "value": f"mongodb://admin:password@{mongodb_service_name}:{mongodb_port}",
            }
        )

    deployment = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {"name": app_name},
        "spec": {
            "replicas": 3,
            "selector": {"matchLabels": {"app": app_name}},
            "template": {
                "metadata": {"labels": {"app": app_name}},
                "spec": {
                    "containers": [
                        {
                            "name": app_name,
                            "image": repository_name,
                            "ports": [{"containerPort": container_port}],
                            "env": env_vars,
                        }
                    ],
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
    # Helper to delete existing resources safely
    # -------------------
    def delete_if_exists(
        delete_func: Callable, name: str, namespace: str, kind: str
    ) -> None:
        """Deploy example."""
        try:
            delete_func(name, namespace)
            print(f"Deleted existing {kind} '{name}'")
        except ApiException as e:
            if e.status == 404:
                print(f"{kind} '{name}' not found, skipping delete.")
            else:
                raise

    # -------------------
    # Cleanup old resources
    # -------------------
    delete_if_exists(
        apps_v1.delete_namespaced_deployment, app_name, namespace, "Deployment"
    )
    delete_if_exists(
        core_v1.delete_namespaced_service, f"{app_name}-service", namespace, "Service"
    )

    if mongodb_enabled:
        delete_if_exists(
            apps_v1.delete_namespaced_deployment,
            mongodb_name,
            namespace,
            "MongoDB Deployment",
        )
        delete_if_exists(
            core_v1.delete_namespaced_service,
            mongodb_service_name,
            namespace,
            "MongoDB Service",
        )

    time.sleep(5)

    # -------------------
    # Deploy resources
    # -------------------
    if mongodb_enabled:
        print("Deploying MongoDB...")
        apps_v1.create_namespaced_deployment(
            namespace=namespace, body=mongodb_deployment
        )
        core_v1.create_namespaced_service(namespace=namespace, body=mongodb_service)
        print(f"MongoDB deployed with service '{mongodb_service_name}'")

    print("Deploying Jaseci-app app...")
    apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment)
    core_v1.create_namespaced_service(namespace=namespace, body=service)

    print(f"Deployment complete! Access Jaseci-app at http://localhost:{node_port}")
    if mongodb_enabled:
        print(
            f"MongoDB accessible at '{mongodb_service_name}:{mongodb_port}' inside cluster."
        )


if __name__ == "__main__":
    deploy_k8()
