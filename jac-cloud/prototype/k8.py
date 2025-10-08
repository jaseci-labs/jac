"""File covering k8 automation."""

import time

import docker

from kubernetes import client, config


# -------------------
# Configuration
# -------------------
app_name = "fastapi-app"
image_name = "fastapi-app:latest"
namespace = "default"
container_port = 8000
node_port = 30080
dockerfile_path = "./"  # path where Dockerfile exists
context_path = "./"  # path for docker build context

# -------------------
# Step 1: Build Docker image programmatically
# -------------------
docker_client = docker.from_env()

print("🚀 Building Docker image...")
image, logs = docker_client.images.build(
    path=context_path, dockerfile="Dockerfile", tag=image_name, rm=True
)
for chunk in logs:
    if "stream" in chunk:
        print(chunk["stream"], end="")

print(f"✅ Docker image '{image_name}' built successfully!")

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
        "replicas": 1,
        "selector": {"matchLabels": {"app": app_name}},
        "template": {
            "metadata": {"labels": {"app": app_name}},
            "spec": {
                "containers": [
                    {
                        "name": app_name,
                        "image": image_name,
                        "ports": [{"containerPort": container_port}],
                    }
                ]
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

# -------------------
# Step 5: Deploy to Kubernetes
# -------------------
# Delete existing deployment/service if exist

apps_v1.delete_namespaced_deployment(app_name, namespace)
core_v1.delete_namespaced_service(f"{app_name}-service", namespace)
time.sleep(5)  # wait for cleanup


print("🛠 Deploying FastAPI app to Kubernetes...")
apps_v1.create_namespaced_deployment(namespace=namespace, body=deployment)
core_v1.create_namespaced_service(namespace=namespace, body=service)

print(f"✅ Deployment complete! Access FastAPI at http://localhost:{node_port}")
