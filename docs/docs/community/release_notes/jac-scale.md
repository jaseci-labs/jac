# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-scale 0.2.26 (Latest Release)

### New Features

- **Cross-pod cache consistency**: in multi-pod deployments, a write on one pod now evicts the affected node from sibling pods' in-memory caches over Redis, so they no longer serve stale graph reads.
- **Lazy read-repair and quarantine auto-retry in the Mongo backend**: Documents whose archetypes declare `__jac_schema__` drift rules are repaired on load and the upgraded form is written back with compare-and-set on the stored fingerprint, so concurrent writers on older app versions safely win and the document repairs again on its next read. Quarantined documents are now stamped with a machine-readable `reason_code` (`CLASS_MISSING`, `FIELD_RECONSTRUCT`, `DESER_ERROR`, `CASCADE`), and at backend startup a capped auto-retry re-attempts the quarantined docs the new deploy plausibly fixed (newly registered classes, aliases, or drift rules) ("deploy the fix and the data heals itself"), with `jac db recover-all` remaining as the manual override.
- **Feature: In-admin "Signal self-check" health card**: A new **Operations -> Self-Check** page in the jac-scale admin dashboard answers "why is observability/health broken?" without a kubeconfig. `GET /admin/ops/health` returns, per signal (traces, logs, metrics, mongo, redis, admin API), a `{status, chain[]}` causal chain where each step is `{name, ok, detail}`, evaluated **short-circuit** so the first red link IS the diagnosis - e.g. "jac-scale[tracing] importable (HAS_OTEL): no" pinpoints a missing tracing extra that makes the Traces page return `count:0`, and "Mongo ping reachable: failed" explains an `/admin/login` returning SPA HTML instead of JSON. Every check is an in-process read (`HAS_OTEL`, config, `self.server`) or a best-effort ~2s backend probe wrapped in try/except, so a dead Tempo/Loki/Prometheus/Mongo/Redis renders a red row, never a 500. The page renders each chain as a vertical green-check / red-x stepper with the first failing step highlighted. Registered on both the monolith server and the microservice gateway. No Kubernetes API access and no RBAC.

### Bug Fixes

- **Fix: No duplicate startup banner in dev mode**: The jac-scale server  no longer prints its own banner (which advertised the API port as the URL to open) when a dev client is running; the main banner shows the correct URLs.

## jac-scale 0.2.25

### Breaking Changes

- **jac-scale: webhook security hardening**: Webhook auth and signing were reworked. The HMAC signature is now computed over `"<timestamp>." + body` using an independent per-key `signing_secret` returned once from `/api-key/create` (no longer the API key itself), and an `X-Webhook-Timestamp` header is required with replay-tolerance enforcement. API keys are now keyed by stable `user_id`, support an optional `allowed_walkers` scope, fail closed on unknown/revoked keys, and api_key tokens can no longer be used as user sessions. Adds request body size limits, an optional per-key rate limit, generic error responses (no traceback leakage), and per-request audit logging. Existing webhook integrations must update to the new signing scheme.

### New Features

