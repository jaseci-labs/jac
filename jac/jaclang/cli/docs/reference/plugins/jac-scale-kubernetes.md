# Scale -- Kubernetes & Operations

> Part of the [Scale subsystem](jac-scale.md).

## Kubernetes Deployment

### Deployment Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Deploy** | `jac scale deploy app.jac` | Ship the project source into the cluster and deploy |
| **Preview** | `jac scale deploy app.jac --dry-run` | Print the manifests that would be applied; change nothing |
| **Enable HTTPS** | `jac scale deploy app.jac --enable-tls` | Enable TLS on a live deployment (no redeploy, run after CNAME propagates) |

There is no image-build step. `jac-scale` does not build, tag, or push a Docker
image, and it needs no registry and no registry credentials: pods run a stock
base image, and your source is shipped into the cluster (see
[Source Distribution](#source-distribution) below).

---

### Runtime Binary

Pods run a prebuilt `jac` binary that carries the jaclang runtime (including the `scale` subsystem). It is never built from source in the pod - the deploy driver selects and ships it. Which binary is shipped depends on the channel:

| Channel | Selected by | Binary shipped |
|---------|-------------|----------------|
| **stable** | no `[dev]` or `[experimental]` stanza in `jac.toml` (default) | Latest published release, or the release matching a `[project] jac-version` pin |
| **experimental** | an `[experimental]` stanza (`pr = <N>`) in `jac.toml` | The `experimental-<PR#>` build; pods run the `jaseci/jaclang:experimental-<PR#>` image |
| **dev** | a `[dev]` stanza in `jac.toml` | Rolling `dev` prerelease (main HEAD) |
| **local** | `JAC_SCALE_BINARY_PATH` set | The exact binary at that path |

Channel precedence is local, then experimental, then dev, then stable -- an `[experimental]` stanza wins over `[dev]`, and `JAC_SCALE_BINARY_PATH` wins over both.

`stable` and `dev` download the binary from [GitHub Releases](https://github.com/jaseci-labs/jac/releases) and run it as-is - there is no source overlay. On the stable channel, a `[project] jac-version` version spec is resolved against the published releases and that exact version is shipped; the deploy errors if the spec matches no release.

**Local binary (`JAC_SCALE_BINARY_PATH`).** Point this environment variable at a `jac` binary you built (or an air-gapped mirror) and the deploy ships that exact file to pods instead of downloading a release. It takes precedence over the `[dev]` stanza:

```bash
export JAC_SCALE_BINARY_PATH=/path/to/jac
jac scale deploy app.jac
```

Use this for air-gapped clusters, to pin an exact build, or to deploy a binary you compiled locally. The driver checksum-caches downloaded release binaries per channel and architecture, so an unchanged `stable`/`dev` deploy does not re-download on every run.

---

### App Artifact (`.jab`)

The app is packed on the deploy driver into a sealed **`.jab`** image, seeded to the bundle PVC, and extracted into the pod's `/app` volume. The `.jab` contains the project source, a `_precompiled/` sealed image (`MANIFEST.json` + content-keyed `.jir` modules built with the pod binary), and the sanitized `jac.toml` (root and nested project tomls, secrets and `[dev]` sections stripped).

The source copy honors the project's [`.jacignore`](../config/index.md#jacignore) with the same patterns and semantics as `jac check`, on top of a fixed floor of paths that never ship (VCS and build directories, `.env` files, private keys and certificates). A tree parked in `.jacignore` reaches neither the seal stage, the `.jab`, nor the pod, and its nested `jac.toml` is not enumerated either. `.jacignore` itself ships, so editing it moves the bundle's content address and the next deploy re-ships instead of hitting the content-addressed skip.

The seal stage is a valid, sanitized copy of the project: sanitized tomls are written into it before the seal runs, so `[placement.pins]` and nested-project scoping are visible at seal time. The seal compiles exactly the modules that emit server code -- client-only modules (pinned or inferred) produce JS, not pod bytecode, and are skipped via the placement facts API. The per-module placement verdict is recorded in the sealed `MANIFEST.json` (`placement` map, manifest format 5). The seal subprocess timeout defaults to 1800s and is configurable with `[scale] seal_timeout` in `jac.toml`.

Sealing is **mandatory**: if the app cannot be sealed into a valid image, the deploy fails rather than shipping a bundle that cold-compiles on the pod's first boot. When a pod starts, the compiler auto-loads the sibling `_precompiled/` image, so services run from precompiled modules with no on-pod compile step - for both single-app and microservice deployments.

If a module in your project cannot be sealed (for example, a file that fails to compile), the deploy aborts with the seal error. Fix the offending module, or park its tree in `.jacignore` if it is not part of the served app, and redeploy.

---

### Naming & Namespace

Controls the application name used for all Kubernetes resource names and the namespace resources are created in.

**Defaults:**

| TOML Key  | Default | Description |
|-----------|---------|-------------|
| `app_name` | slug of `[project].name` | Prefix for all K8s resource names (deployments, services, secrets, etc.). Falls back to `jaseci` when no project name is usable |
| `namespace`| `default` | Kubernetes namespace to deploy into |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
app_name = "myapp"
namespace = "production"
```

---

### Ports

Controls how the application is exposed inside the cluster and externally.

By default, jac-scale deploys a **dedicated NGINX Ingress controller per app**. The controller listens on one NodePort and routes requests to the correct ClusterIP service based on path. Individual services (app, Grafana, dashboards) are all ClusterIP and not directly reachable from outside the cluster.

To use a pre-existing shared controller instead, see [Shared Ingress](#shared-ingress) below.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `container_port`| `8000` | Port your app listens on inside the pod |
| `ingress_node_port` | `30080` | NodePort for the NGINX Ingress controller (all external traffic enters here) |

**Access URLs (local cluster):**

| Path | Destination |
|------|-------------|
| `http://localhost:30080/` | Jaseci application |
| `http://localhost:30080/grafana` | Grafana dashboard (if monitoring enabled) |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
container_port = 8000
ingress_node_port = 30080
```

---

### Shared Ingress

By default each app deploys its own NGINX controller (one Deployment, one NodePort/NLB, one IngressClass). Set `shared_ingress = true` to skip that and attach the app's routing rules to a pre-existing shared NGINX controller in your cluster instead.

**When to use shared ingress:**

- You already run a cluster-wide `ingress-nginx` controller (e.g. installed via Helm) and don't want a separate controller per app
- You are deploying multiple apps to the same cluster and want to reduce resource overhead

**Requirements:**

- An `IngressClass` named `shared_ingress_class` must already exist in the cluster (jac-scale validates the class at deploy time; it does not check that the controller behind it is running, and the controller does not have to be NGINX -- see below)
- `domain` **must** be set. The shared controller sees Ingress resources from all namespaces, so host-based routing is the only way to differentiate two apps. jac-scale raises an error at deploy time if `domain` is empty when `shared_ingress = true`

**Configuration:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `shared_ingress` | `false` | Use a pre-existing shared controller instead of deploying a dedicated one |
| `shared_ingress_class` | `"nginx"` | IngressClass name of the shared controller |
| `shared_ingress_annotations` | `{}` | Extra annotations merged onto the Ingress. Required to drive non-nginx controllers (AWS ALB, Traefik, GKE). Caller-supplied values take precedence |
| `shared_ingress_tls` | `false` | Set when the controller terminates TLS out-of-band (e.g. ALB via an ACM cert) so the reported URL uses `https`. nginx+cert-manager (`spec.tls`) is detected automatically. When cert-manager issuer annotations and `domain` are present, this also emits a `spec.tls` block on the shared Ingress |
| `shared_ingress_skip_reachability` | `false` | Skip the post-deploy reachability check against `domain` in shared mode. By default the deploy health-checks `http://{domain}` and prints DNS guidance on failure |

```toml
[scale.kubernetes]
shared_ingress = true
domain = "myapp.example.com"          # required: used as the Ingress host field

# Override if your shared controller uses a non-default class
# shared_ingress_class = "nginx"
```

**Non-nginx controllers (e.g. AWS ALB).** `shared_ingress_class` may name any controller; nginx-specific tuning is emitted only when the class is `nginx`. Supply controller-specific settings via `shared_ingress_annotations` so jac-scale stays cloud-agnostic:

```toml
[scale.kubernetes]
shared_ingress = true
shared_ingress_class = "alb"
shared_ingress_tls = true
domain = "linkedin.jaseci.app"

[scale.kubernetes.shared_ingress_annotations]
"alb.ingress.kubernetes.io/group.name" = "shared-alb"     # join one shared ALB
"alb.ingress.kubernetes.io/scheme" = "internet-facing"
"alb.ingress.kubernetes.io/target-type" = "ip"
"alb.ingress.kubernetes.io/certificate-arn" = "arn:aws:acm:...:certificate/..."
"alb.ingress.kubernetes.io/listen-ports" = '[{"HTTP": 80}, {"HTTPS": 443}]'
"alb.ingress.kubernetes.io/ssl-redirect" = "443"
```

**What changes in shared mode:**

| Behaviour | Dedicated (default) | Shared |
|-----------|---------------------|--------|
| Controller deployed | Yes (one per app) | No (uses existing controller) |
| IngressClass | `{namespace}-{app_name}-nginx` | Value of `shared_ingress_class` |
| Routing rules | Wildcard, plus a host rule for `domain` when it is set | Host set immediately to `domain` |
| On destroy | Removes controller, RBAC, IngressClass, Ingress rules, and TLS material (TLS secret, cert-manager Certificate and Issuer) | Removes Ingress rules and TLS material only; controller is untouched |
| TLS (`--enable-tls`) | Works (cert-manager Issuer uses app-specific class) | Works (cert-manager Issuer uses shared class) |

!!! note
    Because the shared controller routes by the `Host:` header, each app in the cluster must have a unique domain. Two apps named `jaseci` in `dev` and `prod` namespaces are fully isolated as long as they have different domains (`dev.example.com` vs `prod.example.com`).

---

### Rate Limiting (DDoS Protection)

jac-scale applies NGINX rate limiting annotations to the Ingress to protect against abuse and DDoS traffic. Limits are enforced **per client IP**.

**How it works (leaky bucket algorithm):**

- **`ingress_limit_rps`** - sustained requests per second allowed per IP.
- **`ingress_limit_burst_multiplier`** - burst = `limit_rps x burst_multiplier`. Requests within the burst are queued; requests beyond it are dropped with `429`.
- **`ingress_limit_connections`** - maximum number of concurrent open connections per IP. Excess connections are rejected immediately.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `ingress_limit_rps` | `20` | Sustained requests per second per client IP |
| `ingress_limit_burst_multiplier` | `5` | Burst headroom multiplier (burst = rps × multiplier) |
| `ingress_limit_connections` | `20` | Max concurrent connections per client IP |

Requests that exceed the limits receive `429 Too Many Requests`.

**To customize in `jac.toml`:**

```toml
[scale.kubernetes]
ingress_limit_rps = 50              # allow more sustained traffic
ingress_limit_burst_multiplier = 3  # tighter burst control
ingress_limit_connections = 30      # more concurrent connections
```

---

### Sticky Sessions (Cookie-Based Affinity)

When your pods hold per-user state (e.g. running user processes), you need requests from the same user to always reach the same pod. jac-scale provides cookie-based session affinity via NGINX.

**Enabled by default** (`ingress_session_affinity = true`). Disable it in `jac.toml` if not needed:

```toml
[scale.kubernetes]
ingress_session_affinity = false
```

**How it works:**

On the first response, NGINX sets a `route` cookie in the browser. Every subsequent request includes that cookie and NGINX uses it to route back to the same pod, regardless of IP changes (mobile networks, NAT, VPN, proxies). The cookie never expires in the browser.

| Behaviour | Detail |
|-----------|--------|
| Cookie name | `route` |
| Cookie lifetime | Never expires (`max-age` ~68 years) |
| On pod failure | NGINX re-routes to a healthy pod and rewrites the cookie automatically |
| IP changes (mobile/NAT) | Handled correctly - routing is cookie-based, not IP-based |

**When to use:**

- Your pods run stateful per-user processes (e.g. background workers per user)
- You need a user to consistently land on the pod that owns their session

**Limitations:**

Sticky sessions ensure routing **while a pod is alive**. If a pod is deleted (e.g. during a rolling deployment), in-flight user processes on that pod are lost. The user is automatically re-routed to a new pod, but any in-memory state is gone. For true resilience, externalize per-user state to the shared Postgres database so any pod can serve any user.

---

### Domain & TLS (HTTPS)

jac-scale supports custom domain names and automatic HTTPS via [cert-manager](https://cert-manager.io) + Let's Encrypt. TLS is a two-step process to avoid the chicken-and-egg problem (NLB hostname is unknown until after the first deploy).

#### Step 1 - Deploy (HTTP)

Set your domain in `jac.toml` and deploy normally:

```toml
[scale.kubernetes]
domain = "app.example.com"
cert_manager_email = "you@example.com"
```

```bash
jac scale deploy app.jac
```

After deploy, the external endpoint is printed along with the DNS record to create. The record type is detected automatically: an IP endpoint (e.g. a bare-metal or local cluster) prompts an `A` record, a hostname endpoint (e.g. an AWS NLB) prompts a `CNAME`:

```
Deployment complete! Service available at: http://k8s-default-...elb.amazonaws.com

  ACTION REQUIRED - add a CNAME record in your DNS provider:
    Type:  CNAME
    Name:  app.example.com
    Value: k8s-default-...elb.amazonaws.com

  Then run: jac scale deploy app.jac --enable-tls
```

#### Step 2 - Add DNS record

In your DNS registrar (Namecheap, Route 53, Cloudflare, etc.) add the record exactly as printed (`A` for IP endpoints, `CNAME` for hostname endpoints).

Wait for DNS propagation (usually 1–15 minutes). Verify with `dig app.example.com`.

#### Step 3 - Enable TLS

```bash
jac scale deploy app.jac --enable-tls
```

This installs cert-manager, creates a Let's Encrypt `Issuer`, patches the live Ingress with TLS annotations, and updates all service URLs to HTTPS. No redeployment of your application occurs.

Output:

```
TLS enabled. App is now live at:
  App URL:        https://app.example.com
  Grafana:        https://app.example.com/grafana
```

> **Note:** `--enable-tls` requires a domain and `cert_manager_email`. Both are read from the annotations a prior deploy recorded on the live Ingress (`jac-scale/domain`, `jac-scale/cert-email`), falling back to `jac.toml`; it errors if neither source provides them. Because the annotation wins, changing `domain` in `jac.toml` and re-running `--enable-tls` has no effect while a prior deploy's annotation exists -- re-deploy to update it.

**Configuration options:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `domain` | `""` | Custom domain name (e.g. `app.example.com`). Leave empty for NLB-only access. |
| `cert_manager_email` | `""` | Email for Let's Encrypt certificate registration and expiry notices. |
| `aws_nlb_wait` | `60` | Seconds to wait for the AWS NLB to provision before reading its endpoint. |

**Certificate renewal** is automatic - cert-manager renews ~30 days before expiry.

---

### Resource Limits

Controls CPU and memory requests/limits for the application container. Kubernetes uses requests for scheduling and limits for enforcement (OOM-kill).

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `cpu_request`  | None | CPU units reserved for scheduling (e.g. `"250m"`) |
| `cpu_limit`  | None | Maximum CPU the container may use (e.g. `"1000m"`) |
| `memory_request`  | None | Memory reserved for scheduling (e.g. `"256Mi"`) |
| `memory_limit` | None | Memory ceiling - container is OOM-killed if exceeded |

Values are passed through to Kubernetes as-is; use standard [resource quantities](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/#resource-units-in-kubernetes): `Ki`, `Mi`, `Gi` (binary) or `k`, `M`, `G` (decimal).

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
cpu_request = "250m"
cpu_limit = "1000m"
memory_request = "256Mi"
memory_limit = "2Gi"
```

---

### Health Probes

Kubernetes uses readiness and liveness probes to decide when a pod is ready to serve traffic and when to restart it. Both probes hit `GET <health_check_path>` on the container.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `health_check_path` | `"/docs"` | Endpoint probed by both readiness and liveness checks |
| `readiness_initial_delay` | `10` | Seconds to wait before first readiness check |
| `readiness_period` | `20` | Seconds between readiness checks |
| `liveness_initial_delay`  | `10` | Seconds to wait before first liveness check |
| `liveness_period`  | `20` | Seconds between liveness checks |
| `liveness_failure_threshold` | `80` | Consecutive failures before the pod is restarted |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
health_check_path = "/healthz/ready"
readiness_initial_delay = 15
readiness_period = 10
liveness_initial_delay = 30
liveness_period = 30
liveness_failure_threshold = 5
```

> **Tip:** The scale server ships built-in probe endpoints at `/healthz/live` and `/healthz/ready` - see [Health Checks](#health-checks). Microservice deployments use them automatically; for single-app deployments, point `health_check_path` at one of them to probe something cheaper than the default `/docs` page.

---

### Autoscaling

jac-scale supports two autoscaler engines selected via `autoscaler_engine`. Both engines share `min_replicas`, `max_replicas`, and `cpu_utilization_target`; they differ in what additional triggers and behaviours they support.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `autoscaler_engine` | `"hpa"` | Autoscaler engine: `"hpa"` (CPU/memory, default) or `"keda"` (event-driven, scale-to-zero) |
| `min_replicas` | `1` | Minimum number of pods |
| `max_replicas` | `3` | Maximum number of pods |
| `cpu_utilization_target` | `50` | Average CPU % that triggers scale-out. Seeds the CPU trigger for both engines unless `extra_triggers` is set. |
| `memory_utilization_target` | `80` | Average memory % that triggers scale-out. A memory trigger is seeded automatically for both engines when `memory_request` is set. |
| `autoscaler_scale_up_stabilization` | `60` | Scale-up stabilization window in seconds (HPA `behavior.scaleUp`), applied under both engines. |
| `autoscaler_scale_up_max_pods` | `2` | Maximum pods added per scale-up step, applied under both engines. |

> **Note:** CPU-based scaling requires `cpu_request` to be set. Without a CPU request, Kubernetes cannot compute a utilization percentage. Likewise, memory triggers require `memory_request`; a memory trigger whose resolved request is empty is skipped with a warning under both deploy paths. In microservice deployments the request defaults to `1Gi` (`2Gi` for the gateway), so the skip only occurs when `memory_request` is explicitly set to `""`.

#### HPA Engine (Default)

The `"hpa"` engine creates a standard Kubernetes `HorizontalPodAutoscaler` that scales pods based on average CPU utilization.

**To configure in `jac.toml`:**

```toml
[scale.kubernetes]
min_replicas = 2
max_replicas = 10
cpu_utilization_target = 70   # Scale out when average CPU exceeds 70%
```

> **Note:** The HPA engine only supports CPU and memory metrics. Configuring any other trigger type in `extra_triggers` under the HPA engine fails the deploy with an error telling you to set `autoscaler_engine = "keda"`.

#### KEDA Engine (Event-Driven Autoscaling)

The `"keda"` engine creates a `ScaledObject` custom resource instead of an HPA. It supports the full [KEDA trigger catalogue](https://keda.sh/docs/latest/scalers/) (Prometheus, Redis, RabbitMQ, Kafka, HTTP, and more) and enables scale-to-zero.

!!! note
    KEDA must be installed on the cluster before using this engine. If KEDA CRDs are absent at deploy time, jac-scale emits an install warning with a link to the [KEDA installation docs](https://keda.sh/docs/latest/deploy/) and the deploy continues with the Deployment's static replica count -- 1 for single-app deploys, the configured per-service `replicas` for microservices (no autoscaler is created).

!!! note "HTTP-activated workloads also require the KEDA HTTP Add-on"
    Workloads scaled via `apply_http_activation` (HTTP request-driven scale-to-zero) require the [KEDA HTTP Add-on](https://keda.sh/docs/latest/deploy/#http-add-on) in addition to core KEDA. Call `KEDAAutoscaler.discover_capabilities()` to check both together: it returns a `KEDACapabilities` object that distinguishes a missing core install from a missing or outdated HTTP Add-on, an RBAC-denied check from a genuinely absent API, and a missing external-scaler or interceptor-proxy Service, each with its own diagnostic. Results are cached per cluster; pass `refresh=True` or call `invalidate_capabilities()` to force a recheck. `apply_http_activation` calls `discover_capabilities()` automatically and raises when the Add-on is installed but broken, instead of deploying a workload that will never receive traffic. If the Add-on is simply absent, it logs a warning and skips activation rather than failing the deploy.

    Install both with Helm:
    ```bash
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install keda kedacore/keda -n keda --create-namespace --wait
    helm install http-add-on kedacore/keda-add-ons-http -n keda --wait
    ```

    Upgrading an older HTTP Add-on install (pre-0.14, `HTTPScaledObject` only) to the current `InterceptorRoute` API:
    ```bash
    helm upgrade http-add-on kedacore/keda-add-ons-http -n keda --wait
    ```

    Chart names, flags, and required values can change over time, so every install/upgrade command surfaced by `discover_capabilities()` also links to the current getting-started guide as the authoritative fallback: [https://keda.sh/http-add-on/0.15/getting-started/](https://keda.sh/http-add-on/0.15/getting-started/).

**Switching between engines is safe.** Each engine removes the other engine's resource (`ScaledObject` or `HPA`) on apply, so two autoscalers never compete for `spec.replicas` on the same Deployment.

!!! note "Scale-down pacing"
    `autoscaler_cooldown` governs scale-down for **all** trigger types under both engines: it is applied as the HPA scale-down stabilization window (`behavior.scaleDown.stabilizationWindowSeconds`, clamped to 0-3600), overriding the Kubernetes default of 5 minutes. It is also written (unclamped) as the ScaledObject's `cooldownPeriod`, which KEDA applies to event-driven triggers before dropping to `idle_replicas` (inert for CPU/memory triggers). Scale-up pacing is controlled by `autoscaler_scale_up_stabilization` and `autoscaler_scale_up_max_pods`.

!!! tip "Scaling to zero right after a fresh deploy?"
    On a fresh deploy, triggers may read as inactive before the app has served its first request, making KEDA drop straight to `idle_replicas`. Set `autoscaler_initial_cooldown` (KEDA's `initialCooldownPeriod`) to delay scale-down/idle eligibility after the ScaledObject is created and give pods time to settle:
    ```toml
    autoscaler_initial_cooldown = 120  # no scale-down for 2 minutes after deploy
    ```

**KEDA-specific configuration (`[scale.kubernetes]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `idle_replicas` | `null` | Replica count when all triggers go inactive. Set to `0` for scale-to-zero. Omit to fall back to `min_replicas`. |
| `autoscaler_polling_interval` | `30` | Seconds between trigger evaluations. |
| `autoscaler_cooldown` | `300` | Seconds of continuous inactivity before scaling down to `idle_replicas`. |
| `autoscaler_initial_cooldown` | `0` | Seconds after a fresh deploy before scale-to-zero becomes eligible. Prevents cold-start thrash on slow-booting apps. |
| `extra_triggers` | `[]` | Array of KEDA trigger tables. **Setting this replaces the automatic CPU/memory triggers** -- include a `cpu` trigger explicitly if you still want CPU scaling. In microservice deployments these triggers apply to the gateway only; use per-service `triggers` for individual services. Under the KEDA engine, duplicate trigger names fail the deploy. See trigger entry keys below. |

**Trigger entry keys (`[[scale.kubernetes.extra_triggers]]`):**

| Key | Default | Description |
|-----|---------|-------------|
| `type` | (required) | KEDA trigger type (e.g. `"prometheus"`, `"redis"`, `"rabbitmq"`, `"kafka"`, `"http"`). See the [KEDA trigger catalogue](https://keda.sh/docs/latest/scalers/). |
| `metadata` | `{}` | Dict of trigger-specific key/value pairs. All values are coerced to strings before being sent to KEDA. For `cpu`/`memory` triggers only `averageUtilization` is read -- any other key is silently ignored and the default target applies (50 for `cpu`, 80 for `memory`). |
| `name` | `null` | Optional label for this trigger in KEDA. When using `auth.secret_refs`, set a unique `name` per trigger; it is included in the hash that generates the `TriggerAuthentication` resource name (e.g. `order-service-daa02e20-ta`), making each resource identifiable in the cluster. Without it, trigger position in the spec is used instead, which shifts if triggers are reordered. |
| `auth.secret_refs` | `{}` | KEDA `TriggerAuthentication` bindings. Each key is a KEDA parameter name; the value is a table with `name` (Kubernetes Secret name) and `key` (key within that Secret). |

**To configure in `jac.toml`:**

```toml
[scale.kubernetes]
autoscaler_engine = "keda"
min_replicas = 1
max_replicas = 10
idle_replicas = 0                 # Scale to zero when all triggers are inactive
autoscaler_polling_interval = 15
autoscaler_cooldown = 120
autoscaler_initial_cooldown = 30  # Wait 30s after deploy before allowing scale-to-zero

# extra_triggers REPLACES the automatic CPU/memory triggers, so the CPU
# trigger is declared explicitly here to keep CPU scaling alongside Prometheus
[[scale.kubernetes.extra_triggers]]
type = "cpu"
metadata = { averageUtilization = "50" }

[[scale.kubernetes.extra_triggers]]
type = "prometheus"
name = "queue-depth"
metadata = { serverAddress = "http://prometheus:9090", metricName = "job_queue_depth", threshold = "100", query = "sum(job_queue_depth)" }

# Trigger with authentication: credential pulled from a Kubernetes Secret
[[scale.kubernetes.extra_triggers]]
type = "rabbitmq"
name = "orders-queue"
metadata = { queueName = "orders", mode = "QueueLength", value = "50", protocol = "amqp" }

[scale.kubernetes.extra_triggers.auth.secret_refs]
host = { name = "rabbitmq-secret", key = "host" }
```

#### HTTP Add-on Activation (Scale-to-Zero on Request)

The KEDA engine above scales on CPU, memory, or any KEDA trigger, but none of those triggers can wake a workload from zero replicas in response to an incoming HTTP request itself. There is nothing listening on the Service to observe traffic when replicas are at zero. The [KEDA HTTP Add-on](https://keda.sh/http-add-on/0.15/) closes that gap: it intercepts HTTP traffic bound for the target, holds the request while a zero-replica workload starts, and forwards it only once the workload is ready.

!!! note
    The KEDA HTTP Add-on installs separately from KEDA core. It ships as its own Helm chart:
    ```bash
    helm repo add kedacore https://kedacore.github.io/charts
    helm repo update
    helm install keda kedacore/keda -n keda --create-namespace --wait
    helm install http-add-on kedacore/keda-add-ons-http -n keda --wait
    ```
    If the HTTP Add-on's CRDs are missing at deploy time, jac-scale logs a warning and skips creating the `InterceptorRoute`/`ScaledObject` rather than failing the deploy, matching the `"keda"` engine's own preflight fallback above.

**Prerequisites**

- KEDA core is installed on the cluster, as described above for the `"keda"` engine.
- The KEDA HTTP Add-on is installed, per the note above.
- The scale target exposes Kubernetes' `/scale` subresource. A `Deployment` or `StatefulSet` works out of the box; a standalone `Pod` is rejected with an error explaining the `/scale` requirement. A custom resource such as a `Rollout` also works, but only once `scale_target_plural` is set, so jac-scale can confirm it exists before applying anything.
- The target's Deployment or StatefulSet, and its Service, already exist. This feature manages the `InterceptorRoute` and `ScaledObject` around an existing workload; it does not create the workload or the Service.
- Exactly one of `target_port` or `target_port_name` is set, and at least one of `concurrency_target` or `request_rate_target` is set. Both are validated up front with an error that names the offending `jac.toml` key.

**Interaction with the base autoscaler:** a target with `http_activation.enabled = true` is scaled entirely by its `ScaledObject` (min/max replicas, scale-to-zero). `jac start --scale` skips creating the base HPA/KEDA autoscaler for that same target automatically -- KEDA's admission webhook rejects a `ScaledObject` for a workload already managed by an HPA (or another `ScaledObject`), so both can't coexist on one target. This also means the deploy's usual post-deploy HTTP reachability check is skipped for that target (it may legitimately be sitting at 0 replicas with nothing to reach); a crash-loop check on the pods runs instead.

**HTTP activation configuration (`[scale.kubernetes.http_activation]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Master switch. Off by default. |
| `min_replicas` | `0` | Replica floor while inactive. `0` enables true scale-to-zero. |
| `max_replicas` | `1` | Replica ceiling once activated. |
| `polling_interval` | `30` | Seconds between HTTP metric evaluations. |
| `cooldown_period` | `300` | Seconds of inactivity before scaling back to `min_replicas`. |
| `target_port` / `target_port_name` | `null` | Container port on the app's Service. Set exactly one. |
| `concurrency_target` | `null` | In-flight-request concurrency target. Set this or `request_rate_target`. |
| `request_rate_target` | `null` | Requests-per-window target, as an alternative to `concurrency_target`. |
| `request_rate_window` / `request_rate_granularity` | `"1m"` / `"1s"` | Window and sampling granularity for `request_rate_target`. |
| `[[rules]]` | `[]` | Routing rules: `hosts` (list), `paths` (list), `headers` (list of `{name, value}`, `value` omitted matches any). Fields within one rule are AND'd; separate rules are OR'd. **Leaving this empty means no traffic matches** -- the interceptor never forwards anything and the target never wakes. At least one rule is required; use `hosts = ["*"]` for an explicit catch-all. |
| `cold_start_status_code` / `cold_start_body` / `cold_start_headers` | `503` / `null` / `{}` | Static placeholder response served while the target cold-starts. |
| `cold_start_fallback_service` / `cold_start_fallback_port` | `null` | Service to forward to while cold-starting, as an alternative to a static placeholder. |
| `timeout_readiness` / `timeout_request` / `timeout_response_header` | `null` | Duration strings (e.g. `"30s"`) the interceptor waits at each stage. |
| `scale_target_kind` / `scale_target_api_version` / `scale_target_plural` | `"Deployment"` / `"apps/v1"` / `null` | Only needed when activating a non-Deployment/StatefulSet target. |

**To configure in `jac.toml` (monolith deploy):**

```toml
[scale.kubernetes.http_activation]
enabled = true
target_port = 8000
concurrency_target = 10
min_replicas = 0
max_replicas = 3
cooldown_period = 300

[[scale.kubernetes.http_activation.rules]]
hosts = ["app.example.com"]
```

**Per-service, in microservice mode:** the same keys apply under `[scale.microservices.services.<name>.http_activation]`. The target Service is always the service's own generated Service; it is never user-set. Any key left unset falls back to `[scale.kubernetes.http_activation]`'s value.

```toml
[scale.microservices.services.jac_coder_sv.http_activation]
enabled = true
target_port = 8000
concurrency_target = 5
min_replicas = 0

[[scale.microservices.services.jac_coder_sv.http_activation.rules]]
paths = ["/coder"]
```

**Traffic topology**

```mermaid
graph TD
    Client["Client"] -->|"HTTP request"| Interceptor["HTTP Add-on Interceptor<br/>(matches InterceptorRoute rules)"]
    Interceptor -->|"pending request count"| Scaler["External Scaler"]
    Scaler -->|"external-push metric"| Operator["KEDA Operator"]
    Operator -->|"scale 0 to 1"| Target["Deployment (0 replicas)"]
    Target -->|"pod Ready"| Interceptor
    Interceptor -->|"forward held request"| Target
    Target -->|"response"| Client
```

jac-scale always reconciles the `InterceptorRoute` before the `ScaledObject`, because the external scaler resolves the target Service and scaling metric from the route when KEDA evaluates the trigger. Reconciling in the other order would leave the `ScaledObject` unable to find its metric source.

!!! warning "Route inbound traffic through the interceptor yourself"
    jac-scale creates the `InterceptorRoute` and `ScaledObject`, but does **not** rewire the gateway or Ingress to the interceptor proxy -- they still resolve the app's own Service directly. With `min_replicas = 0`, a request that reaches the Service instead of the interceptor is refused and never wakes the pod. Only enable `http_activation` on a service whose inbound traffic you have already pointed at the KEDA HTTP interceptor proxy. The gateway is exempt and never inherits a shared `enabled = true` default.

!!! note "Programmatic API for dynamic activation"
    A control-plane process that creates and tears down workloads on demand (for example, an IDE-preview orchestrator spinning up a per-session preview) has no fixed target to put in `jac.toml`. For that case, `HTTPActivationSpec` (`jaclang.scale.deploy.autoscale.http_activation`) and `KEDAAutoscaler.apply_http_activation` / `destroy_http_activation` (`jaclang.scale.deploy.autoscale.keda_autoscaler`) remain available as a direct API, unchanged by the `jac.toml` surface above. Use whichever entry point matches your workload's lifecycle: `jac.toml` for a known, standing service; the programmatic API for one created and destroyed at runtime.

---

### Persistent Storage

Persistent storage covers two volumes: the **application bundle PVC** (holds the `.jab` source bundle, shared by all pods) and the **Postgres data PVC** attached to the provisioned StatefulSet.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `bundle_storage_class` | `""` | StorageClass for the application bundle PVC. The PVC needs `ReadWriteMany`; set this to an RWX-capable class (e.g. EFS, NFS). When empty, the single-app deploy silently omits `storageClassName` and uses the cluster default; the microservice bundle path errors instead, since most cloud default classes are RWO-only |
| `postgres_storage` (`[scale.database]`) | `2Gi` | Storage size for the Postgres data PVC |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
bundle_storage_class = "efs-sc"
postgres_storage = "10Gi"  # under [scale.database]
```

**Postgres PVC resize behaviour:**

- **Increase**: Applying a larger `postgres_storage` on redeploy automatically patches the existing PVC. Your stored data is preserved - only the capacity request is updated.
- **Decrease**: Attempting to set a smaller value than the current PVC size raises an explicit error and aborts the deploy. Shrinking a PVC is not supported by Kubernetes.
- **No change**: If the value matches the current size, no action is taken.

> **Note:** Postgres PVC resize requires the cluster's StorageClass to have `allowVolumeExpansion: true`. Most cloud providers (AWS EBS, GCE PD, Azure Disk) and MicroK8s enable this by default. Verify with `kubectl get storageclass`.
> **Note:** The application bundle PVC has a fixed size (1Gi) and is created once, never resized. Bundle contents are content-addressed, so an unchanged app is not re-uploaded on redeploy.

---

### Container Images

Controls the base images used for the application pod and init containers. Override these when you need a specific Python version or when operating in air-gapped environments.

**Defaults:**

| TOML Key  | Default | Description |
|----------|---------|-------------|
| `python_image` | `""` (auto) | Base image for the application pod. When empty, the deploy resolves the official image matching the runtime channel -- `jaseci/jaclang:latest` (stable), `:dev`, `:experimental-<PR#>`, or `:<x.y.z>` for a `jac-version` pin -- and pins it to an immutable `@sha256:` digest when Docker Hub is reachable (experimental builds are deliberately not digest-pinned). Falls back to `python:3.12-slim` when the registry is unreachable and always on the local-binary channel |
| `wait_image` | `busybox` | Init container image used for dependency wait checks (Postgres readiness) |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
python_image = "my-registry/my-base:1.2.3"
wait_image = "busybox:1.36"
```

---

### System Dependencies

OS (apt) packages your app needs at runtime, e.g. `git` for an app that shells out to it. Declare them at the top level under `[dependencies.system]`; keys are apt package names (version specs are ignored on Debian). They are `apt-get install`ed into the **service container** at startup, so the binaries are present where your app actually runs.

**Default:** `[]` (none)

**To add in `jac.toml`:**

```toml
[dependencies.system]
git = "*"
ffmpeg = "*"
```

Debian only: the default base images (`jaseci/jaclang:<tag>`, fallback `python:3.12-slim`) are Debian-based. For fast-starting pods, prefer a base image that already carries these packages (`python_image`).

---

### Additional Packages

Extra apt packages installed into the **bootstrap init container** (the layer that unpacks and installs the runtime). These are *not* present in the running app; for runtime binaries, use [`[dependencies.system]`](#system-dependencies) instead.

**Default:** `[]` (none)

**To add in `jac.toml`:**

```toml
[scale.kubernetes]
additional_packages = ["xz-utils", "zstd"]
```

---

### Version Pinning

The runtime version in the pod is pinned through the same channels as everywhere else -- there is no separate cluster-side pinning config:

- **Runtime**: pin `[project] jac-version` in `jac.toml` (stable channel), use the `[dev]` / `[experimental]` stanzas, or ship an exact binary via `JAC_SCALE_BINARY_PATH`. See [Runtime Binary](#runtime-binary).
- **Project dependencies** (PyPI/npm): pinned in `jac.toml` as usual; the bootstrap init container runs `jac install` against the shipped, sanitized `jac.toml`, so the pod resolves exactly what you pinned.

Scale, the frontend/client framework, byLLM, and the MCP server are part of `jaclang` core and arrive with the `jac` binary, so there is no plugin package to pin: `jaclang` is not on PyPI, and nothing is pip-installed from GitHub during a deploy.

---

### Monitoring Stack

Scale can deploy a full observability stack (Prometheus + Grafana + kube-state-metrics + node-exporter, and optionally Loki + Grafana Alloy for log aggregation and Tempo for tracing) into the same namespace as your application.

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Collects and stores metrics (ClusterIP - internal only; Grafana queries it as a datasource) |
| **Grafana** | Dashboard UI - served via NGINX Ingress at `/grafana` (NodePort locally, NLB on AWS) |
| **kube-state-metrics** | K8s object state: pod counts, replica health, restart counts |
| **node-exporter** | Host-level metrics: CPU, memory, disk, network per node |
| **Loki** *(optional)* | Log store - receives logs from Alloy (ClusterIP, ephemeral storage) |
| **Tempo** *(optional)* | Trace store - receives OTLP traces from Alloy, added to Grafana as a datasource |
| **Grafana Alloy** *(optional)* | DaemonSet that tails `/var/log/pods` on every node and ships to Loki, with an OTLP lane to Tempo when tracing is on (replaces Promtail, which went EOL on 2026-03-02). Deployed when `loki_enabled` or `tracing_enabled` is set |

**Defaults (`[scale.monitoring]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Deploy the monitoring stack and expose the app's `/metrics` endpoint |
| `k8s_metrics_enabled` | `true` | Include kube-state-metrics and node-exporter exporters |
| `prometheus_admin_password` | `Adminpassword123` | Grafana `admin` login password |

**Defaults (`[scale.kubernetes]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `loki_enabled` | `false` | Deploy Loki + Grafana Alloy and add a Pod Logs dashboard to Grafana. Only read from `[scale.kubernetes]` (setting it under `[scale.monitoring]` has no effect). For microservice deployments use `[scale.microservices.logs] enabled` instead |
| `tracing_enabled` | `false` | Deploy Tempo and wire Alloy's OTLP receiver into it |

**To enable in `jac.toml`:**

```toml
[scale.monitoring]
enabled = true
k8s_metrics_enabled = true
prometheus_admin_password = "StrongPassword123!"
```

**To also enable log aggregation and tracing:**

```toml
[scale.kubernetes]
loki_enabled = true
tracing_enabled = true
```

After deployment, access:

- **Grafana:** `http://localhost:<ingress_node_port>/grafana` - log in with `admin` / `<prometheus_admin_password>`

On AWS clusters, the NGINX Ingress controller is exposed via a Network Load Balancer (NLB). Grafana is accessible at `<nlb-url>/grafana`.

**Prometheus scrape targets:**

- Jaseci application `/metrics` endpoint (authenticated with HTTP basic auth: `[scale.admin] username` + `prometheus_admin_password`, mounted from a Secret)
- kube-state-metrics (pod, deployment, replica, restart state)
- node-exporter (CPU, memory, disk, network per node)
- kubernetes-cadvisor via the API-server proxy (node-level container metrics, when `k8s_metrics_enabled = true`)

**Loki log pipeline (`loki_enabled = true`):**

When enabled, two additional components are deployed:

- **Loki** - single-process log store (port 3100, ClusterIP). Uses filesystem/TSDB storage backed by an `emptyDir` volume; logs are ephemeral and reset on pod restart. Suitable for dev and staging environments.
- **Grafana Alloy** - DaemonSet deployed on every node (tolerates `NoSchedule` taints). Tails `/var/log/pods`, labels each stream with `namespace`, `pod`, and `container`, and pushes to Loki via Kubernetes service discovery. Configured in River syntax. (Alloy is the OpenTelemetry-compatible successor to Promtail, which went EOL on 2026-03-02.)

A **Pod Logs** dashboard is automatically added to Grafana with two panels: log volume (lines/min by namespace/pod) and a live log viewer.

> To collect application metrics, also enable `[scale.monitoring] enabled = true` - see [Prometheus Metrics](#prometheus-metrics).

---

### Deployment Status

Check the live health of all deployed components:

```bash
jac scale status app.jac
```

Displays a table with:

- **Component health** - Jaseci App, Postgres, Prometheus, Grafana, NGINX Ingress (companion components appear when deployed)
- **Pod readiness** - `ready/total` replica count per component
- **Service URLs** - application endpoint and Grafana URL

Status values:

| Value | Meaning |
|-------|---------|
| `Running` | All pods ready |
| `Degraded` | Some pods ready, others not |
| `Pending` | Pods are starting up (no pods ready yet) |
| `Restarting` | One or more pods are crash-looping |
| `Not Deployed` | Component was never provisioned |
| `Unknown` | Component state could not be determined |

---

### Resource Tagging

Kubernetes resources created by jac-scale are labeled `managed: jac-scale` for easy auditing:

```bash
# List jac-scale managed resources across all namespaces
kubectl get all -l managed=jac-scale -A
```

Tagged resource types: Deployments, StatefulSets, DaemonSets, Services, ServiceAccounts, ConfigMaps, Secrets, PersistentVolumeClaims, ClusterRoles/Bindings, HorizontalPodAutoscalers, ScaledObjects (KEDA engine), TriggerAuthentications (KEDA engine).

> **Note:** Pod-template labeling is inconsistent: some pods carry `managed: jac-scale` (kube-state-metrics, node-exporter, Alloy, and all microservice pods), while others carry only `app` (the single-app main pod, Postgres, Prometheus, Grafana, Tempo, Loki, NGINX). `kubectl get pods -l managed=jac-scale` therefore returns a partial, misleading subset -- list pods via their owning Deployment/StatefulSet instead.

---

### Remove Deployment

```bash
jac scale destroy app.jac
```

!!! warning
    You will be prompted to confirm with `y` before deletion proceeds. The command deletes the entire namespace and **all** its resources - including persistent volumes and database data.

Removes:

- Application Deployment and pods
- The Postgres StatefulSet
- PersistentVolumeClaims (data is lost)
- Services, ConfigMaps, Secrets, and autoscaler resources

For partial teardown, pass `--component` with one of `application`, `database`, or `monitoring` to remove just that component while leaving the rest of the deployment running:

```bash
jac scale destroy app.jac --component monitoring
```

---

## Health Checks

The scale server registers built-in endpoints for Kubernetes probes:

- `/healthz/live` -- Liveness: returns `200` while the server process is up
- `/healthz/ready` -- Readiness: returns `200` when serving, `503` while the server is draining during shutdown
- `/healthz` -- Legacy combined health endpoint, treated as liveness

Microservice deployments wire their probes to `/healthz/live` and `/healthz/ready` automatically. Single-app deployments probe `health_check_path` (default `/docs`); point it at `/healthz/ready` to use the built-in endpoint -- see [Health Probes](#health-probes).

**The two probes answer different questions, and the split is deliberate.** Liveness answers "is this process wedged, restart it"; readiness answers "can this pod serve traffic, keep it in Endpoints". A database outage is only ever the second question, so `/healthz/live` (and the legacy `/healthz`) do **not** build a request context and never touch the database: they answer from the process alone. `/healthz/ready` does build one, so it reflects database health, and returns `503` when the database is unreachable rather than failing. The pod leaves Endpoints, stops taking traffic, and rejoins when the database recovers -- with no restart, and no restart loop that would outlive the incident. Any ordinary request whose context cannot be built returns `503` with `Retry-After` for the same reason: an unreachable dependency is not an internal server error.

Point a `livenessProbe` at `/healthz/live` and a `readinessProbe` at `/healthz/ready`. Never point a liveness probe at anything that queries the database.

You can also create custom health walkers:

### Health Endpoint

Create a health walker:

```jac
walker health {
    can check with Root entry {
        report {"status": "healthy"};
    }
}
```

Access at: `POST /walker/health`

### Readiness Check

```jac
walker ready {
    can check with Root entry {
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

## Prometheus Metrics

jac-scale provides built-in Prometheus metrics collection for monitoring HTTP requests and walker execution. When enabled, a `/metrics` endpoint is automatically registered for Prometheus to scrape.

### Configuration

Configure metrics in `jac.toml`:

```toml
[scale.monitoring]
enabled = true                  # Enable metrics collection and /metrics endpoint
endpoint = "/metrics"           # Prometheus scrape endpoint path
namespace = "myapp"             # Metrics namespace prefix
walker_metrics = true           # Enable per-walker execution timing
histogram_buckets = [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1.0, 2.5, 5.0, 10.0]
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `false` | Enable Prometheus metrics collection and `/metrics` endpoint |
| `endpoint` | string | `"/metrics"` | Path for the Prometheus scrape endpoint |
| `namespace` | string | `"jaclang_scale"` | Metrics namespace prefix |
| `walker_metrics` | bool | `false` | Enable walker execution timing metrics |
| `histogram_buckets` | list | `[0.005, ..., 10.0]` | Histogram bucket boundaries in seconds |

### Exposed Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `{namespace}_http_requests_total` | Counter | `method`, `path`, `status_code` | Total HTTP requests processed |
| `{namespace}_http_request_duration_seconds` | Histogram | `method`, `path` | HTTP request latency in seconds |
| `{namespace}_http_requests_in_progress` | Gauge | -- | Concurrent HTTP requests |
| `{namespace}_walker_duration_seconds` | Histogram | `walker_name`, `success` | Walker execution duration (only when `walker_metrics=true`) |
| `{namespace}_read_tier_retries_total` | Counter | `unit` | Requests re-run at SERIALIZABLE after a read-tier unit wrote; one per writing unit per replica per `JAC_DB_RO_WRITER_TTL_S` window (see [Persistence](../persistence.md#connections-and-isolation-tiers-under-jac-serve)) |
| `{namespace}_ws_connections_active` | Gauge | -- | Active WebSocket connections |
| `{namespace}_ws_broadcasts_total` | Counter | -- | WebSocket broadcasts sent |

The standard `prometheus_client` process, platform, and GC collector metrics are exposed alongside these.

### Authentication

The `/metrics` endpoint requires authentication; unauthenticated requests receive `403 Forbidden`. Two schemes are accepted:

- **Bearer token** -- an admin JWT in the `Authorization` header:

    ```bash
    curl -H "Authorization: Bearer <admin_token>" http://localhost:8000/metrics
    ```

- **HTTP basic auth** -- `[scale.admin] username` (default `admin`) + `prometheus_admin_password`. This is how the deployed Prometheus scrapes the endpoint: its scrape config uses `basic_auth` with the password mounted from a Kubernetes Secret.

### Admin Metrics Dashboard

The admin portal includes a monitoring page that displays metrics in a visual dashboard. Access it at `/admin` and navigate to the Monitoring section.

Additionally, the `/admin/metrics` endpoint returns parsed metrics as structured JSON:

```bash
curl -H "Authorization: Bearer <admin_token>" http://localhost:8000/admin/metrics
```

Response format (standard transport envelope):

```json
{
  "type": "response",
  "ok": true,
  "data": {
    "enabled": true,
    "summary": {
      "active_requests": 2,
      "scopes": {
        "app": {
          "requests": 156,
          "server_errors": 1,
          "client_errors": 3,
          "p50": {"value": 0.021, "over": false, "known": true},
          "p95": {"value": 0.31, "over": false, "known": true},
          "p99": {"value": 2.5, "over": true, "known": true},
          "distribution": [
            {"label": "under 25ms", "count": 90},
            {"label": "25 - 100ms", "count": 40},
            {"label": "100 - 500ms", "count": 20},
            {"label": "500ms - 2.5s", "count": 4},
            {"label": "over 2.5s", "count": 2}
          ]
        },
        "other": {"...": "same shape, for admin, health and system paths"},
        "all": {"...": "same shape, for every path"}
      },
      "endpoints": [
        {
          "method": "GET",
          "path": "/",
          "kind": "app",
          "count": 42,
          "failed": 0,
          "p50": {"value": 0.004, "over": false, "known": true},
          "p95": {"value": 0.02, "over": false, "known": true}
        }
      ]
    },
    "metrics": [
      {
        "name": "jaclang_scale_http_requests_total",
        "type": "counter",
        "description": "Total HTTP requests processed",
        "values": [
          {"labels": {"method": "GET", "path": "/", "status_code": "200"}, "value": 42, "suffix": ""}
        ]
      }
    ],
    "raw_available": true
  },
  "error": null,
  "meta": {"extra": {"http_status": 200}}
}
```

`summary` is computed from the exposition since the process started. Paths are classified by their first segment: `admin` and the well-known `health`, `healthz`, `metrics`, `docs` and `openapi.json` segments are `admin`, `health` and `system`; everything else is `app`. The `app` scope covers app paths, `other` covers the rest, and `all` covers both. Percentiles are interpolated inside the request-duration histogram bucket that holds them; `over` is true when the percentile falls in the `+Inf` bucket (the value is then the last finite edge), and `known` is false when nothing has been observed. `endpoints` has one row per method and path, sorted by p95 descending; `failed` counts 4xx and 5xx together.

The admin dashboard monitoring page displays:

- Throughput over a selectable 60s, 5m or 15m window, with errors on their own lane, scoped to app or platform traffic
- p50, p95 and p99 latency, the latency distribution, and the 4xx/5xx error rate for the selected scope
- One row per endpoint with request count, error rate, p50 and p95, sorted by p95
- System metrics (GC collections, memory usage, CPU time, file descriptors)

Requests to the metrics endpoint itself are excluded from tracking.

---

## Kubernetes Secrets

Manage sensitive environment variables securely in Kubernetes deployments using the `[scale.secrets]` section.

### Configuration

```toml
[scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
DATABASE_PASSWORD = "${DB_PASS}"
STATIC_VALUE = "hardcoded-value"
```

Values using `${ENV_VAR}` syntax are resolved from the local environment at deploy time; an unset variable fails the config load. Shell-style fallback operators are supported: `${VAR:-default}` substitutes a default when the variable is unset, and `${VAR:?message}` fails with your own error message. The resolved key-value pairs are created as a proper Kubernetes Secret (`{app_name}-secrets`) and injected into pods via `envFrom.secretRef`.

### How It Works

1. At `jac scale deploy app.jac`, environment variable references (`${...}`) are resolved
2. A Kubernetes `Opaque` Secret named `{app_name}-secrets` is created (or updated if it already exists)
3. The Secret is attached to the deployment pod spec via `envFrom.secretRef`
4. All keys become environment variables inside the container
5. On `jac scale destroy`, the Secret is automatically cleaned up

### Example

```toml
# jac.toml
[scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
JAC_DB_URL = "${JAC_DB_URL}"
JWT_SECRET = "${JWT_SECRET}"
```

```bash
# Set local env vars, then deploy
export OPENAI_API_KEY="sk-..."
export JAC_DB_URL="postgresql://jac:secret123@db.example.com:5432/jac"
export JWT_SECRET="my-jwt-key"

jac scale deploy app.jac
```

This eliminates the need for manual `kubectl create secret` commands after deployment.

---

## Source Distribution

`jac-scale` ships **no application image**, so there is no registry to configure
and nothing to push. This is what makes a deploy work the same way against a
local cluster (MicroK8s, kind, k3d, Minikube, Docker Desktop) and a remote one
(EKS, GKE, AKS) -- neither needs to pull an image you built.

Instead, a deploy:

1. Packs the project source into a content-addressed bundle and copies it into
   the cluster on a PVC.
2. Runs a bootstrap initContainer that unpacks the bundle and installs the
   pinned `jac` runtime into a shared volume.
3. Starts every pod on a stock base image -- `jaseci/jaclang:latest` (or the
   tag matching the channel/version pin: `:dev`, `:experimental-<PR#>`,
   `:<x.y.z>`), pinned to an immutable `@sha256:` digest when Docker Hub is
   reachable (experimental builds excepted) and falling back to
   `python:3.12-slim` when it is not.

Override the base image with `python_image` if you need your own:

```toml
[scale.kubernetes]
python_image = "my-registry/my-base:1.2.3"
```

That image only has to provide the interpreter; your code still arrives via the
bundle, not baked into the image.

!!! note
    Earlier releases shipped a Docker build-and-push pipeline. It was removed,
    along with its flags and config keys; see
    [Breaking Changes](../../community/breaking-changes.md#kubernetes-image-build-pipeline-removed)
    if you are migrating from it.

---

## Pre-Bound ServiceAccount

By default microservice + gateway pods run as the namespace's `default` ServiceAccount. Apps that need to call the Kubernetes API at runtime (creating/watching pods or namespaces, listing custom resources, etc.) need a ServiceAccount pre-bound with the right RBAC. Configure with `service_account_name`:

```toml
[scale.kubernetes]
service_account_name = "myapp-sa"
```

`jac-scale` references the SA but does not create it. Both the SA itself and any RoleBindings or ClusterRoleBindings it needs must already exist in the target namespace before deploy -- typically managed by your platform layer (Helm chart, Terraform module, or `kubectl apply` of cluster-scoped policy). When the field is unset (or empty), pods fall back to the namespace's `default` SA.

Once set, every microservice pod and the gateway pod runs under that SA, and any in-pod Kubernetes client (e.g. `kubernetes` Python package's `load_incluster_config()`) picks up the SA token automatically from `/var/run/secrets/kubernetes.io/serviceaccount/token`.

---

## Cross-Service Shared Volumes

Microservice apps that share filesystem state across pods (an IDE backend that writes a project workspace and a build worker that reads it, a job queue that drops files for a worker pool) declare shared volumes in `jac.toml`:

```toml
[[scale.microservices.shared_volumes]]
name = "workspace"
mount_path = "/data/workspace"
services = ["builder_sv", "build_worker"]
size = "10Gi"
access_mode = "ReadWriteMany"
storage_class = "efs-sc"
```

Each entry is an [array of tables](https://toml.io/en/v1.0.0#array-of-tables) (note the double brackets); declare multiple by repeating the block.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | PVC name. Normalized to DNS-1123 automatically (lowercased, `_` becomes `-`). |
| `mount_path` | yes | Where the volume mounts inside each pod. |
| `services` | yes | Module names from `[scale.microservices.routes]` that get this mount. The gateway can also be listed (use `__gateway__`) but rarely needs to. |
| `sub_path` | no | Mount only this subdirectory of the volume (`volumeMounts.subPath`). |
| `size` | no (PVC mode) | Requested storage, e.g. `10Gi`. Default `1Gi`. |
| `access_mode` | no (PVC mode) | One of `ReadWriteMany` (most common for cross-pod), `ReadWriteOnce` (default), `ReadOnlyMany`. ReadWriteMany requires an RWX-capable storage class. |
| `storage_class` | no (PVC mode) | The StorageClass to bind to. Empty uses the cluster default. Cloud providers' RWX classes: AWS `efs-sc`, GCP Filestore CSI, Azure Files. |
| `host_path` | yes (hostPath mode) | Local-cluster-only alternative; binds the volume to a directory on the host node. Use only on MicroK8s / k3d / kind / Minikube; will not survive a pod move on multi-node clusters. |

PVC mode and hostPath mode are mutually exclusive per entry. K-track applies PVCs before Deployments so pods do not crash-loop on "PVC not found".

> **EFS gotcha.** AWS EFS CSI access points enforce a POSIX UID on every file. When the EFS UID differs from the pod's running UID, in-pod `git` commands against the shared volume trip CVE-2022-24765 dubious-ownership checks. Work around it with `git config --system --add safe.directory '*'` in your pod (e.g. via a custom `python_image`), or set a matching `securityContext` on the pod (`runAsUser` / `fsGroup` -- not yet exposed in `[scale.kubernetes]`, on the roadmap).

---

## Microservice Mode in Kubernetes

When `[scale.microservices].enabled = true` and you run `jac scale deploy` against a Kubernetes cluster, every entry in `[scale.microservices.routes]` becomes its own Deployment + Service + HPA + PodDisruptionBudget. The gateway runs as a separate pod that fronts every microservice via its routes prefix.

### Auto-Injected Peer URLs

Outside Kubernetes, sv-to-sv calls find peer providers via auto-spawn (single-process mode) or `JAC_SV_<MODULE>_URL` env vars (manual multi-host setup). Inside `jac scale deploy` Kubernetes mode, K-track auto-injects those env vars on every pod, derived from the routes table:

```text
JAC_SV_<PEER_MODULE>_URL=http://<peer>-service.<namespace>.svc.cluster.local:<container_port>
```

The env-var key uses the raw module name (the peer's key in `[scale.microservices.routes]`) upper-cased and joined with `JAC_SV_..._URL`. The URL host uses the Kubernetes Service name with DNS-1123 normalization (so `jac_coder_sv` becomes `jac-coder-sv-service`). Self is skipped (no service points env at itself).

Alongside the peer URLs, every pod also receives `JAC_SV_ROUTES` (the full routes map as JSON), `K8S_APP_NAME`, and `K8S_NAMESPACE`. Every pod's entrypoint (gateway included) also exports `JAC_SV_SIBLING=1` -- a shell export in the container command, not a PodSpec `env:` entry. (Sibling-only scoping of that variable exists only in local multi-process mode.)

You do not write these env vars by hand in deployed K8s mode; K-track derives them from `[scale.microservices.routes]` and the configured namespace.

Per-service env overrides under `[scale.microservices.services.<name>.env]` cannot shadow these keys. A stale override would silently route sv-to-sv calls to a wrong backend. To point a peer at a non-cluster URL (e.g. a vendor SaaS), use a per-service `deployment_overlay` (which merges raw manifest fields, including env) or edit the Deployment env spec after deploy.

### Per-Service Configuration

Each microservice entry takes optional per-service overrides under `[scale.microservices.services.<name>]`:

| Field | Type | Description |
|-------|------|-------------|
| `replicas` | int | Initial replica count (default 1; HPA can scale higher). |
| `file` | str | Module the service pod boots. Without it the deploy resolves root `<name>.jac`, else the single shipped module with that basename anywhere in the tree; zero or several candidates fail the deploy. The implicit `main` service boots the `[project] entry-point` module, read relative to the `jac.toml` directory even when the deploy starts from a subdirectory. |
| `rpc_timeout` | float (seconds) | Per-service sv-to-sv RPC timeout. Default 10s, fine for CRUD; bump to 120-300s for LLM workers. |
| `http_forward_timeout` | float (seconds) | Gateway-to-service HTTP forward timeout. |
| `env` | dict | Extra env vars merged into the pod spec. `JAC_SV_NAME`, `JAC_SV_FILE`, and `JAC_SV_*_URL` are protected (cannot be overridden). |
| `cpu_request` / `cpu_limit` | str | Per-service CPU request/limit (e.g. `"250m"`). |
| `memory_request` / `memory_limit` | str | Per-service memory request/limit (e.g. `"256Mi"`). |
| `hpa.enabled` | bool | Set to `false` to fix replicas at the configured `replicas` count. Applies to both `"hpa"` and `"keda"` engines. |
| `hpa.min` / `hpa.max` | int | Autoscaler replica bounds. Applies to both engines. |
| `hpa.cpu_target` | int (percent) | Target CPU utilization percentage. Default 50%. Applies to both engines. |
| `hpa.memory_target` | int (percent) | Target memory utilization percentage (default 80). A memory trigger is added alongside CPU whenever the service resolves a memory request -- always, unless `memory_request` is explicitly set to `""`. |
| `pdb.enabled` / `pdb.max_unavailable` | bool / int | PodDisruptionBudget controls for this service. |
| `deployment_overlay` | table | Raw manifest fragment deep-merged onto the generated Deployment (escape hatch for fields not exposed above). |
| `[[services.NAME.triggers]]` | list | Per-service KEDA event-driven triggers. Each entry: `type` (str), `metadata` (dict), optional `name` (str), optional `auth.secret_refs` (dict). Requires `autoscaler_engine = "keda"` in `[scale.kubernetes]`. |

```toml
# Example: scale jac_coder_sv hot during LLM workloads, fix the gateway at 2.
[scale.microservices.services.jac_coder_sv]
rpc_timeout = 300.0
hpa = { enabled = true, min = 2, max = 10, cpu_target = 60 }

[scale.microservices.services.__gateway__]
replicas = 2
hpa = { enabled = false }

# KEDA per-service trigger (requires autoscaler_engine = "keda" in [scale.kubernetes])
[[scale.microservices.services.orders_app.triggers]]
type = "prometheus"
name = "order-queue"
metadata = { serverAddress = "http://prometheus:9090", metricName = "pending_orders", threshold = "20", query = "sum(pending_orders_total)" }
```

#### Gateway High Availability

!!! warning "Gateway defaults to a single replica"
    The gateway service (`__gateway__`) is configured like any other service under `[scale.microservices.services]` -- its HPA defaults to `min = 1`. Because the gateway is the single entry point for all external traffic, a pod restart (crash, rolling deploy, node drain) leaves no pod to serve requests until the replacement boots and passes its readiness probe (`readiness_initial_delay` of 10s plus app boot time) -- a window of 503s for every user, regardless of which backend service they are calling.

    Backend services don't have this exposure -- if one of several replicas restarts, the others keep serving. Give the gateway the same redundancy, either as a fixed count or as an autoscaler floor:

    ```toml
    # Fixed count, no autoscaling (same effect as the __gateway__ example above)
    [scale.microservices.services.__gateway__]
    replicas = 2
    hpa = { enabled = false }

    # Or, if you want the gateway to also scale up under load:
    [scale.microservices.services.__gateway__.hpa]
    min = 2
    ```

    Either config keeps a second pod ready to absorb traffic while the first restarts. The difference is whether the gateway can also scale beyond 2 under load (`hpa.enabled = true`) or stays fixed (`hpa.enabled = false`).

### Centralised Logs

Microservice mode can deploy a Loki + Grafana Alloy log aggregation pipeline alongside the existing Prometheus + Grafana monitoring stack. Off by default.

```toml
[scale.microservices.logs]
enabled = true
```

When enabled, `jac scale deploy` deploys:

- **Loki** -- single-process log store (port 3100, ClusterIP). Uses filesystem/TSDB storage backed by `emptyDir` (logs are ephemeral and reset on pod restart; suitable for dev and staging).
- **Grafana Alloy** -- DaemonSet on every node (tolerates `NoSchedule`). Tails `/var/log/pods`, labels each stream with `namespace`, `pod`, and `container`, and pushes to Loki via Kubernetes service discovery. River-syntax config; supersedes Promtail (EOL 2026-03-02).
- **Prometheus + Grafana** -- the full monitoring stack comes along because the Pod Logs dashboard view lives inside Grafana. Equivalent to setting `[scale.monitoring] enabled = true` plus `[scale.kubernetes] loki_enabled = true` on the monolith target.

A **Pod Logs** dashboard is added to Grafana automatically, with two panels: log volume (lines/min by namespace/pod) and a live log viewer.

| Component | Resource | Reach |
|-----------|----------|-------|
| Loki | Deployment + ClusterIP Service `<app>-loki-service:3100` | Cluster-internal only |
| Alloy | DaemonSet | Per node; reads host `/var/log/pods` (read-only) |
| Grafana | Deployment + ClusterIP Service | Cluster-internal in microservice mode (the `/grafana` ingress path is wired by the monolith target only); reach it with `kubectl port-forward svc/<app>-grafana-service 3000:3000` |

> **Storage caveat.** Loki uses `emptyDir` in v0. A Loki pod restart drops in-flight chunks. Persistent storage modes (PVC, S3-compatible object storage) are planned.

<!-- -->

> **Trace correlation.** Microservice mode already propagates `X-Trace-Id`. Lines from every service touched by one request carry the same trace id; grep for it in Grafana with `{namespace="<ns>"} |~ "trace=<id>"`. Structured-JSON emission with `trace_id` as a first-class queryable field is planned.

<!-- -->

> **Multi-tenant note.** Alloy's ClusterRole reads pods cluster-wide and the default Pod Logs dashboard query is `{namespace=~".+"}`, so anyone with Grafana access sees logs from every namespace -- change the default Grafana password and only enable on clusters where that exposure is acceptable. Persistent multi-tenancy is planned.

---

## Setting Up Kubernetes

### MicroK8s (Recommended on Ubuntu)

Official docs: [MicroK8s Getting Started](https://microk8s.io/docs/getting-started)

```bash
# Install MicroK8s
sudo snap install microk8s --classic

# Allow current user to run microk8s without sudo (re-login required)
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Wait until the cluster is ready
microk8s status --wait-ready

# Enable the addons the deploy needs
microk8s enable dns hostpath-storage

# Expose kubectl and the kubeconfig -- the deploy tooling needs both
sudo snap alias microk8s.kubectl kubectl
mkdir -p ~/.kube && microk8s config > ~/.kube/config
chmod 600 ~/.kube/config
```

The last two steps are required, not cosmetic: `jac scale deploy` reads `~/.kube/config` to reach the cluster and shells out to a real `kubectl` binary to seed the source bundle. A shell alias (`alias kubectl='microk8s kubectl'`) is not enough because subprocesses cannot see it. You do not need the MicroK8s `ingress` addon -- the deploy ships its own NGINX ingress controller.

After `jac scale deploy`, the app is reachable at `http://localhost:30080` (see [Ports](#ports)).

### Docker Desktop

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Open Settings > Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"

### Minikube

```bash
# Install -- see https://minikube.sigs.k8s.io/docs/start/
brew install minikube  # macOS

# Start cluster with the ingress addon
minikube start
minikube addons enable ingress
```

With minikube the ingress NodePort is reachable on the VM's address, not localhost: use `http://$(minikube ip):30080`.

---

## Troubleshooting

### Application Not Accessible

```bash
# Check pod status
kubectl get pods

# Check service
kubectl get svc

# Default local ingress access (minikube: http://$(minikube ip):30080)
# http://localhost:30080
```

### Database Connection Issues

```bash
# Check Postgres (StatefulSet)
kubectl get statefulsets
kubectl get deployments

# Check persistent volumes (Postgres and the bundle PVC)
kubectl get pvc

# View database logs (labels are prefixed with your app name)
kubectl logs -l app=<app_name>-postgres
```

### Pods Stuck in Init

The bootstrap initContainer unpacks the source bundle and installs the runtime
before the app container starts, so a pod that never leaves `Init` usually means
that step failed:

```bash
kubectl logs <pod-name> -c jac-bootstrap
kubectl get pvc                     # the bundle PVC must be Bound
```

- A `Pending` PVC means the cluster has no usable StorageClass; set
  `bundle_storage_class` (or a `host_path` volume) to one it does have.
- `Permission denied` while the deploy seeds the bundle PVC means the volume
  root is not writable by the loader (uid 1000). The bundle-loader pod's
  `bundle-perms` init container chowns the mount root on startup (fsGroup is
  not applied on hostPath/NFS or most ReadWriteMany CSI volumes), so this only
  persists when the backend also rejects root `chown` -- for example a
  root-squash NFS export. Make the export writable by uid/gid 1000 or disable
  root squash.
- `ImagePullBackOff` on the base image means the cluster cannot reach
  `jaseci/jaclang`; set `python_image` to a base it can pull.

### General Debugging

```bash
# Describe a pod for events
kubectl describe pod <pod-name>

# Get all resources
kubectl get all

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

## Programmatic SDK

A platform (a PaaS, a CI job, an ops daemon) can drive deploys in-process
instead of shelling out to `jac scale deploy` and parsing stdout. The SDK is
`jaclang.scale.sdk`: a `ScaleClient` plus a `DeploySpec` that carries the whole
deploy configuration in memory. `jac.toml` is never read, nothing prompts for
input, and every call returns structured data. The CLI is unchanged and shares
the same deploy engine underneath.

One call deploys a folder (config keys are the `DeploySpec` fields below;
`app_name` defaults from the folder name):

```jac
import from jaclang.scale.sdk { deploy }

with entry {
    result = deploy("apps/orders", {"namespace": "orders-prod", "replicas": 2});
    print(result.service_url if result.success else result.message);
}
```

The full client, for platforms that need events and lifecycle control:

```jac
import from jaclang.scale.sdk { DeploySpec, ProgressEvent, ScaleClient }

def stream(event: ProgressEvent) {
    print(f"[{event.phase}:{event.status}] {event.message}");
}

with entry {
    client = ScaleClient(kube_context="prod-cluster");
    result = client.deploy(
        DeploySpec(
            app_name="orders",
            namespace="orders-prod",
            source="apps/orders/main.jac",
            secrets={"STRIPE_KEY": "sk-live-1"},
            env={"FEATURE_CHECKOUT": "on"},
            replicas=2,
            labels={"paas.example/project": "orders"}
        ),
        on_event=stream
    );
    if result.success {
        print(f"live at {result.service_url}");
    } else {
        print(f"failed: {result.message}");
    }
}
```

### DeploySpec

`DeploySpec` mirrors the `[scale.*]` tables, in memory:

| Field | Maps to | Notes |
|---|---|---|
| `app_name`, `namespace` | `[scale.kubernetes]` | required / `"default"` |
| `source` | CLI file argument | entry `.jac` file, or a folder containing `main.jac` |
| `target` | `--target` | `"auto"` (default), `"kubernetes"`, `"kubernetes-microservice"` |
| `secrets` | `[scale.secrets]` | shipped as the app Secret; no `.env` file needed |
| `env` | new | plain (non-secret) env vars injected into every service pod |
| `domain`, `replicas`, `resources`, `autoscaler` | `[scale.kubernetes]` | `resources` takes `cpu_request`/`cpu_limit`/`memory_request`/`memory_limit`; `autoscaler` entries are raw config keys (`max_replicas`, `autoscaler_engine`, ...) |
| `client` | `[scale.microservices.client]` | web client build: `entry` (path), or `{"entry": False}` for a headless API app |
| `microservices` | `[scale.microservices]` | `routes`, `services`, `ingress`, ... |
| `kube_context` | new | kubeconfig context to deploy through; empty = current context, falling back to in-cluster |
| `labels` | new | stamped on every generated Deployment and Service (platform-owned tags) |
| `extra` | any `[scale.kubernetes]` key | escape hatch merged last, e.g. `{"bundle_storage_class": "efs-sc"}` |

With `target = "auto"` the SDK resolves exactly like the CLI: the
microservice target when `microservices` declares routes (or sets
`enabled = true`), the single-app `kubernetes` target otherwise. Lifecycle
calls (`destroy`/`status`/`scale`/`service_url`) have no spec to inspect, so
`"auto"` there probes the namespace instead: a `jac-scale.role=gateway`
Deployment means the microservice target, anything else the plain one. Pass
an explicit `target=` to skip the probe (e.g. when the cluster is not
reachable at call time).

### ScaleClient

| Method | Returns |
|---|---|
| `deploy(spec, on_event=None)` | `DeploymentResult{success, service_url, message, details}` -- `details` is the applied manifest bundle |
| `preview(spec)` | the manifest bundle, nothing applied (microservice target only, like `--dry-run`) |
| `destroy(app_name, namespace, component="")` | removes the deployment; never prompts |
| `status(app_name, namespace)` | full status dict (components, pod counts, URLs) |
| `resource_status(app_name, namespace)` | `ResourceStatusInfo{status, replicas, ready_replicas}` |
| `service_url(app_name, namespace)` | externally reachable URL or `None` |
| `scale(app_name, namespace, replicas)` | resizes the app deployment |

`ScaleClient(kube_context=..., logger=...)` sets a default cluster context for
every call and an optional custom logger. When `deploy` is given `on_event`,
the whole run streams typed `ProgressEvent{phase, step, status, message,
detail}` values: one `deploy` start/ok envelope, the `provision`, `bundle`,
`apply`, and `rollout` phases (each with `start`/`ok`, or `error` on failure;
phase *order* is target-specific -- the plain target ships the bundle before
provisioning backends -- so render by arrival, not a fixed sequence), and
every engine log line as a `phase="log"` event -- enough to render live build
output. Without `on_event`, output goes to the console exactly like the CLI.
One caveat on quiet output: if the deploy tooling (kubernetes client et al.)
is not installed yet, the first call installs it and prints pip progress to
stdout.
