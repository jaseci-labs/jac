# Jac Scale Configuration

`jac start --scale` supports configuration via `jac.toml` (primary) and environment variables (overrides).

## Configuration Methods

1. **Primary**: `jac.toml` file in your project root
2. **Overrides**: Environment variables (for specific fields that support it)

## JWT Configuration

Configure in `jac.toml`:

```toml
[plugins.scale.jwt]
secret = "your-secret-key"
algorithm = "HS256"
exp_delta_days = 7
```

For production, set a strong `secret` and rotate it frequently.

## SSO Configuration

Configure in `jac.toml`:

```toml
[plugins.scale.sso]
host = "http://localhost:8000/sso"
[plugins.scale.sso.google]
client_id = "your-client-id"
client_secret = "your-client-secret"
```

## Kubernetes Configuration

### TOML Configuration (Recommended)

Add to `jac.toml`:

```toml
[plugins.scale.kubernetes]
# Basic settings
app_name = "my-app"
namespace = "default"
container_port = 8000
node_port = 30001
health_check_path = "/docs"

# Docker registry
docker_image_name = "my-app:latest"
docker_username = "myuser"
docker_password = "mypassword"

# Resource limits
cpu_request = "100m"
cpu_limit = "500m"
memory_request = "256Mi"
memory_limit = "512Mi"

# Health check probes
readiness_initial_delay = 10
readiness_period = 20
liveness_initial_delay = 10
liveness_period = 20
liveness_failure_threshold = 80

# Runtime images (TOML only)
python_image = "python:3.12-slim"
busybox_image = "busybox:1.36"
wait_image = "busybox"

# Storage
pvc_size = "5Gi"
app_mount_path = "/app"
code_mount_path = "/code"
workspace_path = "/code/workspace"

# Timing
resource_deletion_wait = 5
aws_nlb_wait = 60

# Jaseci repository (supports env var overrides for CI/CD)
jaseci_repo_url = "https://github.com/jaseci-labs/jaseci.git"
jaseci_branch = "main"
jaseci_commit = null  # Optional: specific commit hash
install_jaseci = true
additional_packages = ["curl", "vim"]

# Databases
mongodb_enabled = true
redis_enabled = true
```

### Environment Variable Overrides

Only these fields support environment variable overrides:

| Variable | Description | Default |
|----------|-------------|---------|
| `K8s_NAMESPACE` | Kubernetes namespace | `default` |
| `K8s_HEALTHCHECK_PATH` | Health check endpoint path | `/docs` |
| `K8s_JASECI_REPO_URL` | Jaseci repository URL | `https://github.com/jaseci-labs/jaseci.git` |
| `K8s_JASECI_BRANCH` | Jaseci branch to checkout | `main` |
| `K8s_JASECI_COMMIT` | Specific commit hash (optional) | - |

Example:
```bash
export K8s_NAMESPACE="production"
export K8s_JASECI_BRANCH="develop"
export K8s_JASECI_COMMIT="abc123def456"
```

**Note**: Most configuration should be in `jac.toml`. Environment variables are primarily for CI/CD scenarios where you need to override repository/branch/commit.

## Database Configuration

Configure in `jac.toml`:

```toml
[plugins.scale.database]
mongodb_uri = "mongodb://localhost:27017"
redis_url = "redis://localhost:6379"
shelf_db_path = ".jac/data/anchor_store.db"
```

Or use environment variables:
- `MONGODB_URI` - MongoDB connection string
- `REDIS_URL` - Redis connection string

**Note**: If you're using external databases (via `MONGODB_URI`/`REDIS_URL`), set `mongodb_enabled = false` and `redis_enabled = false` in the Kubernetes config to prevent auto-provisioning.
