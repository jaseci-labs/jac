# Jac scale configuration

`jac start --scale` not only simplifies application deployment but also supports advanced configurations. Most configuration is done via `jac.toml`, with environment variables reserved for secrets and runtime overrides.

## Configuration via jac.toml

The primary way to configure Jac Scale is through the `jac.toml` file. All configuration options have sensible defaults, so you only need to specify what you want to customize.

### Kubernetes Configuration

All Kubernetes deployment settings can be configured in `jac.toml` under the `[plugins.scale.kubernetes]` section:

```toml
[plugins.scale.kubernetes]
# Basic settings
app_name = "myapp"
namespace = "default"
container_port = 8000
node_port = 30001

# Docker registry (for build mode)
docker_image_name = "myapp:latest"
docker_username = "myuser"
docker_password = "mypassword"  # Consider using environment variable for secrets

# Database provisioning
mongodb_enabled = true
redis_enabled = true

# Resource limits
cpu_request = "100m"
cpu_limit = "500m"
memory_request = "256Mi"
memory_limit = "512Mi"

# Health checks
health_check_path = "/docs"
readiness_initial_delay = 10
readiness_period = 20
liveness_initial_delay = 10
liveness_period = 20
liveness_failure_threshold = 80

# Runtime configuration
python_image = "python:3.12-slim"
busybox_image = "busybox:1.36"
wait_image = "busybox"

# Storage configuration
pvc_size = "5Gi"

# Mount paths
app_mount_path = "/app"
code_mount_path = "/code"
workspace_path = "/code/workspace"

# Jaseci repository configuration
jaseci_repo_url = "https://github.com/jaseci-labs/jaseci.git"
jaseci_branch = "main"
jaseci_commit = null  # Optional: specific commit hash
install_jaseci = true
additional_packages = ["curl", "vim"]

# Timing configuration
resource_deletion_wait = 5  # seconds
aws_nlb_wait = 60  # seconds
```

### JWT Configuration

```toml
[plugins.scale.jwt]
secret = "supersecretkey"  # Use environment variable in production!
algorithm = "HS256"
exp_delta_days = 7
```

### SSO Configuration

```toml
[plugins.scale.sso]
host = "http://localhost:8000/sso"
[plugins.scale.sso.google]
client_id = ""
client_secret = ""  # Use environment variable for secrets!
```

### Database Configuration

```toml
[plugins.scale.database]
mongodb_uri = null  # Set via MONGODB_URI env var or here
redis_url = null    # Set via REDIS_URL env var or here
shelf_db_path = ".jac/data/anchor_store.db"
```

## Environment Variables

Environment variables are primarily used for:
1. **Secrets** (passwords, API keys, etc.)
2. **Runtime overrides** (namespace, health check path)

### Kubernetes Environment Variables

| Parameter | Description | Default | Notes |
|-----------|-------------|---------|-------|
| `K8s_NAMESPACE` | Kubernetes namespace to deploy the application | `default` | Overrides TOML config |
| `K8s_HEALTHCHECK_PATH` | Health check endpoint path | `/docs` | Overrides TOML config |
| `DOCKER_USERNAME` | DockerHub username for pushing the image | - | For build mode |
| `DOCKER_PASSWORD` | DockerHub password or access token | - | **Secret** - use env var |

> **Note**: Most Kubernetes configuration should be done via `jac.toml`. Environment variables are only used for runtime overrides or secrets.

### Database Environment Variables

| Parameter | Description | Default | Notes |
|-----------|-------------|---------|-------|
| `MONGODB_URI` | URL of MongoDB database | - | Overrides TOML config |
| `REDIS_URL` | URL of Redis database | - | Overrides TOML config |

> **Important**: If you are manually setting `MONGODB_URI` or `REDIS_URL` as environment variables, make sure you set `mongodb_enabled = false` or `redis_enabled = false` respectively in your `jac.toml` to avoid auto-provisioning.

### JWT Environment Variables

| Parameter | Description | Default | Notes |
|-----------|-------------|---------|-------|
| `JWT_EXP_DELTA_DAYS` | Number of days until JWT token expires | `7` | Overrides TOML config |
| `JWT_SECRET` | Secret key used for JWT token signing and verification | `'supersecretkey'` | **Secret** - use env var in production! |
| `JWT_ALGORITHM` | Algorithm used for JWT token encoding/decoding | `'HS256'` | Overrides TOML config |

> **Security Note**: For production environments, make sure you set a strong `JWT_SECRET` via environment variable and rotate it frequently.

### SSO Environment Variables

| Parameter | Description | Default | Notes |
|-----------|-------------|---------|-------|
| `SSO_HOST` | SSO host URL | `'http://localhost:8000/sso'` | Overrides TOML config |
| `SSO_GOOGLE_CLIENT_ID` | Google OAuth client ID | - | Overrides TOML config |
| `SSO_GOOGLE_CLIENT_SECRET` | Google OAuth client secret | - | **Secret** - use env var |

## Configuration Priority

Configuration values are loaded in the following priority order:

1. **Environment variables** (for secrets and runtime overrides)
2. **jac.toml** (primary configuration)
3. **Default values** (sensible defaults)

## Example: Production Configuration

For production, use environment variables for secrets and TOML for everything else:

```bash
# .env file (never commit this!)
export JWT_SECRET="your-super-secret-key-here"
export DOCKER_PASSWORD="your-docker-token"
export SSO_GOOGLE_CLIENT_SECRET="your-google-secret"
```

```toml
# jac.toml (can be committed)
[plugins.scale.kubernetes]
app_name = "myapp"
namespace = "production"
container_port = 8000
cpu_limit = "1000m"
memory_limit = "1Gi"
health_check_path = "/health"

[plugins.scale.jwt]
algorithm = "HS256"
exp_delta_days = 7
# secret comes from JWT_SECRET env var

[plugins.scale.sso.google]
# client_id and client_secret come from env vars
```
