# Microservice Mode

Split your Jac app into independent services using `sv import`.

## How It Works

Write `sv import` - the compiler handles the rest:

```jac
# orders_app.jac
sv import from cart_app { get_cart, clear_cart }

def:pub create_order(user_id: str) -> dict {
    cart = get_cart(user_id=user_id);      # cross-service call (HTTP under the hood)
    # ... create order from cart items ...
    clear_cart(user_id=user_id);           # another cross-service call
    return {"order_id": "ord_1", "status": "confirmed"};
}
```

```jac
# cart_app.jac - exposes functions via sv {}
sv {
    def:pub get_cart(user_id: str) -> dict { ... }
    def:pub clear_cart(user_id: str) -> bool { ... }
    def:pub add_to_cart(user_id: str, product_id: str, qty: int) -> dict { ... }
}
```

Locally: runtime spawns subprocesses, assigns ports, routes calls.
On K8s: runtime creates pods, uses K8s DNS, routes calls.
**Same code, zero changes.**

## Quick Start

### 1. Create services

Each service exposes `def:pub` functions via `sv {}`:

```
my-app/
├── jac.toml
├── main.jac              # client UI + entry point
├── products_app.jac      # product catalog functions
├── cart_app.jac          # cart management functions
├── orders_app.jac        # order functions (sv imports cart + products)
```

**products_app.jac**:

```jac
node Product {
    has id: str, name: str, price: float;
}

sv {
    def:pub list_products() -> list[dict] {
        products: list[dict] = [];
        for p in [-->](`?Product) {
            products.append({"id": p.id, "name": p.name, "price": p.price});
        }
        return products;
    }

    def:pub get_product(product_id: str) -> dict | None { ... }
}
```

**orders_app.jac** - consumes other services:

```jac
sv import from cart_app { get_cart, clear_cart }
sv import from products_app { get_product }

sv {
    def:pub create_order(user_id: str) -> dict {
        cart = get_cart(user_id=user_id);
        # ... validate, create order ...
        clear_cart(user_id=user_id);
        return {"order_id": "ord_1", "status": "confirmed"};
    }
}
```

### 2. Configure jac.toml

```toml
[plugins.scale.microservices]
enabled = true

# Map module names to gateway URL prefixes (for client-facing routing)
[plugins.scale.microservices.routes]
products_app = "/api/products"
cart_app = "/api/cart"
orders_app = "/api/orders"

# Optional: client UI served as SPA
[plugins.scale.microservices.client]
entry = "main.jac"
```

Services are NOT declared individually - `sv import` handles discovery.
The TOML only maps module names to gateway prefixes.

### 3. Start

```bash
jac start main.jac
```

Runtime automatically:

1. Discovers providers from `sv import` statements (BFS traversal)
2. Spawns each provider as a subprocess on auto-assigned port
3. Starts gateway on :8000
4. Routes client requests to services by prefix

## URL Structure

```
POST /api/{module}/function/{func_name}     # public functions
POST /api/{module}/walker/{walker_name}      # public walkers
GET  /health                                 # gateway health
```

## CLI Commands

```bash
# Setup
jac setup microservice                   # interactive config
jac setup microservice --list            # show config
jac setup microservice --add file.jac    # add route mapping
jac setup microservice --remove name     # remove route mapping

# Service management
jac scale status                         # show all services
jac scale stop orders_app                # stop one service
jac scale restart cart_app               # restart one service
jac scale logs products_app              # view logs
jac scale destroy                        # stop everything
```

## Inter-Service Communication

**With `sv import` (recommended)**:

```jac
sv import from cart_app { get_cart, clear_cart }

# Just call it like a normal function - auth propagated automatically
cart = get_cart(user_id="u123");
clear_cart(user_id="u123");
```

Under the hood:

1. Compiler generates HTTP stub
2. Stub calls `sv_client.call("cart_app", "get_cart", {user_id: "u123"})`
3. jac-scale hook: reads auth from request context, forwards Authorization header
4. Cart service validates token, executes function, returns result
5. Stub unwraps response and returns to caller

**No manual `service_call()`, no `auth_token` passing, no URL management.**

## Client Frontend

The frontend calls the gateway API directly:

```jac
impl app.apiCall(service: str, endpoint: str, body: dict = {}) -> any {
    token = localStorage.getItem("jac_token");
    resp = await fetch(f"/api/{service}/function/{endpoint}", {
        "method": "POST",
        "headers": {
            "Content-Type": "application/json",
            "Authorization": "Bearer " + (token or "")
        },
        "body": JSON.stringify(body or {})
    });
    return await resp.json();
}
```

### Static asset directories outside dist

By default the gateway only serves files under `client.dist_dir`. If your
SPA references assets from a sibling directory in your repo (e.g. an
`assets/` folder for fonts, images, WASM, monaco workers, etc.) those
URLs will 404 in microservices mode unless you:

1. **Build them into dist** via your bundler (vite-plugin-static-copy,
   `publicDir`, or equivalent), **or**
2. **Declare a static mount** so the gateway serves them directly from
   their source directory.

Static mounts are the simpler option when you don't want to restructure
the build. Add one or more entries to
`[plugins.scale.microservices.client.static_mounts]`:

```toml
[[plugins.scale.microservices.client.static_mounts]]
url_prefix = "/static/assets"
local_path = "assets"

