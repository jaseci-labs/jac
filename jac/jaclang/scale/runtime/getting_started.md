# Get Started - a jac-scale fleet on Kubernetes

Fastest path from zero to a workspace of service apps running on a real K8s
cluster on your laptop. Config reference is [docs.md](docs.md).

## Prereqs

```bash
docker version          # Docker Desktop running (or Linux daemon)
kubectl version --client
minikube version
```

## Install

Fleet mode is built into jaclang core (`jaclang.scale`); there is no separate
package to install.

```bash
jac --version
```

## Run the bundled fixture

```bash
minikube start --driver=docker
minikube addons enable ingress
cd jac/jaclang/scale/tests/fixtures/k8s_e2e
jac scale deploy web
```

The deploy packs the workspace into a bundle, ships it into the cluster on a
PVC, boots one pod per app plus the gateway from a stock base image, spins up
Postgres, and applies every Deployment, Service, autoscaler and PDB.

## Deploy your own workspace

Minimum `jac.toml`:

```toml
[project]
name = "my_app"
default-app = "web"

[apps.web]
kind = "web-app"
entry-point = "main.jac"

[apps.my_service]
kind = "service"
entry-point = "my_service.jac"      # route defaults to /api/my_service
```

`my_service.jac` is a plain server module whose `def:pub` functions and
`walker:pub` walkers are the app's surface; `main.jac` reaches them with a
normal `import from my_service { ... }` (awaited, since the bridge is async).
Then:

```bash
jac run web            # colocated on :8000
jac run web --fleet    # local processes behind the gateway on :8000
jac scale deploy web   # kubernetes
```

No Dockerfile and no registry config, on any cluster: nothing is built and
nothing is pushed.

## Reach your app

```bash
kubectl port-forward svc/gateway-service 8000:8000 -n default &
curl http://localhost:8000/health
curl -X POST http://localhost:8000/api/my_service/walker/<your_walker>
```

For external access enable Ingress:

```toml
[scale.gateway.ingress]
enabled = true
host = "my-app.local"
ingress_class_name = "nginx"
```

```bash
echo "$(minikube ip)  my-app.local" | sudo tee -a /etc/hosts
curl http://my-app.local/health
```

## Per-app tuning

```toml
[apps.my_service.scale]
replicas       = 2
cpu_request    = "100m"
cpu_limit      = "500m"
memory_request = "128Mi"
memory_limit   = "512Mi"

[apps.my_service.scale.hpa]
enabled    = true
min        = 2
max        = 10
cpu_target = 70

[apps.my_service.scale.pdb]
enabled         = true
max_unavailable = 1
```

Re-run `jac scale deploy web` to apply; K8s handles the rolling update.

## Tear down

```bash
jac scale destroy main.jac
minikube stop      # or `minikube delete` to nuke
```
