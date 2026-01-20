# JAC Scale Deployment Guide

## Overview

`jac start --scale` is a comprehensive deployment and scaling solution for JAC applications that provides three powerful capabilities:

### 1. Multi-Layer Memory Architecture

- **Caching Layer**: Redis for high-speed data access and session management
- **Persistence Storage**: MongoDB for reliable, long-term data storage
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

Whether you're developing locally with `jac start` or deploying to production with `jac start --scale`, you get the same powerful features with the flexibility to choose your deployment strategy.

## Prerequisites

- kubenetes(K8s) installed
  - [Minikube Kubernetes](https://minikube.sigs.k8s.io/docs/start/?arch=%2Fwindows%2Fx86-64%2Fstable%2F.exe+download/) (for Windows/Linux)
  - [Docker Desktop with Kubernetes](https://www.docker.com/resources/kubernetes-and-docker/) (alternative for Windows - easier setup)

**Note:** Kubernetes is only needed if you are planning to use `jac start --scale`. If you only want to use `jac start`, Kubernetes is not required.

## Quick Start: Running the Travel Planner Demo Application

Follow these steps to set up and test the Travel Planner JAC application

### 1. Clone the Jaseci Repository

First, clone the main Jaseci repository which contains JAC and JAC-Scale:

```bash
git clone https://github.com/jaseci-labs/jaseci.git
cd jaseci
git submodule update --init --recursive
```

### 2. Create Python Virtual Environment

```bash
python -m venv venv
```

### 3. Activate the Virtual Environment

**Linux/Mac:**

```bash
source venv/bin/activate
```

**Windows:**

```bash
venv\Scripts\activate
```

### 4. Install JAC and JAC-Scale

Install both packages in editable mode from the cloned repository:

```bash
pip install -e ./jac
pip install -e ./jac-scale
```

### 5. Download the Demo Application

Download the Travel Planner demo application from GitHub:

**Option A: Using Git Clone (Recommended)**

```bash
# Navigate back to parent directory or choose a location
cd ..

# Clone the entire repository
git clone https://github.com/jaseci-labs/Agentic-AI.git

# Navigate to the Travel Planner backend and rename
mv Agentic-AI/Travel_planner/BE traveller
cd traveller
```

**Option B: Download Specific Folder**

If you only want the Travel Planner backend:

```bash
# Navigate back to parent directory
cd ..

# Install GitHub CLI if not already installed
# For Linux/Mac with Homebrew:
brew install gh

# For Windows with Chocolatey:
choco install gh

# Clone only the specific folder
gh repo clone jaseci-labs/Agentic-AI
mv Agentic-AI/Travel_planner/BE traveller
cd traveller
```

**Option C: Manual Download**

1. Go to https://github.com/jaseci-labs/Agentic-AI/tree/main/Travel_planner/BE
2. Click on the green "Code" button
3. Select "Download ZIP"
4. Extract the ZIP file
5. Rename the `BE` folder to `traveller`
6. Navigate into the folder:

```bash
cd traveller
```

### 6. Configure Environment Variables

You should now be in the `traveller` folder. Create a `.env` file:

```bash
# Verify you're in the correct directory
pwd  # Should show path ending in /traveller

# Create .env file
touch .env  # Linux/Mac
# OR
type nul > .env  # Windows CMD
# OR
New-Item .env  # Windows PowerShell
```

Add the following to your `.env` file:

```env
OPENAI_API_KEY=your-openai-api-key-here
```

### 7. Install Demo Application Requirements

```bash
pip install byllm python-dotenv
```

### 8. Run the Application with JAC Start

To run your application using FastAPI with ShelfStorage (no Kubernetes required):

```bash
jac start main.jac
```

**What this does:**

- Starts your JAC application as a FastAPI server
- Uses ShelfStorage for persisting anchors (lightweight, file-based storage)
- No database setup required
- Ideal for development and testing

**Access your application:**

- Application: http://localhost:8000
- Swagger Documentation: http://localhost:8000/docs

### 9. Set Up Kubernetes (For JAC Scale)

To use `jac start --scale`, you need Kubernetes installed on your machine.

**Option A: MicroK8s (Windows/Linux/Mac)**

- [Official MicroK8s installation guide](https://microk8s.io/)
- [ubunutu installation guide](https://www.digitalocean.com/community/tutorials/how-to-setup-a-microk8s-kubernetes-cluster-on-ubuntu-22-04)

**Option B: Docker Desktop with Kubernetes (Windows - Recommended)**

- Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Enable Kubernetes in Docker Desktop settings (easier setup)

### 10. Deploy with JAC Scale

Once Kubernetes is running, you have two deployment methods:

#### Method A: Deploy Without Building (Faster)

Deploy your application to Kubernetes without building a Docker image:

```bash
jac start main.jac --scale
```

**What this does:**

- Deploys your JAC application to Kubernetes
- Automatically provisions Redis and MongoDB as persistence storage
- Creates necessary Kubernetes resources (Deployments, Services, StatefulSets)
- Exposes your application via NodePort

**Access your application:**

- Application: http://localhost:30001
- Swagger Documentation: http://localhost:30001/docs

**Use this when:**

- You want faster deployments without rebuilding
- You're testing configuration changes
- You're in development mode

#### Method B: Build, Push, and Deploy (Production)

Build your application as a Docker container and deploy it:

**Prerequisites:**

1. Create a `Dockerfile` in your `traveller` directory
2. Add Docker credentials to your `.env` file:

```env
OPENAI_API_KEY=your-openai-api-key-here
DOCKER_USERNAME=your-dockerhub-username
DOCKER_PASSWORD=your-dockerhub-password-or-token
```

**Deploy with build:**

```bash
jac start main.jac --scale --build
```

**What this does:**

- Builds a Docker image of your JAC application
- Pushes the image to DockerHub
- Deploys the image to Kubernetes
- Sets up Redis and MongoDB for persistence

**Access your application:**

- Application: http://localhost:30001
- Swagger Documentation: http://localhost:30001/docs

**Use this when:**

- Deploying to production
- You want to version and host your Docker image
- Sharing your application with others
- Creating reproducible deployments

### 11. Clean Up Kubernetes Resources

When you're done testing, remove all created Kubernetes resources:

```bash
jac destroy main.jac
```

**What this does:**

- Deletes all Kubernetes deployments, services, and StatefulSets
- Removes persistent volumes and claims
- Cleans up the namespace (if custom namespace was used)

## Quick Start: Running Todo application with frontend

Follow these steps to set up and test the Todo application with frontend

### 1. Clone the Jaseci Repository

First, clone the main Jaseci repository which contains JAC and JAC-Scale:

```bash
git clone https://github.com/jaseci-labs/jaseci.git
cd jaseci
git submodule update --init --recursive
```

### 2. Create Python Virtual Environment

```bash
python -m venv venv
```

### 3. Activate the Virtual Environment

**Linux/Mac:**

```bash
source venv/bin/activate
```

**Windows:**

```bash
venv\Scripts\activate
```

### 4. Install JAC, JAC-Scale and JAC-Client

Install the packages in editable mode from the cloned repository:

```bash
pip install -e ./jac
pip install -e ./jac-scale
pip install -e ./jac-client
```

### 5. Create Todo application using jac-client

Lets create the todo application using jac client.For that lets run following command

```bash
jac create_jac_app todo
```

Then lets copy the todo fully implemented jac code available inside jac-scale/examples/todo to our newly created /todo folder

```bash
cp jac-scale/examples/todo/app.jac todo/app.jac
cd todo
```

### 8. Run the Application Locally

To run your application run the following command

```bash
jac start app.jac
```

**Access your application:**

- Frontend: http://localhost:8000/cl/app
- Backend: http://localhost:8000
- Swagger Documentation: http://localhost:8000/docs

you can add new todo tasks
 from the frontend at http://localhost:8000/cl/app

### 9. Set Up Kubernetes (For JAC Scale)

To use `jac start --scale`, you need Kubernetes installed on your machine.

**Option A: MicroK8 (Windows/Linux/Mac)**

- [Official MicroK8 installation guide](https://microk8s.io/)
- [ubunutu installation guide](https://www.digitalocean.com/community/tutorials/how-to-setup-a-microk8s-kubernetes-cluster-on-ubuntu-22-04)

**Option B: Docker Desktop with Kubernetes (Windows - Recommended)**

- Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- Enable Kubernetes in Docker Desktop settings (easier setup)

### 10. Deploy with JAC Scale

Once Kubernetes is running, you have two deployment methods:

#### Method A: Deploy Without Building (Faster)

Deploy your application to Kubernetes without building a Docker image:

```bash
jac start app.jac --scale
```

**Access your application:**

- Frontend: http://localhost:30001/cl/app
- Backend: http://localhost:30001
- Swagger Documentation: http://localhost:30001/docs

**Use this when:**

- You want faster deployments without rebuilding
- You're testing configuration changes
- You're in development mode

#### Method B: Build, Push, and Deploy (Production)

To Build your application as a Docker container and deploy it you can run

```bash
jac start app.jac --scale --build
```

**Access your application:**

- Frontend: http://localhost:30001/cl/app
- Backend: http://localhost:30001
- Swagger Documentation: http://localhost:30001/docs

**Use this when:**

- Deploying to production
- You want to version and host your Docker image
- Sharing your application with others
- Creating reproducible deployments

### 11. Clean Up Kubernetes Resources

When you're done testing, remove all created Kubernetes resources:

```bash
jac destroy app.jac
```

**What this does:**

- Deletes all Kubernetes deployments, services, and StatefulSets
- Removes persistent volumes and claims
- Cleans up the namespace (if custom namespace was used)

## Async Walkers

JAC Scale supports async walkers for non-blocking operations like external API calls, database queries, and file I/O.

```
import asyncio;

async walker FetchData {
    has url: str;

    async can fetch with `root entry {
        report {"status": "fetching"};
        await asyncio.sleep(0.1);  # Simulate API call
        report {"status": "completed", "data": "result"};
    }
}
```

## Configuration Options

### Optional Environment Variables

| Parameter | Description | Default |
|-----------|-------------|---------|
| `APP_NAME` | Name of your JAC application | `jaseci` |
| `DOCKER_USERNAME` | DockerHub username for pushing the image | - |
| `DOCKER_PASSWORD` | DockerHub password or access token | - |
| `K8s_NAMESPACE` | Kubernetes namespace to deploy the application | `default` |
| `K8s_NODE_PORT` | Port in which your local kubernetes application will run on| `30001` |
| `K8s_CPU_REQUEST` | CPU request for the application container | - |
| `K8s_CPU_LIMIT` | CPU limit for the application container | - |
| `K8s_MEMORY_REQUEST` | Memory request for the application container | - |
| `K8s_MEMORY_LIMIT` | Memory limit for the application container | - |
| `K8s_READINESS_INITIAL_DELAY` | Seconds before readiness probe first checks the pod | `10` |
| `K8s_READINESS_PERIOD` | Seconds between readiness probe checks | `20` |
| `K8s_LIVENESS_INITIAL_DELAY` | Seconds before liveness probe first checks the pod | `10` |
| `K8s_LIVENESS_PERIOD` | Seconds between liveness probe checks | `20` |
| `K8s_LIVENESS_FAILURE_THRESHOLD` | Consecutive liveness probe failures before restart | `80` |
| `K8s_MONGODB` | Whether MongoDB is needed (`True`/`False`) | `True` |
| `K8s_REDIS` | Whether Redis is needed (`True`/`False`) | `True` |
| `MONGODB_URI` | URL of MongoDB database | - |
| `REDIS_URL` | URL of Redis database | - |
| `JWT_EXP_DELTA_DAYS` | Number of days until JWT token expires | `7` |
| `JWT_SECRET` | Secret key used for JWT token signing and verification | `'supersecretkey'` |
| `JWT_ALGORITHM` | Algorithm used for JWT token encoding/decoding | `'HS256'` |
| `SSO_HOST` | SSO host URL | `'http://localhost:8000/sso'` |
| `SSO_GOOGLE_CLIENT_ID` | Google OAuth client ID | - |
| `SSO_GOOGLE_CLIENT_SECRET` | Google OAuth client secret | - |

## Deployment Modes

### Mode 1: Deploy Without Building (Default)

Deploys your JAC application to Kubernetes without building a Docker image.

```bash
jac start main.jac --scale
```

**Use this when:**

- You want faster deployments without rebuilding
- You're testing configuration changes
- You're in development mode

### Mode 2: Build, Push, and Deploy

Builds a new Docker image, pushes it to DockerHub, then deploys to Kubernetes.

```bash
jac start main.jac --scale --build
```

**Requirements for Build Mode:**

- A `Dockerfile` in your application directory
- Environment variables set:
  - `DOCKER_USERNAME` - Your DockerHub username
  - `DOCKER_PASSWORD` - Your DockerHub password/access token

**Use this when:**

- Deploying to production
- You want to version and host your Docker image
- Sharing your application with others

## Important Notes

### Implementation

- The jac-scale plugin is implemented using **Python and Kubernetes Python client libraries**
- **No custom Kubernetes controllers** are used → easier to deploy and maintain

### Database Provisioning

- Databases are created as **StatefulSets** with persistent storage
- Databases are **only created on the first run**
- Subsequent `jac start --scale` calls only update application deployments
- This ensures persistent storage and avoids recreating databases unnecessarily

### Performance

- **First-time deployment** may take longer due to database provisioning and image downloading
- **Subsequent deployments** are faster since:
  - Only the application's final Docker layer is pushed and pulled
  - Only deployments are updated (databases remain unchanged)

## Deployment Process

When you run `jac start --scale`, the following steps are executed:

### 1. Create JAC Application Docker Image

- Build the application image from the source directory
- Tag the image with DockerHub repository

### 2. Push Docker Image to DockerHub (Build Mode Only)

- Authenticate using `DOCKER_USERNAME` and `DOCKER_PASSWORD`
- Push the image to DockerHub
- Subsequent pushes are faster since only the final image layer is pushed

### 3. Deploy to Kubernetes

- Create or update Kubernetes namespace
- Deploy Redis and MongoDB (first run only)
- Create application deployment
- Create services and expose via NodePort

## Architecture

### K8s pods structure

![K8s pod structure](assets/jac-scale-architecture.svg)

## Troubleshooting

### Common Issues

**Kubernetes cluster not accessible:**

- Ensure Kubernetes is running: `kubectl cluster-info`
- Check your kubeconfig: `kubectl config view`

**DockerHub authentication fails:**

- Verify your `DOCKER_USERNAME` and `DOCKER_PASSWORD` are correct
- Ensure you're using an access token (not password) if 2FA is enabled

**Namespace doesn't exist:**

- The plugin creates namespaces automatically
- If using a custom namespace, ensure proper permissions

**Database connection issues:**

- Verify StatefulSets are running: `kubectl get statefulsets -n <namespace>`
- Check pod logs: `kubectl logs <pod-name> -n <namespace>`
- Ensure persistent volumes are bound: `kubectl get pvc -n <namespace>`

**Application not accessible:**

- Check service exposure: `kubectl get svc -n <namespace>`
- Verify NodePort is not blocked by firewall
- For Minikube, use: `minikube service <service-name> -n <namespace>`

**Build failures:**

- Ensure Dockerfile exists in your application directory
- Check Docker daemon is running
- Verify sufficient disk space for image building

### Getting Help

If you encounter issues:

1. Check pod status: `kubectl get pods -n <namespace>`
2. View pod logs: `kubectl logs <pod-name> -n <namespace>`
3. Describe resources: `kubectl describe <resource-type> <resource-name> -n <namespace>`

## Tested Examples

You can find more working examples in the examples directory:

<!-- - [basic](../jac-client/jac_client/examples/basic/) - Minimal JAC application -->
<!-- - [basic-full-stack](../jac-client/jac_client/examples/basic-full-stack/) - Basic full-stack application -->
- [all-in-one](../jac-client/jac_client/examples/all-in-one/) - Complete example with all features
- [with-router](../jac-client/jac_client/examples/with-router/) - Application with routing
<!-- - [nested-folders/nested-basic](../jac-client/jac_client/examples/nested-folders/nested-basic/) - Basic nested folder structure -->
- [nested-folders/nested-advance](../jac-client/jac_client/examples/nested-folders/nested-advance/) - Advanced nested folder structure
- [basic-auth](../jac-client/jac_client/examples/basic-auth/) - Basic authentication
- [basic-auth-with-router](../jac-client/jac_client/examples/basic-auth-with-router/) - Authentication with routing
<!-- - [full-stack-with-auth](../jac-client/jac_client/examples/full-stack-with-auth/) - Full-stack app with authentication -->
- [css-styling/js-styling](../jac-client/jac_client/examples/css-styling/js-styling/) - JavaScript styling example
- [css-styling/material-ui](../jac-client/jac_client/examples/css-styling/material-ui/) - Material-UI styling example
- [css-styling/pure-css](../jac-client/jac_client/examples/css-styling/pure-css/) - Pure CSS styling example
- [css-styling/sass-example](../jac-client/jac_client/examples/css-styling/sass-example/) - SASS styling example
- [css-styling/styled-components](../jac-client/jac_client/examples/css-styling/styled-components/) - Styled Components example
- [css-styling/tailwind-example](../jac-client/jac_client/examples/css-styling/tailwind-example/) - Tailwind CSS example
- [asset-serving/css-with-image](../jac-client/jac_client/examples/asset-serving/css-with-image/) - CSS with image assets
- [asset-serving/image-asset](../jac-client/jac_client/examples/asset-serving/image-asset/) - Image asset serving
- [asset-serving/import-alias](../jac-client/jac_client/examples/asset-serving/import-alias/) - Import alias example
<!-- - [little-x](../jac-client/jac_client/examples/little-x/) - Little X application example -->

Each example includes complete source code and can be run with `jac start`.

## Next Steps

After successfully running the demo:

- **For local development (`jac start`)**: Access your application at http://localhost:8000 and explore the Swagger documentation at http://localhost:8000/docs
- **For Kubernetes (`jac start --scale`)**: Access your application at http://localhost:30001 and explore the Swagger documentation at http://localhost:30001/docs
- Modify the JAC application and redeploy
- Experiment with different configuration options
- Try deploying to a production Kubernetes cluster
