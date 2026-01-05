# JAC Scale introduction

## Overview

`jac scale` is a comprehensive deployment and scaling solution for JAC applications that provides following capabilities:

### 1. Multi-Layer Memory Architecture

- **Caching Layer**: Redis for high-speed data access and session management
- **Persistence Storage**: MongoDB for reliable, long-term data storage. If mongodb is not available uses Shelf storage as persistance storage.
- **Optimized Performance**: Intelligent caching strategy to minimize database load and maximize response times

### 2. FastAPI Integration with Swagger Documentation

- Automatically converts JAC walkers and functions into RESTful FastAPI endpoints
- Built-in Swagger/OpenAPI documentation for easy API exploration and testing
- Interactive API interface accessible at `/docs` endpoint

### 3. Kubernetes Deployment & Auto-Scaling

- **Easy Deployment**: One-command deployment to Kubernetes clusters
- **Auto-Scaling**: Scale your application based on demand
- **Database Auto-Provisioning**: Automatically spawns and configures Redis and MongoDB instances
- **Production-Ready**: Built-in health checks, persistent storage, and service discovery

### 4. SSO support for login/register

### 5. Support for public private endpoints with JWT authentication

## Supported jac commands

- `jac serve`: For deploying jac application with fastapi backend
- `jac scale`: For deploying jac application in k8s

Whether you're developing locally with `jac serve` or deploying to k8s with `jac scale`, you get the same powerful features with the flexibility to choose your deployment strategy.

## Prerequisites

- kubenetes(K8s) installed
  - [Microk8s](https://canonical.com/microk8s) (for Windows/Linux)
  - [Docker Desktop with Kubernetes](https://www.docker.com/resources/kubernetes-and-docker/) (alternative for Windows - easier setup)

**Note:** Kubernetes is only needed if you are planning to use the `jac scale` command. If you only want to use `jac serve`, Kubernetes is not required.

## Important Notes

- The entire `jac scale` plugin is implemented using **Python and Kubernetes Python client libraries**
- **No custom Kubernetes controllers** are used which is easier to deploy and maintain
