# 5-minute Get Started — jac-scale microservices on Kubernetes

Goal: from zero to a microservice topology running on a real Kubernetes
cluster on your laptop, in five minutes.

This is the fastest path to seeing K1-K10 in action. For the full
beginner-to-advanced walkthrough including K8s primitives (Pods, Services,
probes, autoscaling), see `MICROSERVICES_K8S_COURSE.md` at the repo root.
For when things break, see [troubleshooting.md](troubleshooting.md).

---

## What you need

```bash
# Docker Desktop running (or Linux Docker daemon)
docker version

# kubectl
kubectl version --client

# minikube
minikube version

# jac-scale source (until PyPI catches up — see "Install" below)
```

If any of those fail, install them first. On Linux/WSL:

```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install kubectl /usr/local/bin/

# minikube
curl -Lo /tmp/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install /tmp/minikube /usr/local/bin/minikube
```

---

## Install (until PyPI catches up)

The K-track lives on the `feat/k8s-microservice-mode` branch and isn't
on PyPI yet. Install editable from the repo:

```bash
git clone https://github.com/Jaseci-Labs/jaseci.git
cd jaseci
git checkout feat/k8s-microservice-mode

# Editable install of both jaclang + jac-scale, in any conda/venv
pip install -e ./jac
pip install -e "./jac-scale[deploy]"

# Verify
jac --version
```

When the K-track is published to PyPI you'll be able to skip this and
just `pip install jac-scale[deploy]`.

---

## Run the bundled fixture

The fastest way to see the whole pipeline work is the e2e fixture (the
same one CI runs):

```bash
# Start minikube (uses Docker Desktop on macOS/Windows, native on Linux)
minikube start --driver=docker
minikube addons enable ingress

# Run the same script CI runs
cd jaseci
bash jac-scale/scripts/k8s_microservice_real_e2e.sh
```

You'll see (~5 min):

1. Image build inside minikube's docker daemon
2. `kubectl apply` of all manifests (Deployments, Services, HPAs, PDBs, Ingress)
3. `kubectl rollout status` waits for all pods Ready
4. Port-forward + `curl /health` (must return 200)
5. Per-service routing checks (each `/api/<svc>/*` reaches upstream)
6. K10 Ingress check
7. **Zero-downtime rolling-restart**: hammers `/health` while
   `kubectl rollout restart deployment/gateway-deployment`, expects
   zero non-2xx responses
8. Same hammer + restart against a service Deployment
9. PASS

If any step fails, the script dumps `kubectl describe pods` and `kubectl
get events` automatically before cleaning up.

---

## Deploy your own app

After the fixture works, deploying your own app is essentially: write
`jac.toml`, run `jac start <main>.jac --scale`.

### Minimum jac.toml

```toml
[project]
name = "my_app"
version = "1.0.0"
entry-point = "main.jac"

[plugins.scale.microservices]
enabled = true

# At least one route - "module_name = url_prefix"
[plugins.scale.microservices.routes]
my_service = "/api/my"
```

`my_service.jac` should be a sibling file with `def:pub` functions
exposed via the [sv import](docs.md) machinery.

### Deploy

```bash
jac start main.jac --scale
```

That's it. No Dockerfile, no `eval $(minikube docker-env)`, no registry config required for local clusters. Behind the scenes `jac start --scale`:

1. **Detects your cluster type** from kubeconfig (minikube / k3d / kind / remote)
2. **Builds the frontend bundle** by running `jac build <client.entry>` on the host (skipped if no client config)
3. **Builds the container image** using the right Dockerfile for your situation:
   - Your `Dockerfile.microservice` if you committed one (override)
   - The repo's `Dockerfile.microservice.ci` if you're on a developer checkout (uses local source install)
   - The shipped `Dockerfile.microservice` from the jac-scale package (PyPI installs)
   - An embedded fallback template (last resort)
4. **Loads the image into the cluster** via the right mechanism per cluster type:
   - minikube: builds inside minikube's internal docker daemon
   - k3d: docker build then `k3d image import`
   - kind: docker build then `kind load docker-image`
   - remote: tags as `<registry>/<image>:<tag>` and pushes (requires `[plugins.scale.kubernetes].image_registry`)
