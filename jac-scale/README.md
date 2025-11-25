# JAC Scale Deployment Guide

## Overview

`jac scale` is a Kubernetes deployment plugin for JAC applications. It automates the deployment process by building Docker images, pushing them to DockerHub, and creating Kubernetes resources for your application and required databases.Also it supports converting walkers and functions as fastapi endpoints with swagger docs

## Prerequisites
- [minikube Kubernetes](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download/)
- [dockerhub Kubernetes](https://www.docker.com/resources/kubernetes-and-docker/)
kubernetes is needed only if you are planning to use jac scale command.if you only wanted to use jac serve kubernetes is not needed


### Optional environment variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `APP_NAME` | Name of your JAC application | `jaseci` |
| `DOCKER_USERNAME` | DockerHub username for pushing the image | - |
| `DOCKER_PASSWORD` | DockerHub password or access token | - |
| `K8_NAMESPACE` | Kubernetes namespace to deploy the application | `default` |
| `K8_NODE_PORT` | NodePort to expose the service | `30001` |
| `K8_MONGODB` | Whether MongoDB is needed (`True`/`False`) | `True` |
| `K8_REDIS` | Whether Redis is needed (`True`/`False`) | `True` |
| `MONGODB_URI` | URL of Mongodb database |  |
| `REDIS_URL` | URL of Redis database  |  |

## How to run jac serve
To run jac application using FastApi you can use jac serve command. if jac serve didnt connect to Mongodb or Redis it will use ShelfStorage as persistance storage.
Navigate to your JAC application folder:
```bash
cd /path/to/your/jac/app
```

Run the scale command:
```bash
jac serve <filename>
```

**Example:**
```bash
jac serve littlex.jac
```

## How to run jac scale

Navigate to your JAC application folder:
```bash
cd /path/to/your/jac/app
```

Run the scale command:
```bash
jac scale <filename>
```

**Example:**
```bash
jac scale littlex.jac
```
## Deployment Modes

### Mode 1: Deploy Without Building (Default)
Deploys your JAC application to Kubernetes without building docker image.

```bash
jac scale littlex.jac
```

**Use this when:**
- You want faster deployments without rebuilding
- You're testing configuration changes

### Mode 2: Build, Push, and Deploy
Builds a new Docker image, pushes it to Docker Hub, then deploys to Kubernetes.

```bash
jac scale littlex.jac -b
```

**Requirements for Build Mode:**
- A `Dockerfile` in your application directory
- Environment variables set:
  - `DOCKER_USERNAME` - Your Docker Hub username
  - `DOCKER_PASSWORD` - Your Docker Hub password/access token

**Use this when:**
- In production settings.
- Build and host docker image.

## Architecture

### k8 pods structure
![k8 pod structure](diagrams/kubernetes-architecture.png)

## Important Notes

### Implementation

- The entire `jac scale` plugin is implemented using **Python and Kubernetes python client libraries**
- **No custom Kubernetes controllers** are used → easier to deploy and maintain

### Database Provisioning

- Databases are created as **StatefulSets** with persistent storage
- Databases are **only created on the first run**
- Subsequent `jac scale` calls only update application deployments
- This ensures persistent storage and avoids recreating databases unnecessarily

### Performance

- **First-time deployment** may take longer due to database provisioning and image downloading
- **Subsequent deployments** are faster since:
  - Only the application's final Docker layer is pushed and pulled
  - Only deployments are updated (databases remain unchanged)

## Steps followed by jac scale

### 1. Create JAC Application Docker Image

- Build the application image from the source directory
- Tag the image with DockerHub repository

### 2. Push Docker Image to DockerHub

- Authenticate using `DOCKER_USERNAME` and `DOCKER_PASSWORD`
- Push the image to DockerHub
- Subsequent pushes are faster since only the final image layer is pushed


### 3. Deploy application in k8

The plugin automatically:

- Creates Kubernetes Deployments for the JAC application
- Spawns necessary databases (MongoDB, PostgreSQL, Redis) as StatefulSets if requested
- Configures networking and service exposure

## Troubleshooting

- Ensure you have proper Kubernetes cluster access configured
- Verify DockerHub credentials are correct
- Check that the specified namespace exists or will be created
- For database connection issues, verify StatefulSets are running: `kubectl get statefulsets -n <namespace>`

## Future steps

- Caching of [base image](jac_scale/kubernetes/templates/base.Dockerfile) for quick deployment
- Enable horizontal autoscaling
- Auto creation of dockerfile using base image if not found
- Support JWT token in jac scale
- Current implementation uses parent folder of  file to deploy the jac application.It should be converted to identify only modules required to run jac application
