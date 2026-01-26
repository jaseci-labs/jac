# jac-scale Reference

Complete reference for jac-scale, the cloud-native deployment and scaling plugin for Jac.

---

## Installation

```bash
pip install jac-scale
```

For cloud features:

```bash
pip install jac-cloud
```

---

## Starting a Server

### Basic Server

```bash
jac start app.jac
```

### Server Options

| Option | Description | Default |
|--------|-------------|---------|
| `--port` | Server port | 8000 |
| `--host` | Bind address | 0.0.0.0 |
| `--workers` | Number of workers | 1 |
| `--reload` | Hot reload on changes | false |
| `--scale` | Deploy to Kubernetes | false |
| `--build` `-b` | Build and push Docker image (with --scale) | false |
| `--experimental` `-e` | Install from repo instead of PyPI (with --scale) | false |
| `--target` | Deployment target (kubernetes, aws, gcp) | kubernetes |
| `--registry` | Image registry (dockerhub, ecr, gcr) | dockerhub |

### Examples

```bash
# Custom port
jac start app.jac --port 3000

# Multiple workers
jac start app.jac --workers 4

# Development with hot reload
jac start app.jac --reload

# Production
jac start app.jac --host 0.0.0.0 --port 8000 --workers 4
```

---

## API Endpoints

### Automatic Endpoint Generation

Each walker becomes an API endpoint:

```jac
walker get_users {
    can fetch with `root entry {
        report [];
    }
}
```

Becomes: `POST /walker/get_users`

### Request Format

Walker parameters become request body:

```jac
walker search {
    has query: str;
    has limit: int = 10;
}
```

```bash
curl -X POST http://localhost:8000/walker/search \
  -H "Content-Type: application/json" \
  -d '{"query": "hello", "limit": 20}'
```

### Response Format

Walker `report` values become the response.

---

## Authentication

### User Registration

```bash
curl -X POST http://localhost:8000/user/register \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secret"}'
```

### User Login

```bash
curl -X POST http://localhost:8000/user/login \
  -H "Content-Type: application/json" \
  -d '{"email": "user@example.com", "password": "secret"}'
```

Returns:

```json
{
  "access_token": "eyJ...",
  "token_type": "bearer"
}
```

### Authenticated Requests

```bash
curl -X POST http://localhost:8000/walker/my_walker \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{}'
```

---

## Permissions

### Permission Levels

| Permission | Enum | Description |
|------------|------|-------------|
| None | `NoPerm` | No access |
| Read | `ReadPerm` | Read-only access |
| Connect | `ConnectPerm` | Can connect edges |
| Write | `WritePerm` | Full read/write access |

### Grant/Revoke Permissions

```jac
with entry {
    # Grant permission
    grant(node, WritePerm);
    grant(node, level=ConnectPerm);

    # Revoke permission
    revoke(node);
}
```

### Custom Access Validation

```jac
node SecureNode {
    has owner_id: str;

    def __jac_access__() -> Permission {
        # Custom validation logic
        if self.owner_id == current_user_id() {
            return WritePerm;
        }
        return ReadPerm;
    }
}
```

---

## Graph Traversal API

### Traverse Endpoint

```bash
POST /traverse
```

### Parameters

| Parameter | Type | Description | Default |
|-----------|------|-------------|---------|
| `source` | str | Starting node/edge ID | root |
| `depth` | int | Traversal depth | 1 |
| `detailed` | bool | Include archetype context | false |
| `node_types` | list | Filter by node types | all |
| `edge_types` | list | Filter by edge types | all |

### Example

```bash
curl -X POST http://localhost:8000/traverse \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{
    "depth": 3,
    "node_types": ["User", "Post"],
    "detailed": true
  }'