5. **Provisions MongoDB + Redis** as StatefulSets in the cluster (defaults on; set `mongodb_enabled = false` / `redis_enabled = false` to opt out)
6. **Injects `MONGODB_URI` and `REDIS_URL`** as `valueFrom: secretKeyRef` env into every service + gateway pod, so all services share one anchor store
7. **Adds wait-for-DB init containers** to every pod so they don't crash-loop before the databases are reachable
8. **Applies manifests** for all services + gateway (Deployments, ClusterIP Services, HPAs, PDBs, optional Ingress)
9. **Sets `sessionAffinity: ClientIP`** on the gateway Service so WebSocket reconnects land on the same pod

Result: a full FE+BE microservice topology with shared state, autoscaling, rolling deploys, sticky WS sessions, and an external URL via Ingress (if enabled).

### Reach your app

```bash
# Wait for everything to be ready
kubectl wait --for=condition=ready pod -l managed=jac-scale -n default --timeout=180s

# Port-forward to the gateway
kubectl port-forward svc/gateway-service 8000:8000 -n default &

# Open in browser - your frontend renders here
# (assuming you configured [plugins.scale.microservices.client].entry)
open http://localhost:8000

# Or hit the API
curl http://localhost:8000/health
curl -X POST http://localhost:8000/api/your-service/function/your_function -d '{}'
```

For external access without port-forward, enable Ingress in jac.toml:

```toml
[plugins.scale.microservices.ingress]
enabled = true
host = "my-app.local"          # add to /etc/hosts -> $(minikube ip)
ingress_class_name = "nginx"
```

Then `curl http://my-app.local/` after `echo "$(minikube ip)  my-app.local" >> /etc/hosts`.

### Watch what's running

```bash
minikube dashboard       # graphical view of pods/services/logs/events

# Or via kubectl:
kubectl get pods -n default
kubectl logs -l managed=jac-scale -n default -f --max-log-requests=10
kubectl logs -l app=gateway -n default -f
```

`jac start --scale` auto-selects `kubernetes-microservice` target when
microservice mode is enabled in jac.toml. It builds the image, generates
manifests, and applies them to the cluster currently in your kubeconfig.

### Reach your app

```bash
# Port-forward to the gateway
kubectl port-forward svc/gateway-service 8000:8000 -n my-app-ns &

# Hit endpoints
curl http://localhost:8000/health
curl http://localhost:8000/api/my/walker/<your_walker>
```

For external access (no port-forward), enable Ingress:

```toml
[plugins.scale.microservices.ingress]
enabled = true
host = "my-app.local"            # add to /etc/hosts → minikube ip
ingress_class_name = "nginx"
```

Then:

```bash
echo "$(minikube ip)  my-app.local" | sudo tee -a /etc/hosts
curl http://my-app.local/health
```

---

## Tune for production traits

Once the basic deploy works, layer per-service config:

```toml
[plugins.scale.microservices.services.my_service]
replicas       = 2                  # default 1
cpu_request    = "100m"
cpu_limit      = "500m"
memory_request = "128Mi"
memory_limit   = "512Mi"

[plugins.scale.microservices.services.my_service.hpa]
enabled    = true                   # default true
min        = 2
max        = 10
cpu_target = 70                     # CPU % to start scaling

[plugins.scale.microservices.services.my_service.pdb]
enabled         = true
max_unavailable = 1                 # at most N pods down during voluntary disruption
```

Re-run `jac start --scale` to apply. K8s rolling-update controller
handles the changes — zero downtime if K5 wires are correct (they are
by default).

---

## Tear down

```bash
# Delete the namespace (everything jac-scale created lives there)
kubectl delete ns <my-app-ns>

# Or stop minikube entirely
minikube stop                       # keeps state for next start
minikube delete                     # nukes everything
```

---

## Where to next

- **`MICROSERVICES_K8S_COURSE.md`** (repo root): full beginner-to-advanced
  walkthrough of every K8s primitive used here, with worked examples.
- **`docs.md`** (this directory): config reference for every
  `[plugins.scale.microservices.*]` knob.
- **`troubleshooting.md`** (this directory): when things break.
- **`scripts/k8s_microservice_real_e2e.sh`**: the script you just ran;
  source-readable for understanding what each step does.
