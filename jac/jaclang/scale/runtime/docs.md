# Service Apps

A Jac workspace declares its apps in `jac.toml` under `[apps]`. Any app whose
kind has a server (`web-app`, `service`, `service-mesh`) can be reached by the
other apps; `service`-kind apps are the fleet the gateway fronts. There is no
separate service table: **the app boundary is structural, the topology is
profile**. The same workspace serves colocated in one process, as a local
fleet of processes, or as one Kubernetes pod per app, without a code change.

## How It Works

```toml
[project]
name = "shop"
default-app = "web"

[apps.web]                    # the served app: client UI + walkers, hosts the gateway
kind = "web-app"
path = "web"

[apps.cart]                   # a file-rooted service app
kind = "service"
entry-point = "core/cart.jac"

[apps.orders]
kind = "service"
entry-point = "core/orders.jac"
route = "/api/orders"         # optional; default is /api/<name>
```

```jac
# core/orders.jac
import from core.cart { get_cart, clear_cart }

def:pub create_order(user_id: str) -> dict {
    cart = await get_cart(user_id=user_id);     # cross-app call: a typed-async bridge
    clear_cart(user_id=user_id);                # un-awaited spawn: deferred via the outbox
    return {"order_id": "ord_1", "status": "confirmed"};
}
```

```jac
# core/cart.jac - a plain server module; def:pub is the app's surface
def:pub get_cart(user_id: str) -> dict { ... }
def:pub clear_cart(user_id: str) -> bool { ... }
```

The compiler classifies an import whose provider belongs to another app as a
service bridge and lowers it to an `async` stub over `sv_client`. Whether the
provider runs in-process or behind HTTP is decided at serve time, not at
compile time.

## Topologies

| | colocated (default) | `--fleet` / `colocate = false` | `jac scale deploy` |
|-|-|-|-|
| service apps | loaded into the served app's process | one local process each | one pod each |
| served app | in-process server at `/` | root member behind the gateway | root pod behind the gateway pod |
| bridged calls | in-process (`sv_client.register_local`) | HTTP to `JAC_APP_<APP>_URL` | HTTP to `<app>-service.<ns>.svc.cluster.local` |
| URLs | `<route>/walker/<name>`, `<route>/function/<name>` on the app server | the same URLs on the gateway | the same URLs on the gateway |

```bash
jac run web                 # colocated: everything in one process on :8000
jac run web --fleet         # local fleet: cart + orders as processes, gateway on :8000
jac scale deploy web        # kubernetes: pods for web, cart, orders + the gateway
```

`jac run web --fleet` (or `[scale.gateway] colocate = false` for every run)
starts each service app with `jac run --serve --no-client <entry>` on an
auto-assigned port, starts the served app the same way (with its client), then
serves the gateway on `gateway_port`. Providers boot before consumers: the
compiler records `consumer -> provider` app edges in each app's interop
manifest and the orchestrator topologically sorts them, falling back to
declaration order when there are no edges. Every process gets
`JAC_APP_<PEER>_URL` for every other member and `JAC_SV_NAME=<app>`.

## URL Structure

The gateway exposes exactly the URLs the colocated server mounts:

```
POST /api/{app}/walker/{walker}              # a service app's walker
POST /api/{app}/walker/{walker}/{node_id}
POST /api/{app}/function/{function}          # a service app's public function
GET  /api/{app}/walkers                       # per-app listings
GET  /api/{app}/functions
*    /                                        # everything else: the served app
GET  /health, /metrics, /openapi.json, /docs  # gateway-owned
```

Client stubs and `sv_client` resolve `gateway base + route`, so a browser or
another app talks to `http://host:8000/api/orders/...` whether the workspace
runs colocated, as a local fleet, or on Kubernetes.

## Configuration

Infrastructure knobs live under `[scale.gateway]`; per-app knobs live under
`[apps.<name>.scale]`.

```toml
[scale.gateway]
colocate = true                 # false: every `jac run` starts the fleet
gateway_port = 8000
gateway_host = "0.0.0.0"
http_forward_timeout = 30       # gateway -> app forward timeout
boot_health_timeout = 60        # per-app /healthz budget at boot
boot_max_wait = 90              # whole-fleet boot window
health_monitor_interval = 10    # restart loop cadence

[scale.gateway.identity]
gateway_owned = true            # apps provision users the gateway minted

[scale.gateway.rate_limit]
enabled = true
per_ip_rpm = 600
per_user_rpm = 120
shared = true                   # buckets in Postgres, one limit across replicas

[scale.gateway.cors]
allow_origins = ["https://app.example.com"]

[scale.gateway.ingress]
enabled = true
host = "shop.example.com"
ingress_class_name = "nginx"

[scale.gateway.logs]
enabled = true                  # Loki + Alloy lane
[scale.gateway.tracing]
enabled = true                  # OTLP lane

[[scale.gateway.shared_volumes]]
name = "shared-data"
mount_path = "/app/.jachome"
apps = ["orders", "cart"]
size = "10Gi"
```

