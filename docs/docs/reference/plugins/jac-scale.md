# Scale Reference

Scale generates REST endpoints from your Jac walkers and functions. Running `jac start` turns every `:pub` or `:priv` walker into an API endpoint backed by FastAPI, with automatic Swagger docs, SQLite persistence, and built-in authentication.

For production, the `--scale` flag automates Docker image builds and Kubernetes deployment -- generating Dockerfiles, manifests, and service configurations from your code. This reference covers server startup options, endpoint generation, authentication, database persistence, Kubernetes deployment, and the CLI flags for each mode.

Scale ships **built into `jaclang` core** as the `scale` subsystem (importable as `jaclang.scale`) -- there is no separate `jac-scale` package to install. It arrives with the `jac` binary, so the serving and deployment machinery is always present; only the heavier optional third-party libraries it can use (MongoDB, Redis, Kubernetes, Prometheus, ...) are pulled in per-project, on demand.

This reference is split across three focused pages, hubbed here. Use the quick reference below to jump to the area you need.

<!-- This page was split into three sub-pages (see "Reference pages" below). Old
     deep links such as jac-scale/#storage still resolve to this hub; the script
     below forwards a matching fragment to the section's new home so external
     bookmarks keep working. -->
<script>
(function () {
  var moved = {
    "admin-portal": "jac-scale-http",
    "api-documentation": "jac-scale-http",
    "api-endpoints": "jac-scale-http",
    "async-walkers": "jac-scale-persistence",
    "authentication": "jac-scale-http",
    "autoscaling": "jac-scale-kubernetes",
    "builtins": "jac-scale-persistence",
    "centralised-logs": "jac-scale-kubernetes",
    "cli-commands": "jac-scale-http",
    "cross-service-shared-volumes": "jac-scale-kubernetes",
    "database-and-dashboards": "jac-scale-persistence",
    "direct-database-access-kvstore": "jac-scale-persistence",
    "distributed-locks-redis-only": "jac-scale-persistence",
    "emailer": "jac-scale-http",
    "event-streaming": "jac-scale-persistence",
    "firestore-operations": "jac-scale-persistence",
    "graph-traversal-api": "jac-scale-persistence",
    "graph-visualization": "jac-scale-http",
    "health-checks": "jac-scale-kubernetes",
    "identity-management-password-reset": "jac-scale-http",
    "kubernetes-deployment": "jac-scale-kubernetes",
    "kubernetes-secrets": "jac-scale-kubernetes",
    "microservice-interop-sv-to-sv": "jac-scale-http",
    "microservice-mode-in-kubernetes": "jac-scale-kubernetes",
    "middleware-walkers": "jac-scale-http",
    "mongodb-operations": "jac-scale-persistence",
    "permissions-access-control": "jac-scale-http",
    "pre-bound-serviceaccount": "jac-scale-kubernetes",
    "prometheus-metrics": "jac-scale-kubernetes",
    "redis-operations": "jac-scale-persistence",
    "remote-image-registry": "jac-scale-kubernetes",
    "restspec-decorator": "jac-scale-http",
    "sandbox-environments": "jac-scale-kubernetes",
    "service-discovery": "jac-scale-http",
    "setting-up-kubernetes": "jac-scale-kubernetes",
    "starting-a-server": "jac-scale-http",
    "storage": "jac-scale-persistence",
    "sv_client-api-reference": "jac-scale-http",
    "troubleshooting": "jac-scale-kubernetes",
    "walker-imports": "jac-scale-http",
    "webhooks": "jac-scale-http",
    "websockets": "jac-scale-http"
  };
  function reroute() {
    var h = (location.hash || "").replace(/^#/, "");
    if (h && moved[h]) { location.replace("../" + moved[h] + "/#" + h); }
  }
  reroute();
  window.addEventListener("hashchange", reroute);
})();
</script>

---

## Optional dependencies

Scale's core path -- the FastAPI server, JWT auth, and CLI flags -- works out of the box with nothing extra to install. Heavier capabilities (Mongo/Redis storage, Kubernetes deploys, Prometheus metrics, scheduling) rely on third-party libraries that are **not** bundled into the `jac` binary. You enable them per-project by declaring the matching `[scale.*]` config in `jac.toml` and running `jac install`, which resolves the libraries that intent requires into the project's `.jac/venv`.

```bash
# After configuring the capabilities you need in jac.toml, install the
# resolved dependencies into this project's .jac/venv:
jac install
```

For example, configuring a Mongo database under `[scale.database]` makes `jac install` pull in `pymongo`/`redis`; configuring `[scale.kubernetes]` (or using `jac start --scale`) pulls in `kubernetes`/`docker`; enabling `[scale.monitoring]` pulls in `prometheus-client`.

!!! note
    When a feature is used without its dependency present, you get a clear error telling you to declare the relevant `[scale.*]` config and run `jac install`:
    `ImportError: 'pymongo' is required for this feature. Configure '[scale.database]' and run 'jac install'.`

| Capability | What it needs | When you need it |
|-------|-------------|-----------------|
| _(core serving)_ | FastAPI, uvicorn, JWT auth | Always available -- ships with `jaclang` |
| Mongo/Redis storage | pymongo, redis | Using MongoDB/Redis for storage (`jac start` with `[scale.database]`) |
| Firestore | google-cloud-firestore | Using Firestore with `kvstore(db_type='firestore')` |
| Cloud object storage | boto3 | Using S3-compatible cloud storage |
| Monitoring | prometheus-client | Prometheus `/metrics` endpoint |
| Scheduling | apscheduler | `@schedule(trigger=...)` on walkers/functions |
| Deployment | kubernetes, docker | `jac start --scale` or `jac start --build` |

---

## Reference pages

The full Scale reference is organized into three pages:

| Page | Covers |
|------|--------|
| **[HTTP API & Walkers](jac-scale-http.md)** | Starting a server, automatic API endpoint generation, the `@restspec` decorator, middleware walkers, authentication (identity model, registration/login, JWT, SSO, password reset, roles), the admin portal, permissions & access control, webhooks, WebSockets, microservice interop (sv-to-sv), the emailer, CLI commands, API documentation, and graph visualization. |
| **[Data & Storage](jac-scale-persistence.md)** | Object storage (`store()`, local & S3/GCS-compatible backends), the graph traversal API, async walkers, direct database access (kvstore), MongoDB / Firestore / Redis operations, distributed locks, event streaming, database & dashboards (auto-provisioning, memory hierarchy), and graph builtins. |
| **[Kubernetes & Operations](jac-scale-kubernetes.md)** | Kubernetes deployment (modes, ingress, TLS, autoscaling, storage, images, package pinning, monitoring stack), health checks, Prometheus metrics, Kubernetes secrets, remote image registry, pre-bound ServiceAccount, cross-service shared volumes, microservice mode in Kubernetes, cluster setup, troubleshooting, and sandbox environments. |

For end-to-end walkthroughs rather than reference material, see the Deploy tutorials:

- [Local API server](../../tutorials/production/local.md)
- [Microservices](../../tutorials/production/microservices.md)
- [Kubernetes](../../tutorials/production/kubernetes.md)

---

## Library Mode

For teams preferring pure Python syntax or integrating Jac into existing Python codebases, Library Mode provides an alternative deployment approach. Instead of `.jac` files, you use Python files with Jac's runtime as a library.

> **Complete Guide:** See [Library Mode](../language/library-mode.md) for the full API reference, code examples, and migration guide.

**Key Features:**

- All Jac features accessible through `jaclang.lib` imports
- Pure Python syntax with decorators (`@on_entry`, `@on_exit`)
- Full IDE/tooling support (autocomplete, type checking, debugging)
- Zero migration friction for existing Python projects

**Quick Example:**

```python
from jaclang.lib import Node, Walker, spawn, root, on_entry

class Task(Node):
    title: str
    done: bool = False

class TaskFinder(Walker):
    @on_entry
    def find(self, here: Task) -> None:
        print(f"Found: {here.title}")

spawn(TaskFinder(), root())
```

---

## Related Resources

- [Local API Server Tutorial](../../tutorials/production/local.md)
- [Kubernetes Deployment Tutorial](../../tutorials/production/kubernetes.md)
- [Backend Integration Tutorial](../../tutorials/fullstack/backend.md)
