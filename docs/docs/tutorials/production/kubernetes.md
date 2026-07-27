# Kubernetes Deployment

> **Concept:** [Scale invariance](../../reference/plugins/jac-scale.md#the-scale-invariance-contract): `--scale` changes where the program runs, never what it means.

Moving from a local API server to a production Kubernetes deployment typically requires writing Dockerfiles, Kubernetes manifests, configuring databases, and setting up monitoring. Jac's built-in `scale` subsystem eliminates this boilerplate: `jac start --scale` generates and applies all the necessary Kubernetes resources automatically -- your application, a MongoDB instance for graph persistence, Redis for caching, and optionally Prometheus/Grafana for monitoring.

This tutorial covers deploying to a local Kubernetes cluster (MicroK8s, minikube, or Docker Desktop), but the same command works for cloud providers (EKS, GKE, AKS) with `kubectl` properly configured.

> **Prerequisites**
>
> - Completed: [Local API Server](local.md)
> - Kubernetes cluster running (MicroK8s, minikube, Docker Desktop, or cloud provider)
> - `kubectl` configured
> - Deployment dependencies installed into your project: the `scale` subsystem ships with `jaclang`, but `jac start --scale` needs `kubernetes`/`docker` in the project venv. Configure `[scale.kubernetes]` in `jac.toml` (or just run the deploy once -- the first `--scale` run resolves them) and:
>
>   ```bash
>   jac install
>   ```
>
> - Time: ~10 to 20 minutes (first deploy depends on internet speed and machine resources)

---

## Overview

`jac start --scale` handles everything automatically:

- Deploys your application to Kubernetes
- Auto-provisions Redis (caching) and MongoDB (persistence)
- Creates all necessary Kubernetes resources
- Exposes your application through the NGINX ingress NodePort (default `30080`)

```mermaid
graph TD
    subgraph cluster["Kubernetes Cluster (Auto-Created)"]
        subgraph app["Application"]
            P1["Pod: jac-app"]
        end
        subgraph data["Data Layer (Auto-Provisioned)"]
            R["Redis<br/>Caching"]
            M["MongoDB<br/>Persistence"]
        end
        P1 --> R
        P1 --> M
    end
    LB["Ingress NodePort :30080"] --> P1
```

---

## Quick Start

### 1. Prepare Your Application

```jac
# main.jac
node Todo {
    has title: str;
    has done: bool = False;
}

walker:pub add_todo {
    has title: str;

    can create with Root entry {
        todo = here ++> Todo(title=self.title);
        report {"title": todo.title, "done": todo.done};
    }
}

walker:pub list_todos {
    can fetch with Root entry {
        todos = [-->][?:Todo];
        report [{"title": t.title, "done": t.done} for t in todos];
    }
}

walker:pub health {
    can check with Root entry {
        report {"status": "healthy"};
    }
}
```

### 2. Deploy to Kubernetes

!!! note
    `main.jac` is the default entry point for `jac start`. If your entry point has a different name (e.g., `app.jac`), pass it explicitly: `jac start app.jac --scale`.

```bash
jac start --scale
```

That's it. Your application is now running on Kubernetes.

**Access your application:**

- API: http://localhost:30080
- Swagger docs: http://localhost:30080/docs

---

## Deployment Modes

### Deploy

```bash
jac start --scale
```

There is no image to build and no registry to configure. `jac-scale` packs your
source into a bundle, copies it into the cluster, and runs every pod on a stock
base image that a bootstrap initContainer prepares. The same command works
against a local cluster and a remote one.

### Preview

```bash
jac start --scale --dry-run
```

Prints the manifests that would be applied and touches nothing: no cluster
contact, no binary or console download, no client bundle build, no database
provisioned, no TLS certificate issued, and no deploy tooling installed. The
content-addressed bundle keys are rendered as placeholders (a real deploy
computes the digests). Add `--show-yaml` to dump the raw YAML stream.

---

## Configuration

Configure deployment in `jac.toml`:

```toml
[scale.kubernetes]
app_name = "jaseci"
namespace = "default"
ingress_node_port = 30080
```

### Application Settings

| Key | Description | Default |
|----------|-------------|---------|
| `app_name` | Name of your application | slug of `[project].name` (else `jaseci`) |
| `namespace` | Kubernetes namespace | `default` |
| `ingress_node_port` | Ingress NodePort for local access | `30080` |

### Resource Limits

| Key | Description | Default |
|----------|-------------|---------|
| `cpu_request` | CPU request | - |
| `cpu_limit` | CPU limit | - |
| `memory_request` | Memory request | - |
| `memory_limit` | Memory limit | - |

### Health Checks

| Key | Description | Default |
|----------|-------------|---------|
| `readiness_initial_delay` | Readiness probe delay (seconds) | `10` |
| `readiness_period` | Readiness probe interval (seconds) | `20` |
| `liveness_initial_delay` | Liveness probe delay (seconds) | `10` |
| `liveness_period` | Liveness probe interval (seconds) | `20` |
| `liveness_failure_threshold` | Consecutive liveness failures before restart | `80` |

### Database Options

| Key | Description | Default |
|----------|-------------|---------|
| `mongodb_enabled` | Enable MongoDB deployment | `true` |
| `redis_enabled` | Enable Redis deployment | `true` |

To use external databases instead of the auto-provisioned ones, set them under `[scale.database]` (the `MONGODB_URI` / `REDIS_URL` environment variables override these at runtime):

```toml
[scale.database]
mongodb_uri = "mongodb://user:pass@host:27017"
redis_url = "redis://host:6379"
```

### Authentication

| Key | Description | Default |
|----------|-------------|---------|
| `[scale.jwt]` `secret` | JWT signing key | Testing-only default; set your own in production |
| `[scale.jwt]` `exp_delta_days` | Token expiration (days) | `7` |
| `[scale.sso.google]` `client_id` | Google OAuth client ID | - |
| `[scale.sso.google]` `client_secret` | Google OAuth secret | - |

---

## Autoscaling

By default scale creates a Kubernetes `HorizontalPodAutoscaler` that scales pods based on average CPU utilization. Configure the bounds in `jac.toml`:

```toml
[scale.kubernetes]
min_replicas = 2
max_replicas = 10
cpu_utilization_target = 70   # Scale out when average CPU exceeds 70%
```

For event-driven scaling or scale-to-zero, switch to the KEDA engine:

```toml
[scale.kubernetes]
autoscaler_engine = "keda"
min_replicas = 1              # default 1; floor while triggers are active
max_replicas = 10             # default 3; ceiling for scale-out
cpu_utilization_target = 50   # default 50; seeds a CPU trigger (requires cpu_request)
idle_replicas = 0             # default null (uses min_replicas); set 0 for scale-to-zero
autoscaler_polling_interval = 30   # default 30; seconds between trigger evaluations
autoscaler_cooldown = 300          # default 300; seconds of inactivity before scaling down
autoscaler_initial_cooldown = 0    # default 0; seconds after deploy before scale-to-zero kicks in
```

!!! note
    KEDA must be installed on your cluster before setting `autoscaler_engine = "keda"`. See the [KEDA installation guide](https://keda.sh/docs/latest/deploy/).

For the full list of autoscaling options (including event triggers, polling intervals, cooldown tuning, and authenticated triggers), see the [Scale Reference](../../reference/plugins/jac-scale-kubernetes.md#autoscaling).

---

## Local and Remote Clusters

The same `jac start --scale` works against both, and neither needs a container
registry. Because no application image is built, there is nothing to push and
nothing for the cluster to pull: your source travels into the cluster as a
bundle on a PVC, and pods boot from a stock base image.

Pods pull only that base image -- `jaseci/jaclang` by default. If your cluster
cannot reach Docker Hub, point `python_image` at one it can:

```toml
[scale.kubernetes]
python_image = "123456789012.dkr.ecr.us-east-2.amazonaws.com/jaclang:latest"
```

That is the only registry a deploy depends on, and only for the base image --
your code is never baked into it.

### Base Image Channel

Which `jaseci/jaclang` tag pods boot from is chosen automatically:

| `jac.toml`                     | Base image                     |
| ------------------------------ | ------------------------------ |
| _(default)_                    | `jaseci/jaclang:latest`        |
| `[dev]`                        | `jaseci/jaclang:dev` (main HEAD) |
| `[experimental]` `pr = <N>`    | `jaseci/jaclang:experimental-<N>` |

The experimental channel runs an open PR's own build in your pods, for trying a
not-yet-merged change against a real cluster:

```toml
[experimental]
pr = 7494
```

A maintainer publishes and deletes that image on demand via the **Experimental
jac image** workflow (dispatched with the PR number and a `build`/`delete`
action). If it is not published yet, the deploy falls back to `:dev`. An explicit
`python_image` still overrides all of this.

---

## Cross-Service Shared Filesystem

When two services need to read and write the same files (e.g. an IDE backend and a build worker that both touch a project workspace), declare a shared volume that gets mounted on both pods:

```toml
[[scale.microservices.shared_volumes]]
name = "workspace"
mount_path = "/data/workspace"
services = ["builder_sv", "build_worker"]

# Cloud K8s (RWX storage class - EFS / Filestore / Azure Files):
size = "10Gi"
access_mode = "ReadWriteMany"
storage_class = "efs-sc"

# OR for local dev clusters (k3d/kind/minikube), use a hostPath instead:
# host_path = "/var/lib/myapp-workspace"
```

Each entry is an array-of-tables (note the double brackets), so you can declare multiple shared volumes in the same project. The microservice target creates one PersistentVolumeClaim per entry and adds the corresponding `volumeMount` to every service named in `services`. PVCs and mounts come up in the right order during `apply_manifests`, so pods do not crash-loop with "PVC not found".

> **Note on EFS access points.** EFS CSI access points enforce a POSIX UID on every file. The shipped image marks `*` as a [git safe.directory](https://git-scm.com/docs/git-config#Documentation/git-config.txt-safedirectory) so in-pod `git` commands inside the shared volume do not trip CVE-2022-24765 ownership checks when the EFS UID differs from the pod's running UID. If you bake your own image, add `RUN git config --system --add safe.directory '*'`.

---

## Pre-Bound ServiceAccount

By default microservice + gateway pods run as the namespace's `default` ServiceAccount, which has no RBAC. Apps that talk to the cluster API at runtime (sandbox-spawning, operator-style controllers, K8s Job / CronJob managers) need a ServiceAccount pre-bound with the right Role / ClusterRole. The microservice target does not create the SA -- it only references one you provide:

```toml
[scale.kubernetes]
service_account_name = "myapp-sa"
```

The SA must already exist in the target namespace, and any RoleBindings or ClusterRoleBindings it needs must already be applied (typically by your platform team or a separate Helm/Terraform run that owns cluster-scoped policy). Once set, every microservice pod and the gateway pod run under that SA, and any in-pod K8s API client picks up the SA's token automatically from the projected volume at `/var/run/secrets/kubernetes.io/serviceaccount/`.

Auto-creating the SA + RoleBindings from `jac.toml` is on the roadmap but not yet shipped -- treat the SA as a prerequisite that lives outside the project repo for now.

---

## Managing Your Deployment

### Check Status

Use `jac scale status main.jac` to see the health of all deployment components at a glance:

```bash
jac scale status main.jac
```

This displays a table showing each component's status (Running, Degraded, Pending, Restarting, or Not Deployed), pod readiness counts, and service URLs.

For lower-level debugging, you can also use `kubectl` directly:

```bash
kubectl get pods
kubectl get services
```

All scale-managed resources are labeled with `managed: jac-scale`, so you can list everything it owns:

```bash
kubectl get all -l managed=jac-scale
```

### View Logs

```bash
kubectl logs -l app=jaseci -f
```

### Clean Up

Remove all Kubernetes resources created by scale:

```bash
jac scale destroy main.jac
```

This removes:

- Application deployments and pods
- Redis and MongoDB StatefulSets
- Services and persistent volumes
- ConfigMaps and secrets

---

## How It Works

When you run `jac start --scale`, the following happens automatically:

1. **Namespace Setup** - Creates or uses the specified Kubernetes namespace
2. **Database Provisioning** - Deploys Redis and MongoDB as StatefulSets with persistent storage (first run only)
3. **Application Deployment** - Creates a deployment for your Jac application
4. **Service Exposure** - Exposes the application through the NGINX ingress NodePort

Subsequent deployments only update the application - databases persist across deployments.

---

## Setting Up Kubernetes

### Option A: MicroK8s (Recommended on Ubuntu)

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

### Option B: Docker Desktop

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/)
2. Open Settings > Kubernetes
3. Check "Enable Kubernetes"
4. Click "Apply & Restart"

### Option C: Minikube

```bash
# Install minikube -- see https://minikube.sigs.k8s.io/docs/start/
brew install minikube  # macOS

# Start cluster with the ingress addon
minikube start
minikube addons enable ingress
```

With minikube the ingress NodePort is reachable on the VM's address, not localhost: use `http://$(minikube ip):30080`.

---

## Troubleshooting

### Application not accessible

```bash
# Check all component statuses at once
jac scale status main.jac

# Or use kubectl for more detail
kubectl get pods
kubectl get svc

# Default local ingress access (minikube: http://$(minikube ip):30080)
# http://localhost:30080
```

If the app is not reachable yet, wait for the pod to be `Running` and `Ready` first -- the first deploy installs dependencies inside the cluster and can take several minutes:

```bash
kubectl get pods -w
```

### Database connection issues

```bash
# Check StatefulSets
kubectl get statefulsets

# Check persistent volumes
kubectl get pvc

# View database logs
kubectl logs -l app=mongodb
kubectl logs -l app=redis
```

### Pods stuck in Init

The bootstrap initContainer unpacks the source bundle and installs the runtime
before your app starts, so a pod stuck in `Init` almost always failed there:

```bash
kubectl logs <pod-name> -c jac-bootstrap
kubectl get pvc                     # the bundle PVC must be Bound
```

A `Pending` PVC means the cluster has no usable StorageClass; an
`ImagePullBackOff` means it cannot reach the base image, so set `python_image`
to one it can pull.

### General debugging

```bash
# Quick overview of all components
jac scale status main.jac

# Describe a pod for events
kubectl describe pod <pod-name>

# Get all scale-managed resources
kubectl get all -l managed=jac-scale

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

---

## Example: Full-Stack App with Auth

```bash
# Create a new full-stack project
jac create todo --kind web-static
cd todo

# Deploy to Kubernetes
jac start --scale
```

Access:

- Frontend: http://localhost:30080/cl/app
- Backend API: http://localhost:30080
- Swagger docs: http://localhost:30080/docs

---

## Next Steps

- [Local API Server](local.md) - Development without Kubernetes
- [Authentication](../fullstack/auth.md) - Add user authentication
- [Scale Reference](../../reference/plugins/jac-scale.md) - Full configuration options
