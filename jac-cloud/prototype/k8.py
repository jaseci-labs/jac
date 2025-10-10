"""File covering k8 automation."""

import os
import time


from dotenv import load_dotenv

from kubernetes import client, config
from kubernetes.client.exceptions import ApiException

load_dotenv()
# -------------------
# Configuration
# -------------------
app_name = os.getenv("APP_NAME", "./fastapi-app")
image_name = os.getenv("IMAGE_NAME", "jaseci:latest")
namespace = os.getenv("NAMESPACE", "default")
container_port = os.getenv("CONTAINER_PORT", "8000")
node_port = os.getenv("NODE_PORT", "30001")
docker_username = os.getenv("DOCKER_USERNAME", "juzailmlwork")
repository_name = f"{docker_username}/{image_name}"

# -------------------
# Step 2: Load kubeconfig
# -------------------
config.load_kube_config()
apps_v1 = client.AppsV1Api()
core_v1 = client.CoreV1Api()

# -------------------
# Step 3: Define Deployment
# -------------------
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
                        "ports": [{"containerPort": int(container_port)}],
                    }
                ],
            },
        },
    },
}

# -------------------
# Step 4: Define Service
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

try:
    apps_v1.delete_namespaced_deployment(app_name, namespace)
    print(f"Deleted existing deployment '{app_name}'")
except ApiException as e:
    if e.status == 404:
        print(f"Deployment '{app_name}' not found, skipping delete.")
    else:
        raise

# Delete existing service if it exists
try:
    core_v1.delete_namespaced_service(f"{app_name}-service", namespace)
    print(f"Deleted existing service '{app_name}-service'")
except ApiException as e:
    if e.status == 404:
        print(f"Service '{app_name}-service' not found, skipping delete.")
    else:
        raise

time.sleep(5)  # wait for cleanup


print("Deploying FastAPI app to Kubernetes...")
apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment)
core_v1.create_namespaced_service(namespace=namespace, body=service)

print(f"✅ Deployment complete! Access FastAPI at http://localhost:{node_port}")
