# Scale -- Kubernetes & Operations

> Part of the [Scale subsystem](jac-scale.md).

## Kubernetes Deployment

### Deployment Modes

| Mode | Command | Description |
|------|---------|-------------|
| **Deploy** | `jac scale deploy app.jac` | Ship the project source into the cluster and deploy |
| **Preview** | `jac scale deploy app.jac --dry-run` | Print the manifests that would be applied; change nothing |
| **Enable HTTPS** | `jac scale deploy app.jac --enable-tls` | Enable TLS on a live deployment (no redeploy, run after CNAME propagates) |
| **Build only** | `jac scale build app.jac --out build --arch amd64` | Seal the app into `build/` without contacting the cluster |
| **Deploy a build** | `jac scale deploy app.jac --from-build build` | Apply a build without building anything |

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
| **local** | `pod_binary` in the `[dev]` stanza | The exact binary at that path |

Channel precedence is local, then experimental, then dev, then stable -- an `[experimental]` stanza wins over `[dev]`, and `[dev] pod_binary` wins over both.

`stable` and `dev` download the binary from [GitHub Releases](https://github.com/jaseci-labs/jac/releases) and run it as-is - there is no source overlay. On the stable channel, a `[project] jac-version` version spec is resolved against the published releases and that exact version is shipped; the deploy errors if the spec matches no release.

**Local binary (`[dev] pod_binary`).** Point `pod_binary` at a `jac` binary you built (or an air-gapped mirror); a relative path resolves against the project root. The deploy ships that exact file to pods instead of downloading a release, and it takes precedence over every other channel:

```toml
[dev]
pod_binary = "../jac/zig-out/bin/jac"
```

Use this for air-gapped clusters, to pin an exact build, or to deploy a binary you compiled locally. The driver checksum-caches downloaded release binaries per channel and architecture, so an unchanged `stable`/`dev` deploy does not re-download on every run.

**GitHub API rate limit.** Once the release version is known, the binary, its checksum and the admin console download straight from `github.com/jaseci-labs/jac/releases/download/`, which uses no API quota. An exact `jac-version` pin therefore makes no `api.github.com` request, a range makes one listing request, and an unpinned deploy asks the Releases API for the latest release. Unauthenticated, that API allows 60 requests per hour per IP, which a shared CI runner can use up. Set `GH_TOKEN` (or `GITHUB_TOKEN`; `GH_TOKEN` wins) in the environment that runs `jac scale deploy` and those requests use your own quota instead. The token is sent only to `api.github.com`, never to a redirect target or any other host. When the quota is exhausted the deploy stops with an error naming `GH_TOKEN` and the exact-pin alternative.

---

### App Artifact (`.jab`)

The app is packed on the deploy driver into a sealed **`.jab`** image, seeded to the bundle PVC, and extracted into the pod's `/app` volume. The `.jab` contains the project source, a `_precompiled/` sealed image (`MANIFEST.json` + content-keyed `.jir` modules built with the pod binary), and the sanitized `jac.toml` (root and nested project tomls, secrets and `[dev]` sections stripped).

The source copy honors the project's [`.jacignore`](../config/index.md#jacignore) with the same patterns and semantics as `jac check`, on top of a fixed floor of paths that never ship (VCS and build directories, `.env` files, private keys and certificates). A tree parked in `.jacignore` reaches neither the seal stage, the `.jab`, nor the pod, and its nested `jac.toml` is not enumerated either. `.jacignore` itself ships, so editing it moves the bundle's content address and the next deploy re-ships instead of hitting the content-addressed skip.

The seal stage is a valid, sanitized copy of the project: sanitized tomls are written into it before the seal runs, so `[placement.pins]` and nested-project scoping are visible at seal time. The seal compiles exactly the modules that emit server code -- client-only modules (pinned or inferred) produce JS, not pod bytecode, and are skipped via the placement facts API. The per-module placement verdict is recorded in the sealed `MANIFEST.json` (`placement` map, manifest format 5). The seal subprocess timeout defaults to 1800s and is configurable with `[scale] seal_timeout` in `jac.toml`.

**Reusing seals.** A sealed bundle is kept in the project's `.jac/seal-cache/`, keyed by a digest of everything that shapes it: the seal binary, pod architecture, app name, fat/thin mode, the sanitized `jac.toml` and nested tomls, and each source file's relative path, mode and content. A deploy whose inputs match a kept bundle skips the seal. To reuse bundles across checkouts (CI runners, other machines, other deploy hosts), point `[scale] seal_cache` in `jac.toml` (relative to the project or absolute) or the `JAC_SEAL_CACHE` environment variable (which wins) at a directory the deploys share. A deploy then looks in the project cache, then the shared directory, and writes every fresh seal to both. The shared directory is never pruned; keep it outside the project tree (or in `.jacignore`) so its bundles do not become deploy inputs, and remove old bundles yourself. Bundles in the shared directory are written with the deploying user's umask, like any other file, so when deploys run as different users give them a shared group with a group-readable umask (or a setgid directory with a default ACL). Bundles in the project cache stay readable by their owner only.

Sealing is **mandatory**: if the app cannot be sealed into a valid image, the deploy fails rather than shipping a bundle that cold-compiles on the pod's first boot. When a pod starts, the compiler auto-loads the sibling `_precompiled/` image, so services run from precompiled modules with no on-pod compile step - for both single-app and microservice deployments.

If a module in your project cannot be sealed (for example, a file that fails to compile), the deploy aborts with the seal error. Fix the offending module, or park its tree in `.jacignore` if it is not part of the served app, and redeploy.

**Fat bundles.** By default the `.jab` also carries the app's Python dependency closure as wheels under `_vendor/wheels/`, resolved by the seal binary (the same jac version pods run) so pods install their dependencies offline at boot with no PyPI access. The wheels are resolved for the **pod platform**, not the deploy host: CPython of the pod binary, the node architecture (`x86_64` or `aarch64`, see `JAC_NODE_ARCH`), and Linux with glibc 2.36 or newer, which is what the official pod images provide. pip is asked for every tag such a pod accepts, `manylinux2014_<arch>` and each `manylinux_2_17` through `manylinux_2_36` PEP 600 tag, so compiled wheels (`cryptography`, `grpcio`, `bcrypt`, `watchdog`) resolve the same way they would on the pod itself. A dependency that publishes no wheel at all is built on the deploy host with `pip wheel`; the result ships only when it fits the pod (a pure-Python `none-any` wheel always does, a bare Linux compiled wheel only when the host is Linux on the same architecture and its detected glibc is no newer than the pod floor; unknown libc versions and musl hosts are rejected).

`[scale] fat_bundle` in `jac.toml` controls the outcome when a dependency still has no usable wheel: unset, the deploy logs a warning naming the packages and ships a thin bundle whose pods install from PyPI at boot; `fat_bundle = true` makes that a deploy failure; `fat_bundle = false` skips vendoring entirely.

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

Every deploy puts a gateway in front of the app. It is reached through the `gateway-service` Service, a ClusterIP Service on `container_port`. Like every other Service jac-scale creates (Grafana, Prometheus, the database), it has no address outside the cluster.

jac-scale does not install an ingress controller. With no ingress configured, the deploy prints a port-forward command instead of a URL:

```bash
kubectl -n default port-forward svc/gateway-service 8080:8000
# then open http://localhost:8080
```

To give the app an external address, run an ingress controller in the cluster (for example ingress-nginx installed with Helm, the MicroK8s or minikube `ingress` addon, or the AWS Load Balancer Controller), then point an Ingress at the gateway in one of two ways:

- [Shared Ingress](#shared-ingress): set `shared_ingress = true` and `domain` under `[scale.kubernetes]`.
- `[scale.gateway.ingress]`: emit an Ingress for the gateway with your own host, class and annotations.

Either way the deploy creates one Ingress, `gateway-ingress`, in the app's namespace, routing `/` to `gateway-service`.

**Defaults:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `container_port`| `8000` | Port your app listens on inside the pod |
| `ingress_node_port` | `30080` | Port in the URL jac-scale reports and checks after deploying to a local cluster with an Ingress. It does not open a port: set it to the port your ingress controller listens on |

**`[scale.gateway.ingress]` keys:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Emit the `gateway-ingress` Ingress |
| `host` | none | Host rule. Leave it unset to match any host |
| `ingress_class_name` | none | IngressClass of your controller, e.g. `nginx`, `alb`, `gce` |
| `annotations` | `{}` | Controller-specific annotations |

```toml
[scale.gateway.ingress]
enabled = true
host = "myapp.local"
ingress_class_name = "nginx"
```

---

### Shared Ingress

Set `shared_ingress = true` to attach the app's routing rules to an ingress controller that already runs in your cluster, with the app's `domain` as the host.

**When to use shared ingress:**

- You run a cluster-wide controller (for example `ingress-nginx` installed with Helm, or the AWS Load Balancer Controller) and want the app reachable at its own domain
- You deploy several apps to the same cluster and want them behind one controller, told apart by host

**Requirements:**

- An `IngressClass` named `shared_ingress_class` must already exist in the cluster. jac-scale does not check that it exists or that a controller is running behind it, so a wrong class leaves the app unreachable. The controller does not have to be NGINX (see below)
- `domain` **must** be set. The shared controller sees Ingress resources from all namespaces, so host-based routing is the only way to differentiate two apps. jac-scale raises an error at deploy time if `domain` is empty when `shared_ingress = true`

**Configuration:**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `shared_ingress` | `false` | Attach the app's Ingress to an existing controller, with `domain` as the host |
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

**Non-nginx controllers (e.g. AWS ALB).** `shared_ingress_class` may name any controller. jac-scale adds no controller-specific settings of its own, so supply them via `shared_ingress_annotations`:

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

**What the deploy creates in shared mode:**

| Behaviour | Shared |
|-----------|--------|
| Controller | None; the existing controller is used and never modified |
| Ingress | `gateway-ingress` in the app's namespace, routing `/` to `gateway-service` |
| IngressClass | Value of `shared_ingress_class` |
| Routing rules | Host set to `domain` |
| On destroy | Removes the app's Ingress; the controller is untouched |

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
| `readiness_initial_delay` | `0`  | Seconds to wait before first readiness check (the startup probe already gates readiness) |
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

> **Note:** CPU-based scaling requires `cpu_request` to be set. Without a CPU request, Kubernetes cannot compute a utilization percentage. Likewise, memory triggers require `memory_request`; a memory trigger whose resolved request is empty is skipped with a warning under both deploy paths. The default memory trigger is added only when `memory_request` is set for the app or under `[scale.kubernetes]`; the `1Gi` (`2Gi` for the gateway) fallback request never adds one, because a jac server can idle above 80% of it and pin the HPA at `max_replicas`.

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
    KEDA must be installed on the cluster before using this engine. If KEDA CRDs are absent at deploy time, jac-scale emits an install warning with a link to the [KEDA installation docs](https://keda.sh/docs/latest/deploy/) and the deploy continues with the Deployment's static replica count -- 1 for single-app deploys, each app's configured `[apps.<name>.scale] replicas` for a workspace fleet (no autoscaler is created). If the deploying identity is not allowed to list ScaledObjects in the deploy namespace, the deploy fails with an error naming that namespace instead.

!!! note "HTTP-activated workloads also require the KEDA HTTP Add-on"
    Workloads scaled via `apply_http_activation` (HTTP request-driven scale-to-zero) require the [KEDA HTTP Add-on](https://keda.sh/docs/latest/deploy/#http-add-on) in addition to core KEDA. Call `KEDAAutoscaler.discover_capabilities("<your namespace>")` to check both together in the namespace you deploy to: it returns a `KEDACapabilities` object that distinguishes a missing core install from a missing or outdated HTTP Add-on, an RBAC-denied check from a genuinely absent API, and a missing external-scaler or interceptor-proxy Service, each with its own diagnostic. Results are cached per cluster and namespace; pass `refresh=True` or call `invalidate_capabilities()` to force a recheck. `apply_http_activation` calls `discover_capabilities` automatically with its own namespace and raises when the Add-on is installed but broken, instead of deploying a workload that will never receive traffic. If the Add-on is simply absent, it logs a warning and skips activation rather than failing the deploy.

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

    Chart names, flags, and required values can change over time, so every install/upgrade command surfaced by `discover_capabilities` also links to the current getting-started guide as the authoritative fallback: [https://keda.sh/http-add-on/0.15/getting-started/](https://keda.sh/http-add-on/0.15/getting-started/).

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

**Interaction with the base autoscaler:** a target with `http_activation.enabled = true` is scaled entirely by its `ScaledObject` (min/max replicas, scale-to-zero). `jac scale deploy` skips creating the base HPA/KEDA autoscaler for that same target automatically -- KEDA's admission webhook rejects a `ScaledObject` for a workload already managed by an HPA (or another `ScaledObject`), so both can't coexist on one target. This also means the deploy's usual post-deploy HTTP reachability check is skipped for that target (it may legitimately be sitting at 0 replicas with nothing to reach); a crash-loop check on the pods runs instead.

**HTTP activation configuration (`[scale.kubernetes.http_activation]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Master switch. Off by default. |
| `min_replicas` | `0` | Replica floor while inactive. `0` enables true scale-to-zero. |
| `max_replicas` | `1` | Replica ceiling once activated. |
| `polling_interval` | `30` | Seconds between HTTP metric evaluations. |
| `cooldown_period` | `300` | Seconds of inactivity before scaling back to `min_replicas`. |
| `initial_cooldown_period` | `0` | Seconds after the ScaledObject is created before the target may scale to `min_replicas`. A new target has served no request yet, so with `0` KEDA scales it down at once. |
| `target_port` / `target_port_name` | `null` | Container port on the app's Service. Set exactly one. |
| `concurrency_target` | `null` | In-flight-request concurrency target. Set this or `request_rate_target`. |
| `request_rate_target` | `null` | Requests-per-window target, as an alternative to `concurrency_target`. |
| `request_rate_window` / `request_rate_granularity` | `"1m"` / `"1s"` | Window and sampling granularity for `request_rate_target`. |
| `[[rules]]` | `[]` | Routing rules: `hosts` (list), `paths` (list), `headers` (list of `{name, value}`, `value` omitted matches any). Fields within one rule are AND'd; separate rules are OR'd. **Leaving this empty means no traffic matches** -- the interceptor never forwards anything and the target never wakes. At least one rule is required; use `hosts = ["*"]` for an explicit catch-all. |
| `cold_start_status_code` / `cold_start_body` / `cold_start_headers` | `503` / `null` / `{}` | Static placeholder response served while the target cold-starts. |
| `cold_start_fallback_service` / `cold_start_fallback_port` | `null` | Service to forward to while cold-starting, as an alternative to a static placeholder. |
| `timeout_readiness` / `timeout_request` / `timeout_response_header` | `null` | Duration strings (e.g. `"30s"`) the interceptor waits at each stage. |
| `scale_target_kind` / `scale_target_api_version` / `scale_target_plural` | `"Deployment"` / `"apps/v1"` / `null` | Only needed when activating a non-Deployment/StatefulSet target. |
| `interceptor_service_address` | `"keda-add-ons-http-interceptor-proxy.keda:8080"` | `host:port` of the HTTP Add-on interceptor proxy Service that activated apps are routed through. Cluster-wide, so it is read from this block only, never from a per-app `[apps.<name>.scale.http_activation]` override. Change it when the Add-on is installed outside the default `keda` namespace. |

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

**Per app, in a workspace fleet:** the same keys apply under `[apps.<name>.scale.http_activation]`. The target Service is always the app's own generated Service; it is never user-set. Any key left unset falls back to `[scale.kubernetes.http_activation]`'s value.

```toml
[apps.coder.scale.http_activation]
enabled = true
target_port = 8000
concurrency_target = 5
min_replicas = 0

[[apps.coder.scale.http_activation.rules]]
paths = ["/api/coder"]
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

!!! note "Interceptor routing is automatic"
    Once `http_activation.enabled = true` for a service, jac-scale routes traffic to it through the interceptor automatically -- both gateway-forwarded requests (the Ingress path) and sv-to-sv RPC calls (walker/function invocations from another service) resolve the interceptor's proxy address instead of the app's own Service, with a `Host` header set to the service's own Service DNS name so the interceptor's `InterceptorRoute` can tell which target a request is for. No manual Ingress or gateway rewiring is required. The Ingress itself still points at the gateway's own Service, unchanged: the gateway is exempt from `http_activation` and always stays warm, so it never needs to be woken.

    A cold wake holds the request until the pod is Ready, so set `rpc_timeout` and `http_forward_timeout` (under `[apps.<name>.scale]`, or `http_forward_timeout` under `[scale.gateway]`) above the service's cold boot time, and `timeout_readiness` if you set interceptor timeouts; with the 10s / 30s defaults the first call to a service sitting at zero replicas fails. WebSocket connections proxied through the gateway are not yet routed through the interceptor.

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

**Postgres disk usage:**

- `jac scale status` shows how much of the Postgres data PVC is in use and warns once it passes 80%. Raise `postgres_storage` and redeploy before it fills: a full volume stops every write.
- Not all of `postgres_storage` holds your data. Postgres keeps its write-ahead log on the same volume and lets it grow toward 2GB between checkpoints, plus some space for the empty database itself. On the `2Gi` default, your data gets much less than 2Gi.

> **Note:** Postgres PVC resize requires the cluster's StorageClass to have `allowVolumeExpansion: true`. Most cloud providers (AWS EBS, GCE PD, Azure Disk) and MicroK8s enable this by default. Verify with `kubectl get storageclass`.
> **Note:** The application bundle PVC has a fixed size (1Gi) and is created once, never resized. Bundle contents are content-addressed, so an unchanged app is not re-uploaded on redeploy.

---

### Container Images

Controls the base images used for the application pod and init containers. Override these when you need a specific Python version or when operating in air-gapped environments.

**Defaults:**

| TOML Key  | Default | Description |
|----------|---------|-------------|
| `python_image` | `""` (auto) | Base image for the application pod. When empty, the deploy resolves the official image matching the runtime channel -- `jaseci/jaclang:latest` (stable), `:dev`, `:experimental-<PR#>`, or `:<x.y.z>` for a `jac-version` pin -- and pins it to an immutable `@sha256:` digest when Docker Hub is reachable (experimental builds are deliberately not digest-pinned). When Docker Hub cannot be reached, the image is used unpinned. When Docker Hub reports the tag unpublished, pods fall back to `python:3.12-slim`, except on the experimental channel, where the deploy stops. Always `python:3.12-slim` on the local-binary channel |
| `wait_image` | `busybox:1.36` | Init container image used for dependency wait checks (Postgres readiness) |

**To change in `jac.toml`:**

```toml
[scale.kubernetes]
python_image = "my-registry/my-base:1.2.3"
wait_image = "busybox:1.36"
```

---

### System Dependencies

OS (apt) packages your app needs at runtime, e.g. `git` for an app that shells out to it. Declare them at the top level under `[dependencies.system]`; keys are apt package names (version specs are ignored on Debian). They are `apt-get install`ed into the **service container** at startup, so the binaries are present where your app actually runs.

The install is best effort. When every package is already present the step is skipped; when `apt-get` fails the pod reports `could not install system packages (...)` on stderr and starts without them. The official image runs as the unprivileged `jac` user, which cannot install packages, so on that image a declared package that the image does not already carry is never installed: bake it into a custom `python_image` instead.

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

- **Runtime**: pin `[project] jac-version` in `jac.toml` (stable channel), use the `[dev]` / `[experimental]` stanzas, or ship an exact binary via `[dev] pod_binary`. See [Runtime Binary](#runtime-binary).
- **Project dependencies** (PyPI/npm): pinned in `jac.toml` as usual; the bootstrap init container runs `jac install` against the shipped, sanitized `jac.toml`, so the pod resolves exactly what you pinned.

Scale, the frontend/client framework, byLLM, and the MCP server are part of `jaclang` core and arrive with the `jac` binary, so there is no plugin package to pin: `jaclang` is not on PyPI, and nothing is pip-installed from GitHub during a deploy.

---

### Monitoring Stack

Scale can deploy a full observability stack (Prometheus + Grafana + kube-state-metrics + node-exporter, and optionally Loki + Grafana Alloy for log aggregation and Tempo for tracing) into the same namespace as your application.

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Collects and stores metrics (ClusterIP - internal only; Grafana queries it as a datasource) |
| **Grafana** | Dashboard UI, served at `/grafana` (ClusterIP - reach it with `kubectl port-forward`) |
| **kube-state-metrics** | K8s object state: pod counts, replica health, restart counts |
| **node-exporter** | Host-level metrics: CPU, memory, disk, network per node |
| **Loki** *(optional)* | Log store - receives logs from Alloy (ClusterIP; data is ephemeral unless `storage_enabled` is set) |
| **Tempo** *(optional)* | Trace store - receives OTLP traces from Alloy, added to Grafana as a datasource |
| **Grafana Alloy** *(optional)* | DaemonSet that tails `/var/log/pods` on every node and ships to Loki, with an OTLP lane to Tempo when tracing is on (replaces Promtail, which went EOL on 2026-03-02). Deployed when `loki_enabled` or `tracing_enabled` is set |

**Defaults (`[scale.monitoring]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `enabled` | `false` | Deploy the monitoring stack and expose the app's `/metrics` endpoint |
| `k8s_metrics_enabled` | `true` | Include kube-state-metrics and node-exporter exporters |
| `prometheus_admin_password` | `Adminpassword123` | Grafana `admin` login password |
| `storage_enabled` | `false` | Keep Prometheus, Loki and Tempo data on PersistentVolumeClaims. See [Monitoring data storage](#monitoring-data-storage) |
| `storage_class` | `""` | StorageClass for those claims. Empty uses the cluster's default class |
| `prometheus_storage` | `10Gi` | Size of the Prometheus claim |
| `loki_storage` | `10Gi` | Size of the Loki claim |
| `tempo_storage` | `5Gi` | Size of the Tempo claim |
| `loki_retention` | `168h` | How long Loki keeps logs when `storage_enabled` is set |
| `prometheus_cpu_request`, `prometheus_memory_request` | unset | CPU and memory requests for the Prometheus container. See [Monitoring resource requests](#monitoring-resource-requests) |
| `loki_cpu_request`, `loki_memory_request` | unset | CPU and memory requests for the Loki container |
| `tempo_cpu_request`, `tempo_memory_request` | unset | CPU and memory requests for the Tempo container |

**Defaults (`[scale.kubernetes]`):**

| TOML Key | Default | Description |
|----------|---------|-------------|
| `loki_enabled` | `false` | Deploy Loki + Grafana Alloy and add a Pod Logs dashboard to Grafana. Only read from `[scale.kubernetes]` (setting it under `[scale.monitoring]` has no effect). For workspace fleet deployments use `[scale.gateway.logs] enabled` instead |
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

After deployment, reach Grafana through a port-forward:

```bash
kubectl -n <namespace> port-forward svc/<app_name>-grafana-service 3000:3000
```

Then open `http://localhost:3000/grafana` and log in with `admin` / `<prometheus_admin_password>`. The app's Ingress routes only to the gateway, so Grafana is not exposed outside the cluster.

#### Monitoring data storage

By default Prometheus, Loki and Tempo each keep their data on an `emptyDir`, which lives only as long as the pod. A node drain, a lost node or a rollout replaces the pod, and the new one starts with no history.

Set `storage_enabled` to keep the data on PersistentVolumeClaims instead:

```toml
[scale.monitoring]
enabled = true
storage_enabled = true
storage_class = ""           # empty: the cluster's default StorageClass
prometheus_storage = "30Gi"
loki_storage = "20Gi"
tempo_storage = "5Gi"
loki_retention = "168h"
```

With it on, each of the three components gets:

- a `ReadWriteOnce` claim named `<app>-prometheus-data`, `<app>-loki-data` or `<app>-tempo-data`
- a `Recreate` rollout, because the volume attaches to one node at a time. Every later rollout of that component has a few seconds with no pod
- a limit that fits the volume: Prometheus is capped at 80% of the size its claim really has and keeps 15 days at most, Loki keeps `loki_retention`, Tempo keeps 48 hours

Things to know before turning it on:

- **The switch itself replaces each pod once.** Whatever is on the `emptyDir` at that moment is lost one last time.
- **Use a block-storage class.** Leave `storage_class` empty for the cluster default, or name a `ReadWriteOnce` class such as `gp3`. Do not reuse the `ReadWriteMany` class set as `bundle_storage_class`: Prometheus does not support NFS-style file systems.
- **A setting that cannot be applied refuses the deploy.** A size or retention period that is not valid, a `storage_class` the cluster does not have, or an empty `storage_class` on a cluster with no default class stops the deploy before anything is applied. Only the parts a deploy runs are checked, so a leftover `tempo_storage` does not stop an app with tracing off. The class is looked up only while a claim still has to be made. If the deployer may not list StorageClasses, the deploy logs that it could not check and carries on.
- **A claim that already exists is used as it is.** To use volumes you provisioned yourself, create the claims `<app>-prometheus-data`, `<app>-loki-data` and `<app>-tempo-data` before the first deploy. `jac scale destroy` deletes them like any other.
- **Size Loki for its busiest week.** Loki and Tempo drop data by age only, so a volume that fills stays full until it is grown. Sizes are whole-number quantities of at least `1Gi`, and `loki_retention` is hours, days or weeks of at least `24h` (`168h`, `7d`, `1w`).
- **Sizes can be raised, not lowered.** A larger value grows the claim on the next deploy. A smaller one is ignored with a warning, and so is a larger one on a class that cannot expand volumes: the claim keeps its size and Prometheus stays capped to the volume it has. After a size is raised, the cap follows on the next deploy, once the volume has grown. `storage_class` cannot be changed on a claim that exists.
- **Turning it off leaves the claims in place.** The pods go back to `emptyDir`, and the claims keep their data until `jac scale destroy` deletes them, either in full or with `--component monitoring`.

#### Monitoring resource requests

Prometheus, Loki and Tempo are deployed with no CPU or memory request, so nothing is reserved for them and they are among the first pods evicted when a node runs short of memory. On `emptyDir` an evicted pod comes back with no history. Set requests to reserve room for them:

```toml
[scale.monitoring]
enabled = true
prometheus_cpu_request = "100m"
prometheus_memory_request = "1Gi"
loki_cpu_request = "50m"
loki_memory_request = "1Gi"
tempo_cpu_request = "25m"
tempo_memory_request = "512Mi"
```

- **Nothing is set unless you set it.** There are no defaults, so an app that sets none of these keys is deployed exactly as before, and a request another tool put on the Deployment is left as it is. Each key is on its own: set only `loki_memory_request` and only that is sent. An empty string counts as unset.
- **The memory request is the one that protects the pod.** Under memory pressure a node evicts the pods that use more than they requested before any that do not: the lowest priority among them first, then the furthest over. A pod with no request is always over. Set it near what the component really uses (`kubectl top pod`), not far below.
- **Requests only.** No limit is set. The request is what moves these pods down the eviction order, and eviction, like any other pod replacement, is what empties an `emptyDir`. A memory limit would not add to that: it turns a spike into an out-of-memory kill, after which the container restarts in the same pod with its data intact.
- **Setting or changing a request replaces that pod once.** On `emptyDir` that loses its data one more time, so set requests and `storage_enabled` in the same deploy where you can.
- **Removing a key leaves the old request in place.** The deploy stops sending it, and the Deployment keeps the value it has until you change it by hand or the stack is destroyed and deployed again.
- **A value that cannot be applied refuses the deploy.** CPU is millicores or cores (`100m`, `1`, `0.5`). Memory is a whole number with a unit (`768Mi`, `1Gi`). The check runs before anything is applied, with `storage_enabled` on or off, and only for the parts a deploy runs. Only the form is checked: a request that no node can fit is accepted and leaves the new pod Pending, and with `storage_enabled` the old pod is already gone by then.

**Prometheus scrape targets:**

- Jaseci application `/metrics` endpoint (authenticated with HTTP basic auth: `[scale.admin] username` + `prometheus_admin_password`, mounted from a Secret)
- kube-state-metrics (pod, deployment, replica, restart state)
- node-exporter (CPU, memory, disk, network per node)
- kubernetes-cadvisor via the API-server proxy (node-level container metrics, when `k8s_metrics_enabled = true`)

**Loki log pipeline (`loki_enabled = true`):**

When enabled, two additional components are deployed:

- **Loki** - single-process log store (port 3100, ClusterIP). Uses filesystem/TSDB storage on an `emptyDir` volume by default, so logs reset whenever the pod is replaced. Set `[scale.monitoring] storage_enabled = true` to keep them on a volume (see [Monitoring data storage](#monitoring-data-storage)).
- **Grafana Alloy** - DaemonSet deployed on every node (tolerates `NoSchedule` taints). Tails `/var/log/pods` for the pods in the app namespace only, labels each stream with `namespace`, `pod`, and `container`, and pushes to Loki via Kubernetes service discovery. Configured in River syntax. (Alloy is the OpenTelemetry-compatible successor to Promtail, which went EOL on 2026-03-02.)

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
| `Active` | Every desired replica runs the current template and is available |
| `Activating` | Replicas are starting, or a rollout is still in progress |
| `Inactive` | Scaled to zero on purpose: the replica floor is 0 (`idle_replicas = 0` under KEDA, or `http_activation`), so this is the healthy resting state, not an error |
| `Deactivating` | Scaling down; surplus replicas are still draining |
| `Degraded` | Something is wrong: the rollout passed its progress deadline, pods are crash-looping, or the workload sits at zero replicas below its floor |
| `Not Deployed` | Component was never provisioned |
| `Unknown` | Component state could not be determined |

The same verdict backs `ScaleClient.resource_status`, the fleet-ready gate at the end of `jac scale deploy`, and the Ops Console's `/admin/ops/deploy` endpoint, so all four agree about a workload. Scaling intent is read from the `jac-scale.replica-floor` annotation that `jac scale deploy` stamps on each Deployment; a Deployment applied before this annotation existed is treated as having a floor of 1 until it is redeployed.

A Deployment whose replicas an autoscaler owns is redeployed with `spec.replicas` left out of the update, so the count the HPA, ScaledObject or HTTP interceptor set survives. Two consequences follow:

- A service already idled to zero stays at zero through a redeploy, so `jac scale deploy` finishes without ever starting the new revision. The deploy log names those services: the image is unverified until the first request wakes one. Deploy a warm service, or set `idle_replicas` above zero, when a deploy has to prove the new build boots.
- `idle_replicas` is a fleet-wide setting and the gateway is exempt from it, for the reason it is already exempt from `http_activation`: it is the ingress entry point, and nothing wakes it once it sleeps. Put `http_activation` on the services that should sleep instead.

---

### Autoscaler runtime status

`resource_status` reads the Deployment, which reports how many replicas exist and never why. Those are different questions, and three situations produce the same Deployment:

| Zero replicas because | Reality |
|---|---|
| No trigger is firing, KEDA idled it | healthy |
| The scaler cannot reach its metric endpoint | broken, and silent |
| Someone scaled it by hand | neither |

`autoscaler_status` reads the autoscaler's own view to separate them:

```jac
import from jaclang.scale.sdk { ScaleClient }

with entry {
    s = ScaleClient().autoscaler_status("orders", "prod");
    if s.scaler_ready == False {
        print(f"scaler failing: {s.reason}: {s.message}");
    }
}
```

| Field | Meaning |
|---|---|
| `status` | the same `ResourceStatus` vocabulary `resource_status` uses |
| `engine` | `keda` or `hpa` |
| `autoscaler_name` | the live resource, resolved from the target rather than supplied |
| `trigger_active` | a trigger is firing. `None` when the engine cannot say |
| `scaler_ready` | the scaler itself is healthy. `None` when the engine cannot say |
| `conditions` | the ScaledObject's and HPA's conditions, normalized to dicts |
| `resource_version` | the version the status was read at |

`trigger_active` and `scaler_ready` are tri-state on purpose. A plain HPA has nothing corresponding to a trigger firing, and a ScaledObject that could not be read leaves both unknown, so `None` is not `False`: reporting `False` would assert a scaler failure nobody observed. A pod whose Role predates the `keda.sh` read rule gets a 403 here, and the result falls back to the workload's own state rather than raising.

The caller passes a **scale target**, not an autoscaler resource name. Which resource is live depends on the scaling mode (`{target}-scaledobject`, `{target}-http-scaledobject`, `{target}-hpa`), and deriving that is the abstraction's job.

### Observing transitions

Polling `autoscaler_status` on a timer costs one request per target per interval and still reports a change an interval late. `watch_autoscaler_transitions` streams them instead:

```jac
import from jaclang.scale.sdk { ScaleClient }

with entry {
    for t in ScaleClient().watch_autoscaler_transitions("orders", "prod") {
        print(f"{t.scale_target_name}: {t.previous_state} -> {t.state} ({t.reason})");
    }
}
```

**Watch cardinality is the caller's responsibility.** One call opens a bounded number of watches for one namespace, and nothing is shared between callers. A consumer tracking many targets makes **one** call and fans out in its own process; calling it once per target opens one watch per target, which is what the bound exists to avoid.

Transitions are deduplicated: a target only yields when its state actually changes. The opening list seeds that cache and yields nothing, because an observer that has just started has witnessed no transition and reporting current state as one invents history on every restart. When Kubernetes answers `410 Gone`, meaning the stream fell too far behind to resume, the watch relists and keeps the cache, so targets whose state did not move stay silent.

**`observed_at` is not durable history.** It records when *this observer* saw the change, not when the change happened. A transition that occurred while the observer was down surfaces as current state on the next relist, carrying that later timestamp. Nothing here persists transitions, so a caller that needs the real moment something happened keeps its own record.

This watches the ScaledObject, so KEDA-side changes (a trigger firing, a scaler failing) are observed. A pod becoming ready without the ScaledObject changing is not, and needs a second watch.

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

## Shutdown Hooks

jac owns `SIGTERM` while it serves, so a handler an app installs with `signal.signal` never runs. Register shutdown code with the `on_drain` builtin instead. It takes a function with no arguments and returns it, so it also works as a decorator:

```jac
import threading;

glob stop_dispatcher: threading.Event = threading.Event();

@on_drain
def stop_background_work {
    stop_dispatcher.set();
}

with entry {
    on_drain(lambda { print("draining"); });
}
```

Drain hooks start when the server starts draining. They run once per process, on their own thread, in the order they were registered, alongside the requests still in flight, and a coroutine function is awaited. The server waits for them up to what is left of `[serve.timeouts] drain`, so a hook slower than that is cut off at exit. A hook that raises is logged and the others still run. A hook registered after the drain started runs once the requests in flight have finished, within the same budget.

With `[serve.workers] count` above one, hooks registered while the app loads run in the supervisor, where threads started at load time live, and forked workers do not inherit them. Requests run in the workers, so a load-time hook cannot see what they changed: one that flushes a buffer finds it empty in the supervisor, and the workers' copies are never flushed. To run a hook in a worker, call `on_drain` from code that runs there, such as a walker. Registering a function that is already registered does nothing, so pass a named function there, not a lambda. jac logs a warning once more than 100 hooks are registered.

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
| `namespace` | string | `"jaclang_scale"` | Metrics namespace prefix. Anything outside `[a-zA-Z0-9_]` is rewritten to `_`, runs of `_` collapse, and a leading digit gets a `_` prefix; a rewrite logs a warning at startup |
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

`summary` is computed from the exposition since the process started. Paths are classified by their first segment: `admin` and the well-known `health`, `healthz`, `metrics`, `docs` and `openapi.json` segments are `admin`, `health` and `system`; everything else is `app`. The `app` scope covers app paths, `other` covers the rest, and `all` covers both. Percentiles are interpolated inside the request-duration histogram bucket that holds them; `over` is true when the percentile falls in the `+Inf` bucket (the value is then the last finite edge), and `known` is false when nothing has been observed. `distribution` cuts the histogram at the configured `histogram_buckets` edges nearest 25ms, 100ms, 500ms and 2.5s, drops duplicates, and labels each band with the edge it actually uses, so the five bands in the example are the default layout; it is empty until something has been observed. `endpoints` has one row per method and path, sorted by p95 descending; `failed` counts 4xx and 5xx together.

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
   reachable (experimental builds excepted) and used unpinned when it is not.
   A tag Docker Hub reports as unpublished falls back to `python:3.12-slim`;
   on the experimental channel the deploy stops instead.

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

Once set, every microservice pod and the gateway pod runs under that SA (the one exception is the gateway when `ops_console = true`, below), and any in-pod Kubernetes client (e.g. `kubernetes` Python package's `load_incluster_config()`) picks up the SA token automatically from `/var/run/secrets/kubernetes.io/serviceaccount/token`.

### Ops Console ServiceAccount

With `ops_console = true`, `jac-scale` creates a ServiceAccount named `<app_name>-ops`, binds the Ops Console Role to it, and runs only the gateway pod as it. Microservice pods keep `service_account_name`, or the namespace `default` when it is empty, and do not receive the console's permissions. The account is removed with the rest of the console's RBAC when the app is destroyed. The `--show-yaml` output includes the account without jac-scale's labels, so applying it over an account you pre-created never marks yours for deletion; an account created by applying that YAML is likewise left in place by destroy and has to be deleted by hand. The identity that runs the deploy needs permission to create ServiceAccounts in the namespace (it already does when `jac-scale` provisions the in-cluster database or monitoring).

This holds whatever `service_account_name` is: the console's Role is never bound to `default` or to the account your workloads share, because every pod running as that account would inherit it. A gateway that needs `service_account_name` for something else (for example a cloud identity annotated on it) therefore cannot also serve the console; the deploy logs a warning saying so. To give the gateway such an identity, pre-create `<app_name>-ops` with the annotations before the first deploy: an existing account of that name is used as it is and never overwritten. Destroying the app deletes it only when it carries the `managed=jac-scale` and `app=<app_name>` labels, so an account you created without them is left in place.

Redeploying an app that already has the console enabled moves its gateway from the previous account to `<app_name>-ops`, which rolls the gateway pods once.

---

## Cross-App Shared Volumes

Apps of a fleet that share filesystem state across pods (an IDE backend that writes a project workspace and a build worker that reads it, a job queue that drops files for a worker pool) declare shared volumes in `jac.toml`:

```toml
[[scale.gateway.shared_volumes]]
name = "workspace"
mount_path = "/data/workspace"
apps = ["builder", "build_worker"]
size = "10Gi"
access_mode = "ReadWriteMany"
storage_class = "efs-sc"
```

Each entry is an [array of tables](https://toml.io/en/v1.0.0#array-of-tables) (note the double brackets); declare multiple by repeating the block.

| Field | Required | Description |
|-------|----------|-------------|
| `name` | yes | PVC name. Normalized to DNS-1123 automatically (lowercased, `_` becomes `-`). |
| `mount_path` | yes | Where the volume mounts inside each pod. |
| `apps` | yes | App names from `[apps]` that get this mount. The gateway can also be listed (use `__gateway__`) but rarely needs to. |
| `sub_path` | no | Mount only this subdirectory of the volume (`volumeMounts.subPath`). |
| `size` | no (PVC mode) | Requested storage, e.g. `10Gi`. Default `1Gi`. |
| `access_mode` | no (PVC mode) | One of `ReadWriteMany` (most common for cross-pod), `ReadWriteOnce` (default), `ReadOnlyMany`. ReadWriteMany requires an RWX-capable storage class. |
| `storage_class` | no (PVC mode) | The StorageClass to bind to. Empty uses the cluster default. Cloud providers' RWX classes: AWS `efs-sc`, GCP Filestore CSI, Azure Files. |
| `host_path` | yes (hostPath mode) | Local-cluster-only alternative; binds the volume to a directory on the host node. Use only on MicroK8s / k3d / kind / Minikube; will not survive a pod move on multi-node clusters. |

PVC mode and hostPath mode are mutually exclusive per entry. K-track applies PVCs before Deployments so pods do not crash-loop on "PVC not found".

A freshly provisioned volume usually arrives root-owned, and the service container runs as the image's unprivileged `jac` user (uid/gid 1000). Every pod that mounts a shared volume therefore runs a `jac-volume-perms` init container first: a hardened root step that hands the mount root (the `sub_path` directory when one is set) to uid/gid 1000 without touching the data below it, and the pod carries `fsGroup: 1000` with `fsGroupChangePolicy: OnRootMismatch` for the storage backends that honor it. A backend that refuses `chown` (a root-squash NFS export, for example) logs `jac-volume-perms: chown/chmod ... not permitted` in the init container and the pod starts with the permissions as provisioned; make the export writable by uid/gid 1000 in that case.

> **EFS gotcha.** AWS EFS CSI access points enforce a POSIX UID on every file. When the EFS UID differs from the pod's running UID, in-pod `git` commands against the shared volume trip CVE-2022-24765 dubious-ownership checks. Work around it with `git config --system --add safe.directory '*'` in your pod (e.g. via a custom `python_image`), or give the access point uid/gid 1000 to match the pod (`runAsUser` is not yet exposed in `[scale.kubernetes]`).

---

## Service Apps in Kubernetes

A workspace with **service apps** (`[apps.<name>] kind = "service"`; see [Workspaces & Apps](../apps.md)) always deploys as a **fleet**: `jac scale deploy` turns every serving app into its own Deployment + Service + HPA + PodDisruptionBudget, and the deployed app (usually the `web-app`) hosts the gateway pod that fronts each service app at its route (`[apps.<name>] route`, default `/api/<name>`). Whether the apps were colocated locally (`jac run <app>`) or split (`--fleet`) makes no difference here -- `[scale.gateway] colocate` is ignored on deploy. Providers boot before their consumers, in the order of the app dependency graph the compiler recorded.

### Auto-Injected Peer URLs

Outside Kubernetes, bridged calls find their provider app in-process when it is colocated, or through `JAC_APP_<APP>_URL` env vars when it runs as its own process (`--fleet` sets them; a manual multi-host setup sets them by hand). Inside `jac scale deploy` Kubernetes mode, K-track auto-injects those env vars on every pod, derived from `[apps]`:

```text
JAC_APP_<PEER_APP>_URL=http://<peer>-service.<namespace>.svc.cluster.local:<container_port>
```

The env-var key uses the app name (the peer's key in `[apps]`) upper-cased, with any non-alphanumeric character as `_`, joined with `JAC_APP_..._URL`; `JAC_APP_<PEER_APP>_ROUTE` carries the peer's route prefix. The URL host uses the Kubernetes Service name with DNS-1123 normalization (so `social_graph` becomes `social-graph-service`). Self is skipped (no app points env at itself).

Alongside the peer URLs, every pod (gateway included) also receives `JAC_SV_FLEET` (the fleet spec as JSON: every serving app, its route and its boot order), `JAC_SV_SIBLING=1`, `K8S_APP_NAME`, and `K8S_NAMESPACE` as PodSpec `env:` entries. `JAC_SV_SIBLING` tells the runtime it is one pod of a fleet, so it serves its own app instead of colocating the workspace's service apps; it is part of the pod's identity, not something the boot script sets. (Sibling-only scoping of that variable exists only in local fleet mode.)

You do not write these env vars by hand in deployed K8s mode; K-track derives them from `[apps]` and the configured namespace.

Per-app env overrides under `[apps.<name>.scale.env]` cannot shadow these keys. A stale override would silently route bridged calls to a wrong backend. To point a peer at a non-cluster URL (e.g. a vendor SaaS), use a per-app `deployment_overlay` (which merges raw manifest fields, including env) or edit the Deployment env spec after deploy.

### Per-App Configuration

Each app takes optional scale overrides in its `[apps.<name>.scale]` overlay (the same keys a single-app project puts under `[scale.kubernetes]`, scoped to that app):

| Field | Type | Description |
|-------|------|-------------|
| `replicas` | int | Initial replica count (default 1; HPA can scale higher). |
| `rpc_timeout` | float (seconds) | Per-app bridged-call timeout. Default 10s, fine for CRUD; bump to 120-300s for LLM workers. |
| `http_forward_timeout` | float (seconds) | Gateway-to-app HTTP forward timeout. |
| `env` | dict | Extra env vars merged into the pod spec. `JAC_SV_NAME`, `JAC_SV_FILE`, and `JAC_APP_*_URL` are protected (cannot be overridden). |
| `cpu_request` / `cpu_limit` | str | Per-app CPU request/limit (e.g. `"250m"`). |
| `memory_request` / `memory_limit` | str | Per-app memory request/limit (e.g. `"256Mi"`). |
| `hpa.enabled` | bool | Set to `false` to fix replicas at the configured `replicas` count. Applies to both `"hpa"` and `"keda"` engines. |
| `hpa.min` / `hpa.max` | int | Autoscaler replica bounds. Applies to both engines. |
| `hpa.cpu_target` | int (percent) | Target CPU utilization percentage. Default 50%. Applies to both engines. |
| `hpa.memory_target` | int (percent) | Target memory utilization percentage (default 80). A memory trigger is added alongside CPU only when `memory_request` is set for the app or under `[scale.kubernetes]`. |
| `pdb.enabled` / `pdb.max_unavailable` | bool / int | PodDisruptionBudget controls for this app. |
| `deployment_overlay` | table | Raw manifest fragment deep-merged onto the generated Deployment (escape hatch for fields not exposed above). |
| `[[apps.NAME.scale.triggers]]` | list | Per-app KEDA event-driven triggers. Each entry: `type` (str), `metadata` (dict), optional `name` (str), optional `auth.secret_refs` (dict). Requires `autoscaler_engine = "keda"` in `[scale.kubernetes]`. |

The gateway itself is configured under `[scale.gateway]` (replicas, `hpa`, `pdb`, resources, `cors`, `rate_limit`, `logs`, `tracing`, `shared_volumes`, timeouts).

```toml
# Example: scale the coder app hot during LLM workloads, fix the gateway at 2.
[apps.coder.scale]
rpc_timeout = 300.0
hpa = { enabled = true, min = 2, max = 10, cpu_target = 60 }

[scale.gateway]
replicas = 2
hpa = { enabled = false }

# KEDA per-app trigger (requires autoscaler_engine = "keda" in [scale.kubernetes])
[[apps.orders.scale.triggers]]
type = "prometheus"
name = "order-queue"
metadata = { serverAddress = "http://prometheus:9090", metricName = "pending_orders", threshold = "20", query = "sum(pending_orders_total)" }
```

#### Gateway High Availability

!!! warning "Gateway defaults to a single replica"
    The gateway is configured under `[scale.gateway]` like any app under its `[apps.<name>.scale]` -- its HPA defaults to `min = 1`. Because the gateway is the single entry point for all external traffic, a pod restart (crash, rolling deploy, node drain) leaves no pod to serve requests until the replacement boots and passes its readiness probe (`readiness_initial_delay` of 10s plus app boot time) -- a window of 503s for every user, regardless of which backend service they are calling.

    Backend services don't have this exposure -- if one of several replicas restarts, the others keep serving. Give the gateway the same redundancy, either as a fixed count or as an autoscaler floor:

    ```toml
    # Fixed count, no autoscaling (same effect as the [scale.gateway] example above)
    [scale.gateway]
    replicas = 2
    hpa = { enabled = false }

    # Or, if you want the gateway to also scale up under load:
    [scale.gateway.hpa]
    min = 2
    ```

    Either config keeps a second pod ready to absorb traffic while the first restarts. The difference is whether the gateway can also scale beyond 2 under load (`hpa.enabled = true`) or stays fixed (`hpa.enabled = false`).

### Centralised Logs

A fleet deploy can add a Loki + Grafana Alloy log aggregation pipeline alongside the existing Prometheus + Grafana monitoring stack. Off by default.

```toml
[scale.gateway.logs]
enabled = true
```

When enabled, `jac scale deploy` deploys:

- **Loki** -- single-process log store (port 3100, ClusterIP). Uses filesystem/TSDB storage on `emptyDir` by default, so logs reset whenever the pod is replaced. `[scale.monitoring] storage_enabled = true` keeps them on a volume (see [Monitoring data storage](#monitoring-data-storage)).
- **Grafana Alloy** -- DaemonSet on every node (tolerates `NoSchedule`). Tails `/var/log/pods` for the pods in the app namespace only, labels each stream with `namespace`, `pod`, and `container`, and pushes to Loki via Kubernetes service discovery. River-syntax config; supersedes Promtail (EOL 2026-03-02).
- **Prometheus + Grafana** -- the full monitoring stack comes along because the Pod Logs dashboard view lives inside Grafana. Equivalent to setting `[scale.monitoring] enabled = true` plus `[scale.kubernetes] loki_enabled = true` on the monolith target.

A **Pod Logs** dashboard is added to Grafana automatically, with two panels: log volume (lines/min by namespace/pod) and a live log viewer.

| Component | Resource | Reach |
|-----------|----------|-------|
| Loki | Deployment + ClusterIP Service `<app>-loki-service:3100` | Cluster-internal only |
| Alloy | DaemonSet | Per node; reads host `/var/log/pods` (read-only) |
| Grafana | Deployment + ClusterIP Service | Cluster-internal in fleet mode (the `/grafana` ingress path is wired by the single-app target only); reach it with `kubectl port-forward svc/<app>-grafana-service 3000:3000` |

> **Storage caveat.** Loki uses `emptyDir` unless `[scale.monitoring] storage_enabled` is set, and a replaced Loki pod then starts empty. S3-compatible object storage is planned.

<!-- -->

> **Trace correlation.** The gateway already propagates `X-Trace-Id`. Lines from every app touched by one request carry the same trace id; grep for it in Grafana with `{namespace="<ns>"} |~ "trace=<id>"`. Structured-JSON emission with `trace_id` as a first-class queryable field is planned.

<!-- -->

> **Multi-tenant note.** Each app's Alloy collects only the logs of its own namespace, so its Loki and Grafana do not show other apps on the cluster. Apps deployed into the same namespace share that namespace's logs; give each tenant its own `[scale.kubernetes] namespace` to keep them apart. An app deployed before this scoping keeps the other namespaces' logs its Loki already stored until the Loki pod restarts; `kubectl rollout restart deployment/<app>-loki -n <namespace>` clears them, along with the app's own earlier logs.

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

The last two steps are required, not cosmetic: `jac scale deploy` reads `~/.kube/config` to reach the cluster and shells out to a real `kubectl` binary to seed the source bundle. A shell alias (`alias kubectl='microk8s kubectl'`) is not enough because subprocesses cannot see it.

After `jac scale deploy`, reach the app with the port-forward command the deploy prints (see [Ports](#ports)). To serve it through an Ingress instead, run `microk8s enable ingress` and set `[scale.gateway.ingress]`; the addon's controller then answers on `http://localhost` for the configured `host`.

### Docker Desktop

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Open Settings > Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"

### Minikube

```bash
# Install -- see https://minikube.sigs.k8s.io/docs/start/
brew install minikube  # macOS

minikube start
# Optional: an ingress controller for [scale.gateway.ingress]
minikube addons enable ingress
```

The `ingress` addon is only needed if you set `[scale.gateway.ingress]`. Its controller answers on the VM's address, not localhost: use `http://$(minikube ip)` with the configured `host`.

---

## Troubleshooting

### Application Not Accessible

```bash
# Check pod status
kubectl get pods

# Check service
kubectl get svc

# Without an Ingress, the app is reached through the gateway Service
kubectl port-forward svc/gateway-service 8080:8000
# then open http://localhost:8080
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
- `Permission denied` from the app on a `shared_volumes` mount means the
  `jac-volume-perms` init container could not hand the mount root to uid/gid
  1000; read its log (`kubectl logs <pod-name> -c jac-volume-perms`) and make
  the backend accept root `chown` or provision the volume writable by that
  identity.
- `ImagePullBackOff` on the base image means the cluster cannot reach
  `jaseci/jaclang`; set `python_image` to a base it can pull.

### Building and Deploying Separately

`jac scale deploy` builds the app (the client build, `jac install`, the seal)
and applies it in one process. To run the two halves in different places, for
example an unprivileged CI runner that builds and a trusted step that holds the
kubeconfig and applies, split them:

```bash
jac scale build app.jac --out build --arch amd64     # no cluster access
jac scale deploy app.jac --from-build build --plan-out plan.json
```

`jac scale build` never loads cluster config, so it takes the node architecture
from `--arch` or `JAC_NODE_ARCH` and refuses when neither is set. It writes
the sealed bundle as `build/bundle-<sha256 prefix>.jab` and then
`build/build.json`, which names that file and records the jac version,
channel, node architecture, app name, the bundle's object key, sha256 and size,
the pod runtime's sha256 and one sha256 over every `jac.toml` sealed into the
bundle (the root one and each nested one). `build.json` is replaced last, so a
deploy reading the directory always finds the bundle it names; older bundle
files are removed afterwards. The output directory holds only these files: the
build refuses a directory with anything else in it, or a symlink.

`--from-build` never builds. It refuses a build whose bundle does not match its
recorded sha256, or that was made by another jac version, for another app,
node architecture or jac channel, or whose sealed `jac.toml` files differ from
the ones this deploy would ship (the refusal names each file and key that
differs, never the values). It fetches the
pod runtime the usual way and refuses when its sha256 differs from the one the
build recorded. `--plan-out` writes the rendered Deployments as JSON
(`{expect, parked, deployments}`, where `parked` lists the ones that may sit at
zero replicas) before anything is applied; with `--dry-run` it writes the plan
and applies nothing.

### Node Architecture

The pod runtime is built for the nodes' architecture, which the deploy reads by
listing the cluster's nodes. A kubeconfig bound to a namespace-scoped Role
cannot list them, so the deploy stops with `Could not read the cluster's node
architectures (HTTP 403 Forbidden)`. Grant the deploy identity `list` on `nodes`
through a ClusterRole, or name the architecture:

```bash
JAC_NODE_ARCH=x86_64 jac scale deploy    # or aarch64; amd64 and arm64 also work
```

Set it too when the nodes report several architectures or none, or when a
`jac-bootstrap` log shows `Exec format error` (the pods got the wrong one).

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
| `apps` | `[apps]` | the workspace's app tables; every serving app becomes a fleet member, per-app scale keys come from `[apps.<name>.scale]` |
| `gateway` | `[scale.gateway]` | `ingress`, `cors`, `rate_limit`, timeouts, `shared_volumes`, ... |
| `kube_context` | new | kubeconfig context to deploy through; empty = current context, falling back to in-cluster; a set context that does not load is an error |
| `labels` | new | stamped on every generated Deployment and Service (platform-owned tags) |
| `extra` | any `[scale.kubernetes]` key | escape hatch merged last, e.g. `{"bundle_storage_class": "efs-sc"}` |

With `target = "auto"` the SDK resolves exactly like the CLI: the
fleet target when the workspace has service apps, the single-app
`kubernetes` target otherwise. Lifecycle
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
| `resource_status(app_name, namespace)` | `ResourceStatusInfo{status, replicas, ready_replicas, available_replicas, updated_replicas, replica_floor, reason, message}`; `status` is one of `active`, `activating`, `inactive`, `deactivating`, `degraded`, `unknown` (see [Deployment Status](#deployment-status)) |
| `autoscaler_status(app_name, namespace, service="")` | `AutoscalerRuntimeStatus`: everything `ResourceStatusInfo` carries plus `engine`, `autoscaler_name`, `trigger_active`, `scaler_ready`, `conditions`, `resource_version` (see [Autoscaler runtime status](#autoscaler-runtime-status)) |
| `watch_autoscaler_transitions(app_name, namespace, label_selector=None, timeout_seconds=None)` | iterator of `AutoscalerTransition` (see [Observing transitions](#observing-transitions)) |
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
