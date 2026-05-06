# Jac-Scale Release Notes

This document provides a summary of new features, improvements, and bug fixes in each version of **Jac-Scale**. For details on changes that might require updates to your existing code, please refer to the [Breaking Changes](../breaking-changes.md) page.

## jac-scale 0.2.15 (Latest Release)

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
