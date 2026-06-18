# Get Started - jac-scale microservices on Kubernetes

Fastest path from zero to a microservice topology running on a real K8s
cluster on your laptop. Config reference is [docs.md](docs.md).

## Prereqs

```bash
docker version          # Docker Desktop running (or Linux daemon)
kubectl version --client
minikube version
```

## Install

Microservice mode lives on the `feat/k8s-microservice-mode` branch and
isn't on PyPI yet. Editable install from the repo:

```bash
git clone https://github.com/Jaseci-Labs/jaseci.git
cd jaseci
git checkout feat/k8s-microservice-mode
pip install -e ./jac
jac install -e ./jac-scale --extras deploy
jac --version
```

## Run the bundled fixture

```bash
minikube start --driver=docker
minikube addons enable ingress
bash jac-scale/scripts/k8s_microservice_real_e2e.sh
```

The script builds the image, applies manifests, waits for pods Ready,
runs gateway + ingress checks, then a zero-downtime rolling-restart
stress test. On failure it dumps `kubectl describe pods` and events
before cleanup.

## Deploy your own app

### Zero-config (recommended)

You don't need a `[plugins.scale.microservices]` block at all. Minimum
`jac.toml`:

```toml
[project]
name = "my_app"
entry-point = "main.jac"
```

A **service** is any sibling `.jac` module with a `to sv:` section that
exposes a public endpoint:

```jac
# my_service.jac
to sv:

def:pub ping -> dict { return {"ok": true}; }
```

The entry-point (`main.jac`) is the **gateway** and is never itself a
service. `jac start` discovers every `to sv:` module in the project, maps
each to a conventional route prefix (`my_service` -> `/api/my_service`,
`orders_app` -> `/api/orders`), and activates microservice mode - the same
behavior locally and on Kubernetes:

```bash
jac start main.jac           # local: gateway + one subprocess per service
jac start main.jac --scale   # K8s: gateway pod + one Deployment per service
```

To override the auto-derived prefixes (or add a service the scan can't
reach), declare a routes block - it always wins over discovery:

```toml
[plugins.scale.microservices.routes]
my_service = "/api/my"
```

### Deploy without building an image (`--no-image`)

```bash
jac start main.jac --scale --no-image
```

Instead of building a per-app Docker image, this ships your project source
into a **ConfigMap** mounted at `/app` in every pod, running a cached
`jac-scale-base:<version>` image (built once per cluster, reused after).
No Dockerfile, no per-deploy build - a code change just re-applies the
ConfigMap and rolls the pods (a `JAC_SOURCE_HASH` env stamp triggers the
rollout). Best for fast iteration; the source must fit a ConfigMap (~1 MB).
For large projects or ones needing extra OS/pip deps, use the default
image-build path (drop `--no-image`).

No Dockerfile, no registry config required for local clusters.
`jac start --scale` detects your cluster type from kubeconfig, builds
the image, loads it into the cluster (minikube internal daemon /
`k3d image import` / `kind load` / `docker push` for remote), spins up
MongoDB + Redis StatefulSets, injects `MONGODB_URI` / `REDIS_URL` env
into every pod, and applies all Deployments + Services + HPAs + PDBs.

## Reach your app

```bash
kubectl port-forward svc/gateway-service 8000:8000 -n default &
curl http://localhost:8000/health
curl http://localhost:8000/api/my/walker/<your_walker>
```

For external access enable Ingress:

```toml
[plugins.scale.microservices.ingress]
enabled = true
host = "my-app.local"
ingress_class_name = "nginx"
```

```bash
echo "$(minikube ip)  my-app.local" | sudo tee -a /etc/hosts
curl http://my-app.local/health
```

## Per-service tuning

```toml
[plugins.scale.microservices.services.my_service]
replicas       = 2
cpu_request    = "100m"
cpu_limit      = "500m"
memory_request = "128Mi"
memory_limit   = "512Mi"

[plugins.scale.microservices.services.my_service.hpa]
enabled    = true
min        = 2
max        = 10
cpu_target = 70

[plugins.scale.microservices.services.my_service.pdb]
enabled         = true
max_unavailable = 1
```

Re-run `jac start --scale` to apply; K8s handles the rolling update.

## Tear down

```bash
kubectl delete ns default
minikube stop      # or `minikube delete` to nuke
```