Per-app overrides (formerly `[scale.microservices.services.<name>]`):

```toml
[apps.orders.scale]
rpc_timeout = 120.0             # app-to-app RPC timeout
http_forward_timeout = 30.0     # gateway -> this app
replicas = 2
cpu_request = "100m"
cpu_limit = "2000m"
memory_request = "128Mi"
memory_limit = "4Gi"
env = { LOG_LEVEL = "DEBUG" }
read_cache = false

[apps.orders.scale.hpa]
enabled = true
min = 1
max = 20
cpu_target = 60
memory_target = 80

[apps.orders.scale.pdb]
enabled = true
max_unavailable = 1

[apps.orders.scale.http_activation]   # KEDA HTTP Add-on scale-to-zero
enabled = true
target_port = 8000
concurrency_target = 5
[[apps.orders.scale.http_activation.rules]]
hosts = ["*"]

[[apps.orders.scale.triggers]]        # KEDA event triggers
type = "prometheus"
metadata = { serverAddress = "http://prometheus:9090", metricName = "queue", threshold = "5", query = "sum(queue)" }
```

The gateway pod takes the same pod keys (`replicas`, `cpu_*`, `memory_*`,
`env`, `hpa`, `pdb`, `deployment_overlay`) directly under `[scale.gateway]`.
Every reader of a per-app value goes through
`jaclang.scale.config.config_loader.app_scale_overrides(config, app)`, which
validates `[apps.<name>.scale]` against the schema (strict under
`JAC_SCALE_CONFIG_STRICT=1`) and reads the effective, profile-merged value.

## CLI Commands

```bash
jac run <app> --fleet                    # local fleet for one run
jac scale status                         # local fleet members and health
jac scale stop orders                    # stop one app
jac scale restart cart
jac scale logs products
jac scale destroy                        # stop every app

jac scale deploy [app | app.jac]         # kubernetes; default app when omitted
jac scale deploy --dry-run               # per-app plan + lint, no side effects
jac scale deploy --dry-run --show-yaml   # + raw multi-doc YAML
jac scale status app.jac                 # platform status
jac scale destroy app.jac                # tear down
```

`--dry-run` renders the same manifests as the real deploy and exits before
any side effect: one row per app (image, replicas, cpu/mem, HPA bounds,
route, PDB) plus the gateway, with inline lint findings. Errors block the
apply (exit 2); warnings are advisory.

## Inter-App Communication

```jac
import from core.cart { get_cart, ClearCart }

cart = await get_cart(user_id="u123");     # awaited: BridgeError family on failure
ClearCart(user_id="u123");                 # statement spawn: enqueued to the outbox
```

1. The compiler sees that `core.cart` belongs to app `cart`, not the importer's
   app, and emits an async stub keyed by the provider app name.
2. The stub calls `sv_client.call("cart", "get_cart", {...})`.
3. Colocated: the call runs in-process. Fleet or Kubernetes: jac-scale's
   transport forwards the request with the caller's `Authorization`,
   `X-Trace-Id` and `traceparent`, plus the bridge bearer token and an
   `X-Jac-Idempotency-Key` for outbox deliveries.
4. The provider validates the token, executes, and the stub rehydrates the
   result.

Awaited failures raise `BridgeUnavailable`, `BridgeTimeout`, `BridgeRejected`
or `BridgeError`. Un-awaited walker spawns never raise at the call site; the
outbox delivers them with retries.

## Architecture

```
Browser --> Gateway (:8000) --> /api/orders/*   --> orders  (:18567)
                            --> /api/cart/*     --> cart    (:18103)
                            --> everything else --> web     (:18342)  (root member)
                            --> /admin/*, /health, /metrics, /docs      (gateway-owned)

App-to-app (direct, no gateway hop):
  orders --sv_client.call()--> cart   via JAC_APP_CART_URL
```

Local ports are auto-assigned (`18000 + hash(app) % 1000`, 100 retries). The
served app is the fleet's root member: the gateway forwards every path it does
not own or proxy to it, so pages, `/walker/*`, `/user/*` (unless the gateway
owns identity) and `/cl/<sibling>/` bundles behave as they do colocated.

## Auth Flow

```
1. Browser --> Gateway (Authorization: Bearer USER_TOKEN)
2. Gateway forwards Authorization --> orders
3. orders calls get_cart(user_id) through the bridge
4. jac-scale transport reads Authorization from the execution context and
   forwards it to cart
5. cart validates the token (same JWT secret) and, with
   [scale.gateway.identity] gateway_owned = true, provisions the user's root
   on first sight
```

## Kubernetes Deployment

`jac scale deploy [app]` always deploys a fleet (`colocate` is ignored): one
`Deployment` + `ClusterIP Service` + autoscaler + PDB per app in the fleet
(the served app included) plus the gateway. Each pod boots with
`JAC_SV_NAME=<app>`, `JAC_SV_FILE=<entry relative to the bundle>`,
`JAC_SV_FLEET=<the fleet as JSON>` and a `JAC_APP_<PEER>_URL` for every peer,
resolved by in-cluster DNS (`<app>-service.<ns>.svc.cluster.local`). The
gateway pod runs `jac scale gateway` and reads the fleet from `JAC_SV_FLEET`;
every other pod runs `jac run --serve "$JAC_SV_FILE"`.

