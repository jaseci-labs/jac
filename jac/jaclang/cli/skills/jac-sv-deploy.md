---
name: jac-sv-deploy
description: Running a Jac server in production - jac start flags, database backends (SQLite/Mongo/Redis), secrets, Kubernetes deploys (--scale, TLS, autoscaling, jac status/destroy), webhooks, WebSockets, S3 storage, metrics, distributed locks. Load when moving a server beyond local dev or wiring external services in. Pair with `jac-sv-endpoints`, `jac-sv-microservices` (multi-service k8s), `jac-config`.
---

Production serving is jac-scale's job: `pip install jac-scale` (or `jac-scale[all]`), then `jac plugins enable scale` if it isn't already active (`jac plugins` to check).

## jac start

`jac start [app.jac]` (default entry `main.jac`; needs a `jac.toml` in the cwd). Flags use **underscores**: `--no_client` (API only, skip client bundling), `--port/-p` (auto-falls back if taken), `--faux` (print the generated API surface without starting - cheap endpoint preview), `--profile prod` (config profile), `--dev` (HMR). `jac start` exits when stdin closes - any backgrounded/daemonized server must be launched with `< /dev/null` (systemd/containers do this for you; shell scripts and CI must do it explicitly). For prod, kill Swagger:

```toml
[plugins.scale.server]
docs_enabled = false          # disables /docs, /redoc, /openapi.json
suppress_health_check_logs = true
```

**Backends:** SQLite at `.jac/data/` by default (graph + users; zero setup). Set `MONGODB_URI` (or `[plugins.scale.database] mongodb_uri`) for MongoDB and `REDIS_URL` for the Redis cache tier - required for multi-replica deployments. Config precedence everywhere: **env var > jac.toml > default**.

**Secrets** ship to pods via `[plugins.scale.secrets]` with `${ENV_VAR}` interpolation, resolved from your local env at deploy time and injected as a k8s Secret:

```toml
[plugins.scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
JWT_SECRET = "${JWT_SECRET}"        # see jac-sv-auth: the default JWT secret MUST be changed
```

## Kubernetes (`--scale`)

```bash
jac start app.jac --scale --dry-run   # lint config + print the plan; nothing applied. Use before every deploy.
jac start app.jac --scale             # dev deploy (no image build)
jac start app.jac --scale --build     # build+push Docker image (DOCKER_USERNAME/PASSWORD in .env), then deploy
jac status app.jac                    # component health table (app, Mongo, Redis, Grafana)
jac destroy app.jac                   # DELETES THE NAMESPACE INCLUDING PERSISTENT VOLUMES - all data is lost
```

```toml
[plugins.scale.kubernetes]
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

HTTPS is a **two-step**: deploy plain (`--scale`), point your domain's CNAME at the printed NLB hostname, then `jac start app.jac --scale --enable-tls` (cert-manager + Let's Encrypt, patches the live ingress - no redeploy). Mongo/Redis are auto-provisioned as StatefulSets; everything is labeled `managed=jac-scale`. Multi-service stacks: `jac-sv-microservices`.

## Webhooks (external callbacks in)

`@restspec(protocol=APIProtocol.WEBHOOK)` on a walker serves it at **`POST /webhook/<name>` only** (not `/walker/<name>`). Auth is API-key + HMAC, not JWT: create a key with `POST /api-key/create` (JWT-authed; `DELETE /api-key/{id}` revokes), then callers send `X-API-Key` plus `X-Webhook-Signature` = HMAC-SHA256 of the raw body keyed by the API key:

```bash
SIG=$(echo -n "$PAYLOAD" | openssl dgst -sha256 -hmac "$API_KEY" | cut -d' ' -f2)
curl -X POST $HOST/webhook/PaymentReceived -H "X-API-Key: $API_KEY" \
  -H "X-Webhook-Signature: $SIG" -H "Content-Type: application/json" -d "$PAYLOAD"
```

Keys are durable only with MongoDB configured - in-memory otherwise (a restart invalidates them all).

## WebSockets

`@restspec(protocol=APIProtocol.WEBSOCKET)` on an **`async walker`** serves `ws://host/ws/<name>`; each JSON message maps onto `has` fields, `report` values stream back. `:pub` = anonymous; without it, JWT. `broadcast=True` sends each response to ALL connected clients of that walker (chat/live-update fan-out).

## Files / S3

`store()` (ambient) is local-disk by default; flip to S3 in config - same code:

```toml
[plugins.scale.storage]
type = "s3"
bucket = "my-app-uploads"      # region, prefix, endpoint_url (non-AWS), public_read
```

`storage.get_url(path, expires_in=600)` returns a presigned URL on private S3 (permanent public URL if `public_read = true`, `file://` locally). Upload endpoints: `jac-sv-endpoints`.

## Observability and coordination

- `/health`, `/ready` - built-in probe endpoints; `/healthz` variants also exist.
- **Prometheus**: `[plugins.scale.monitoring] enabled = true` registers `/metrics` - **admin-token-gated** (403 otherwise); `walker_metrics = true` adds per-walker timing. Visual dashboard in the admin portal.
- **CORS**: single-process `jac start` hardwires `allow_origins=['*']` - no knob. Only the microservice gateway has configurable CORS (`[plugins.scale.microservices.cors]`). Don't ship a `:pub`-heavy API assuming you can lock origins down in single-process mode.
- **Distributed locks** (Redis only - raises `NotImplementedError` on Mongo): `kvstore(db_name=..., db_type='redis')` exposes `set_nx_with_ttl(key, value, ttl)` (atomic acquire, TTL mandatory) + `delete_if_equals(key, fence)` (compare-and-delete release). `threading.Lock` only serializes one process - it silently fails to protect anything once you have 2+ replicas.

## Pitfalls

- **`jac destroy` deletes data.** PVCs included. There is a y/N prompt; there is no undo.
- `--dry-run` catches config errors (HPA min>max, bad resource units like `500MB` vs `500Mi`) in ~1s vs finding out after a 5-10 minute build-push-deploy.
- HPA does nothing without `cpu_request` - Kubernetes can't compute a utilization %.
- Multi-replica + SQLite = corruption/confusion. Going past one replica requires `MONGODB_URI` (+ Redis for cache/locks).
- Schema edits in prod: never `rm -rf .jac/data/` - use the alias/quarantine machinery (`jac db ...`) in `jac-sv-persistence`.
- Webhook walkers don't answer on `/walker/<name>`, and regular walkers don't answer on `/webhook/<name>` - a 404 there is routing, not registration.
