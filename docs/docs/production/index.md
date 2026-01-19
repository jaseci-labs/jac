# Production & Scaling with jac-scale

Deploy your Jac applications to production with jac-scale. Transform your local Jac code into scalable, production-ready services with Kubernetes support, tiered memory architecture, and built-in authentication.

## Key Capabilities

| Feature | Description |
|---------|-------------|
| **REST API Generation** | Walkers automatically become REST endpoints |
| **Kubernetes Native** | Deploy to K8s with a single command |
| **Tiered Memory** | L1 (in-memory) → L2 (Redis) → L3 (MongoDB) |
| **Authentication** | JWT tokens and SSO (Google OAuth) |
| **Auto-Scaling** | Horizontal Pod Autoscaler based on CPU |

---

## Quick Start

```bash
# Start locally (development, uses main.jac by default)
jac start

# Deploy to Kubernetes (production)
jac start --scale

# Teardown deployment
jac destroy main.jac
```

---

## CLI Commands

### `jac start` - Local API Server (and Kubernetes Deployment)

```bash
jac start [filename.jac] [options]
```

> **Note**:
>
> - If no filename is provided, `jac start` defaults to `main.jac` in the current directory
> - If your project uses a different entry file (e.g., `app.jac`, `server.jac`), specify it explicitly: `jac start app.jac`
| Option | Default | Description |
|--------|---------|-------------|
| `--port` | 8000 | Server port |
| `--session` | "" | Session name for persistence |
| `--main` | true | Run as main module |
| `--faux` | false | Print endpoints without starting |
| `--scale` | false | Deploy to Kubernetes (requires jac-scale) |
| `--build` | false | Build Docker image before deploying (with --scale) |

**Access Points:**

- API: `http://localhost:8000`
- Docs: `http://localhost:8000/docs` (Swagger UI)
- Client: `http://localhost:8000/cl/app` (if using jac-client)

### Kubernetes Deployment

**Two Deployment Modes:**

1. **Fast Mode (Default)**: Uses Python base image, syncs code via PVC

   ```bash
   jac start --scale
   ```

2. **Production Mode**: Builds Docker image, pushes to registry

   ```bash
   jac start --scale --build
   ```

### `jac destroy` - Teardown

```bash
jac destroy <filename.jac>
```

Removes all Kubernetes resources: deployments, services, StatefulSets, PVCs.

---

## REST API Generation

### Access Control (Secure by Default)

By default, all walkers and functions **require authentication** when exposed as API endpoints. Use the `: pub` modifier to make endpoints publicly accessible without authentication.

| Access Modifier | Authentication Required | Use Case |
|----------------|------------------------|----------|
| None (default) | **Yes** | Secure by default |
| `: pub` | No | Public APIs |
| `: protect` | Yes | Protected APIs |
| `: priv` | Yes | Private APIs |

```jac
# Requires authentication (default - secure by default)
walker create_item {
    has name: str;
}

# Public endpoint - no authentication needed
walker : pub get_items {
    can list with `root entry {
        report [here -->];
    }
}