```

---

## Async Walkers

```jac
walker async_processor {
    has items: list;

    async can process with `root entry {
        results = [];
        for item in self.items {
            result = await process_item(item);
            results.append(result);
        }
        report results;
    }
}
```

---

## Database Configuration

### jac.toml

```toml
[database]
host = "localhost"
port = 5432
name = "jacdb"
user = "jac"
password = "secret"
```

### Environment Variables

| Variable | Description |
|----------|-------------|
| `DATABASE_HOST` | Database hostname |
| `DATABASE_PORT` | Database port |
| `DATABASE_NAME` | Database name |
| `DATABASE_USER` | Database username |
| `DATABASE_PASSWORD` | Database password |

---

## Kubernetes Deployment

### Docker Image

```dockerfile
FROM python:3.11-slim

WORKDIR /app
RUN pip install jaclang jac-scale
COPY . .

EXPOSE 8000
CMD ["jac", "start", "app.jac", "--host", "0.0.0.0"]
```

### Deployment Manifest

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jac-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: jac-app
  template:
    metadata:
      labels:
        app: jac-app
    spec:
      containers:
      - name: jac-app
        image: myregistry/jac-app:latest
        ports:
        - containerPort: 8000
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8000
          initialDelaySeconds: 5
```

### Service

```yaml
apiVersion: v1
kind: Service
metadata:
  name: jac-app-service
spec:
  selector:
    app: jac-app
  ports:
  - port: 80
    targetPort: 8000
  type: ClusterIP
```

### Horizontal Pod Autoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: jac-app-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: jac-app
  minReplicas: 2
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## CLI Commands

### jac-scale Commands

| Command | Description |
|---------|-------------|
| `jac scale init` | Initialize K8s manifests |
| `jac scale deploy` | Deploy to cluster |
| `jac scale status` | Show deployment status |
| `jac scale logs` | View application logs |
| `jac scale replicas N` | Scale to N replicas |
| `jac scale autoscale` | Configure HPA |
| `jac scale update` | Update deployment |
| `jac scale rollback` | Rollback deployment |

### jac-cloud Commands

| Command | Description |
|---------|-------------|
| `jac serve` | Start server (alias for jac start) |
| `jac serve --faux` | Print API docs without starting |
| `jac create_system_admin` | Create admin user |

---

## Configuration

### jac.toml

```toml
[project]
name = "myapp"
version = "1.0.0"

[serve]
port = 8000
host = "0.0.0.0"
workers = 4
reload = false

[database]
host = "localhost"
port = 5432
name = "jacdb"

[environments.production]
debug = false

[environments.response.headers]
# Custom response headers
Cross-Origin-Opener-Policy = "same-origin"
Cross-Origin-Embedder-Policy = "require-corp"
```

### Package Version Pinning

Configure specific package versions for Kubernetes deployments:

```toml
[plugins.scale.kubernetes.plugin_versions]
jaclang = "0.1.5"      # Specific version
jac_scale = "latest"   # Latest from PyPI (default)
jac_client = "0.1.0"   # Specific version
jac_byllm = "none"     # Skip installation
```

| Package | Description | Default |
|---------|-------------|---------|
| `jaclang` | Core Jac language package | latest |
| `jac_scale` | Scaling plugin | latest |
| `jac_client` | Client/frontend support | latest |
| `jac_byllm` | LLM integration (use "none" to skip) | latest |

---

## Health Checks

### Health Endpoint

Create a health walker:

```jac
walker health {
    can check with `root entry {
        report {"status": "healthy"};
    }
}
```

Access at: `POST /walker/health`

### Readiness Check

```jac
walker ready {
    can check with `root entry {
        db_ok = check_database();
        cache_ok = check_cache();

        if db_ok and cache_ok {
            report {"status": "ready"};
        } else {
            report {
                "status": "not_ready",
                "db": db_ok,
                "cache": cache_ok
            };
        }
    }
}
```

---

## Builtins

### Root Access

```jac
with entry {
    # Get all roots in memory/database
    roots = allroots();
}
```

### Memory Commit

```jac
with entry {
    # Commit memory to database
    commit();
}
```

---

## API Documentation

When server is running:

- **Swagger UI:** `http://localhost:8000/docs`
- **ReDoc:** `http://localhost:8000/redoc`
- **OpenAPI JSON:** `http://localhost:8000/openapi.json`

---

## Related Resources

- [Local API Server Tutorial](../../tutorials/production/local.md)
- [Kubernetes Deployment Tutorial](../../tutorials/production/kubernetes.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
