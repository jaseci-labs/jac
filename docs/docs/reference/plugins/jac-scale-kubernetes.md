# Scale -- Kubernetes & Operations

> Part of the [Scale subsystem](jac-scale.md).

## Kubernetes Deployment

### Deployment Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Deploy** | `jac start app.jac --scale` | Ship the project source into the cluster and deploy |
| **Preview** | `jac start app.jac --scale --dry-run` | Print the manifests that would be applied; change nothing |
| **Enable HTTPS** | `jac start app.jac --scale --enable-tls` | Enable TLS on a live deployment (no redeploy, run after CNAME propagates) |

There is no image-build step. `jac-scale` does not build, tag, or push a Docker
image, and it needs no registry and no registry credentials: pods run a stock
base image, and your source is shipped into the cluster (see
[Source Distribution](#source-distribution) below).

---

### Runtime Binary

Pods run a prebuilt `jac` binary that carries the jaclang runtime (including the `scale` subsystem). It is never built from source in the pod - the deploy driver selects and ships it. Which binary is shipped depends on the channel:

| Channel | Selected by | Binary shipped |
|---------|-------------|----------------|
| **stable** | no `[dev]` stanza in `jac.toml` (default) | Latest published release |
| **dev** | a `[dev]` stanza in `jac.toml` | Rolling `dev` prerelease (main HEAD) |
| **local** | `JAC_SCALE_BINARY_PATH` set | The exact binary at that path |

Both `stable` and `dev` download the binary from [GitHub Releases](https://github.com/jaseci-labs/jaseci/releases) and run it as-is - there is no source overlay.

**Local binary (`JAC_SCALE_BINARY_PATH`).** Point this environment variable at a `jac` binary you built (or an air-gapped mirror) and the deploy ships that exact file to pods instead of downloading a release. It takes precedence over the `[dev]` stanza:

```bash
export JAC_SCALE_BINARY_PATH=/path/to/jac
jac start app.jac --scale
```

Use this for air-gapped clusters, to pin an exact build, or to deploy a binary you compiled locally. The driver checksum-caches downloaded release binaries per channel, so an unchanged `stable`/`dev` deploy does not re-download on every run.

---

### App Artifact (`.jab`)

The app is packed on the deploy driver into a sealed **`.jab`** image, seeded to the bundle PVC, and extracted into the pod's `/app` volume. The `.jab` contains the project source, a `_precompiled/` sealed image (`MANIFEST.json` + content-keyed `.jir` modules built with the pod binary), and the sanitized `jac.toml`.

Sealing is **mandatory**: if the app cannot be sealed into a valid image, the deploy fails rather than shipping a bundle that cold-compiles on the pod's first boot. When a pod starts, the compiler auto-loads the sibling `_precompiled/` image, so services run from precompiled modules with no on-pod compile step - for both single-app and microservice deployments.

If a module in your project cannot be sealed (for example, a file that fails to compile), the deploy aborts with the seal error. Fix or exclude the offending module and redeploy.

---

### Naming & Namespace

Controls the application name used for all Kubernetes resource names and the namespace resources are created in.

**Defaults:**

| TOML Key  | Default | Description |
|-----------|---------|-------------|
| `app_name` | `jaseci` | Prefix for all K8s resource names (deployments, services, secrets, etc.) |
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
| `http://localhost:30080/cache-dashboard/` | Redis Insight (if `redis_dashboard = true`) |
| `http://localhost:30080/db-dashboard` | Mongo Express (if `mongodb_dashboard = true`) |

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

- A running NGINX ingress controller must already exist in the cluster
- `domain` **must** be set. The shared controller sees Ingress resources from all namespaces, so host-based routing is the only way to differentiate two apps. jac-scale raises an error at deploy time if `domain` is empty when `shared_ingress = true`

**Configuration:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `shared_ingress` | `false` | Use a pre-existing shared controller instead of deploying a dedicated one |
| `shared_ingress_class` | `"nginx"` | IngressClass name of the shared controller |
| `shared_ingress_annotations` | `{}` | Extra annotations merged onto the Ingress. Required to drive non-nginx controllers (AWS ALB, Traefik, GKE). Caller-supplied values take precedence |
| `shared_ingress_tls` | `false` | Set when the controller terminates TLS out-of-band (e.g. ALB via an ACM cert) so the reported URL uses `https`. nginx+cert-manager (`spec.tls`) is detected automatically |

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
| Routing rules | Wildcard (host set by `--enable-tls`) | Host set immediately to `domain` |
| On destroy | Removes controller, RBAC, IngressClass, and Ingress rules | Removes Ingress rules only; controller is untouched |
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

When your pods hold per-user state (e.g. running user processes), you need requests from the same user to always reach the same pod. jac-scale supports opt-in cookie-based session affinity via NGINX.

**Enabled by default.** Disable it in `jac.toml` if not needed:

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

- Your pods run stateful per-user processes (e.g. sandbox environments, background workers per user)
- You need a user to consistently land on the pod that owns their session

**Limitations:**

Sticky sessions ensure routing **while a pod is alive**. If a pod is deleted (e.g. during a rolling deployment), in-flight user processes on that pod are lost. The user is automatically re-routed to a new pod, but any in-memory state is gone. For true resilience, externalize per-user state to Redis or a database so any pod can serve any user.

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
jac start app.jac --scale
```

After deploy, the NLB hostname is printed:

```
Deployment complete! Service available at: http://k8s-default-...elb.amazonaws.com
Point your domain CNAME to: k8s-default-...elb.amazonaws.com
```

#### Step 2 - Add CNAME record

In your DNS registrar (Namecheap, Route 53, Cloudflare, etc.) add:

| Type | Host | Value |
|------|------|-------|
| CNAME | `app` (or `@`) | `k8s-default-...elb.amazonaws.com` |

Wait for DNS propagation (usually 1–15 minutes). Verify with `dig app.example.com`.

#### Step 3 - Enable TLS

```bash
jac start app.jac --scale --enable-tls
```

This installs cert-manager, creates a Let's Encrypt `Issuer`, patches the live Ingress with TLS annotations, and updates all service URLs to HTTPS. No redeployment of your application occurs.

Output:

```
TLS enabled. App is now live at:
  App URL:        https://app.example.com
  Grafana:        https://app.example.com/grafana
  Mongo Express:  https://app.example.com/db-dashboard
  RedisInsight:   https://app.example.com/cache-dashboard
```

> **Note:** `--enable-tls` requires `domain` to be set in `jac.toml`. It will error if no domain is configured.

**Configuration options:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `domain` | `""` | Custom domain name (e.g. `app.example.com`). Leave empty for NLB-only access. |
| `cert_manager_email` | `""` | Email for Let's Encrypt certificate registration and expiry notices. |

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

Accepted suffixes: `Ki`, `Mi`, `Gi` (binary) or `K`, `M`, `G` (decimal).

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
health_check_path = "/health"
readiness_initial_delay = 15
readiness_period = 10
liveness_initial_delay = 30
liveness_period = 30
liveness_failure_threshold = 5
```

> **Tip:** Set `health_check_path = "/health"` to use the built-in liveness and readiness endpoints - see [Health Checks](#health-checks).

---

### Autoscaling

jac-scale supports two autoscaler engines selected via `autoscaler_engine`. Both engines share `min_replicas`, `max_replicas`, and `cpu_utilization_target`; they differ in what additional triggers and behaviours they support.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `autoscaler_engine` | `"hpa"` | Autoscaler engine: `"hpa"` (CPU/memory, default) or `"keda"` (event-driven, scale-to-zero) |
| `min_replicas` | `1` | Minimum number of pods |
| `max_replicas` | `3` | Maximum number of pods |
| `cpu_utilization_target` | `50` | Average CPU % that triggers scale-out. Seeds the CPU trigger for both engines unless explicitly overridden. |

> **Note:** CPU-based scaling requires `cpu_request` to be set. Without a CPU request, Kubernetes cannot compute a utilization percentage.

#### HPA Engine (Default)

The `"hpa"` engine creates a standard Kubernetes `HorizontalPodAutoscaler` that scales pods based on average CPU utilization.

**To configure in `jac.toml`:**

```toml
[scale.kubernetes]
min_replicas = 2
max_replicas = 10
cpu_utilization_target = 70   # Scale out when average CPU exceeds 70%
```

#### KEDA Engine (Event-Driven Autoscaling)

The `"keda"` engine creates a `ScaledObject` custom resource instead of an HPA. It supports the full [KEDA trigger catalogue](https://keda.sh/docs/latest/scalers/) (Prometheus, Redis, RabbitMQ, Kafka, HTTP, and more) and enables scale-to-zero.

!!! note
    KEDA must be installed on the cluster before using this engine. If KEDA CRDs are absent at deploy time, jac-scale emits an install warning with a link to the [KEDA installation docs](https://keda.sh/docs/latest/deploy/) and falls back to static replicas rather than failing the deploy.

**Switching between engines is safe.** Each engine removes the other engine's resource (`ScaledObject` or `HPA`) on apply, so two autoscalers never compete for `spec.replicas` on the same Deployment.

!!! warning "CPU/memory triggers: scale-down always takes ~5 minutes"
    When using CPU or memory triggers, KEDA implements scaling through an internal Kubernetes `HorizontalPodAutoscaler`. Kubernetes applies a built-in 5-minute scale-down stabilization window (`stabilizationWindowSeconds = 300`) to every HPA regardless of the `autoscaler_cooldown` value set in `jac.toml`. Replicas will not decrease until CPU/memory has stayed below the target for a full 5 minutes. The `autoscaler_cooldown` setting is effective only for **event-driven triggers** (e.g. Prometheus, Redis, RabbitMQ) where KEDA directly controls the replica count without going through the HPA stabilization window.

!!! tip "Startup CPU spikes causing unwanted scale-up?"
    Pod initialization (Python imports, FastAPI startup, Jac runtime boot) can briefly spike CPU above the target, causing KEDA to scale up immediately after a fresh deploy before the app has finished starting. Set `autoscaler_initial_cooldown` to delay KEDA's first evaluation and give pods time to settle:
    ```toml
    autoscaler_initial_cooldown = 120  # wait 2 minutes after deploy before scaling
    ```

**KEDA-specific configuration (`[scale.kubernetes]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `idle_replicas` | `null` | Replica count when all triggers go inactive. Set to `0` for scale-to-zero. Omit to fall back to `min_replicas`. |
| `autoscaler_polling_interval` | `30` | Seconds between trigger evaluations. |
| `autoscaler_cooldown` | `300` | Seconds of continuous inactivity before scaling down to `idle_replicas`. |
| `autoscaler_initial_cooldown` | `0` | Seconds after a fresh deploy before scale-to-zero becomes eligible. Prevents cold-start thrash on slow-booting apps. |
| `extra_triggers` | `[]` | Array of additional KEDA trigger tables applied to every service. See trigger entry keys below. |

**Trigger entry keys (`[[scale.kubernetes.extra_triggers]]`):**

| Key | Default | Description |
|-----|---------|-------------|
| `type` | (required) | KEDA trigger type (e.g. `"prometheus"`, `"redis"`, `"rabbitmq"`, `"kafka"`, `"http"`). See the [KEDA trigger catalogue](https://keda.sh/docs/latest/scalers/). |
| `metadata` | `{}` | Dict of trigger-specific key/value pairs. All values are coerced to strings before being sent to KEDA. |
| `name` | `null` | Name for this trigger. Required when using `auth.secret_refs`; used as the `TriggerAuthentication` resource name. |
| `auth.secret_refs` | `{}` | KEDA `TriggerAuthentication` bindings. Each key is a KEDA parameter name; the value is a table with `name` (Kubernetes Secret name) and `key` (key within that Secret). |

**To configure in `jac.toml`:**

```toml
[scale.kubernetes]
autoscaler_engine = "keda"
min_replicas = 1
max_replicas = 10
cpu_utilization_target = 50       # Seeds the automatic CPU trigger
idle_replicas = 0                 # Scale to zero when all triggers are inactive
autoscaler_polling_interval = 15
autoscaler_cooldown = 120
autoscaler_initial_cooldown = 30  # Wait 30s after deploy before allowing scale-to-zero

# Add a Prometheus trigger alongside the automatic CPU trigger
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

---

### Persistent Storage

Controls the PersistentVolumeClaim (PVC) sizes for the application code volume, MongoDB, and Redis StatefulSets.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `pvc_size` | `5Gi` | Storage size for the application code PVC |
| `mongodb_storage_size` | `1Gi` | Storage size for the MongoDB data PVC |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
pvc_size = "20Gi"
mongodb_storage_size = "10Gi"
```

**MongoDB PVC resize behaviour:**

- **Increase**: Applying a larger `mongodb_storage_size` on redeploy automatically patches the existing PVC. Your stored data is preserved - only the capacity request is updated.
- **Decrease**: Attempting to set a smaller value than the current PVC size raises an explicit error and aborts the deploy. Shrinking a PVC is not supported by Kubernetes.
- **No change**: If the value matches the current size, no action is taken.

> **Note:** MongoDB PVC resize requires the cluster's StorageClass to have `allowVolumeExpansion: true`. Most cloud providers (AWS EBS, GCE PD, Azure Disk) and MicroK8s enable this by default. Verify with `kubectl get storageclass`.
> **Note:** `pvc_size` (application code PVC) cannot be changed after creation - it is created once and never resized.

---

### Container Images

Controls the base images used for the application pod and init containers. Override these when you need a specific Python version or when operating in air-gapped environments.

**Defaults:**

| TOML Key  | Default | Description |
|----------|---------|-------------|
| `python_image` | `python:3.12-slim` | Base image for the application pod |
| `busybox_image` | `busybox:1.36` | Init container image used for dependency health checks |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
python_image = "python:3.11-slim"
busybox_image = "busybox:1.35"
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

Debian only: every jac-scale base image is Debian-based (`python:*-slim`). For fast-starting pods, prefer a base image that already carries these packages (`python_image`).

---

### Additional Packages

Extra apt packages installed into the **bootstrap init container** (the layer that clones/unpacks the runtime). These are *not* present in the running app; for runtime binaries, use [`[dependencies.system]`](#system-dependencies) instead.

**Default:** `[]` (none)

**To add in `jac.toml`:**

```toml
[scale.kubernetes]
additional_packages = ["xz-utils", "zstd"]
```

---

### Jaseci Source Pinning (Experimental)

When using `--experimental` mode, the Jaseci plugin packages (byllm and friends) are installed from the GitHub repository instead of PyPI. Pin a specific branch or commit for reproducible builds. (The jaclang runtime itself -- which includes the `scale` subsystem -- always comes from the pod's `jac` binary base image, so it is never installed from PyPI in either mode.)

**Defaults:**

| TOML Key  | Default | Description |
|-----------|---------|-------------|
| `jaseci_repo_url` | `https://github.com/jaseci-labs/jaseci.git` | GitHub repository to install Jaseci packages from |
| `jaseci_branch` | `main` | Repository branch to install from |
| `jaseci_commit` | None | Specific commit SHA - leave empty for latest of the branch |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
jaseci_branch = "develop"
jaseci_commit = "a1b2c3d4"
```

---

### Package Version Pinning

Pin specific PyPI versions for genuine third-party Jaseci plugin packages installed inside the pod. Use `"none"` to skip a package entirely.

> The pod's base image provides the `jac` binary, which is the jaclang runtime -- so jaclang (and the built-in subsystems that ship inside core: `scale`, the client/frontend framework, byLLM, and the MCP server) is host-provided and is never pinned or `pip install`ed here. Only genuine third-party plugins below are installed into the pod.
>
> **Note:** `jaclang` is no longer on PyPI, so the pod image must install the `jac` binary (e.g. via the install script). The cluster deploy code is being migrated to this model; until then, deploys that expect a PyPI `jaclang` will not resolve.

**Defaults:** all packages default to `"latest"` from PyPI.

**To configure in `jac.toml`:**

```toml
[scale.kubernetes.plugin_versions]
# Pin a genuine third-party plugin to an explicit version, or "none" to skip it:
my_third_party_plugin = "1.2.3"   # Pin an exact PyPI version
another_plugin        = "none"    # Skip installation entirely
```

> Scale, the frontend/client framework, byLLM, and the MCP server are all part of `jaclang` core and arrive with the `jac` binary in the pod image, so there is no `jac_scale`, `jac_byllm`, or `jac_mcp` package to pin here -- those subsystems are built into the binary. Use `plugin_versions` only for genuine third-party plugins that are still distributed as separate PyPI packages.

---

### Monitoring Stack

Scale can deploy a full observability stack (Prometheus + Grafana + kube-state-metrics + node-exporter, and optionally Loki + Grafana Alloy for log aggregation) into the same namespace as your application.

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Collects and stores metrics (ClusterIP - internal only, scraped by Grafana) |
| **Grafana** | Dashboard UI - served via NGINX Ingress at `/grafana` (NodePort locally, NLB on AWS) |
| **kube-state-metrics** | K8s object state: pod counts, replica health, restart counts |
| **node-exporter** | Host-level metrics: CPU, memory, disk, network per node |
| **Loki** *(optional)* | Log store - receives logs from Alloy (ClusterIP, ephemeral storage) |
| **Grafana Alloy** *(optional)* | DaemonSet that tails `/var/log/pods` on every node and ships to Loki (replaces Promtail, which went EOL on 2026-03-02) |

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Deploy the monitoring stack and expose the app's `/metrics` endpoint |
| `k8s_metrics_enabled` | `true` | Include kube-state-metrics and node-exporter exporters |
| `loki_enabled` | `false` | Deploy Loki + Grafana Alloy and add a Pod Logs dashboard to Grafana |
| `prometheus_admin_password` | `Adminpassword123` | Grafana `admin` login password |

**To enable in `jac.toml`:**

```toml
[scale.monitoring]
enabled = true
k8s_metrics_enabled = true
prometheus_admin_password = "StrongPassword123!"
```

**To also enable log aggregation:**

```toml
[scale.kubernetes]
loki_enabled = true
```

After deployment, access:

- **Grafana:** `http://localhost:<ingress_node_port>/grafana` - log in with `admin` / `<prometheus_admin_password>`

On AWS clusters, the NGINX Ingress controller is exposed via a Network Load Balancer (NLB). Grafana is accessible at `<nlb-url>/grafana`.

**Prometheus scrape targets:**

- Jaseci application `/metrics` endpoint
- kube-state-metrics (pod, deployment, replica, restart state)
- node-exporter (CPU, memory, disk, network per node)

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

- **Component health** - Jaseci App, Redis, MongoDB, Prometheus, Grafana
- **Pod readiness** - `ready/total` replica count per component
- **Service URLs** - application endpoint and Grafana URL

Status values:

| Value | Meaning |
|-------|---------|
| `Running` | All pods ready |
| `Degraded` | Some pods ready, others not |
| `Pending` | Pods are starting up |
| `Restarting` | One or more pods are crash-looping |
| `Failed` | No pods are running |
| `Not Deployed` | Component was never provisioned |

---

### Resource Tagging

All Kubernetes resources created by jac-scale are labeled `managed: jac-scale` for easy auditing:

```bash
# List all jac-scale managed resources across all namespaces
kubectl get all -l managed=jac-scale -A
```

Tagged resource types: Deployments, StatefulSets, Services, ConfigMaps, Secrets, PersistentVolumeClaims, HorizontalPodAutoscalers, ScaledObjects (KEDA engine), TriggerAuthentications (KEDA engine).

---

### Remove Deployment

```bash
jac scale destroy app.jac
```

!!! warning
    You will be prompted to confirm with `y` before deletion proceeds. The command deletes the entire namespace and **all** its resources - including persistent volumes and database data.

Removes:

- Application Deployment and pods
- Redis and MongoDB StatefulSets
- PersistentVolumeClaims (data is lost)
- Services, ConfigMaps, Secrets, and HPA

---

## Health Checks

Built-in endpoints are available for Kubernetes probes:

- `/health` -- Liveness probe
- `/ready` -- Readiness probe

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
| `namespace` | string | `"jac_scale"` | Metrics namespace prefix |
| `walker_metrics` | bool | `false` | Enable walker execution timing metrics |
| `histogram_buckets` | list | `[0.005, ..., 10.0]` | Histogram bucket boundaries in seconds |

> **Note:** If `namespace` is not set, it is derived from the Kubernetes namespace config (sanitized) or defaults to `"jac_scale"`.

### Exposed Metrics

| Metric | Type | Labels | Description |
|--------|------|--------|-------------|
| `{namespace}_http_requests_total` | Counter | `method`, `path`, `status_code` | Total HTTP requests processed |
| `{namespace}_http_request_duration_seconds` | Histogram | `method`, `path` | HTTP request latency in seconds |
| `{namespace}_http_requests_in_progress` | Gauge | -- | Concurrent HTTP requests |
| `{namespace}_walker_duration_seconds` | Histogram | `walker_name`, `success` | Walker execution duration (only when `walker_metrics=true`) |

### Authentication

The `/metrics` endpoint requires admin authentication. Include the admin token in the `Authorization` header:

```bash
# Scrape metrics (admin token required)
curl -H "Authorization: Bearer <admin_token>" http://localhost:8000/metrics
```

Unauthenticated requests receive a 403 Forbidden response. This protects sensitive server performance data from unauthorized access.

### Admin Metrics Dashboard

The admin portal includes a monitoring page that displays metrics in a visual dashboard. Access it at `/admin` and navigate to the Monitoring section.

Additionally, the `/admin/metrics` endpoint returns parsed metrics as structured JSON:

```bash
curl -H "Authorization: Bearer <admin_token>" http://localhost:8000/admin/metrics
```

Response format:

```json
{
  "status": "success",
  "data": {
    "metrics": [
      {
        "name": "jac_scale_http_requests_total",
        "type": "counter",
        "help": "Total HTTP requests processed",
        "values": [
          {"labels": {"method": "GET", "path": "/", "status_code": "200"}, "value": 42}
        ]
      }
    ],
    "summary": {
      "total_requests": 156,
      "avg_latency_ms": 45.2,
      "error_rate_percent": 0.5,
      "active_requests": 2
    }
  }
}
```

The admin dashboard monitoring page displays:

- HTTP traffic breakdown by method and status code
- Request latency statistics
- Active requests gauge
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

Values using `${ENV_VAR}` syntax are resolved from the local environment at deploy time. The resolved key-value pairs are created as a proper Kubernetes Secret (`{app_name}-secrets`) and injected into pods via `envFrom.secretRef`.

### How It Works

1. At `jac start app.jac --scale`, environment variable references (`${...}`) are resolved
2. A Kubernetes `Opaque` Secret named `{app_name}-secrets` is created (or updated if it already exists)
3. The Secret is attached to the deployment pod spec via `envFrom.secretRef`
4. All keys become environment variables inside the container
5. On `jac scale destroy`, the Secret is automatically cleaned up

### Example

```toml
# jac.toml
[scale.secrets]
OPENAI_API_KEY = "${OPENAI_API_KEY}"
MONGO_PASSWORD = "${MONGO_PASSWORD}"
JWT_SECRET = "${JWT_SECRET}"
```

```bash
# Set local env vars, then deploy
export OPENAI_API_KEY="sk-..."
export MONGO_PASSWORD="secret123"
export JWT_SECRET="my-jwt-key"

jac start app.jac --scale
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
3. Starts every pod on a stock base image -- `jaseci/jaclang:latest` (or
   `:dev` on the dev channel), falling back to `python:3.12-slim` when that tag
   is unreachable.

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
| `name` | yes | PVC name. Must be DNS-1123 (lowercase alphanumeric and `-`). |
| `mount_path` | yes | Where the volume mounts inside each pod. |
| `services` | yes | Module names from `[scale.microservices.routes]` that get this mount. The gateway can also be listed (use `__gateway__`) but rarely needs to. |
| `size` | yes (PVC mode) | Requested storage, e.g. `10Gi`. |
| `access_mode` | yes (PVC mode) | One of `ReadWriteMany` (most common for cross-pod), `ReadWriteOnce`, `ReadOnlyMany`. ReadWriteMany requires an RWX-capable storage class. |
| `storage_class` | yes (PVC mode) | The StorageClass to bind to. Cloud providers' RWX classes: AWS `efs-sc`, GCP Filestore CSI, Azure Files. |
| `host_path` | yes (hostPath mode) | Local-cluster-only alternative; binds the volume to a directory on the host node. Use only on MicroK8s / k3d / kind / Minikube; will not survive a pod move on multi-node clusters. |

PVC mode and hostPath mode are mutually exclusive per entry. K-track applies PVCs before Deployments so pods do not crash-loop on "PVC not found".

> **EFS gotcha.** AWS EFS CSI access points enforce a POSIX UID on every file. The shipped microservice image sets `git config --system --add safe.directory '*'` so in-pod `git` commands against the shared volume do not trip CVE-2022-24765 dubious-ownership checks when the EFS UID differs from the pod's running UID. If you bake your own image, add the same line, or set a matching `securityContext` on the pod (`runAsUser` / `fsGroup` -- not yet exposed in `[scale.kubernetes]`, on the roadmap).

---

## Microservice Mode in Kubernetes

When `[scale.microservices].enabled = true` and you run `jac start --scale` against a Kubernetes cluster, every entry in `[scale.microservices.routes]` becomes its own Deployment + Service + HPA + PodDisruptionBudget. The gateway runs as a separate pod that fronts every microservice via its routes prefix.

### Auto-Injected Peer URLs

Outside Kubernetes, sv-to-sv calls find peer providers via auto-spawn (single-process mode) or `JAC_SV_<MODULE>_URL` env vars (manual multi-host setup). Inside `--scale` Kubernetes mode, K-track auto-injects those env vars on every pod, derived from the routes table:

```text
JAC_SV_<PEER_MODULE>_URL=http://<peer>-service.<namespace>.svc.cluster.local:<container_port>
```

The env-var key uses the raw module name (the value to the right of `sv import from`) upper-cased and joined with `JAC_SV_..._URL`. The URL host uses the Kubernetes Service name with DNS-1123 normalization (so `jac_coder_sv` becomes `jac-coder-sv-service`). Self is skipped (no service points env at itself).

You do not write these env vars by hand in `--scale` K8s mode; K-track derives them from `[scale.microservices.routes]` and the configured namespace.

Per-service env overrides under `[scale.microservices.services.<name>.env]` cannot shadow these keys. A stale override would silently route sv-to-sv calls to a wrong backend, and the right way to point a peer at a non-cluster URL (e.g. a vendor SaaS) is to edit the Deployment env spec directly after deploy.

### Per-Service Configuration

Each microservice entry takes optional per-service overrides under `[scale.microservices.services.<name>]`:

| Field | Type | Description |
|-------|------|-------------|
| `replicas` | int | Initial replica count (default 1; HPA can scale higher). |
| `rpc_timeout` | float (seconds) | Per-service sv-to-sv RPC timeout. Default 10s, fine for CRUD; bump to 120-300s for LLM workers. |
| `image_tag` | str | Override the image tag for just this service (rare; most apps use the same image and select via `JAC_SV_NAME`). |
| `env` | dict | Extra env vars merged into the pod spec. `JAC_SV_NAME` and `JAC_SV_*_URL` are protected (cannot be overridden). |
| `hpa.enabled` | bool | Set to `false` to fix replicas at the configured `replicas` count. Applies to both `"hpa"` and `"keda"` engines. |
| `hpa.min` / `hpa.max` | int | Autoscaler replica bounds. Applies to both engines. |
| `hpa.cpu_target` | int (percent) | Target CPU utilization percentage. Default 70%. Applies to both engines. |
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
    The gateway service (`__gateway__`) is configured like any other service under `[scale.microservices.services]` -- its HPA defaults to `min = 1`. Because the gateway is the single entry point for all external traffic, a pod restart (crash, rolling deploy, node drain) leaves no pod to serve requests until the replacement passes its readiness probe. With the default `readiness_initial_delay = 300`, that is a ~5 minute window of 503s for every user, regardless of which backend service they are calling.

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

When enabled, `jac start --scale` deploys:

- **Loki** -- single-process log store (port 3100, ClusterIP). Uses filesystem/TSDB storage backed by `emptyDir` (logs are ephemeral and reset on pod restart; suitable for dev and staging).
- **Grafana Alloy** -- DaemonSet on every node (tolerates `NoSchedule`). Tails `/var/log/pods`, labels each stream with `namespace`, `pod`, and `container`, and pushes to Loki via Kubernetes service discovery. River-syntax config; supersedes Promtail (EOL 2026-03-02).
- **Prometheus + Grafana** -- the full monitoring stack comes along because the Pod Logs dashboard view lives inside Grafana. Equivalent to setting `[scale.kubernetes].monitoring_enabled = true` and `loki_enabled = true` on the monolith target.

A **Pod Logs** dashboard is added to Grafana automatically, with two panels: log volume (lines/min by namespace/pod) and a live log viewer.

| Component | Resource | Reach |
|-----------|----------|-------|
| Loki | Deployment + ClusterIP Service `<app>-loki-service:3100` | Cluster-internal only |
| Alloy | DaemonSet | Per node; reads host `/var/log/pods` (read-only) |
| Grafana | Deployment + Service, NodePort/NLB via Ingress | `/grafana` on the app's external endpoint |

> **Storage caveat.** Loki uses `emptyDir` in v0. A Loki pod restart drops in-flight chunks. Persistent storage modes (PVC, S3-compatible object storage) land in M-14.c.

<!-- -->

> **Trace correlation.** Microservice mode already propagates `X-Trace-Id` (K-12). Lines from every service touched by one request carry the same trace id; grep for it in Grafana with `{namespace="<ns>"} |~ "trace=<id>"`. Structured-JSON emission with `trace_id` as a first-class queryable field ships in M-14.b.

<!-- -->

> **Multi-tenant note.** Alloy's ClusterRole reads pods cluster-wide and the default Pod Logs dashboard query is `{namespace=~".+"}`, so anyone with Grafana access sees logs from every namespace -- change the default Grafana password and only enable on clusters where that exposure is acceptable. Persistent multi-tenancy lands in M-14.c.

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

The last two steps are required, not cosmetic: `jac start --scale` reads `~/.kube/config` to reach the cluster and shells out to a real `kubectl` binary to seed the source bundle. A shell alias (`alias kubectl='microk8s kubectl'`) is not enough because subprocesses cannot see it. You do not need the MicroK8s `ingress` addon -- the deploy ships its own NGINX ingress controller.

After `jac start --scale`, the app is reachable at `http://localhost:30080` (see [Ports](#ports)).

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
# Check StatefulSets
kubectl get statefulsets

# Check persistent volumes
kubectl get pvc

# View database logs
kubectl logs -l app=mongodb
kubectl logs -l app=redis
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

---

## Sandbox Environments

jac-scale includes a **sandbox system** for creating isolated, ephemeral preview environments. Each sandbox runs a user's Jac application in its own container or pod with resource limits, network isolation, and automatic cleanup -- ideal for live preview, collaborative editing, or CI/CD preview deployments.

### Overview

The sandbox system follows jac-scale's factory pattern: an abstract `SandboxEnvironment` interface with three provider implementations. You choose the provider via configuration, and the factory handles instantiation.

| Provider | Isolation | Use Case |
|----------|-----------|----------|
| `local` | Subprocess | Local development, no container runtime needed |
| `docker` | Container | Staging, basic isolation with Docker |
| `kubernetes` | Pod | Production, full isolation with resource limits and RBAC |

### Configuration

Enable and configure sandboxes in `jac.toml`:

```toml
[scale.sandbox]
enabled = true
type = "kubernetes"              # "kubernetes", "docker", or "local"
namespace = "jac-sandboxes"      # K8s namespace for sandbox pods
max_per_user = 3                 # Maximum concurrent sandboxes per user
ttl_seconds = 3600               # Auto-cleanup after this many seconds (1 hour)
cpu_limit = "500m"               # CPU limit per sandbox
memory_limit = "512Mi"           # Memory limit per sandbox
base_image = "python:3.12-slim"  # Base Docker/K8s image
storage_limit = "256Mi"          # Scratch storage (/tmp) limit
domain_template = "{sandbox_id}.preview.example.com"  # URL template
security_context = true          # Run as non-root, no privilege escalation
network_isolation = true         # Isolate sandboxes from each other
ingress_class = "nginx"          # K8s Ingress class (nginx, alb, traefik)
tls_enabled = false              # Enable TLS via cert-manager
tls_issuer = "letsencrypt-prod"  # cert-manager ClusterIssuer name
proxy_mode = false               # Use shared proxy instead of per-sandbox Ingress
warm_pool_size = 0               # Pre-initialized pods for instant startup (K8s only)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enabled` | bool | `false` | Enable the sandbox system |
| `type` | string | `"local"` | Provider: `"kubernetes"`, `"docker"`, or `"local"` |
| `namespace` | string | `"jac-sandboxes"` | Kubernetes namespace for sandbox resources |
| `max_per_user` | int | `3` | Maximum concurrent sandboxes per user |
| `ttl_seconds` | int | `3600` | Time-to-live before automatic cleanup (seconds) |
| `cpu_limit` | string | `"500m"` | CPU limit per sandbox (K8s format) |
| `memory_limit` | string | `"512Mi"` | Memory limit per sandbox (K8s format) |
| `base_image` | string | `"python:3.12-slim"` | Base container image for sandboxes |
| `storage_limit` | string | `"256Mi"` | Ephemeral storage limit for `/tmp` |
| `domain_template` | string | `"{sandbox_id}.preview.example.com"` | URL template (`{sandbox_id}` is replaced) |
| `security_context` | bool | `true` | Enable security context (non-root, no privilege escalation) |
| `network_isolation` | bool | `true` | Isolate sandboxes from each other |
| `ingress_class` | string | `"nginx"` | Kubernetes Ingress class name |
| `tls_enabled` | bool | `false` | Enable TLS via cert-manager |
| `tls_issuer` | string | `"letsencrypt-prod"` | cert-manager ClusterIssuer name |
| `proxy_mode` | bool | `false` | Use shared routing proxy (see [Proxy Mode](#proxy-mode)) |
| `warm_pool_size` | int | `0` | Number of pre-initialized warm pods (see [Warm Pool](#warm-pool)) |

**Environment Variables (override jac.toml):**

| Variable | Description |
|----------|-------------|
| `JAC_SANDBOX_TYPE` | Provider type (`"kubernetes"`, `"docker"`, `"local"`) |
| `JAC_SANDBOX_NAMESPACE` | Kubernetes namespace |
| `JAC_SANDBOX_DOMAIN` | Domain template |

Configuration priority: environment variables > `jac.toml` > defaults.

---

### Programmatic Usage

Use `SandboxFactory` to create and manage sandboxes in your Jac code:

```jac
import from jaclang.scale.factories.sandbox_factory { SandboxFactory }

# Create sandbox using jac.toml config
glob sandbox = SandboxFactory.get_default();

# Or create with explicit type and config
glob sandbox = SandboxFactory.create("kubernetes", {
    "namespace": "jac-sandboxes",
    "base_image": "python:3.12-slim",
    "memory_limit": "1Gi",
    "ttl_seconds": 1800,
    "domain_template": "{sandbox_id}.preview.example.com"
});
```

#### Creating a Sandbox

```jac
with entry {
    result = sandbox.create(
        user_id="user-123",
        project_id="my-project",
        code_path="/path/to/project/files"
    );

    if result.success {
        print(f"Sandbox ready at: {result.url}");
        print(f"Sandbox ID: {result.sandbox_id}");
    }
}
```

#### Sandbox Lifecycle

```jac
with entry {
    # Check status
    status = sandbox.status("jac-sbx-abc123");
    print(f"State: {status.state}");  # pending, starting, running, stopped, error

    # List user's sandboxes
    sandboxes = sandbox.list_sandboxes("user-123");
    for s in sandboxes {
        print(f"{s.sandbox_id}: {s.state} - {s.url}");
    }

    # Stop a sandbox
    sandbox.stop("jac-sbx-abc123");

    # Destroy and clean up all resources
    sandbox.destroy("jac-sbx-abc123");

    # Clean up expired sandboxes (beyond TTL)
    cleaned = sandbox.cleanup_expired();
    print(f"Cleaned {cleaned} expired sandboxes");
}
```

#### File Operations

Read, write, and manage files inside a running sandbox:

```jac
with entry {
    # Write a file
    sandbox.write_file("jac-sbx-abc123", "main.jac", "with entry { print('hello'); }");

    # Read a file
    result = sandbox.read_file("jac-sbx-abc123", "main.jac");
    print(result["content"]);

    # Read binary files (images) -- returned as base64
    result = sandbox.read_file("jac-sbx-abc123", "assets/logo.png");
    # result = {"success": True, "content": "<base64>", "is_binary": True, "mime_type": "image/png"}

    # Delete a file
    sandbox.delete_file("jac-sbx-abc123", "old_file.jac");

    # List files
    result = sandbox.list_files("jac-sbx-abc123");
    for f in result["files"] {
        print(f);
    }
}
```

**Path Security:** All file paths are validated against directory traversal, absolute paths, and shell metacharacters. Paths like `../`, `/etc/passwd`, or strings containing `;`, `|`, `&`, `` ` `` are rejected.

**Excluded Directories:** File listing automatically skips `.jac/`, `node_modules/`, `__pycache__/`, `dist/`, and `.git/`.

#### Command Execution

```jac
with entry {
    result = sandbox.exec_command("jac-sbx-abc123", "ls -la /app", timeout=30);
    print(result["stdout"]);
}
```

#### Log Retrieval

```jac
with entry {
    result = sandbox.logs("jac-sbx-abc123", offset=0);
    print(result["content"]);
    # result["offset"] contains the byte offset for the next read (streaming)
}
```

---

### Sandbox States

| State | Description |
|-------|-------------|
| `pending` | Pod/container created, waiting to start |
| `starting` | Container starting, installing dependencies |
| `running` | Application fully ready and serving traffic |
| `stopping` | Shutdown in progress |
| `stopped` | Container stopped |
| `error` | Error or crash state |

---

### Local Sandbox Provider

The `local` provider runs each sandbox as a subprocess on the host machine. No container runtime required.

```toml
[scale.sandbox]
enabled = true
type = "local"
```

**How it works:**

- Allocates a port pair from a pool (base ports 5180-5200, stride of 2)
- Runs `jac start --dev -p {port}` as a child process
- Checks for readiness by scanning process output for `"Server ready"`
- Returns `http://localhost:{port}` as the preview URL

**Environment sourcing:**

- Global: `~/.jac-ide/global.env` (if it exists)
- Project: `.env` in the project directory (if it exists)

**Limitations:**

- No isolation between sandboxes
- No resource limits
- Port pool limits concurrent sandboxes (10 by default)
- Development and testing only

---

### Docker Sandbox Provider

The `docker` provider runs each sandbox in an isolated Docker container with resource limits.

```toml
[scale.sandbox]
enabled = true
type = "docker"
base_image = "python:3.12-slim"
memory_limit = "512Mi"
cpu_limit = "500m"
network_isolation = true
```

**How it works:**

- Creates a Docker container from `base_image`
- Copies project files into `/app` via tarball injection
- Runs `jac install && jac start --dev -p 8000`
- Applies resource limits (memory, CPU, storage)
- Optionally creates an isolated Docker bridge network per sandbox
- Polls container health via HTTP until ready (120s timeout)

**Container labels:**

| Label | Value |
|-------|-------|
| `jac-sandbox` | `true` |
| `jac-sandbox-id` | `{sandbox_id}` |
| `jac-sandbox-user` | `{user_id}` |
| `jac-sandbox-project` | `{project_id}` |

**Requirements:** Docker daemon must be running on the host.

---

### Kubernetes Sandbox Provider

The `kubernetes` provider creates isolated pods in a dedicated namespace with RBAC, resource limits, and automatic cleanup. This is the recommended provider for production.

```toml
[scale.sandbox]
enabled = true
type = "kubernetes"
namespace = "jac-sandboxes"
base_image = "python:3.12-slim"
memory_limit = "2Gi"
cpu_limit = "500m"
ttl_seconds = 3600
max_per_user = 3
security_context = true
```

**How it works:**

1. Ensures namespace exists with label `jac-sandbox: namespace`
2. Provisions RBAC (ServiceAccount, Role, RoleBinding) for pod management
3. Packages project files into a ConfigMap (text files in `data`, binary files in `binaryData` as base64)
4. Creates a pod with an init container that unpacks the ConfigMap into `/app`
5. Main container runs `jac install && jac start --dev -p 8000`
6. Creates a Service and Ingress (unless `proxy_mode = true`)
7. Polls pod readiness (container ready + "Server ready" in logs, 120s timeout)
8. Returns the preview URL

**Pod naming:** `jac-sbx-{user}-{project}-{uuid}` (lowercase, max 63 chars per K8s requirements)

**Pod labels:**

| Label | Value |
|-------|-------|
| `jac-sandbox` | `true` |
| `jac-sandbox-id` | `{sandbox_id}` |
| `jac-sandbox-user` | `{user_id}` |
| `jac-sandbox-project` | `{project_id}` |

**Environment variables injected into sandbox pods:**

| Variable | Value | Purpose |
|----------|-------|---------|
| `JAC_SANDBOX_ID` | `{sandbox_id}` | Sandbox identifier |
| `JAC_SANDBOX_USER` | `{user_id}` | Owner user ID |
| `JAC_SANDBOX_PROJECT` | `{project_id}` | Project ID |
| `CHOKIDAR_USEPOLLING` | `1` | Force file watcher to use polling (for HMR) |
| `WATCHPACK_POLLING` | `true` | Webpack polling fallback (for HMR) |

**Resource configuration:**

- Limits: `cpu_limit`, `memory_limit` from config
- Requests: 100m CPU, 64Mi memory (fixed)
- Scratch storage: `storage_limit` as tmpfs on `/tmp`
- Active deadline: `ttl_seconds` (K8s kills the pod after this)
- Graceful shutdown: 10 seconds

**Security context (when enabled):**

- `runAsNonRoot: true`
- `runAsUser: 1000`
- `allowPrivilegeEscalation: false`

**ConfigMap limits:** Project files are packed into a single ConfigMap with a 1MB size limit. Binary files (images, fonts, etc.) are stored in the `binaryData` field using base64 encoding. Files in `.jac/`, `node_modules/`, `__pycache__/`, `dist/`, and `.git/` directories are excluded.

**RBAC auto-provisioning:** On first use, the provider creates a Role (`jac-sandbox-manager`) and RoleBinding in the sandbox namespace with permissions for pods, services, configmaps, and ingresses. If running inside a K8s cluster, it binds the role to the pod's ServiceAccount (via `POD_SERVICE_ACCOUNT` and `POD_NAMESPACE` environment variables).

**Automatic cleanup:** A background thread runs every 60 seconds and:

1. Lists all sandbox pods in the namespace
2. Deletes pods older than `ttl_seconds`
3. Deletes pods in terminal states (Failed, Succeeded)
4. Purges stale registry entries for pods that no longer exist

---

### Ingress Routing

When using `type = "kubernetes"`, sandboxes need to be accessible from the browser. There are two routing modes:

#### Per-Sandbox Ingress (default)

Each sandbox gets its own Kubernetes Ingress resource:

```toml
[scale.sandbox]
proxy_mode = false              # default
ingress_class = "nginx"         # or "alb", "traefik"
domain_template = "{sandbox_id}.preview.example.com"
tls_enabled = true
tls_issuer = "letsencrypt-prod"
```

**Traffic flow:**

```
Browser → Load Balancer → Ingress ({sandbox_id}.preview.example.com) → Service → Pod
```

Each sandbox creates:

- A `ClusterIP` Service: `{sandbox_id}-svc`
- An Ingress resource: `{sandbox_id}-ingress` with the configured hostname

**Custom Ingress annotations:**

```toml
[scale.sandbox.ingress_annotations]
"nginx.ingress.kubernetes.io/proxy-read-timeout" = "3600"
"nginx.ingress.kubernetes.io/proxy-send-timeout" = "3600"
```

**TLS:** When `tls_enabled = true`, cert-manager is used to automatically provision TLS certificates. Requires a `ClusterIssuer` named `tls_issuer` to be deployed in the cluster.

**Drawback:** Creating per-sandbox Ingress resources is slow on some cloud providers (e.g., AWS ALB target group registration takes 30-60 seconds).

#### Proxy Mode

A single shared proxy service routes traffic to all sandboxes by pod IP. No per-sandbox Ingress or Service is created.

```toml
[scale.sandbox]
proxy_mode = true
domain_template = "{sandbox_id}.preview.example.com"
```

**Traffic flow:**

```
Browser → Load Balancer → Wildcard Ingress (*.preview.example.com) → Proxy Service → Pod IP
```

**How it works:**

1. A single proxy deployment runs in the sandbox namespace (2 replicas recommended)
2. The proxy watches all pods labeled `jac-sandbox=true` via the Kubernetes Watch API
3. It maintains an in-memory routing table: `sandbox_id → {ip, phase, ready}`
4. Incoming requests have their `Host` header parsed to extract the `sandbox_id` (e.g., `jac-sbx-abc.preview.example.com → jac-sbx-abc`)
5. HTTP requests are forwarded to `http://{pod_ip}:8000{path}`
6. WebSocket connections are bidirectionally relayed (supports Vite HMR with `vite-hmr` sub-protocol)

**Loading page:** When a sandbox pod isn't ready yet, the proxy returns an auto-refreshing HTML page with a loading spinner. The page refreshes every 2 seconds until the pod is ready, then serves the actual application. This only applies to browser navigation requests (`Accept: text/html`); API calls receive proper 502/503 status codes.

**Advantages over per-sandbox Ingress:**

- Instant routing (no Ingress provisioning delay)
- No per-sandbox K8s resources (Service, Ingress)
- Scales to hundreds of concurrent sandboxes
- Native WebSocket support for HMR

**Proxy environment variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SANDBOX_NAMESPACE` | `jac-sandboxes` | Namespace to watch for sandbox pods |
| `SANDBOX_LABEL` | `jac-sandbox=true` | Label selector for sandbox pods |
| `INTERNAL_PORT` | `8000` | Port on sandbox pods |
| `PROXY_PORT` | `8080` | Port the proxy listens on |

**Deploying the proxy:** K8s manifest templates are included in `jac-scale/targets/kubernetes/templates/sandbox-proxy/`:

- `rbac.yaml` -- ServiceAccount + Role (get/list/watch pods) + RoleBinding
- `deployment.yaml` -- 2-replica Deployment (replace `REPLACE_WITH_IMAGE` with your built proxy image)
- `service.yaml` -- ClusterIP Service on port 8080
- `ingress.yaml` -- Wildcard Ingress (replace `*.example.com` with your domain)

The proxy itself is a Jac application. Build it with a Dockerfile that installs the self-contained `jac` binary (which provides the jaclang runtime, including the built-in `scale` subsystem), then layers in the extra deps it needs:

```dockerfile
FROM python:3.12-slim
# Install the `jac` binary -- no PyPI jaclang; the binary provides the runtime
# (and scale, which is built into core).
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && curl -fsSL https://raw.githubusercontent.com/jaseci-labs/jaseci/main/scripts/install.sh | bash
ENV PATH="/root/.local/bin:${PATH}"
RUN jac install aiohttp kubernetes_asyncio docker
COPY sandbox_proxy.jac /app/sandbox_proxy.jac
WORKDIR /app
EXPOSE 8080
CMD ["jac", "run", "sandbox_proxy.jac"]
```

**Health check endpoint:** `GET /_proxy/health` returns `ok (N routes)` where N is the number of tracked sandbox pods.

---

### Warm Pool

The warm pool pre-creates idle pods that are ready to accept code instantly, eliminating pod scheduling and image pull delays.

```toml
[scale.sandbox]
type = "kubernetes"
warm_pool_size = 3    # Keep 3 idle pods ready
```

**How it works:**

1. On startup, the provider creates `warm_pool_size` pods using `base_image`
2. Warm pods run a wait loop: `while [ ! -f /app/.jac-start ]; do sleep 0.5; done`
3. When a sandbox is requested, a warm pod is claimed and relabeled with the user's sandbox ID
4. Project code is injected via `kubectl exec` (tar stream piped into the pod)
5. A signal file (`/app/.jac-start`) is touched, triggering `jac install && jac start`
6. The pool automatically replenishes in the background

**Warm pod labels:**

| Label | Value |
|-------|-------|
| `jac-sandbox` | `true` |
| `jac-sandbox-pool` | `warm` (idle) or `active` (claimed) |

**Benefits:**

- Eliminates ~10 seconds of pod scheduling + image pull time
- No ConfigMap creation needed (code is injected directly)
- Pool replenishes automatically after each claim

**Fallback:** If no warm pod is available (pool exhausted), the provider falls back to the standard cold-start path (ConfigMap + new pod creation).

---

### HMR (Hot Module Replacement) Support

When using `proxy_mode = true`, Vite HMR works through the proxy:

```
Browser (Vite client) ←→ Proxy (WebSocket relay) ←→ Pod (Vite dev server)
```

The proxy:

- Detects WebSocket upgrade requests via the `Upgrade: websocket` header
- Forwards the `Sec-WebSocket-Protocol` header (e.g., `vite-hmr`) to the backend
- Uses a separate session with no timeout for long-lived WebSocket connections
- Bidirectionally relays `TEXT` and `BINARY` messages
- Properly propagates close events between both sides

**File watcher polling:** Sandbox pods have `CHOKIDAR_USEPOLLING=1` and `WATCHPACK_POLLING=true` environment variables set. This forces Vite's file watcher to use polling instead of `inotify`, which is necessary because files written via `kubectl exec` don't trigger filesystem notification events.

---

### Troubleshooting

#### Sandbox pod stuck in Pending

```bash
kubectl describe pod <pod-name> -n jac-sandboxes
```

Check events for scheduling failures, insufficient resources, or image pull errors.

#### Preview shows loading page indefinitely

```bash
# Check if pod is running
kubectl get pods -n jac-sandboxes -l jac-sandbox-id=<sandbox-id>

# Check pod logs
kubectl logs <pod-name> -n jac-sandboxes -c sandbox
```

Common causes: `jac install` failing (missing dependencies), port conflict, application crash.

#### ConfigMap too large

If your project exceeds the 1MB ConfigMap limit, consider:

- Using `warm_pool_size > 0` (warm pools inject code via tar, no size limit)
- Adding large files to the base image instead
- Excluding unnecessary files from the project directory

#### HMR not updating the preview

Verify the proxy is forwarding WebSocket traffic:

```bash
# Check proxy logs
kubectl logs -l app=sandbox-proxy -n jac-sandboxes

# Verify proxy health
curl http://<proxy-service>:8080/_proxy/health
```

#### Cleaning up stuck sandboxes

```bash
# List all sandbox pods
kubectl get pods -n jac-sandboxes -l jac-sandbox=true

# Delete a specific sandbox
kubectl delete pod <pod-name> -n jac-sandboxes

# Delete all sandboxes
kubectl delete pods -n jac-sandboxes -l jac-sandbox=true
```

---