# Explicitly protected - requires authentication
def : protect admin_action() -> str {
    return "admin only";
}
```

### Walker Endpoints

Walkers automatically become REST endpoints:

```jac
walker create_item {
    has name: str;
    has price: float;

    can create with `root entry {
        item = here ++> Item(name=self.name, price=self.price);
        report item;
    }
}
```

**Generated Endpoint:**

```
POST /walker/create_item
Content-Type: application/json

{
    "name": "Widget",
    "price": 9.99
}
```

### Function Endpoints

```jac
def calculate_total(items: list[float]) -> float {
    return sum(items);
}
```

**Generated Endpoint:**

```
POST /function/calculate_total
Content-Type: application/json

{
    "items": [10.0, 20.0, 30.0]
}
```

---

## Authentication

### Built-in Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/register` | POST | Create new user |
| `/login` | POST | Get JWT token |
| `/refresh_token` | POST | Refresh JWT token |
| `/sso/{platform}/login` | GET | Start SSO flow |
| `/sso/{platform}/callback` | GET | SSO callback |

### JWT Configuration

```toml
# jac.toml
[plugins.scale.jwt]
secret = "your-secret-key"     # Use env var: ${JWT_SECRET}
algorithm = "HS256"
exp_delta_days = 7
```

### Google SSO

```toml
# jac.toml
[plugins.scale.sso]
host = "http://localhost:8000/sso"

[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"
```

---

## Memory Architecture

### Three-Tier Hierarchy

```
Request
    ↓
L1: In-Memory Cache (VolatileMemory)
    ↓ (read-through / write-through)
L2: Redis Cache (if available)
    ↓ (read-through / write-through)
L3: MongoDB (persistent storage)
    ↓ (fallback)
ShelfDB (file-based, local development)
```

### How It Works

- **L1**: Fast, ephemeral, per-process
- **L2**: Distributed cache for multi-pod deployments
- **L3**: Durable storage, survives restarts
- **Fallback**: If Redis/MongoDB unavailable, uses ShelfDB

### Configuration

```toml
# jac.toml
[plugins.scale.database]
mongodb_uri = "${MONGODB_URI}"
redis_url = "${REDIS_URL}"
shelf_db_path = ".jac/data/anchor_store.db"
```

---

## Kubernetes Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_NAME` | `jaseci` | App name in K8s |
| `K8s_NAMESPACE` | `default` | Kubernetes namespace |
| `K8s_NODE_PORT` | `30001` | NodePort for local access |
| `K8s_CPU_REQUEST` | - | CPU request (e.g., "100m") |
| `K8s_CPU_LIMIT` | - | CPU limit (e.g., "500m") |
| `K8s_MEMORY_REQUEST` | - | Memory request (e.g., "128Mi") |
| `K8s_MEMORY_LIMIT` | - | Memory limit (e.g., "512Mi") |
| `K8s_MONGODB` | `True` | Auto-provision MongoDB |
| `K8s_REDIS` | `True` | Auto-provision Redis |
| `DOCKER_USERNAME` | - | DockerHub username (for -b mode) |
| `DOCKER_PASSWORD` | - | DockerHub password (for -b mode) |

### jac.toml Configuration

```toml
[plugins.scale.kubernetes]
app_name = "myapp"
namespace = "default"
container_port = 8000
node_port = 30001
mongodb_enabled = true
redis_enabled = true

# For production builds
docker_username = "${DOCKER_USERNAME}"
docker_password = "${DOCKER_PASSWORD}"
```

---

## Auto-Provisioned Resources

When you run `jac start --scale`, these resources are created automatically:

### MongoDB StatefulSet (if enabled)

- Persistent storage (5Gi default)
- Service on port 27017
- Connection: `mongodb://<app>-mongodb-service:27017/jac_db`

### Redis Deployment (if enabled)

- Service on port 6379
- Connection: `redis://<app>-redis-service:6379/0`

### Application Deployment

- Init containers for dependency setup
- Health checks (readiness + liveness probes)
- Resource limits and requests
- Volume mounts for code and data

### Service

- **Local clusters**: NodePort (default 30001)
- **AWS EKS**: Network Load Balancer

---

## Health Checks

```toml
# jac.toml environment variables
K8s_HEALTHCHECK_PATH = "/docs"
K8s_READINESS_INITIAL_DELAY = 10   # seconds
K8s_READINESS_PERIOD = 20          # seconds
K8s_LIVENESS_INITIAL_DELAY = 10    # seconds
K8s_LIVENESS_PERIOD = 20           # seconds
K8s_LIVENESS_FAILURE_THRESHOLD = 80
```

---

## Horizontal Pod Autoscaler

jac-scale automatically configures HPA:

- **Metric**: CPU utilization
- **Min replicas**: 1
- **Max replicas**: 5 (configurable)
- **Target**: 80% CPU utilization

---

## Complete Configuration Example

```toml
# jac.toml
[project]
name = "my-production-app"
version = "1.0.0"
entry-point = "main.jac"

[serve]
port = 8000
session = "prod"
cl_route_prefix = "cl"

[plugins.scale]

[plugins.scale.jwt]
secret = "${JWT_SECRET}"
algorithm = "HS256"
exp_delta_days = 7

[plugins.scale.sso]
host = "${SSO_HOST}"
[plugins.scale.sso.google]
client_id = "${GOOGLE_CLIENT_ID}"
client_secret = "${GOOGLE_CLIENT_SECRET}"

[plugins.scale.database]
mongodb_uri = ""    # Auto-provisioned in K8s
redis_url = ""      # Auto-provisioned in K8s
shelf_db_path = ".jac/data/anchor_store.db"

[plugins.scale.kubernetes]
app_name = "my-app"
namespace = "production"
container_port = 8000
node_port = 30001
mongodb_enabled = true
redis_enabled = true

[plugins.scale.server]
port = 8000
host = "0.0.0.0"
```

---

## Deployment Workflow

### Development → Staging → Production

```bash
# 1. Development: Run locally
jac run main.jac

# 2. Local API: Test as server
jac start
# → http://localhost:8000/docs

# 3. Production: Deploy to K8s
jac start --scale
# → http://localhost:30001/docs (NodePort)
# → or LoadBalancer URL (AWS)

# 4. Cleanup
jac destroy main.jac
```

### Production with Docker Build

```bash
# Set credentials
export DOCKER_USERNAME="your-username"
export DOCKER_PASSWORD="your-token"

# Build, push, and deploy
jac start --scale --build
```

---

## Supported Platforms

| Platform | Access Type | Notes |
|----------|-------------|-------|
| Minikube | NodePort | Local development |
| Docker Desktop | NodePort | Local development |
| AWS EKS | LoadBalancer | Production (NLB) |
| Generic K8s | NodePort | Any cluster |

---

## Migration from jac-cloud

!!! warning "jac-cloud is Deprecated"
    If you're using jac-cloud, migrate to jac-scale. The jac-cloud package is no longer maintained.

**Key Differences:**

| jac-cloud | jac-scale |
|-----------|-----------|
| Proprietary cloud | Self-managed K8s |
| External DB management | Auto-provisioned DBs |
| Vendor lock-in | Cloud-agnostic |
| SaaS pricing | Infrastructure costs only |

---

## Learn More

| Topic | Resource |
|-------|----------|
| Getting Started | [README](../jac-scale/README.md) |
| Quickstart | [First Deployment](../jac-scale/quickstart.md) |
| Configuration | [All Options](../jac-scale/configuration.md) |
| Roadmap | [Upcoming Features](../jac-scale/roadmap.md) |
