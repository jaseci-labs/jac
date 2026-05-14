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
pip install -e "./jac-scale[deploy]"
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

Minimum `jac.toml`:

```toml
[project]
name = "my_app"
entry-point = "main.jac"

[plugins.scale.microservices]
enabled = true

[plugins.scale.microservices.routes]
my_service = "/api/my"
```

`my_service.jac` is a sibling file with `def:pub` functions discoverable
via `sv import`. Then:

```bash
jac start main.jac --scale
```

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