The deploy resolves every app's entry host-side against the sources the
bundle ships; a missing, parked (`.jacignore`) or out-of-tree entry fails the
deploy, `--dry-run` included, before anything is downloaded or sealed. The
served app's client bundle is built on the host from the staged sources and
shipped in the bundle.

### Rolling deploy, autoscaling, drain

Every Deployment gets `RollingUpdate { maxSurge: 1, maxUnavailable: 0 }`,
readiness on `/healthz/ready`, `terminationGracePeriodSeconds =
[serve.timeouts] drain + 5` and a `preStop` sleep. Together with the drain
middleware, `kubectl rollout restart deployment/<app>-deployment` completes
with zero non-2xx responses.

Each app gets an autoscaler (HPA, or a KEDA `ScaledObject` when
`autoscaler_engine = "keda"` is set in `[scale.kubernetes]`) and a PDB. Opt
out per app with `hpa.enabled = false` / `pdb.enabled = false` under
`[apps.<name>.scale]`. `[[apps.<name>.scale.triggers]]` adds KEDA triggers;
`auth.secret_refs` wires a `TriggerAuthentication`. `http_activation` (KEDA
HTTP Add-on) scales an app to zero; the gateway is never scaled to zero.

### Ingress

```toml
[scale.gateway.ingress]
enabled = true
host = "shop.example.com"
ingress_class_name = "nginx"
annotations = { "nginx.ingress.kubernetes.io/proxy-body-size" = "10m" }
```

One `Ingress` routes `/` to `gateway-service`; the gateway dispatches each
app's route internally and everything else to the served app.

### Tear down

```bash
jac scale destroy app.jac
# or:
kubectl delete deployment,service,hpa,pdb,ingress -l managed=jac-scale -n <ns>
```

## Built-in Route Passthrough

With a root member every non-owned path forwards to the served app. Without
one (a gateway fronting service apps only) the gateway probes healthy apps:

| Route | What |
|-------|------|
| `/user/*` | Auth (register, login, refresh); gateway-owned when its identity store is up |
| `/sso/*` | SSO (Google, Apple, GitHub) |
| `/walker/*`, `/function/*` | Direct walker/function calls |
| `/healthz` | Health check |
| `/cl/*` | Client pages and sibling app bundles |
| `/docs`, `/openapi.json` | Aggregated API documentation |

## Production-Hardening Knobs

### Graceful shutdown on SIGTERM

```toml
[serve.timeouts]
drain = 10.0
```

On SIGTERM (or `jac scale stop`), the gateway and every app flip a drain flag
(`/healthz/ready` answers 503, new requests get `503 SERVICE_UNAVAILABLE`
with `Retry-After: 1`) and the transport waits up to `[serve.timeouts]
drain` for in-flight requests to complete. Under `[serve.workers] count > 1`
the supervisor fans SIGTERM out and every worker drains on the same budget.
Mirrors K8s `terminationGracePeriodSeconds`.

### Per-app RPC timeout

`[apps.<name>.scale] rpc_timeout` (default 10s) bounds connection setup and
the wait for the response head of every bridged call into that app.

### Streaming app-to-app RPC (generator returns)

A `def:pub` function that returns a generator is delivered to the caller as
a live SSE stream (`Content-Type: text/event-stream`, one `data:` frame per
yield, `event: end` terminator, `event: error` re-raised as `RuntimeError`).
The consumer's generator owns the connection; exhausting or dropping it
closes the stream. `rpc_timeout` bounds only connection setup and the
response head. Retries happen only for connect-phase failures.

### WebSockets + SSE proxy at the gateway

`/api/{app}/ws/{rest}` is proxied bidirectionally to the app's
`ws://.../ws/{rest}` with auth and trace forwarding; `text/event-stream` and
chunked responses stream through the gateway.

### CORS

`[scale.gateway.cors]`: open by default (`allow_origins = ["*"]`); set a
concrete list to restrict or `[]` to disable. Registered outermost so
preflights answer even during drain.

### Rate limiting

`[scale.gateway.rate_limit]`: token bucket per IP plus an optional per-user
tier, kept in the project database (`shared = true`) so one limit holds
across every gateway process and replica. The client address comes from the
transport's proxy resolver: `X-Forwarded-For` is honored only from
`[serve.proxy] trusted`, so list your ingress there or every client shares
one bucket. 429 responses carry the standard envelope and `Retry-After`.

### Observability

+ `GET /health` - JSON summary of app statuses (always on).
+ `GET /metrics` - Prometheus exposition; enable with `[scale.monitoring] enabled = true`.
+ `X-Trace-Id` - minted by the gateway when absent and threaded through every hop.
+ `GET /docs` + `GET /openapi.json` - unified Swagger UI + merged OpenAPI across every healthy app.