- **Feature: distributed tracing now covers the memory hierarchy**. Each request's trace previously stopped at the HTTP hop boundary - one opaque span per service. Now the Redis (L2 cache) and MongoDB (L3 persistence) backend operations are traced as child spans nested under the request, so a trace shows which tier and which database call was slow, not just which service. Spans carry the backend (`redis`/`mongodb`), tier (L2/L3), and operation (get/put/batch_get/commit/sync). Off unless tracing is enabled (`[plugins.scale.microservices.tracing] enabled = true`); a no-op otherwise. Covered by `test_memory_tracing.jac`.
- **Feature: Build identity stamped into microservice images**: Auto-built images now carry a `JAC_BUILD_SHA` env (12-char git commit SHA, suffixed `-dirty` when the build tree has uncommitted changes, baked in via a `--build-arg` on the shipped/embedded `Dockerfile.microservice`), and every pod exposes a `JAC_IMAGE_REF` env with its fully-resolved image ref including the content-addressed tag suffix. Together these let an in-pod self-check report "running build X" and answer "did my deploy actually update?" with zero RBAC. The build-identity layer is stamped last so a changing SHA only rebuilds that tiny build-time layer (note: because K-29's content-addressed tag is derived from the image digest, a new commit still forces a rollout - build identity is coupled to the commit, not just byte-content). (K-29's content-addressed image tag, which forces a rolling update and defeats the node image cache on rebuild, was already in place via `_retag_with_content_id`.)
- **Per-domain TLS on a shared nginx ingress**. In `shared_ingress` mode the Ingress now gets a `spec.tls` block (`{app_name}-tls` secret for the configured domain) when `shared_ingress_tls` is set on an nginx class, so cert-manager's ingress-shim issues a per-domain Let's Encrypt cert. The issuer is supplied by the caller via `shared_ingress_annotations` (`cert-manager.io/cluster-issuer`). Gated on the nginx class, so non-nginx shared controllers (AWS ALB + ACM) that terminate TLS at the load balancer are unaffected. This lets one shared nginx controller front many domains, each with its own cert.
- **`root.shared` resolves in jac-scale deployments**: The server maps the guest account to its root at startup so walkers can address the public graph via `root.shared`. (jaseci-labs/jaseci#6554)
- **Pinned-public mode for the graph visualizer**. The `/graph` page accepts a `?public=1` query parameter that always shows the public (super root) graph, ignoring any stored session token, so embeds are unaffected by a logged-in session on the same origin.
- **`GET /__build_status` on the jac-scale server**: Serves the hot reloader's build health as a documented endpoint.

### Bug Fixes

- **Fix: creating graph nodes is now crash-safe with MongoDB persistence (#6488)**: if a server was killed or restarted (deploy, OOM, pod eviction) just after a `root ++> Node()` connect, the graph could be left with an edge pointing at a node that was never saved, and every later traversal across it failed with `NodeAnchor [...] is not a valid reference!`. New nodes and their edges are now persisted in a crash-safe order, so an interrupted write can no longer leave a dangling edge that breaks traversal. (jaseci-labs/jaseci#6488)

### Refactors

- **Refactor: Scheduler hardening**: Dynamic jobs run as the creating user (stable `user_id`) while static jobs continue running as `__system__`; system-role accounts are no longer loginable over HTTP; `/jobs` endpoints enforce per-job ownership on `GET`/`PUT`/`DELETE` and support `limit`/`offset`/`trigger`/`created_by` pagination; jobs are persisted before scheduling with MongoDB authoritative when configured; cron expressions are validated via `CronTrigger.from_crontab`; thread-pool size, misfire grace, and shutdown drain timeout are configurable under `[plugins.scale.scheduler]`; scheduled jobs record `last_run_at`, `last_status`, `last_error`, and `run_count`; graceful shutdown drains in-flight tasks on `SIGTERM`.
- **Admin portal UI drops redundant `cl` markers**: Its `.cl.jac` sources rely on the file extension for client context. (jaseci-labs/jaseci#6557)

## jac-scale 0.2.24

### New Features

- **Feature: distributed tracing for microservice mode**. Adds OpenTelemetry tracing across the gateway and services: each request opens a span on every hop, the spans are linked into one trace, and that trace shares the same id as the request's log lines so you can pivot between logs and traces. Off by default - enable with `[plugins.scale.microservices.tracing] enabled = true` (optional `endpoint` and `sample_ratio`). OpenTelemetry is an optional dependency (`jac-scale[tracing]`); without it tracing is a no-op and nothing changes. Covered by `test_tracing.jac`. The trace-collection backend and the in-admin Traces page follow in separate PRs.
- **Feature: distributed tracing - trace storage and collection**. The cluster side of distributed tracing, on top of the app-side OpenTelemetry SDK. Deploys Tempo as an in-cluster trace store and turns the existing Grafana Alloy log agent into an OpenTelemetry collector that forwards spans to it, adds a Tempo datasource to Grafana (so you can jump from a span to its logs by trace id), and points every pod at the in-cluster collector. Enable per app with `[plugins.scale.microservices.tracing] enabled = true`. Logs-only, traces-only, and both are all supported, and teardown removes the trace store cleanly. Covered by `test_tempo_collection.jac`. The in-admin Traces page follows in a separate PR.
- **Feature: distributed tracing - in-admin Traces page**. Adds a Distributed Traces page to the jac-scale admin, completing the tracing feature. Under Monitoring you get a search bar (filter by service, errors only, minimum duration, and time window), a list of matching traces, and a flame-graph waterfall for the selected trace (one bar per span, sized by duration and nested by parent). It reads traces straight from the in-cluster Tempo store through admin-auth-gated endpoints, so no Grafana login is needed, and because a span and its log lines share the same trace id you can pivot between the Logs and Traces pages. Works in both monolith and microservice mode. Covered by `test_traces_admin.jac`.
- **jac-scale server serves a conventionally-named client page at `/`**: Matching the core server, when `[serve] base_route_app` is unset the jac-scale (uvicorn) server serves a conventionally-named client page (`app`, `index`, `main`, `home`, or `root`) at the root path; otherwise the root path stays the JSON API index.
- **Perf: Use cached `typecache` module for field-type resolution in MongoBackend**: Replaced `Serializer._get_field_types` calls with the new cached `get_field_types` from `typecache`, matching the jaclang-side optimization.
- **Feature: deliver SSO tokens to native/desktop loopback origins (RFC 8252)**: native/desktop "thin client" apps can now pass their own `http://127.0.0.1:<port>` callback through the OAuth `state` parameter so the token is redirected back to the origin that initiated the flow. The requested callback is validated with a new `is_safe_loopback_redirect` helper, honored only when the scheme is http/https and the host resolves to a loopback address (`127.0.0.1`/`localhost`/`::1`), otherwise it falls back to the server-configured `client_auth_callback_url`, guarding against `state` being abused as an open redirect to exfiltrate the token. As part of this work, the FastAPI route generator now `repr()`-escapes parameter descriptions when emitting endpoint source, so descriptions containing quotes, apostrophes, backslashes, or newlines no longer produce an `unterminated string literal` `SyntaxError` at server startup.
- **Feature: redesigned admin dashboard**. The in-admin portal gets a clean, modern flat redesign: a sidebar layout, a light/dark theme toggle, and consistent lucide iconography across the Users, SSO, Metrics, Traces, and Logs pages. Login and reset screens are restyled to match. UI-only - no change to endpoints or behavior.

### Bug Fixes

- **Fix: jac-scale CLI output no longer prints raw Rich markup**: scale plan, microservice orchestrator banners, deployment status, and serve status lines use semantic `style=` roles and console helpers instead of inline `[red]`/`[cyan]`/`[bold]` tags.
- **Fix: monolith deploys now get a meaningful `service` field, populated service-filter dropdown, and a working pod regex in the admin Logs UI**. The M-14.b structured-logging stack was reachable in monolith mode (the FastAPI middleware installs the JSON formatter for every request, monolith or microservice), but three monolith-specific blind spots made the in-admin Logs UI feel half-broken: (1) `_SVC_NAME` read only `JAC_SV_NAME` which K-track only injects on microservice pods, so every monolith line landed with `"service":"unknown"`; (2) `_microservice_services` returned `["gateway"] + routes.keys()`, which on a monolith is just `["gateway"]` (one bogus dropdown entry); (3) `_service_to_pod_regex` produced `<svc>-deployment-.*`, but monolith pods are named `<app_name>-<rs>-<rand>` with no `-deployment-` infix, so filtering by service silently returned zero lines. Fix: `_SVC_NAME` now falls back through `JAC_SV_NAME -> K8S_APP_NAME -> "unknown"`; `_microservice_services` returns `[app_name]` when the routes table is empty; and `_service_to_pod_regex` drops the `-deployment-` infix in monolith mode. Microservice deploys are unaffected (existing code path runs verbatim whenever the routes table is non-empty). Regression tests in `test_admin_logs.jac` exercise both modes through pure helpers (`_services_for_mode`, `_service_to_pod_regex_for_mode`).
- **Fix: microservice gateway OOM-killed at its 1Gi memory limit, CrashLoopBackOff'ing the K8s deploy**. The gateway pod runs `jac scale gateway` and loads the admin portal, admin-UI SPA, LLM-telemetry, log wiring and runtime OpenAPI aggregation that plain service pods (`jac start <name>.jac`) never touch, so its startup working set had grown up to the shared 1Gi service default in `manifest_builder._build_resources` and exceeded it - the pod terminated with `OOMKilled` / exit 137 and never finished its rollout. The gateway role now defaults to a 2Gi memory limit (service pods unchanged at 1Gi); the limit is still overridable per-service and via `[plugins.scale.kubernetes]`. The `k8s_e2e` fixture pins the gateway to 2Gi explicitly so a default regression can't silently reintroduce the crash loop, and `Dockerfile.microservice.exp` pins `python:3.12-slim` by digest plus runs `pip freeze` so unpinned-dependency drift is recorded in the build log.

### Refactors

- **Refactor: introduce `Autoscaler` abstraction and route HPA paths through `AutoscalerFactory`**: Adds an `Autoscaler` base class with `AutoscalerSpec` / `Trigger` models, an `HPAAutoscaler` engine wrapping the existing HPA logic, and an `AutoscalerFactory` with a plugin registry. Both the monolith and microservice HPA deploy paths now resolve the engine via `AutoscalerFactory.create(autoscaler_engine, ...)`. A new `autoscaler_engine` field (default `"hpa"`) is added to `KubernetesConfig`; existing `jac.toml` files require no changes. **Operators upgrading will see two minor changes to existing HPAs:** the `metadata` block now includes `namespace` and an `app` label alongside the existing `managed: jac-scale` label; and the update path switches from a single `replace` (PUT) to a `read` + `patch` (GET + PATCH). Both changes are non-breaking.

## jac-scale 0.2.23

### Bug Fixes

- **Fix: LLM telemetry and bare `/jobs` endpoints were missing on the microservice gateway**. Two endpoint groups the monolith registers in `serve.core`'s `_register_endpoints` were not reachable through the microservice gateway, so requests that work in monolith mode 404'd (or returned the SPA `index.html` instead of JSON). (1) The gateway inherited `JacAPIServerAdmin` + `JacAPIServerLogs` and called `register_admin_endpoints` + `register_logs_endpoints` in `_install_admin_api`, but never inherited `JacAPIServerLLMTelemetry` nor called `register_llm_telemetry_endpoints` - so `/admin/llm/telemetry/*` (the in-admin LLM metrics page) was never materialized as FastAPI routes and the `/admin/*` dispatcher's `call_next` hit the SPA catchall. The gateway now wires the telemetry registrar alongside admin + logs. (2) The scheduler registers a bare `/jobs` (POST create, GET list) alongside `/jobs/{job_id}`, but the gateway's builtin passthrough only matched the `/jobs/` prefix and `"/jobs".startswith("/jobs/")` is False, so list/create 404'd while `/jobs/{id}` worked; `/jobs` is now in `_BUILTIN_EXACT`, mirroring how `/graph` handles its own bare form. Regression guards added in `test_gateway.jac`.

## jac-scale 0.2.22

### New Features

- **jac-scale: add shared ingress support for Kubernetes deployments**: Added `shared_ingress` and `shared_ingress_class` config options. When `shared_ingress = true`, jac-scale skips deploying a dedicated NGINX controller and instead attaches the app's Ingress routing rules to a pre-existing shared controller (default class `nginx`). The Ingress host field is set immediately at deploy time (not deferred to `--enable-tls`) so the shared controller can differentiate apps across namespaces by hostname. `domain` is required in this mode and is validated before any cluster resources are created. On local clusters the NodePort availability check is skipped. The post-deploy health check runs against the domain directly (`http://{domain}{health_check_path}`) instead of `localhost:30080`; a failure is reported as a warning rather than an error since the DNS record may not have propagated yet (A record on local clusters, CNAME on AWS). On destroy, only the Ingress rules are removed; the shared controller is left untouched.
- **jac-scale: support non-NGINX shared ingress controllers**: Added `shared_ingress_annotations` and `shared_ingress_tls` to `KubernetesConfig`. In shared-ingress mode, NGINX-specific annotations are now emitted only when `shared_ingress_class` is `nginx`, and caller-supplied annotations are merged onto the Ingress metadata (caller values take precedence). This lets annotation-driven controllers such as the AWS Load Balancer Controller (ALB), Traefik, and GKE be used without baking any cloud-specific values into jac-scale, for example attaching apps to one shared ALB via `alb.ingress.kubernetes.io/group.name` with TLS from an ACM certificate. `shared_ingress_tls` makes the reported service URL use `https` for controllers that terminate TLS out-of-band (no `spec.tls` on the Ingress). Builds on the shared-ingress support in #6012.
- **Fix: in-admin Logs UI now shows newest-first with cursor pagination**. The listing was sorted ascending and capped at 200 lines with no way to reach older entries, so the React panel showed only the oldest 200 lines in the window and stopped (the bottom looked like a hard cap rather than the end of the page). The `/admin/logs` endpoint now sorts newest-first, accepts a `before=<nanosecond ts>` cursor, and returns `next_before` in the response; the LogsPage renders a "Load older" button that appends the next page beneath the current one. The trace-detail endpoint (`/admin/logs/trace/{id}`) still returns lines in causal (oldest-first) order so the trace journey side panel reads top-down.

### Bug Fixes

- **Fix: in-admin Logs UI on the microservice gateway returned HTML / hit a bogus Loki URL**. Two pieces of the M-14/A-05 work were dropped during PR-slicing and are restored here. (1) The microservice gateway lost its `JacAPIServerLogs` inheritance and the `register_logs_endpoints()` call in `_install_admin_api`: A-05c (#6153) correctly dropped the logs wiring as out-of-scope, but A-05a (#6211) only re-added it to the monolith server (`serve.jac`), not the gateway - so `/admin/logs?…` fell through to the SPA catchall and returned `index.html` (200 HTML), leaving the React Logs page spinning on "Loading logs...". (2) `_loki_base_url` lost its `K8S_APP_NAME` env-var resolution + `os.path.expandvars` handling - the manifest_builder half of that fix shipped in #6152 but the consumer half never made it into A-05a, so on K8s the URL resolved to a literal `http://${K8S_APP_NAME}-loki-service:3100` and DNS-failed. Both restore the EKS-validated state; a `test_gateway.jac` regression guard asserts the gateway exposes both `register_admin_endpoints` + `register_logs_endpoints`.
- **Fix: Redis L2 cache served stale empty edge list after edge writes**: After any edge write, Redis could return `data.edges=[]` for a node while MongoDB held the correct merged list, causing edge traversal (`[-->(?:Type)]`) to silently return nothing & breaking find-or-create logic. `_put_node_atomic` now reads back the authoritative merged edge set from MongoDB and invalidates the Redis entry instead of re-writing the un-merged in-memory snapshot, so the next read re-hydrates the correct edge list from MongoDB. Cross-pod L1 eviction is tracked separately in #6313.
- **Fix: uvicorn / FastAPI access logs bypassed M-14.b's JSON formatter, blanking trace_id on the in-admin Logs UI**. `install_structured_logging` configured only the root logger, but uvicorn ships its own logger hierarchy (`uvicorn`, `uvicorn.access`, `uvicorn.error`, `fastapi`) with their own handlers and `propagate=False` - so request access lines (`INFO:     192.168.x.y:p - "GET /healthz HTTP/1.1" 200 OK`) stayed raw text and never reached the JSON formatter. Result: the bulk of pod logs on Loki had no `service` / `level` / `trace_id` fields and the trace-journey side panel in `/admin/logs` looked empty even for lines emitted during a real request. Fix: `install_structured_logging` now clears those four loggers' handlers and flips `propagate=True` so every line (app code, uvicorn access, uvicorn error, FastAPI) lands on the root handler in the same JSON shape. Regression guard added in `test_log_emit.jac`.
- **Fix: clicking a trace in the in-admin Logs UI returned `Log backend unavailable` because the generated LogQL contained a bare `\[` Loki's parser rejects as `invalid char escape`**. `_build_logql`'s trace-id pipeline emitted `\[trace=...\]` inside the line-filter string literal; Go's `strconv.Unquote` (used by Loki's LogQL parser) only allows the escapes `\\ \" \n \r \t` etc. and bails on `\[`. Brackets now render as `\\[` / `\\]` in the LogQL string so unescaping yields `\[` / `\]` for the regex engine. Also fixed an unrelated replace-order bug in the `search` filter where backslashes were doubled *after* quotes had been escaped, re-doubling the just-inserted escapes and delivering stray backslashes to Loki's substring matcher. Regression tests in `test_admin_logs.jac`.

### Refactors

- **Refactor: migrate jac-scale modules to updated jac runtime structure**: Reorganized jac-scale package internals and tests to align with the latest compiler/runtime and plugin layout, including updated optional dependency wiring and microservice/admin module paths.
- **Refactor: One-line JSX returns across the admin UI**: Applied the updated formatter, collapsing short `return <Element/>;` statements onto a single line across the `jac-scale` admin UI components, contexts, and pages.

## jac-scale 0.2.21

### New Features

- **Feature: centralised log aggregation in the K8s monitoring stack (Loki + Grafana Alloy)**. Opt in for monolith deploys via `[plugins.scale.kubernetes].loki_enabled = true` and for microservice deploys via `[plugins.scale.microservices.logs].enabled = true`. Brings up a Loki StatefulSet (filesystem-backed, single-binary mode) plus a Grafana Alloy v1.6.0 DaemonSet (River-syntax config) that tails `/var/log/pods/*` via `discovery.kubernetes` + `loki.source.file` and ships to Loki. Grafana gets a **Pod Logs** dashboard. Alloy supersedes Promtail, which went EOL on 2026-03-02. Alloy's `--storage.path` is set to `/tmp/alloy` to sidestep a v1.6 remotecfg quirk where mkdir under a mounted emptyDir fails with EACCES. Microservice mode reuses the same `MonitoringDeployer` so a single `jac start --scale` deploy with `logs.enabled = true` brings up Prometheus + Grafana + Loki + Alloy in one shot. (M-14.a)
- **Feature: structured-JSON log emission across microservice mode (M-14.b)**. Apps now emit one JSON document per log line on stdout instead of plain text, and Alloy's log pipeline parses the JSON, promotes bounded-cardinality fields (`service`, `level`) to Loki labels, and keeps high-cardinality `trace_id` as a queryable JSON field. Switches the operational workflow from `kubectl logs ... | grep trace=abc12345` to typed LogQL queries like `{namespace="X"} | json | trace_id="abc12345"`, `{namespace="X"} | json | service="gateway", level=~"ERROR|WARNING"`. New `install_structured_logging()` helper in `jac_scale.microservices.runtime.log_emit` wires a JSON formatter onto the root logger; the gateway calls it at `setup()` time and `JFastApiServer.request_context_middleware` calls it once per process so every microservice emits JSON without per-app boilerplate. `TraceIdLogFilter` now sets `record.trace_id` as a first-class field (keeping the `[trace=...]` msg prefix for plain-text consumers). Builds on M-14.a's Loki + Alloy stack (#6155); enables A-05a's in-admin Logs UI.
- **Feature: in-admin Pod Logs UI (A-05a)**. The admin React bundle (mounted at `/admin/` on the microservice gateway and the monolith server alike) gains a Monitor -> Logs tab that queries Loki directly through three new admin-auth-gated JSON endpoints (`/admin/logs/services`, `/admin/logs?...`, `/admin/logs/trace/<id>`). Replaces the "Grafana iframe" workflow for the common case - operators stay inside the admin UI, get a focused service+level+time filter row that auto-applies, a live-tail toggle, and a click-to-open side drawer per line that shows the line metadata + the **whole trace journey** (every other log line sharing the same `trace_id` across all services, in causal order). Builds on M-14.a's Loki + Alloy backend (#6155) and M-14.b's structured-JSON shape (#6210) so `service` / `level` come from Loki labels and `trace_id` from the JSON body. Microservice gateway gets the same admin-API plumbing the monolith server already has by adding `JacAPIServerLogs` to its inheritance.

### Bug Fixes

- **Fix: `jac start --scale` no longer wipes TLS configuration on redeployment**: `_deploy_ingress_resource` was calling `replace_namespaced_ingress` (a full PUT) on every deploy, silently stripping the `spec.tls` block, rule host, and TLS annotations (`cert-manager.io/issuer`, `ssl-redirect`, `force-ssl-redirect`) that `--enable-tls` had previously written. After any redeployment following TLS enablement, the app served the controller's default self-signed certificate on HTTPS while the cert-manager `Certificate` and TLS secret remained intact, masking the issue. The fix switches to `patch_namespaced_ingress` and removes `spec.tls` and `spec.rules[*].host` from the patch body entirely; fields jac-scale does not own are simply never sent, so the API server leaves them untouched. The same change applies to the RedisInsight Ingress. No read-before-write is required and there are no fields to carry forward.

## jac-scale 0.2.20

### New Features

- Added `suppress_health_check_logs` option under `[plugins.scale.server]` in `jac.toml`. When set to `true`, health-check endpoint access log entries (`/docs`, `/`, `/openapi.json`, `/health`, `/healthz`, `/healthz/ready`, `/healthz/live`) are suppressed from CLI output and Kubernetes pod logs to reduce noise. Defaults to `false` (logs shown by default).
- **Add: identity management, email verification, password reset, and pluggable emailer**: Five new endpoints under `/user/*` (`add-identity`, `send-verification`, `verify-identity`, `forgot-password`, `reset-password`) plus an `Emailer` abstraction that lets any backend (built-in SMTP, SendGrid, Mailgun, etc.) be plugged in via `jac.toml`. `add-identity` only attaches identities; `send-verification` dispatches the email and is retryable. Identity uniqueness is enforced atomically at the storage layer (Mongo unique sparse index, SQLite PK with transactional rollback), so concurrent `add-identity` requests for the same value resolve to a clean 409 instead of a race. Tokens are SHA256-hashed at rest, single-use, and TTL-bounded; persisted in MongoDB (TTL index) when configured, in-memory otherwise. `forgot-password` and `send-verification` are rate-limited (per recipient email and per authenticated user respectively) with budgets configurable under `[plugins.scale.auth]` (`forgot_password_rate_per_hour`, `forgot_password_burst`, `send_verification_rate_per_hour`, `send_verification_burst`); `send-verification` returns `429 RATE_LIMITED` with `retry_after_seconds` on rejection, while `forgot-password` keeps the 200 envelope to preserve the existence-leak guarantee. Structured audit events for both flows are routed through a dedicated `jac_scale.audit` logger so ops can ship them to file / syslog / ELK independently of regular logs. See [Identity Management & Password Reset](../../reference/plugins/jac-scale.md#identity-management--password-reset) and [Emailer](../../reference/plugins/jac-scale.md#emailer) for full docs.
- **Feature: S3 Storage Backend**: Implemented a robust S3 storage provider using `boto3`, supporting AWS S3, MinIO, and Cloudflare R2 with full file lifecycle support.
- **Feature: Configuration-Driven Storage**: Added `StorageFactory` support for dynamic switching between local and S3 backends via `jac.toml` or environment variables (e.g., `JAC_STORAGE_TYPE=s3`).
- **Feature: AWS Optional Dependency**: Added `aws` and `test` optional dependency groups to `pyproject.toml` to manage `boto3` and `moto` requirements.
- **Refactor: Cluster provider detection now uses the Strategy pattern**: Previously, cloud-provider-specific behaviour (service type, port validation, Prometheus scrape port, ingress controller service, NLB wait) was scattered across `kubernetes_target.jac`, `monitoring.jac`, and `ingress.jac` as repeated `if cluster_env == 'aws'` string comparisons. These have been replaced by a `ClusterProvider` base class with concrete `AWSProvider` and `LocalProvider` subclasses. A new `get_cluster_provider()` function detects the cluster at deploy time and returns the appropriate instance. Adding support for a new cloud provider (e.g. GCP, DigitalOcean) now requires only a single new subclass - no changes to deploy, monitoring, or ingress logic.
- **Feature: `jac start --scale --dry-run` preview with lint validation**: A new dry-run mode renders the K8s deployment plan as a per-service card view (image, replicas, HPA bounds, cpu/mem resources, route, PDB, mounts) instead of dumping raw YAML. Inline lint diagnostics catch config bugs the manifest builder won't reject - HPA `min > max`, `cpu_request > cpu_limit`, invalid resource units, missing images, PDB drain-deadlocks, etc. Exit code 2 if errors are found. The raw multi-doc YAML stream is gated behind `--show-yaml` for `kubectl diff` workflows.
- **`MongoBackend` native pushdown via capabilities**: declares `{'type_pushdown', 'field_pushdown', 'id_in', 'slice'}` and implements `execute_plan` to translate a `QueryPlan` into a single `collection.find(filter)` + `skip`/`limit`. `ensure_indexes()` (idempotent, called from `postinit`) creates the `(arch_type, type)` compound index plus a descending `updated_at` index so type-based queries IXSCAN instead of COLLSCAN. `get_roots` now uses the indexed filter rather than scanning the whole collection.
- **Feature: K8S_APP_NAME and K8S_NAMESPACE env vars on every K-track pod**: In-pod code (Loki URL builder, log shippers, future observability helpers) had no reliable way to learn the deployed app name. `jac.toml` templating like `app_name = "${K8S_APP_NAME}"` is taken literally because the config loader doesn't expand env-var placeholders, and stock K-track pods had no upstream env var carrying the app name. `MicroserviceManifestBuilder._build_env` now emits `K8S_APP_NAME` and `K8S_NAMESPACE` on every microservice container alongside the existing `JAC_SV_NAME` sentinel, sourced from `k8s_config` at deploy time. Matches the convention already in place for `MONGODB_URI` / `REDIS_URL` where in-pod code reads from `os.environ` instead of re-parsing `jac.toml`.
- **Feature: admin JSON endpoints (`/admin/login`, `/admin/me`, `/admin/users`, ...) on the microservice gateway**: Previously the static admin UI loaded on the microservice gateway but every `fetch()` from the React bundle fell through to the SPA fallback - so `POST /admin/login` returned `<!DOCTYPE html>` and React died with `Unexpected token '<'`. `MicroserviceGateway` now inherits `JacAPIServerAdmin` and gains an `_install_admin_api()` step inside `setup()` that wraps the gateway's existing FastAPI app in a `JFastApiServer`, wires up `UserManager` + `ApiKeyManager`, registers the admin endpoints via the inherited `register_admin_endpoints()`, and calls `create_server()` to materialize the queued JEndPoints as real FastAPI routes. The dispatcher middleware grew a `/admin*` branch that delegates to FastAPI's router via `call_next` when the API is installed and falls back to the static `handle_admin` path otherwise. Partial-install failures (Mongo unreachable, etc.) reset `self.server = None` so the static-UI fallback stays reachable instead of routing into an empty FastAPI router. `bootstrap_admin_ui` also gained an editable-install fallback: when `jac-scale/admin/_dist/` is missing (because `pip install -e` skips the release pipeline that pre-builds the bundle) it invokes the inherited `build_admin_client()` to run `jac build main.jac` in `admin/ui/`. Drops the need for downstream consumers to add their own `RUN jac run scripts/build_admin_ui.jac` step.

### Bug Fixes

- **Fix: `recover_all` now processes nodes before edges, and warns when a re-link target is missing**: Quarantine recovery previously iterated in undefined DB order -- if an `EdgeAnchor` was restored before its connected `NodeAnchor`, the re-link step silently no-oped and left `data.edges` empty even though both records were nominally recovered. The batch is now sorted so every `NodeAnchor` is written back first. Additionally, both the SQLite and Mongo backends now emit a `logger.warning` when a re-link target is not found (missing `else` branch in SQLite; discarded `matched_count` in Mongo), giving operators a clear signal when recovery is partial.
- **Fix: `_deploy_databases` signature mismatch in microservice provisioner**: #5840 dropped the `cluster_env` parameter from `KubernetesTarget._deploy_databases()` and updated the monolith call site but missed the microservice path in `database_provisioner.jac`, breaking every `jac start --scale --experimental` deploy with `takes 5 positional arguments but 6 were given`. Aligned the microservice call site to the new 4-arg signature.
- **Fix**: `jac-scale` plugin hooks (SSO, auth, `/healthz`, admin) now apply reliably when the module is imported outside the `jac` CLI, restoring SSO endpoints, the `/healthz` probe, and authenticated `/metrics`.
- **Fix: graph writes no longer silently lost on MongoDB deployments**: Every node update that involved an edge change (connecting a child node, adding an edge from a walker) was being silently discarded on MongoDB 6.x. The internal atomic edge-merge operation uses MongoDB's aggregation-pipeline `$set`, which rejects empty embedded documents with error 40180. Because the default access-control field (`access.roots.anchors`) always serialises as `{}`, every write through this path failed. The fix strips empty dictionaries from the serialised node data before it reaches MongoDB. Existing data does not need migration; the deserialiser restores empty dicts automatically on load.
- **Fix: `jac start --scale` no longer silently no-ops as a dry-run (#6115)**: removes the workaround in `plugin.jac` that read the underscored arg name to dodge the upstream phantom-key bug; with the registry + `HookContext.get_arg` fix landing in jaclang, either spelling resolves correctly. `jac start --scale` now reliably hits the deploy path; `jac start --scale --dry-run` reliably hits the plan path.
- **Fix: quarantine reason now tells you exactly what went wrong**: When a node is quarantined, the stored reason now distinguishes between a missing class ("class X unresolvable") and a bad field value ("archetype field deserialization failed: X"), so you know immediately whether to update your import paths or fix your stored data.
- **Fix: Stale Redis cache after cascade quarantine causes dangling edge errors**: After a node was quarantined and its connected edges were cascade-quarantined, pods that had previously cached the affected live nodes continued to serve stale entries with the orphaned edge IDs - even across restarts - causing `EdgeAnchor [<id>] is not a valid reference` on the next walker traversal. Redis is now correctly invalidated as part of the cascade.

### Refactors

- **Refactor: split `JacScaleUserManager.create_user` into a `UserManager`-contract overload + `create_user_with_identities`**: The base `UserManager` interface expects `create_user(username, password)`; jac-scale's identity-aware variant moves to a separate `create_user_with_identities(identities, credential, profile)` method, and `create_user(username, password)` is now a thin shim that delegates to it. Authenticate now mints the JWT inline so the result carries the `token` the contract expects.
- **Refactor: read base path via `Jac.get_base_path_dir()`**: Migrated to the new accessor; the prior `Jac.base_path_dir` class attribute has been removed.
- **Refactor: request middleware uses token-based context push/reset**: jfast_api's per-request context now uses `push_request_context` + `reset_request_context(token)` with an explicit `ctx.close()`, replacing the removed `set_request_context` / `clear_request_context` footgun pair.

## jac-scale 0.2.19

### Bug Fixes

- **Fix: Redis authentication and RedisInsight dashboard connectivity in K8s**: Refactored Redis configuration loading and ACL rule definitions, added username/password secrets to deployment tests, opened metrics endpoints for unauthenticated scraping, tuned liveness/readiness probe timeouts and failure thresholds, enabled gzip compression and improved HTML handling on the Redis Ingress, and configured RedisInsight to auto-accept the EULA with a provided encryption key so the dashboard connects out of the box.
- **jac-scale: fix blocking event-loop call in request middleware**: `request_context_middleware` was calling `ctx.set_user_root()` synchronously inside an `async def` handler, blocking the uvicorn event loop on every authenticated request. Switched to `await ctx.aset_user_root()` so the user-root anchor load goes through the non-blocking async Redis/MongoDB path.
- **Fix: cascade-quarantine dangling edges on schema drift**: When a `NodeAnchor`'s archetype becomes unresolvable (e.g. a node type is removed between deploys), `MongoBackend` now also quarantines every connected `EdgeAnchor` and strips those IDs from the source node's `data.edges`, preventing permanently corrupt traversal state. Recovery (`recover-all`) re-links edges back to their source node, fully restoring graph connectivity.
- **Fix: `_put_node_atomic` no longer clobbers archetype scalars from concurrent walkers**: Replaced the shallow `$mergeObjects` pipeline (which wholesale-replaced `data.archetype` on every commit) with per-field `data.archetype.<field>` dot-notation writes that only touch dirty fields. Concurrent walkers on separate pods can now safely write different scalar fields to the same node without reverting each other's changes. The atomic edge-merge guarantee from PR #5644 is fully preserved.
- **Fix: identity storage uses Jac-native `any`**: `identity_storage.jac` now imports the Jac `any` keyword instead of Python's `typing.Any`, clearing W1104 and cascading type errors across all storage methods.

## jac-scale 0.2.16

### New Features

- **Configurable MongoDB PVC Storage Size**: MongoDB persistent volume storage size is now configurable via `mongodb_storage_size` in `jac.toml` (default: `1Gi`). Increasing the size on redeploy is supported and automatically patched onto the existing PVC without affecting stored data. Decreasing the size is blocked with an explicit error to prevent data loss.
- **Add: streaming sv-to-sv RPC**: `def:pub` generator returns now stream yields to the caller as SSE (`text/event-stream` + `data: {json}` + `event: end` terminator; errors via `event: error`). The consumer side gets a Python generator that yields parsed event dicts; httpx connection lifecycle follows the generator. Retry/circuit-breaker applies to connect failures; in-flight streams are not retried. Includes fixes to jaclang `_finalize_call_response` (isgenerator check was on the wrong field) and a missing SSE framing wrapper in jac-scale's serve.
- **Add: configurable gateway-to-service forward timeout**: `[plugins.scale.microservices].http_forward_timeout` (float seconds, default 30), with per-service override at `[...services.NAME].http_forward_timeout`. Controls aiohttp timeout in `raw_forward` + `stream_forward`. Distinct from `rpc_timeout` (sv import httpx). `jac setup microservice` emits a reference block.
- **Add: K-track v1 - Kubernetes deploy for microservice mode**: New `KubernetesMicroserviceTarget(KubernetesTarget)` fans one image out to one Deployment + ClusterIP Service + HPA + PDB per `sv import`-discovered service, plus a gateway. Auto-selected by `_scale_pre_hook` when `[plugins.scale.microservices].enabled=true` + `--scale`. Pod-spec `JAC_SV_NAME` differentiates services from the gateway (`__gateway__`). Includes:
  - **K8s DNS adapter**: new `get_sv_registry` hookimpl detects K8s-in-cluster via `KUBERNETES_SERVICE_HOST` and returns `http://<svc>-service.<ns>.svc.cluster.local:<port>` URLs; gateway works unchanged in both local and K8s modes.
  - **Zero-downtime rolling deploys**: `RollingUpdate{maxSurge:1, maxUnavailable:0}` + `/healthz/ready` + `/healthz/live` (split so liveness doesn't trip on dependency degradation) + `terminationGracePeriodSeconds = drain_timeout_seconds + 5` + `preStop sleep 5` (bridges kube-proxy endpoint-propagation gap). Verified by the real-app e2e: zero non-2xx during gateway + service rolling restarts.
  - **HPA + PDB per service**: `autoscaling/v2 HPA` (default min=1, max=3, cpu_target=70%) and `policy/v1 PDB` (default `maxUnavailable=1`). Opt-out per-service with `hpa.enabled=false` / `pdb.enabled=false`.
  - **Per-service config layering**: `[plugins.scale.microservices.services.NAME]` (and `__gateway__` for the gateway) controls `replicas`, `cpu_request`/`cpu_limit`, `memory_request`/`memory_limit`, `env`, `image_tag` (canary), `rpc_timeout`, `http_forward_timeout`, `hpa.*`, `pdb.*`.
  - **Optional Ingress**: `[plugins.scale.microservices.ingress]` with `enabled`, `host`, `ingress_class_name`, `annotations`. Single Ingress -> gateway Service; HTTP only (TLS via cert-manager/ACM is deployment-specific). Controller-agnostic.
- **Add: auto-build + auto-distribute**: `jac start --scale` now builds + distributes the image automatically. New `_cluster_detect.jac` classifies the active kubeconfig context (minikube / k3d / kind / remote / unknown); `_image_build.jac` resolves the right Dockerfile (user override `<project>/Dockerfile.microservice` > shipped `<pkg>/scripts/Dockerfile.microservice` > embedded fallback) and dispatches build/distribute per cluster type (minikube docker-env, `k3d image import`, `kind load docker-image`, or `docker push` for remote). Activated only when `_JAC_SCALE_AUTO_BUILD=1` so existing tests bypass cluster-touching work. Builds the FE bundle (`jac build <client.entry>`) on the host before docker build so the gateway image contains `.jac/client/dist/`. Writes a `.dockerignore` to the build context to avoid 2GB+ context transfers.
- **Add: stateful microservices out of the box**: MongoDB + Redis auto-provisioned as StatefulSets (reusing the monolith K8s target's `_deploy_databases`) and `MONGODB_URI` / `REDIS_URL` env injected via `valueFrom: secretKeyRef` on every pod. Wait-for-DB init containers prevent crash-loops on first deploy. Opt-out via `[plugins.scale.kubernetes].mongodb_enabled=false` / `redis_enabled=false`.
- **Add: gateway sticky sessions for WebSocket**: gateway Service gets `sessionAffinity: ClientIP` (3-hour timeout) so WS reconnects land on the same pod. Service pods stay round-robin.
- **Add: cross-service shared volumes** (`[[plugins.scale.microservices.shared_volumes]]`): per-volume `services` list of pods that should mount the volume at `mount_path`. PVC mode (`size`, `access_mode`, `storage_class`) for cloud; hostPath mode (`host_path`) for single-node dev clusters. Use case: services that intentionally share filesystem state.
- **Add: K8s Secrets injection** (`[plugins.scale.secrets]`): values are jaclang-core-interpolated (`${VAR}` expanded) and applied as a K8s Secret; pods get the secrets via `envFrom: secretRef`.
- **Add: `service_account_name` config**: attach every pod to a pre-bound SA (apps that need cluster API access for sandbox-spawning / operator-style controllers).
- **Add: peer URL auto-injection**: every pod gets `JAC_SV_<PEER>_URL` env vars pointing at sibling Service DNS, so `sv import` dispatch works without depending on the runtime hookimpl populating the registry first.
- **Add: real-app e2e** (`jac-scale/scripts/k8s_microservice_real_e2e.sh`): builds an actual image, deploys via the microservice K8s pipeline, waits for rollout, exercises gateway + per-service routing + optional Ingress, then runs a zero-downtime rolling-restart assertion (hammer at 10 req/s during `kubectl rollout restart`, fail on non-2xx).
- **Fix: gateway `/healthz` no longer fans out to backends**: was in the builtin-passthrough exact-match set, returning 404 before any backend registered. Now direct-handled as a `/health` alias (matches K8s convention).
- **Fix: K8s-mode registry pre-marked HEALTHY**: `start_gateway_only` skips the orchestrator (K8s owns lifecycle), so registry entries used to stay REGISTERED forever and `handle_proxy` 503'd every request. Now pre-flipped to HEALTHY; transport errors from not-yet-Ready pods bubble naturally (kube-proxy only routes to Ready pods).
- **Fix: `get_microservices_config` returns the `ingress` block**: previously dropped silently so `ingress.enabled=true` had no effect.
- **UX: actionable errors** on the three most-common K8s deploy failures: missing kubeconfig + no in-cluster SA (re-raise with minikube/eks/gcloud guidance), unreachable API server (early `list_namespace` probe instead of failing mid-apply), empty routes (concrete `[plugins.scale.microservices.routes]` snippet instead of silent gateway-only deploy).
- **UX: clean exit on deploy fail**: pre-hook used to `raise` and fall through to the local-mode dev server; now prints a red message and sets `cancel_return_code=1`.
- **UX: fail loud on python_image fallback**: microservice pods used to silently CrashLoopBackOff with "jac: command not found" when the deploy fell through to `python:3.12-slim`. Now raises with concrete next-step guidance (opt-in via `_JAC_SCALE_GUARD_FALLBACK_IMAGE=1`).
- **Docs**: `microservices/docs.md` K8s section, `getting_started.md` (5-min walkthrough), updated `[plugins.scale.kubernetes]` reference.
- **Add: `PATCH /user/me` and stricter profile validation**: New `PATCH /user/me` endpoint merges supplied keys into the existing profile (preserving SSO data) and returns `UpdateProfileResponse`. Profile validation now runs as a Pydantic `AfterValidator`, so `POST /user/register` and `PATCH /user/me` return 422 on invalid input automatically. `sso` is reserved as a server-managed profile key, and the SSO callback defensively coerces `profile.sso` to `{}` when it isn't a dict, protecting users registered before reserved-key enforcement. `GET /user/me` now returns a typed `MeResponse` (with `exclude_none` preserving the original wire shape).
- **Add: kvstore distributed-lock primitives**: `Db` (returned by `kvstore(db_type="redis")`) gains `set_nx_with_ttl(key, value, ttl)` for atomic acquire (Redis `SET NX EX`) and `delete_if_equals(key, expected_value)` for fence-token release (Lua `if GET == expected then DEL`). Together these are the minimal building block for cross-pod mutexes, leader leases, and debounce windows, so apps no longer need to reach past the kvstore abstraction and pool their own redis-py clients to coordinate. MongoDB raises `NotImplementedError`, matching the existing pattern for `set_with_ttl` / `incr` / `expire`.
- **Feat: Event-streaming broker**: Adds an `EventStreamBroker` abstraction (`jac_scale.events.broker`) with `publish` / `@subscribe` / `consume` / `ack`, retry with DLQ, and replayable offsets via `start_from`. Ships with `LocalEventStream` (in-memory) and `RedisEventStream` (Redis Streams); selection is automatic based on whether a Redis URL resolves. Off by default; enable via `[plugins.scale.events]` in `jac.toml`.
- **Feature: walker-flavored sv-to-sv RPCs**: The `JacScalePlugin` overrides the new `sv_walker_call` hook so cross-service walker spawns benefit from the same machinery as `def:pub` calls: Authorization passthrough, `X-Trace-Id` propagation, exponential-backoff retry, per-service `rpc_timeout`, and a per-provider circuit breaker. Walker calls share the breaker with function calls (both signal provider liveness), so a tripped breaker protects either RPC kind.
- **jac-scale: Native async drivers for MongoDB and Redis**: `MongoBackend` overrides `aget`/`acommit` using PyMongo `AsyncMongoClient` (PyMongo >= 4.9) and `RedisBackend` overrides `aget`/`aput` using `redis.asyncio`, eliminating `asyncio.to_thread` overhead for L2/L3 reads under concurrent load. Both clients are held as process-level singletons via `_process_cache`, matching the pattern established for the sync clients. `ScaleTieredMemory.acommit` coordinates the async flush path.
- **Feat: MongoBackend / RedisBackend slice-pushdown instrumentation**: `MongoBackend` and `RedisBackend` now expose `fetch_count`, `put_count`, and `reset_counters()` (mirroring `SqliteMemory.l3_fetch_count`) so the new edge-ref slice-pushdown runtime can be empirically verified end-to-end against the production stack. With the pushdown active, `[-->][?:T][0:50]` against a 2,000-neighbor graph drops from 4,400 Mongo fetches / 4,400 Redis cache promotions / 2,250 ms to 50 / 50 / 37 ms (60x) on `ScaleTieredMemory`. New `test_topology_slice_pushdown.jac` integration tests assert these bounds via testcontainers.

### Bug Fixes

- **Fix: Desktop apps installed at read-only paths no longer crash on startup**: The SQLite identity store now writes to the user's data directory, so apps installed system-wide (e.g. via `.deb` / `.rpm` under `/usr/lib/`) start cleanly.
- **Fix: declare `uvicorn[standard]` so jac-scale's WebSocket endpoints actually work**: jac-scale's `serve.jac` registers WebSocket routes (`WebSocketConnectionManager`, `register_websocket_endpoints`), but the package previously pinned bare `uvicorn`, which has no WebSocket implementation library bundled. Any WebSocket upgrade against the API server (jac-scale's own WS routes, browser dev tools probing, monitoring tooling, etc.) was rejected with `Unsupported upgrade request. No supported WebSocket library detected.` followed by HTTP 405. Switching the dep to `uvicorn[standard]>=0.38.0,<0.39.0` pulls in `websockets`, `httptools`, `uvloop`, `watchfiles`, and `python-dotenv` -- the conventional production install when a FastAPI app exposes WS routes -- so upgrades succeed and the warning is gone.
- **Fix: MongoDB process-level connection pool**: `MongoBackend` now shares a single `MongoClient` per worker process via `_process_cache`, eliminating per-request connection churn. `is_available()` only caches `True` so a missing `MONGODB_URI` in one context no longer permanently blocks MongoDB in later contexts; `close()` drops the local reference only, keeping the shared client alive.
- **Fix: Redis process-level connection pool + MGET + TTL**: `RedisBackend` now shares a single client per worker process via `_process_cache` (bounded by `redis_max_connections`, default 20); `batch_get()` uses a single MGET pipeline call instead of N individual GETs; default `redis_default_ttl` raised from 0 to 3600s to prevent unbounded key growth; `is_available()` only caches `True` to avoid cross-context blocking.
- **Fix: ScaleTieredMemory.batch_get full L1→L2→L3 read-through**: `batch_get()` previously skipped the Redis L2 tier and always fetched L1 misses directly from MongoDB. Corrected order: L1 hit → Redis MGET for L1 misses → MongoDB `$in` for L2 misses, with L3 hits promoted to both L1 and L2.
- **Fix: JWT validation removes redundant user_exists() DB call**: `validate_jwt_token()` previously called `user_exists()` (a MongoDB round-trip) on every authenticated request after already verifying the JWT signature and expiry. Removed the extra call; `jwt.decode()` verification is sufficient.
- **Fix: Isolated ExecutionContext per scheduled job**: Scheduled jobs now create their own `JScaleExecutionContext` (pushed via `push_request_context`, reset in `finally`) so concurrent jobs cannot share L1 memory state with each other or with in-flight HTTP requests.
- **Fix: RedisBackend.batch_put for bulk L2 cache writes**: Added `batch_put(anchors)` method to `RedisBackend` so callers can promote multiple anchors into L2 cache in a single logical operation without repeated per-anchor calls.
- **Fix: acommit race condition causing edge data loss under concurrent walker writes**: `MongoBackend.acommit` used a plain `bulk_write` with `_anchor_to_doc` (last-writer-wins), bypassing the delta-merge `_put_node_atomic` path in `sync()`. Under concurrent load, concurrent walker commits could silently overwrite each other's edge writes. Fixed by routing `ScaleTieredMemory.acommit` through `asyncio.to_thread(self.commit)` so the correct merge-aware `sync()` path (with `$setUnion`/`$setDifference` MongoDB pipeline) is always used. Also fixes the user registration format in `test_async_io_blocking.jac` and `test_persistence_race.jac` to match the current identity-based auth API.
- **Fix: redundant MongoDB system root lookup on every request eliminated**: `JScaleExecutionContext.init()` constructed a fresh in-memory L1 cache on every request, causing the system root anchor lookup to fall through L1 → L2 (Redis) → L3 (MongoDB) unconditionally. The `_process_cache` dict now caches the system root anchor after the first resolve; subsequent requests inject it directly into L1 before the lookup, reducing per-request MongoDB round-trips to zero for this path.
- **Fix: eliminate redundant `MongoBackend.sync()` pass per request (issue 1g)**: Added `_committed: bool` flag to `ScaleTieredMemory`; `acommit()` sets the flag after a successful full commit and short-circuits on subsequent calls. The jfast middleware commit is changed from synchronous `ctx.mem.commit()` to `await ctx.mem.acommit()`, removing O(L1-size) hash computation from the event loop on every request while preserving the middleware as a safety net for error paths and non-walker routes.
- **Fix: `ScaleTieredMemory.acommit()` now forwards `anchor` argument to `commit()`**: Previously the `anchor` parameter was accepted but silently dropped. `commit()` always received `None` regardless of what the caller passed. The argument is now forwarded correctly via `asyncio.to_thread(self.commit, anchor)`, matching the contract of the base `Memory.acommit()` interface.

## jac-scale 0.2.15

### New Features

- **Add: Nested LLM Trace Tree in Admin Dashboard**: The LLM Traces page now renders a fully nested, arbitrarily-deep call tree for `by llm()` invocations, with parent-child relationships resolved via byllm's `parent_invocation_id`.
- **Add: Streaming sv-to-sv RPC (generator returns)**: A `def:pub` function returning an iterator now streams its yields to the caller as Server-Sent Events instead of being str-fallback-serialized. Wire format is `Content-Type: text/event-stream` with `data: {json}\n\n` framing and an explicit `event: end` terminator; producer-side exceptions are emitted as `event: error` and re-raised as `RuntimeError` out of the consumer's iterator. The consumer side (sv-RPC stub in jaclang core + jac-scale's plugin override) detects SSE by Content-Type and hands back a Python generator that yields parsed event dicts; lifecycle of the underlying httpx connection follows the generator. Retry/circuit-breaker still applies to connect failures; in-flight streams are not retried (already-consumed events cannot be replayed). Pairs with a `_finalize_call_response` fix in jaclang/runtimelib (the existing isgenerator check was on `reports`, not `result`, so explicit generator returns silently fell into the str() fallback) and a missing SSE framing wrapper in jac-scale's serve.endpoints (the StreamingResponse path emitted dict reprs instead of valid SSE).
- **Add: Configurable gateway-to-service forward timeout**: `[plugins.scale.microservices].http_forward_timeout` (float seconds, default 30) controls the aiohttp timeout used by `raw_forward` (built-in passthrough fan-out) and `stream_forward` (path-routed proxy). Per-service overrides at `[plugins.scale.microservices.services.NAME].http_forward_timeout` mirror the existing `rpc_timeout` precedence pattern - useful for LLM/long-running services that need minutes rather than the global default. Distinct from `rpc_timeout`, which still controls inter-service `sv import` calls (httpx); these are two different code paths through two different HTTP clients. `jac setup microservice` emits a commented reference block.
- **Feat: Custom Object Support in Walker/Function API Parameters**: Walkers and `@restspec` functions with `has`/parameter fields typed as user-defined Jac `obj` (or nested/list/optional thereof) now generate proper nested Pydantic request bodies and OpenAPI schemas instead of collapsing to `str`. Endpoint wrappers reconstruct typed archetype instances from validated JSON before dispatch, so walker handlers receive real `UserBody` (etc.) instances, not raw dicts. Recursive obj types (`obj TreeNode { has children: list[TreeNode]; }`) are handled via a placeholder-cached model registry inspired by PR #5387's ref-mode tracking. Implemented by resolving each parameter's actual `type_obj` via `get_type_hints` in `create_{walker,function}_parameters`, carrying it through `APIParameter.type_obj`, and adding `_resolve_type` / `_build_pydantic_model` / `_pydantic_to_jac` to `JFastApiServer`.
- **Add: Email format validation on register/login**: Identities with `type: email` are now validated as proper email addresses at the pydantic layer, returning `422 Unprocessable Entity` with a clear error for malformed values. `IdentityInput` is now a discriminated union of `EmailIdentityInput` (typed as `EmailStr`) and `UsernameIdentityInput`, and the OpenAPI schema at `/docs` marks email identities with `format: email`.
- **Feat: Partial Anchor Updates**: Optimizes MongoDB writes by skipping full document replacement when only archetype fields change. Implements four-layer system with dirty-field tracking, selective serialization, and smart routing to targeted `$set` operations on changed fields, while preserving full rewrites for structural changes or first inserts.
- **Add: optional `profile` on register, `GET /user/me`, and SSO profile population**: `POST /user/register` accepts an optional `profile` dict (string/number/boolean values, bounded for safety). The new `GET /user/me` returns the authenticated user's identities, role, and profile with credentials stripped. SSO providers (Google, GitHub, Apple) populate `profile.sso.<platform>` (`display_name`, `first_name`, `last_name`, `picture`) and refresh it on every login.
- **FastAPI `/cl/__error__` resolves React component stacks**: The jac-scale client-error endpoint now logs source-mapped JS and React component-stack frames mapped onto the originating `.jac` files, matching the built-in server's behavior.
- **Scale context: initialize PermissionDenied diagnostics list**: `JScaleExecutionContext.init` now seeds the new `diagnostics: list[PermissionDenied]` field on the parent `ExecutionContext`, so the scale subclass participates in the cross-user write-denial diagnostic plumbing introduced in #5788 instead of `AttributeError`-ing on the first denial.

### Bug Fixes

- **Fix: Authenticated requests now always run as the correct user**: Previously, there was a brief window during request startup where a request could execute as the system root instead of the authenticated user, even with a valid JWT. This has been resolved by moving JWT validation into a dedicated middleware that runs before the request context is created. Your user's root node is set correctly from the very first operation in every request. Invalid, expired, or forged tokens are now rejected with `401 Unauthorized` immediately at the middleware layer rather than silently falling through.
- **Fix: Concurrent walker edge loss**: Concurrent walkers modifying the same node no longer silently lose edges. Edge changes are merged via per-request deltas instead of full replacement. MongoDB uses atomic aggregation pipelines (`$setUnion` / `$setDifference`); SQLite uses `BEGIN IMMEDIATE` transactions. `MongoBackend.put` is deferred to `sync()`, and `ScaleTieredMemory.commit` routes all writes through `sync()` so nothing bypasses the merge-aware path.
- **Fix: Per-walker atomicity for MongoDB persistence**: `MongoBackend.put()` now defers all writes to `sync()`, which already routes `NodeAnchor` updates through `_put_node_atomic` and other anchors through `_write_to_db`. This restores per-walker transactional boundaries matching `Jac.commit()`'s contract.
- **Fix: `pub` endpoints no longer return 401 on invalid/expired bearer tokens**: The JWT middleware was short circuiting all requests carrying an invalid or expired `Authorization: Bearer` token with an immediate `401` response, before any endpoint handler could run. This caused `pub` (public) endpoints to reject requests from clients with stale tokens in browser storage. The middleware now ignores token validation failures and lets requests through; per-endpoint auth checks (`requires_auth`) still enforce `401` for protected walkers and functions.

### Refactors

- **Refactor: Sandbox module removed**: The sandbox module (local, docker, kubernetes providers, ingress providers, and related infrastructure) has been removed from jac-scale.
- **Refactor: Share testcontainers across `test_memory_hierarchy` tests**: Each test previously started and stopped its own MongoDB and Redis Docker containers, adding ~14 redundant container lifecycle operations and doubling suite runtime (5 min → 10 min). Containers are now started once per test session via lazy-init helpers (`_get_mongo`, `_get_redis`) and stopped via `atexit`. State is reset between tests by dropping `jac_db` and calling `redis.flushall()` instead of restarting containers.

## jac-scale 0.2.14

- **Identity-based auth system**: Replaced flat username/password user model with a flexible identity + credential architecture. Users can register with multiple identities (username, email) and credentials (password), stored as arrays in MongoDB. Login accepts any identity type. SSO accounts are stored as identities (`type: sso`, `provider: google`) within the user document instead of a separate `sso_accounts` collection.
- **JWT user_id claim**: JWT tokens now use `user_id` (UUID) instead of `username` as the primary claim, enabling identity changes without token invalidation.
- **Feat: SV-to-SV Eager Auto-Spawn in `jac start`**: `jac start consumer.jac` now brings up every `sv import`-ed provider (including transitive ones) automatically before serving the first request, so single-host multi-service deployments need exactly one terminal and zero env vars.
- **Fix: ScaleTieredMemory Initialization**: Changed `ScaleTieredMemory.init(use_cache)` to `postinit` lifecycle method with `use_cache` as a class field, fixing initialization order issues.
- **Fix: Windows Compatibility for Local Sandbox**: Added platform guards for Unix-only APIs, cross-platform temp paths, Windows-compatible shell commands, --jac-cli sidecar support, and increased readiness timeout to 300s.
- **Fix: Spurious "write access" warnings on system root during sync**: Skip `check_write_access()` for unchanged anchors in MongoDB sync, eliminating noisy `Current root doesn't have write access to NodeAnchor Root` log spam on every authenticated request.
- **Persistence: MongoBackend gets Schema Drift + Quarantine + Aliases**: `MongoBackend` now mirrors `SqliteMemory`'s schema-migration surface -- documents are stamped with archetype identity + fingerprint, undeserializable docs route to a `<collection>_quarantine` sidecar instead of being silently dropped, and DB-resident rescue aliases live in `<collection>_aliases`. The new jaclang `jac db inspect / quarantine / alias / recover` commands work against Mongo deployments unchanged. See [Persistence & Schema Migration](../../reference/persistence.md).

- **Optional Install Groups**: Heavy dependencies (pymongo, redis, prometheus-client, apscheduler, kubernetes, docker) are no longer required by default. Install only what you need via extras: `pip install jac-scale[data]` (MongoDB + Redis), `[monitoring]` (Prometheus), `[scheduler]` (APScheduler), `[deploy]` (Kubernetes + Docker), or `[all]` for everything. Groups are combinable: `pip install jac-scale[data,monitoring]`. Missing dependencies produce clear error messages with install instructions. Existing users should use `pip install jac-scale[all]` to keep current behavior.
- **Fix: `jac start` crashes without `jac-scale[scheduler]`**: The scheduler setup in `jac start` unconditionally initialized APScheduler, causing a `'NoneType' object is not callable` error when APScheduler wasn't installed. The scheduler now gracefully degrades: static/interval/cron tasks still work via the core jaclang scheduler, and dynamic scheduling features are skipped with a clear log message when APScheduler is absent.
- 1 small refactor/change.

## jac-scale 0.2.13

- **jac-mcp included by default**: Added to the default Kubernetes package set in jac-scale.

## jac-scale 0.2.12

- **Pre-built Admin Dashboard**: The admin dashboard UI is now pre-built during the release process and shipped as static assets in the package. Previously, navigating to `/admin/` on first load triggered a full Vite build from source, causing significant lag. The server now copies bundled assets instantly, falling back to source build only in dev mode.
- **Dev Mode: Named endpoints in Swagger docs**: Dev mode (`jac start --dev`) now registers individual named endpoints (e.g. `/walker/read_todos`) instead of generic catch-all routes (`/walker/{walker_name}`), so Swagger UI shows all walker/function names. HMR still works - routes are refreshed automatically on file changes.
- **API docs enabled by default**: `/docs`, `/redoc`, and `/openapi.json` are now available in all modes (not just dev). Disable with `docs_enabled = false` in `[plugins.scale.server]`.
- 2 small refactors/changes.

## jac-scale 0.2.11

- **Fix: Sandbox status returns stale RUNNING for dead pods**: `KubernetesSandbox.status()` was returning the cached registry state (often `RUNNING`) when `read_namespaced_pod_status()` threw an exception (pod deleted or unreachable). This caused callers to believe the sandbox was still alive, preventing recovery. Now returns `STOPPED` when the pod query fails so dead pods are detected immediately.
- **Fix: Admin portal build fails from PyPI install**: `jac.toml` and `styles/*.css` were excluded from the wheel because `pyproject.toml` package-data only included `*.jac` files. The admin portal's `jac build` command needs these files to discover the project config and generate Tailwind CSS output.

## jac-scale 0.2.10

- **Dev Mode: API Docs accessible from client URL**: In dev mode (`jac start --dev`), the FastAPI Swagger UI (`/docs`) and OpenAPI spec (`/openapi.json`) are now proxied through the Vite dev server, so you can browse your API docs at the same URL as your app without switching ports.
- **Configurable API docs**: `/docs`, `/redoc`, and `/openapi.json` are controlled by the `docs_enabled` setting in `[plugins.scale.server]` (defaults to `true`). Set `docs_enabled = false` to hide them in production.
- **Health check endpoint**: Added `GET /healthz` for liveness checks. Returns `{"status": "ok"}` with no authentication required. Useful for Kubernetes probes and monitoring.
- **Warm Pool TTL**: Added `warm_pool_ttl` config to control warm pod lifetime independently from sandbox `ttl_seconds`. Default `0` means warm pods live indefinitely until claimed, preventing the pool from emptying after the sandbox TTL expires.

## jac-scale 0.2.9

- **Ingress Rate Limiting (DDoS Protection)**: Added configurable NGINX rate limiting to the Kubernetes ingress. Limits sustained requests per second, burst headroom, and concurrent connections per client IP using the leaky bucket algorithm. Returns `429 Too Many Requests` when limits are exceeded. Configurable via `[plugins.scale.kubernetes]` in `jac.toml`: `ingress_limit_rps` (default: 20), `ingress_limit_burst_multiplier` (default: 5), `ingress_limit_connections` (default: 20).
- **Cookie-Based Sticky Sessions (optional)**: Added opt-in session affinity via NGINX cookie (`route`). When enabled, every user is pinned to the same pod regardless of IP changes (mobile, NAT, proxies). Cookie never expires in the browser. On pod failure NGINX automatically re-routes and rewrites the cookie. Enabled by default. Disable via `ingress_session_affinity = false` in `[plugins.scale.kubernetes]`.
- **Performance: MongoBackend.batch_get()**: New `batch_get(ids)` uses `find({_id: {$in: [...]}})` so edge traversals hit MongoDB with 2-3 queries instead of one per anchor. On cold starts with 100 edges this cuts 201 round-trips down to 3.
- **Extensible Deployment Targets and Image Registries**: `DeploymentTargetFactory` and `ImageRegistryFactory` now support plugin-registered targets via `register(name, factory)`. External packages can register custom deployment targets (e.g. `DeploymentTargetFactory.register("enterprise-kubernetes", my_factory)`) and image registries without modifying jac-scale. Custom targets load their config from `[plugins.scale.<target-name>]` in `jac.toml`.
- **PWA/Web Target Integration Test**: Added test to verify `jac start --client pwa` uses jac-scale's FastAPI server when installed (checks `/docs` endpoint availability).
- **Fix: HPA config ignored on redeployment**: `create_hpa` silently swallowed 409 Conflict errors when the HPA already existed, so updated `min_replicas`, `max_replicas`, and `cpu_utilization_target` values in `jac.toml` were never applied on subsequent deploys. Changed to a replace-first, create-on-404 pattern consistent with how Ingress and ConfigMap resources are managed, ensuring HPA configuration is always kept in sync with `jac.toml`.
- **Sandbox Security Hardening**: Hardened K8s sandbox pods by dropping all Linux capabilities (`drop: ALL`), enabling seccomp `RuntimeDefault` profile (~44 dangerous syscalls blocked), disabling service account token automounting (prevents K8s API access from inside sandboxes), and adding a configurable `/app` emptyDir size limit (`app_storage_limit`, default 1Gi) to prevent node disk exhaustion. Applied consistently to both on-demand and warm pool pods. The sandbox base Dockerfile now creates a dedicated non-root user (`jac`, UID 1000) and installs Bun system-wide so it's accessible under the security context.

## jac-scale 0.2.8

- 1 small changes.

## jac-scale 0.2.7

- **Apple & GitHub SSO Support**: Added Apple Sign In and GitHub as SSO providers via `fastapi-sso`. Unified the SSO callback into a single endpoint per platform (`/sso/{platform}/callback`) that auto-registers new users or logs in existing ones. Initiation endpoints remain separate (`/sso/{platform}/login`, `/sso/{platform}/register`). SSO `host` config simplified to just the base URL (e.g., `http://localhost:8000`). Configure via `[plugins.scale.sso.apple]` and `[plugins.scale.sso.github]` in `jac.toml`.
- **Kubernetes Security Hardening**: Added container-level security contexts (`allowPrivilegeEscalation: false`, `drop: ALL`, `readOnlyRootFilesystem`, `seccompProfile: RuntimeDefault`), dedicated `ServiceAccount` per workload, component-specific NetworkPolicies enforcing proper isolation (databases only accept traffic from main app + dashboards, monitoring components only accept ingress from trusted internal sources), and `pod-security.kubernetes.io/enforce: baseline` namespace labels.
- **Scheduler Code Quality Cleanup**: Extracted shared `_authenticate_request()` and `_validate_trigger()` helpers to remove duplicated auth/validation logic across `/jobs` endpoints. Fixed `get_job()` to query by ID directly instead of loading all jobs. Replaced deprecated `datetime.utcnow()` with `datetime.now(timezone.utc)`. Persisted `is_walker` in job data to avoid redundant introspector lookups. Replaced silent exception swallowing with debug logging.
- **Metrics Endpoint Fix & Prometheus Auth**: Fixed `/metrics` 500 error (`TransportResponse` is a dataclass, not Pydantic - replaced `.model_dump()` with `dataclasses.asdict()`). Added HTTP Basic Auth support so Prometheus can scrape `/metrics` via `basic_auth` in `prometheus.yml`.
- **Hash-based dirty checking for MongoDB/Redis persistence**: Replaced `is_updated` flag with hash-based change detection at sync time. Read-only requests no longer trigger any database writes. All mutation types, including in-place mutations (`list.append()`, `dict[k]=v`, `set.add()`, nested objects), are automatically detected and persisted.
- **Client-Side Error Reporting Endpoint**: Added `POST /cl/__error__` endpoint to `JacAPIServerCore` for receiving client-side JavaScript errors. Errors are logged via the `jaclang.client_errors` logger and printed to the dev console with stack traces for visibility.
- **Source-Mapped Error Stack Traces**: Client error stack traces received at `/cl/__error__` are now resolved from bundled JS locations to original `.jac` file paths and exact line numbers via the centralized `SourceMapper` with two-layer resolution.
- **Client Error Rate Limiting**: The `/cl/__error__` endpoint now deduplicates identical error messages (10s window) and caps at 20 errors per minute to prevent log flooding from render loops or repeated failures.
- **Add: LLM Telemetry Admin Dashboard**: Added a `TelemetryStore` backend that subscribes to byllm's agent callback and litellm's per-call logger, grouping all LLM calls within a single agent invocation into one trace (tokens, cost, latency, user prompt, agent response). Traces are served via four new admin REST endpoints (`/admin/llm/telemetry/summary`, `/traces`, `/traces/{id}`, `/filters`) and visualized in the admin UI with a metrics overview page and a paginated, filterable trace detail view.
- **Fix: Nginx error when domain is set before `--enable-tls`**: Ingress now always deploys with a wildcard rule; the domain `host` is only applied when `--enable-tls` is run, fixing the app being unreachable via IP/NLB when `domain` was set in `jac.toml` before initial deployment.
- **Sandbox System**: Isolated preview environments with Docker and Kubernetes backends, warm pod pool, routing proxy with WebSocket/HMR, and path-safe file operations. Configure via `[plugins.scale.sandbox]` in `jac.toml`.
- **Request-Scoped L1 Memory Cache**: Made the L1 (in-memory) cache request-scoped using `ContextVar`, ensuring each request gets an isolated cache that is automatically cleared after execution, preventing stale data, memory leaks, and cross-request interference while maintaining backward compatibility for CLI and tests.

## jac-scale 0.2.6

- **Domain & TLS support (`--enable-tls`)**: Added custom domain name routing and automatic HTTPS via cert-manager + Let's Encrypt. Set `domain` in `jac.toml`, deploy normally, point your CNAME to the NLB, then run `jac start app.jac --scale --enable-tls` to enable HTTPS without a full redeploy. cert-manager is installed automatically and certificates are renewed automatically. Configurable via `domain` and `cert_manager_email` in `[plugins.scale.kubernetes]`.

## jac-scale 0.2.5

- **Fix: Walker Route OpenAPI Parameter Naming**: Fixed inconsistency where walker routes with node parameters used `{nd}` in URL paths but declared `node` in OpenAPI schema, causing FastAPI validation errors (`"Field required"` for parameter `node`). The OpenAPI schema now correctly uses `nd` to match the actual path variable and function parameter. This fixes requests to `/walker/{walker_name}/{node_id}` endpoints. Note: `node` is a reserved Jac keyword, so `nd` is used as the parameter name throughout.
- **Fix: K8s deployment time regression**: NGINX Ingress controller now starts in parallel with databases/monitoring, restoring test runtimes.
- **NGINX Ingress Controller**: Replaced individual NodePort services with a single NGINX Ingress controller. All services are now ClusterIP, accessible via path-based routing through `ingress_node_port` (default: `30080`): `/` app, `/grafana`, `/cache-dashboard/`, `/db-dashboard`.
- **Fix: Ingress routes now update correctly on re-deploy**: Switched from `patch` to `replace` for Ingress resources so toggling monitoring or dashboards off actually removes the old routes instead of leaving them in place.
- **Security: RedisInsight always requires authentication**: The `/cache-dashboard` route now always enforces HTTP basic-auth when `redis_dashboard = true`. Credentials are hashed with bcrypt (replaces the previous SHA1 scheme). The auth Secret is also cleaned up automatically when `redis_dashboard` is disabled.
- Fix: Redis Insight dashboard 404 and nginx-auth ConfigMap not updating on re-deploy.
- **Fix: Parser Strictness Compliance**: Moved docstrings before signatures in `kubernetes_utils.impl.jac` and converted nested function docstring to comment in `api.cl.jac` to comply with the stricter RD parser.
- [Internal] Refactor: Extract graph visualizer HTML into a standalone template file.
- **User storage now supports both MongoDB and SQLite**: User authentication and management automatically uses SQLite when MongoDB is not configured, maintaining full backward compatibility with existing installations.
- **Fix: Include `redis.conf.template` in package distribution**: Fixed `FileNotFoundError` during Redis deployment when jac-scale is installed via pip (non-editable install). The `redis.conf.template` file is now correctly included in the wheel distribution via `package-data` configuration in `pyproject.toml`.

## jac-scale 0.2.4

- **Automatic Port Fallback**: When starting the server with `jac start`, if the specified port is already in use, the server now automatically finds and uses the next available port instead of crashing with "Address already in use". A warning message displays when using an alternative port. Supports up to 10 port retries with cross-platform compatibility (Linux and Windows).
- [fix]Fix for internet facing aws load balancer
- 1 Minor refactor/change.
- **Scheduling Support**: Added static and dynamic task scheduling for walkers and functions via `@schedule(trigger=...)`. Static schedules (INTERVAL/CRON/DATE) start automatically at server startup; dynamic schedules (DYNAMIC) are managed via a new `/jobs` REST API (create, list, get, update, delete) with MongoDB persistence. Scheduled items are excluded from standard walker/function endpoints. A `__system__` user executes all scheduled tasks; configure via `[plugins.scale.scheduler]` in `jac.toml`.
- **Fix**: Fix for internet-facing AWS load balancer
- [Internal] Convert username and password for redis and mongodb to secret when injecting to pod deployment
- 3 Minor refactors/changes.
- update jac-scale plugin documentation with missing features
- APP_NAME, K8s_NAMESPACE, DOCKER_USERNAME, DOCKER_PASSWORD are no longer read from environment variables and must be configured via `jac.toml.

- **Component-Level Destroy**: `jac destroy app.jac --component <name>` now supports removing individual Kubernetes components (`application`, `database`, `cache`, `monitoring`, `dashboard`) without tearing down the entire deployment.
- **Redis Cache Configuration with TTL Support**: Added configurable eviction policies and TTL support for Kubernetes Redis deployments via `jac.toml` (`redis_max_memory`, `redis_eviction_policy`, `redis_eviction_samples`, `redis_default_ttl`, `redis_enable_keyspace_notifications`); ConfigMap-based with automatic pod restart on change. Anchors stored in Redis L2 cache now respect the `redis_default_ttl` setting and will automatically expire after the configured duration (default: 0 = no expiration).
- 1 small refactor/change.
- **Fix: Redis deployment annotation null guard**: Fixed `'NoneType' object has no attribute 'get'` crash during `jac start --scale` when an existing Redis deployment has no annotations. Kubernetes returns `None` for the annotations field when none exist, so the config-hash check now guards against this.

## jac-scale 0.2.3

- **Admin API Endpoints**: REST API for administrative operations at `/admin/*` including user management, SSO provider listing, and configuration access.
- **Admin-Only Metrics Endpoint**: The `/metrics` Prometheus scrape endpoint now requires admin authentication. Unauthenticated requests receive a 403 Forbidden response. This prevents unauthorized access to server performance data.
- **Admin Metrics Dashboard**: Added `/admin/metrics` endpoint that returns parsed Prometheus metrics as structured JSON with summary statistics (total requests, average latency, error rate, active requests). The admin dashboard monitoring page now displays metrics in a visual dashboard with HTTP traffic breakdown, system stats (GC, memory, CPU time), and real-time counters.
- Set default maximum memory limit of k8s pods from unlimited to 12Gb
- Automatically deploy Redis (RedisInsight) and MongoDB (MongoDB Dashboard) dashboards in Kubernetes when the redis_dashboard and mongodb_dashboard flags are enabled.
- Set default maximum memory limit for jaseci app pod to None (unlimited)
- 1 Minor refactor/change.

## jac-scale 0.2.2

- **Data Persists Across Server Restarts**: Graph nodes and edges created during a session now persist automatically in MongoDB. When you restart your `jac start` server, previously created data is restored and accessible - no manual save operations required.
- **`jac status` Command**: New `jac status app.jac` command to check the live deployment status of all Kubernetes components (Jaseci App, Redis, MongoDB, Prometheus, Grafana). Displays a color-coded table with component health, pod readiness counts, and service URLs. Detects running, degraded, pending, restarting (crash-loop), and not-deployed states.
- **Resource Tagging**: All Kubernetes resources created by jac-scale are now labeled with `managed: jac-scale`, enabling easy auditing and identification via `kubectl get all -l managed=jac-scale -A`.
- k8s metrics dashboard in prometheus and grafana
- Jac status command to check deployment status of each component of k8s
- **Chore: Codebase Reformatted**: All `.jac` files reformatted with improved `jac format` (better line-breaking, comment spacing, and ternary indentation).
- **Fix: Root-Level Font/Asset 404s**: Added `.jac/client/dist/` as a search candidate in `serve_root_asset`, fixing 404s for font files (`.woff2`, `.ttf`, etc.) bundled by Vite with root-relative `@font-face url()` paths.

## jac-scale 0.2.1

- **Admin Portal**: Added a built-in `/admin` dashboard for user management and administration. Features include user CRUD operations (list, create, edit, delete), role-based access control with `admin`, `moderator`, and `user` roles, force password reset, and SSO account management view.
- **Admin API Endpoints**: REST API for administrative operations at `/admin/*` including user management, SSO provider listing, and configuration access.
- **Admin Configuration**: New `[plugins.scale.admin]` section in `jac.toml` to configure admin portal settings. Environment variables `ADMIN_USERNAME`, `ADMIN_EMAIL`, and `ADMIN_DEFAULT_PASSWORD` supported.
- **Refactor: `JacSerializer` removed, use `Serializer(api_mode=True)`**: `JacSerializer` has been removed from `jaclang.runtimelib.server`. API serialization is now handled directly by `Serializer.serialize(obj, api_mode=True)` from `jaclang.runtimelib.serializer`. Storage backends are unaffected; continue using `Serializer.serialize(obj, include_type=True)` for round-trip persistence. Added `social_graph.jac` fixture demonstrating native persistence with `db.find_nodes()` for querying the `_anchors` collection using MongoDB filters.
- Internal: refactor jac-scale k8s loadbalancer/service to support other vendors
- Before deploying to the local Kubernetes cluster, check whether the required NodePorts are already in use in any namespace; if they are, throw an error.
- jac destroy command deletes non default namespace
- **Fix: Code-sync pod stuck in ContainerCreating**: Added preferred `podAffinity` to the code-sync pod spec so it prefers scheduling on the same node as the code-server pod. Fixes RWO (ReadWriteOnce) PVC mount failures when Kubernetes schedules the two pods on different nodes.
- 1 Minor refactor
- Internal: check whether redis,mongodb,grafana and prometheus are also restarted when checking deployment status

## jac-scale 0.2.0

- **SSO Frontend Callback Redirect**: SSO callback endpoints now support automatic redirection to frontend applications. Configure `client_auth_callback_url` in `jac.toml` to redirect with token/error parameters instead of returning JSON, enabling seamless browser-based OAuth flows.
- **Graph Visualization Tests**: Added tests for `/graph` and `/graph/data` endpoints.

## jac-scale 0.1.11

- **Graph Visualization Endpoint (`/graph`)**: Added a built-in `/graph` endpoint that serves an interactive graph visualization UI in the browser.

## jac-scale 0.1.10

- **support horizontal scaling**:  based on average cpu usage k8s pods are horizontally scaled
- **Client Build Error Diagnostics**: Build errors now display formatted diagnostic output with error codes, source snippets, and quick fix suggestions instead of raw Vite/Rollup output. Uses the `jac-client` diagnostic engine for consistent error formatting across `jac start` and `jac build`.

## jac-scale 0.1.9

- **Refactor: Modular JacAPIServer Architecture**: Split the monolithic `serve.impl.jac` into three focused impl files using mixin composition:
  - `serve.core.impl.jac`: Auth, user management, JWT, API keys, server start/postinit
  - `serve.endpoints.impl.jac`: Walker, function, webhook, WebSocket endpoint registration
  - `serve.static.impl.jac`: Static files, pages, client JS, graph visualization
- **Fix: `@restspec` Path Parameters**: Resolved a critical bug where using `@restspec` with URL path parameters (e.g. `path="/items/{item_id}"`) caused the server to crash on startup with `Cannot use 'Query' for path param 'id'`. Both functions and walkers with `@restspec` path templates now correctly annotate matching parameters as `Path()` instead of `Query()`. Mixed usage (path params alongside query params or body params) works correctly across GET and POST methods. Starlette converter syntax (e.g. `{file_path:path}`) is also handled.
- **Remove Authorization header input from Swagger UI**: The `Authorization` header is no longer exposed as a visible text input field in Swagger UI for walker, function, and API key endpoints. Authentication tokens are now read transparently from the standard `Authorization` request header (accessible via the lock icon), consistent with the `update_username` and `update_password` endpoints.
- 1 Minor refactors/changes.

## jac-scale 0.1.8

- Internal: K8s integration tests now install jac plugins from fork PRs instead of always using main
- **.jac folder is excluded when creating the zip folder that is uploaded into jaseci deployment pods.Fasten up deployment**
- **Fix: `jac start` Startup Banner**: Server now displays the startup banner (URLs, network IPs, mode info) correctly via `on_ready` callback, consistent with stdlib server behavior.
- Various refactors
- **PWA Build Detection**: Server startup now detects existing PWA builds (via `manifest.json`) and skips redundant client bundling. The `/static/client.js` endpoint serves Vite-hashed files (`client.*.js`) in PWA mode.
- **Prometheus Metrics Integration**: Added `/metrics` endpoint with HTTP request metrics, configurable via `[plugins.scale.metrics]
` in `jac.toml`.
- Update jaseci scale k8s pipeline to support parellel test cases.
- **early exit from k8s deployment if container restarted**
- **Direct Database Access (`kvstore`)**: Added `kvstore()` function for direct MongoDB and Redis operations without graph layer. Supports database-specific methods (MongoDB: `find_one`, `insert_one`, `update_one`; Redis: `set_with_ttl`, `incr`, `scan_keys`) with common methods (`get`, `set`, `delete`, `exists`) working across both. Import from `jac_scale.lib` with URI-based connection pooling and configuration fallback (explicit URI → env vars → jac.toml).
- **Code refactors**: Backtick escape, etc.
- **Persistent Webhook API Keys**: Webhook API key metadata is now stored in MongoDB (`webhook_api_keys` collection) instead of in-memory dictionaries. API keys now survive server restarts.
- **Native Kubernetes Secret support**: New `[plugins.scale.secrets]` config section. Declare secrets with `${ENV_VAR}` syntax, auto-resolved at deploy time into a K8s Secret with `envFrom.secretRef`.
- **Minor Internal Refactor in Tests**: Minor internal refactoring in test_direct.py to improve test structure
- **fix**: Return 401 instead of 500 for deleted users with valid JWT tokens.
- Docs update: return type `any` -> `JsxElement`
- **1 Small Refactors**
- **promethius and grafana deployment**: Jac-scale automatically deploys promethius and grafana and connect with metrics endpoint.

## jac-scale 0.1.7

- **KWESC_NAME syntax changed from `<>` to backtick**: Updated keyword-escaped names from `<>` prefix to backtick prefix to match the jaclang grammar change.
- **Update syntax for TYPE_OP removal**: Replaced backtick type operator syntax (`` `root ``) with `Root` and filter syntax (``(`?Type)``) with `[?:Type]` across all docs, tests, examples, and README.

## jac-scale 0.1.6

- **WebSocket Support**: Added WebSocket transport for walkers via `@restspec(protocol=APIProtocol.WEBSOCKET)` with persistent bidirectional connections at `ws://host/ws/{walker_name}`. The `APIProtocol` enum (`HTTP`, `WEBHOOK`, `WEBSOCKET`) replaces the previous `webhook=True` flag-migrate by changing `@restspec(webhook=True)` to `@restspec(protocol=APIProtocol.WEBHOOK)`.

- **fix: Exclude `jac.local.toml` during K8s code sync**: The local dev override file (`jac.local.toml`) is now excluded when syncing application code to the Kubernetes PVC. Previously, this file could override deployment settings such as the serve port, causing health check failures.

## jac-scale 0.1.5

- **JsxElement Return Types**: Updated all JSX component return types from `any` to `JsxElement` for compile-time type safety.
- **Client bundle error help message**: When the client bundle build fails during `jac start`, the server now prints a troubleshooting suggestion to run `jac clean --all` and a link to the Discord community for support.

## jac-scale 0.1.4

- **Console infrastructure**: Replaced bare `print()` calls with `console` abstraction for consistent output formatting.
- **Hot fix: call state**: Normal spawn calls inside API spawn calls supported.
- **`--no_client` flag support**: Server startup now honors the `--no_client` flag, skipping eager client bundling when the client bundle is built separately, adn we need server only.
- **PyJWT version pinned**: Pinned `pyjwt` to `>=2.10.1,<2.11.0` and updated default JWT secret to meet minimum key length requirements.

## jac-scale 0.1.3

- **GET Method Support**: Added full support for HTTP GET requests for both walkers and functions, including correct mapping of query parameters, support for both dynamic (HMR) and static endpoints, and customization via `@restspec(method=HTTPMethod.GET)`.

- **Streaming Response Support**: Streaming responses are supported with walker spawn calls and function calls.
- **Webhook Support**: Added webhook transport for walkers with HMAC-SHA256 signature verification. Walkers can be configured with `@restspec(webhook=True)` to receive webhook requests at `/webhook/{walker_name}` endpoints with API key authentication and signature verification.

- **Storage Abstraction**: Introduced a pluggable storage abstraction layer for file operations.
  - Abstract `Storage` interface with standard operations: `upload`, `download`, `delete`, `list`, `copy`, `move`, `get_metadata`
  - Default `LocalStorage` implementation in `jaclang.runtimelib.storage`
  - Hookable `store(base_path, create_dirs)` builtin that returns a configured `Storage` instance
  - Configure via `jac.toml [storage]` section or `JAC_STORAGE_PATH` / `JAC_STORAGE_CREATE_DIRS` environment variables

- **jac destroy** command wait till fully removal of resources

- **SPA Catch-All for BrowserRouter Support**: The FastAPI server's `serve_root_asset` endpoint now falls back to rendering SPA HTML for extensionless paths when `base_route_app` is configured. API prefix paths (`cl/`, `walker/`, `function/`, `user/`, `static/`) are excluded from the catch-all. This matches the built-in HTTP server's behavior for BrowserRouter support.

- **Internal**: Explicitly declared all postinit fields across the codebase.

### PyPI Installation by Default

Kubernetes deployments now install Jaseci packages from PyPI by default instead of cloning the entire repository. This provides faster startup times and more reproducible deployments.

**Default behavior (PyPI installation):**

```bash
jac start app.jac --scale
```

**Experimental mode (repo clone - previous behavior):**

```bash
jac start app.jac --scale --experimental
```

### New CLI Flag: `--experimental`

Added `--experimental` (`-e`) flag to `jac start --scale` command. When enabled, falls back to the previous behavior of cloning the Jaseci repository and installing packages in editable mode. Useful for testing unreleased changes.

### Version Pinning via `plugin_versions` Configuration

Added `plugin_versions` configuration in `jac.toml` to pin specific package versions:

```toml
[plugins.scale.kubernetes.plugin_versions]
jaclang = "0.1.5"      # or "latest"
jac_scale = "0.1.1"    # or "latest"
jac_client = "0.1.0"   # or "latest"
jac_byllm = "none"     # use "none" to skip installation (will install relevant byllm version)
```

When not specified, defaults to `"latest"` for all packages.

### Enhanced `restspec` Decorator

The `@restspec` decorator now supports custom HTTP methods and custom endpoint paths for both walkers and functions.

- **Custom Methods**: Use `method=HTTPMethod.GET`, `method=HTTPMethod.PUT`, etc.
- **Custom Paths**: Use `path="/my/custom/path"` to override the default routing.

## jac-scale 0.1.1

## jac-scale 0.1.0

### Initial Release

First release of **Jac-Scale** - a scalable runtime framework for distributed Jac applications.

### Key Features

- Conversion of walker to fastapi endpoints
- Multi memory hierachy implementation
- Support for Mongodb (persistance storage) and Redis (cache storage) in k8s
- Deployment of app code directly to k8s cluster
- k8s support for local deployment and aws k8s deployment
- SSO support for google

- **Custom Response Headers**: Configure custom HTTP response headers via `[environments.response.headers]` in `jac.toml`. Useful for security headers like COOP/COEP (required for `SharedArrayBuffer` support in libraries like monaco-editor).

### Installation

```bash
pip install jac-scale
```
