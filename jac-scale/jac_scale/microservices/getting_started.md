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

### Build + deploy (current workflow)

Today, `jac start --scale` expects either a Dockerfile in your project or a pre-built image. Two paths:

**Path A — easiest, the bundled e2e script** (recommended for now):

```bash
# From the repo root (gets the build right automatically)
cd /path/to/jaseci
bash jac-scale/scripts/k8s_microservice_real_e2e.sh /path/to/your/project
```

This handles the image build + load into minikube, applies manifests, and tears down on exit. Same as what CI runs.

**Path B — manual workflow** (if you want full control):

1. Drop a `Dockerfile.microservice` into your project root (template at `jac-scale/scripts/Dockerfile.microservice` in the jaseci repo).
2. Build inside minikube's docker context:

   ```bash
   eval $(minikube docker-env)
   docker build -t myapp:dev -f Dockerfile.microservice .
   ```

3. Tell jac.toml to use the prebuilt image:

   ```toml
   [plugins.scale.kubernetes]
   docker_image_name = "myapp:dev"
   ```

4. Deploy:

   ```bash
   jac start main.jac --scale
   eval $(minikube docker-env -u)   # restore your shell
   ```

> **Coming soon — auto-build.** The K-track has an in-flight task to make `jac start --scale` detect the cluster type (minikube/k3d/kind/remote), auto-generate a Dockerfile from a baked-in template if your project doesn't have one, and auto-distribute the image to the right place. Once it lands (paired with the matching PyPI publish), the workflow becomes literally `jac start main.jac --scale` with zero Docker knowledge required. Until then, use Path A or Path B above.

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
