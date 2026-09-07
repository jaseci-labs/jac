---
name: jac-sv-deploy
description: Configure production serving, secrets, infrastructure, and operations. Use when preparing deployment or integrating production services.
---

Production serving is the built-in `scale` subsystem's job. Scale ships inside `jaclang` -- there is no `jac-scale` package to install and no plugin to enable. Its optional heavier deps (kubernetes, docker, prometheus-client, opentelemetry-sdk, ...) are pulled per-project: declare the matching `[scale.*]` config in `jac.toml`, then run `jac install` to resolve them into `.jac/venv` (a `jac scale deploy` also resolves its deps on first run).

## jac run

`jac run [app.jac]` (default entry `main.jac`; needs a `jac.toml` in the cwd). Boolean flags are **hyphenated**: `--no-client` (API only, skip client bundling), `--port/-p` (auto-falls back if taken), `--faux` (print the generated API surface without starting - cheap endpoint preview), `--profile prod` (config profile), `--dev` (HMR). `jac run` exits when stdin closes - any backgrounded/daemonized server must be launched with `< /dev/null` (systemd/containers do this for you; shell scripts and CI must do it explicitly). For prod, kill Swagger:

```toml
[serve]
docs_enabled = false          # disables /docs, /openapi.json
graph_enabled = false         # disables /graph, /graph/data

[serve.workers]
count = "auto"                # one worker per core of the CPU quota; "1" for I/O-bound apps

[serve.access_log]
format = "json"
suppress_health_checks = true
```

Every `[serve]` key has a `JAC_SERVE_*` mirror (`JAC_SERVE_WORKERS`, `JAC_SERVE_AUTH_SECRET`, `JAC_SERVE_PROXY_TRUSTED`, ...), and `jac scale deploy` sets them on every pod. `jac run --workers N` overrides the count for one run.

**Backend:** Postgres, always. An embedded per-project server provisions automatically (zero setup); set `JAC_DB_URL` (or `[scale.database] url`) to use an external server - k8s deploys provision a Postgres StatefulSet and inject `JAC_DB_URL` into every pod. Config precedence everywhere: **env var > jac.toml > default**.

**Secrets** ship to pods via `[scale.secrets]` with `${ENV_VAR}` interpolation, resolved from your local env at deploy time and injected as a k8s Secret:

```toml
[scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
JWT_SECRET = "${JWT_SECRET}"        # see jac-sv-auth: the default JWT secret MUST be changed
```

## Kubernetes (`jac scale deploy`)

```bash
jac scale deploy app.jac --dry-run    # lint config + print the plan; nothing applied. Use before every deploy.
jac scale deploy app.jac              # deploy (no image build: source ships into the cluster on a PVC)
jac scale status app.jac              # component health table (app, Postgres, Prometheus, Grafana)
jac scale destroy app.jac             # DELETES THE NAMESPACE INCLUDING PERSISTENT VOLUMES - all data is lost
```

```toml
[scale.kubernetes]
app_name = "myapp"
namespace = "production"
min_replicas = 2                   # HPA bounds; scaling needs cpu_request set
max_replicas = 10
cpu_utilization_target = 70
cpu_request = "250m"
memory_limit = "2Gi"
health_check_path = "/health"      # built-in /health (liveness) and /ready (readiness)
domain = "app.example.com"         # custom domain
cert_manager_email = "you@example.com"
ingress_limit_rps = 20             # per-IP rate limit at the ingress; excess gets 429
```

HTTPS is a **two-step**: deploy plain (`jac scale deploy`), point your domain's CNAME at the printed NLB hostname, then `jac scale deploy app.jac --enable-tls` (cert-manager + Let's Encrypt, patches the live ingress - no redeploy). Postgres is auto-provisioned as a StatefulSet; everything is labeled `managed=jac-scale`. Multi-service stacks: `jac-sv-microservices`.

## Webhooks (external callbacks in)

`@restspec(protocol=APIProtocol.WEBHOOK)` on a walker serves it at **`POST /webhook/<name>` only** (not `/walker/<name>`). Auth is API-key + HMAC, not JWT: create a key with `POST /api-key/create` (JWT-authed; `DELETE /api-key/{id}` revokes), then callers send `X-API-Key` plus `X-Webhook-Signature` = HMAC-SHA256 of the raw body keyed by the API key:

```bash
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$API_KEY" | cut -d' ' -f2)
curl -X POST $HOST/webhook/PaymentReceived -H "X-API-Key: $API_KEY" \
  -H "X-Webhook-Signature: $SIG" -H "Content-Type: application/json" -d "$PAYLOAD"
```

Keys live in the shared Postgres store, so they survive restarts; only if the store is unreachable do they fall back to in-memory (a restart then invalidates them all).

## WebSockets

`@restspec(protocol=APIProtocol.WEBSOCKET)` on an **`async walker`** serves `ws://host/ws/<name>`; each JSON message maps onto `has` fields, `report` values stream back. `:pub` = anonymous; without it, JWT. `broadcast=True` sends each response to ALL connected clients of that walker (chat/live-update fan-out).

## Files / S3

`store()` (ambient) is local-disk by default; flip to S3 in config - same code:

```toml
[scale.storage]
type = "s3"
bucket = "my-app-uploads"      # region, prefix, endpoint_url (non-AWS), public_read
```

`storage.get_url(path, expires_in=600)` returns a presigned URL on private S3 (permanent public URL if `public_read = true`, `file://` locally). Upload endpoints: `jac-sv-endpoints`.

## Observability

- `/health`, `/ready` - built-in probe endpoints; `/healthz` variants also exist.
- **Prometheus**: `[scale.monitoring] enabled = true` registers `/metrics` - **admin-token-gated** (403 otherwise); `walker_metrics = true` adds per-walker timing. Visual dashboard in the admin portal.
- **CORS**: single-process `jac run` hardwires `allow_origins=['*']` - no knob. Only the fleet gateway (`--fleet` / deploy of a workspace with service apps) has configurable CORS (`[scale.gateway.cors]`). Don't ship a `:pub`-heavy API assuming you can lock origins down in single-process mode.

## Pitfalls

- **`jac scale destroy` deletes data.** PVCs included. There is a y/N prompt; there is no undo.
- `--dry-run` catches config errors (HPA min>max, bad resource units like `500MB` vs `500Mi`) in ~1s vs finding out after a 5-10 minute build-push-deploy.
- HPA does nothing without `cpu_request` - Kubernetes can't compute a utilization %.
- Multi-replica pods must share one database: the k8s deploy injects `JAC_DB_URL` for you; for other topologies point every replica at the same Postgres URL.
- **Invalid anchors after a change:** check the reference, selected app/store, and schema migration state. Follow `jac-debugging` and `jac-sv-persistence`; do not infer that an anchor error requires deleting project data.
- Webhook walkers don't answer on `/walker/<name>`, and regular walkers don't answer on `/webhook/<name>` - a 404 there is routing, not registration.