[[plugins.scale.microservices.client.static_mounts]]
url_prefix = "/uploads"
local_path = "/var/jac-uploads"
```

Each entry maps a URL prefix to a directory on disk. `local_path` can be
relative (resolved from the gateway's working directory) or absolute.
At request time the gateway checks `static_mounts` **before** falling
back to `client.dist_dir`, so a `GET /static/assets/logo.png` is served
from `<local_path>/logo.png`.

**Canonical ownership semantics**: a URL whose prefix matches a configured
mount belongs to that mount exclusively. A miss inside the mount returns
**404**, even if a same-named file exists under `client.dist_dir`. This
prevents dist from silently masking a missing asset and surfaces the
real configuration bug instead.

**Path safety**: requests are jailed to the configured `local_path` via
`Path.resolve()` + common-prefix check; `..` traversal and symlink
escapes are rejected.

**When dist works fine**: prefer building assets into dist if your
bundler already produces them (e.g. monaco workers via vite plugins).
Static mounts shine when you have a stable repo-root directory with
content that has no reason to be rebuilt by vite - fonts, vendored WASM,
agent prompt fixtures, manifest files, etc.

## What Is and Isn't a Service

Any module `sv import`ed somewhere is a service. No TOML declaration needed:

| File | How it becomes a service |
|------|------------------------|
| `cart_app.jac` | Some module has `sv import from cart_app { ... }` |
| `products_app.jac` | Some module has `sv import from products_app { ... }` |
| `shared/models.jac` | Regular import, NOT a service |
| `main.jac` | Entry point, client UI |

The TOML `[routes]` section only controls which services get **public gateway URLs**.
A service without a route still works for internal `sv import` calls.

## Architecture

```
Client --> Gateway (:8000) --> /api/products/* --> products_app (:18342)
                           --> /api/orders/*   --> orders_app   (:18567)
                           --> /api/cart/*     --> cart_app     (:18103)
                           --> Static files, Admin UI

Inter-service (sv import, direct - no gateway hop):
  orders_app (:18567) --sv_client.call()--> cart_app (:18103)
```

Ports are auto-assigned: `18000 + hash(module_name) % 1000`, 100 retries.

## Auth Flow

```
1. Client --> Gateway (Authorization: Bearer USER_TOKEN)
2. Gateway forwards Authorization --> orders_app
3. orders_app walker calls: get_cart(user_id)  [sv imported]
4. jac-scale sv_service_call hook:
   a. Reads Authorization from execution context
   b. POST to cart_app with same Authorization header
5. cart_app validates token (same JWT secret)
6. Result flows back automatically
```

No manual token passing. The hook reads it from the execution context.

## Local vs Kubernetes

Same code, different deployer:

| | Local | K8s (`--scale`) |
|-|-------|-----------------|
| Spawning | Subprocess per service | Pod per service |
| URLs | `http://127.0.0.1:18xxx` | `http://svc.ns.svc.cluster.local:8000` |
| Health | HTTP `/healthz` polling | K8s probes |
| Lifecycle | `LocalDeployer` | `KubernetesDeployer` |
| Scaling | 1 replica | HPA per service |
| Data | `.jac/data/{module}/` per process | Separate PVC per pod |

## Kubernetes Deployment

`jac start <file>.jac --scale` with `[plugins.scale.microservices].enabled = true`
auto-routes to the microservice K8s target: one image built and pushed,
then per-service `Deployment` + `ClusterIP Service` + HPA + PDB applied
for every `sv import`-discovered service plus the gateway.

Each pod boots with `JAC_SV_NAME=<service>` (`__gateway__` for gateway);
the entrypoint reads it to know which service to host. Gateway resolves
peers via in-cluster DNS (`<svc>-service.<ns>.svc.cluster.local`) - no
code changes from local mode.

### Per-service config

`[plugins.scale.microservices.services.NAME]` (gateway = `__gateway__`):

| Key | Default | Notes |
|---|---|---|
| `replicas` | `1` | `Deployment.spec.replicas` |
| `cpu_request`/`cpu_limit` | unset | `"100m"`, `"2000m"` |
| `memory_request`/`memory_limit` | unset | `"128Mi"`, `"4Gi"` |
| `env` | `{}` | extra env vars |
| `image_tag` | unset | per-service override (canary) |
| `rpc_timeout` | `10.0` | `sv import` httpx timeout (s) |
| `http_forward_timeout` | `30.0` | gateway-to-service forward (s) |
| `hpa.enabled` / `min` / `max` / `cpu_target` | `true` / `1` / `3` / `70` | autoscaler |
| `pdb.enabled` / `max_unavailable` | `true` / `1` | PodDisruptionBudget |

```toml
[plugins.scale.microservices.services.llm_app]
replicas = 2
cpu_limit = "2000m"
memory_limit = "4Gi"
rpc_timeout = 120.0

[plugins.scale.microservices.services.llm_app.hpa]
min = 3
max = 20
```

### Rolling deploy, autoscaling, drain

Every Deployment gets `RollingUpdate { maxSurge: 1, maxUnavailable: 0 }`,
readinessProbe on `/healthz/ready`, `terminationGracePeriodSeconds =
drain_timeout_seconds + 5`, and `preStop: sleep 5`. Together with the
drain middleware (`P13`), `kubectl rollout restart deployment/<svc>-deployment`
completes with zero non-2xx responses.

Each service also gets an HPA and a PDB (`maxUnavailable=1`). Opt out
per-service with `hpa.enabled = false` / `pdb.enabled = false`.

### Ingress

Default off. Opt in for an external URL routed to the gateway:

```toml
[plugins.scale.microservices.ingress]
enabled = true
host = "shop.example.com"          # optional
ingress_class_name = "nginx"       # or alb / gce / traefik
annotations = { "nginx.ingress.kubernetes.io/proxy-body-size" = "10m" }
```

One `Ingress` routes `/` to `gateway-service`; the gateway dispatches
`/api/{svc}/*` internally. HTTP only - TLS automation (cert-manager,
ACM) is deployment-specific; add via your own annotations/`tls:` block.

### Tear down

```bash
target.destroy("app-name")
# or:
kubectl delete deployment,service,hpa,pdb,ingress -l managed=jac-scale -n <ns>
```

`destroy()` deletes by `managed=jac-scale,jac-scale.role in
(microservice,gateway)` so renamed services still get cleaned up.

### Image + entrypoint

Every pod runs the same image, only needs `jac` + `jac-scale[deploy]`.
The pod-spec's `command`/`args` reads `JAC_SV_NAME` and dispatches:
`<svc>` -> `jac start <svc>.jac`, `__gateway__` -> `jac scale gateway`.
`JAC_SV_SIBLING=1` is set so the JacScalePlugin pre-hook skips the
local-mode orchestrator.

Starter Dockerfile + .dockerignore at
`jac-scale/scripts/Dockerfile.microservice` / `dockerignore.microservice`.

### End-to-end smoke

`jac-scale/scripts/k8s_microservice_real_e2e.sh` builds the image,
deploys, waits for rollout, curls gateway + per-service routes, then
hammers `/health` during a rolling restart asserting zero non-2xx.

```bash
minikube start
bash jac-scale/scripts/k8s_microservice_real_e2e.sh /path/to/project

# Remote (registry):
USE_MINIKUBE=0 REGISTRY=myregistry.io/myorg \
    bash jac-scale/scripts/k8s_microservice_real_e2e.sh /path/to/project
```

## Built-in Route Passthrough

The gateway forwards these to healthy services (tries all, skips 404):

| Route | What |
|-------|------|
| `/user/*` | Auth (register, login, refresh) |
| `/sso/*` | SSO (Google, Apple, GitHub) |
| `/walker/*`, `/function/*` | Direct walker/function calls |
| `/healthz` | Health check |
| `/cl/*` | Client error reporting |
| `/docs`, `/openapi.json` | API documentation |

## Production-Hardening Knobs

All configured under `[plugins.scale.microservices]` in `jac.toml`. `jac
setup microservice` writes commented reference blocks for each; uncomment
and tune per deployment.

### Graceful shutdown on SIGTERM

```toml
[plugins.scale.microservices]
drain_timeout_seconds = 10
```

On SIGTERM (or `jac scale stop`), gateway + services flip a drain flag
(new requests get `503 SERVICE_UNAVAILABLE` with `Retry-After: 2`) and
then uvicorn waits up to `drain_timeout_seconds` for in-flight requests
to complete. Mirrors K8s `terminationGracePeriodSeconds`.

### Per-service RPC timeout

Default is 10s. Override for LLM / generation / long-running services:

```toml
[plugins.scale.microservices.services.llm_app]
rpc_timeout = 120.0
```

The override is read on every `sv` RPC and passed through to
`httpx.Client(timeout=...)`.

### Streaming sv-to-sv RPC (generator returns)

A `def:pub` function that returns a Python generator (or any iterator
yielding JSON-serializable dicts) is automatically delivered to the
caller as a live stream. No new toml - the framing is per-call:

```jac
# Provider service
def:pub stream_events(run_id: str) -> Iterator[dict] {
    yield {"type": "started", "run_id": run_id};
    for chunk in some_long_running_work() {
        yield {"type": "chunk", "data": chunk};
    }
    yield {"type": "done"};
}

# Consumer service - exact same call shape as a non-streaming sv import,
# the runtime reads Content-Type and returns a generator on SSE.
sv import from llm_app { stream_events }

for ev in stream_events(run_id="abc") {
    handle(ev);
}
```

Wire format: `Content-Type: text/event-stream`, each yield framed as
`data: {json}\n\n`, terminated by `event: end\ndata: {}\n\n`. Producer-
side exceptions raised mid-stream surface as `event: error\ndata: {...}`
and re-raise as a `RuntimeError` out of the consumer's iterator
(so a normal `for ... in` loop sees the failure rather than a
silently-truncated stream).

Lifecycle: the consumer's generator owns the underlying httpx
connection. Exhausting the iterator OR letting it go out of scope
closes the connection cleanly. Dropping mid-stream (consumer
disconnects) closes too - the producer's `finally` blocks run.

`rpc_timeout` semantics on streaming: the timeout applies to
*establishing* the connection and to each blocking read between
events. A long, idle stream that sends no events for `rpc_timeout`
seconds will time out, matching the behavior we want for a hung
producer; a fast-stepping stream of any total duration is fine.

Retries are skipped once the stream is open: an in-flight stream
cannot be replayed without losing already-consumed events. Connect-
time failures (DNS, refused) still retry + count against the breaker
as they would for a non-streaming RPC.

### WebSockets + SSE proxy at the gateway

No config needed. Any client-hit `/api/{service}/ws/{rest}` is proxied
bidirectionally to `{service}`'s `ws://.../ws/{rest}` endpoint with
auth + trace forwarding. HTTP responses that are `text/event-stream`
or chunked are streamed through the gateway rather than buffered -
this also covers the generator-return path above when a public
client (vs. another sv-imported service) hits it.

### CORS

Open by default - `allow_origins` defaults to `["*"]` so local SPA
dev workflows (Vite on `:5173`, React on `:3000`, etc.) work without
config. Override to restrict:

```toml
[plugins.scale.microservices.cors]
allow_origins     = ["https://app.example.com"]   # concrete list
allow_methods     = ["GET", "POST", "OPTIONS"]
allow_headers     = ["Authorization", "Content-Type"]
allow_credentials = true    # requires concrete origins (not "*")
max_age           = 600
```

Set `allow_origins = []` to disable CORS entirely. Registered
outermost so preflights answer even during drain (clients need CORS
headers to read a 503 envelope).

### Rate limiting

Token bucket, per-IP + optional per-user. Opt-in:

```toml
[plugins.scale.microservices.rate_limit]
enabled           = true
per_ip_rpm        = 600
per_user_rpm      = 120        # 0 disables per-user tier
burst_multiplier  = 2.0        # capacity = rpm * burst / 60
exempt_paths      = ["/health", "/healthz", "/metrics"]
```

Per-IP key falls back from `X-Forwarded-For` (first hop) to
`request.client.host`. Per-user key is `sha256(Authorization)[:32]`. 429
responses carry the standard envelope + `Retry-After` header.

### Observability

+ `GET /health` - JSON summary of service statuses (always on).
+ `GET /metrics` - Prometheus exposition. Enable with
  `[plugins.scale.monitoring] enabled = true`.
+ `X-Trace-Id` - gateway mints one if the client omits it and threads
  it through every downstream hop (including `sv` RPCs). Echoed back
  on every response.
+ `GET /docs` + `GET /openapi.json` - unified Swagger UI + merged
  OpenAPI doc across all healthy services.
