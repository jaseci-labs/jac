# Cloud Deployment Guide

!!! warning "Deprecated"
    **Jac Cloud is deprecated.** Use [jac-scale](../../production/index.md) for new projects.

## Overview

Jac Cloud provides a Kubernetes-based deployment template to easily deploy your service into your cluster. This setup includes:

1. A Docker image with all necessary dependencies
2. Kubernetes configuration for essential resources (namespaces, service accounts, roles, etc.)
3. Dynamic configuration through environment variables and ConfigMaps

This guide will help you deploy your Jac applications to a Kubernetes cluster with minimal effort.

## Prerequisites

Before you begin, ensure you have:

1. **Kubernetes Cluster**: Access to a running Kubernetes cluster
2. **kubectl**: The Kubernetes command-line tool installed and configured
3. **Docker**: Docker installed for building and pushing images
4. **Namespace**: The target namespace should be created before deployment
5. **OpenAI API Key**: (Optional) An OpenAI API key if you're using OpenAI services

## Directory Structure

The deployment files are organized as follows:

```
jac-cloud/
├── scripts/
│   ├── Dockerfile
│   ├── init_jac_cloud.sh
│   ├── jac-cloud.yml
│   ├── module-config.yml
```

## Step-by-Step Deployment Guide

Follow these steps to deploy your Jac application to Kubernetes:

### 1. Build and Push the Docker Image

First, build the Jac Cloud Docker image using the provided Dockerfile:

```bash
docker build -t your-dockerhub-username/jac-cloud:latest -f jac-cloud/scripts/Dockerfile .
docker push your-dockerhub-username/jac-cloud:latest
```

After pushing the image, update the `image` field in `jac-cloud.yml` with your Docker image path.

### 2. Apply the ConfigMap

Apply the module configuration to set up module-specific settings:

```bash
kubectl apply -f jac-cloud/scripts/module-config.yml
```

This creates the `littlex` namespace and configures the module settings.

### 3. Apply Kubernetes Resources

Deploy the Jac Cloud application and all required resources:

```bash
kubectl apply -f jac-cloud/scripts/jac-cloud.yml
```

This sets up:

- RBAC roles and bindings
- The Jac Cloud deployment in the `littlex` namespace

### 4. Add OpenAI API Key (Optional)

If your application uses OpenAI services, add your API key as a Kubernetes secret:

```bash
# Encode your API key in base64
echo -n "your-openai-key" | base64
```

Then, update the base64 value in the `data.openai-key` field of the secret definition in `jac-cloud.yml` and apply it:

```bash
kubectl apply -f jac-cloud/scripts/jac-cloud.yml
```

### 5. Verify Your Deployment

Check that all resources are created successfully:

```bash
kubectl get all -n littlex
```

You should see the Jac Cloud pod running along with all associated resources.

## Configuration Details

### Environment Variables

The following environment variables can be configured for your deployment:

| Variable         | Description                         | Default Value   |
| ---------------- | ----------------------------------- | --------------- |
| `NAMESPACE`      | Target namespace for the deployment | `default`       |
| `CONFIGMAP_NAME` | Name of the ConfigMap to mount      | `module-config` |
| `FILE_NAME`      | JAC file to execute in the pod      | `example.jac`   |
| `OPENAI_API_KEY` | OpenAI API key (from secret)        | None            |

## Troubleshooting and Validation

### Verify Namespace

Check if the namespace exists:

```bash
kubectl get namespaces
```

### Verify ConfigMap

Ensure the ConfigMap is properly applied:

```bash
kubectl get configmap -n littlex
```

### Verify Deployment

Check if the Jac Cloud pod is running:

```bash
kubectl get pods -n littlex
```

## Advanced Usage

### Updating Configurations

To update the ConfigMap or deployment:

1. Modify the YAML files as needed
2. Apply the changes:

```bash
kubectl apply -f jac-cloud/scripts/module-config.yml
kubectl apply -f jac-cloud/scripts/jac-cloud.yml
```

### Monitoring Logs

View the logs of your Jac Cloud application:

```bash
kubectl logs -f deployment/jac-cloud -n littlex
```

### Scaling the Deployment

Increase the number of replicas to handle more traffic:

```bash
kubectl scale deployment jac-cloud --replicas=3 -n littlex
```

### Configuring Resource Limits

Adjust CPU and memory limits in the `jac-cloud.yml` file:

```yaml
resources:
  limits:
    cpu: "1"
    memory: "1Gi"
  requests:
    cpu: "500m"
    memory: "512Mi"
```

## Cleanup

To remove all deployed resources:

```bash
kubectl delete namespace littlex
```

This will delete all resources associated with your Jac Cloud deployment.

## Next Steps

- Learn about [Environment Variables](env_vars.md) for configuration options
- Explore [WebSockets](websocket.md) for real-time features
- Set up [Logging](logging.md) to monitor your deployment
- Implement [Task Scheduling](scheduler.md) for background processing
