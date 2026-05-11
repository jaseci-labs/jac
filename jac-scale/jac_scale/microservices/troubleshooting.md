# Troubleshooting jac-scale microservice deploys

Common failure modes for `jac start <file> --scale` on K8s, in the order
most users hit them.

## "Could not load Kubernetes config..."

`jac start --scale` couldn't find a cluster.

```bash
# Laptop
minikube start --driver=docker
kubectl get nodes        # must show Ready

# Remote
aws eks update-kubeconfig --name <cluster> --region <region>
gcloud container clusters get-credentials <cluster> --zone <zone>
az aks get-credentials --resource-group <rg> --name <cluster>

# Verify
kubectl cluster-info
```

In-cluster: pod needs a ServiceAccount with cluster API permissions. Run
from a laptop or use a cluster-admin SA.

## "Kubernetes API server is unreachable"

Kubeconfig loads but the cluster behind it doesn't respond. Cluster
stopped, network partition, expired creds, or firewall.

```bash
minikube status                  # "Running" expected; otherwise minikube start
aws eks update-kubeconfig ...    # re-fetch creds if remote
kubectl cluster-info             # confirms API server reachable
```

We fail-fast at the first `list_namespace` call, so no manifests are
applied if you got here - nothing to clean up.

## "[plugins.scale.microservices.routes] is empty"

Microservice mode is enabled but no routes are declared. Add at least
one route per service `.jac` file:

```toml
[plugins.scale.microservices]
enabled = true

[plugins.scale.microservices.routes]
products_app = "/api/products"   # products_app.jac -> /api/products/*
orders_app   = "/api/orders"
```

Key = module name (file basename without `.jac`); value = URL prefix.

## Pods deploy but `kubectl logs` shows `jac: command not found`

The image was built without jac-scale installed. Either the wrong
Dockerfile was picked or pip install failed silently.

```bash
kubectl logs -n <ns> <pod> | head -40

# Check which Dockerfile was used
ls -la <project>/Dockerfile.microservice
ls -la <repo-root>/jac-scale/scripts/Dockerfile.microservice.ci
```

If you committed a custom `Dockerfile.microservice` in your project, it
overrides everything; verify it actually `pip install`s jac-scale.

## Pod stuck in `ImagePullBackOff` / `ErrImagePull`

The cluster can't pull the image jac-scale built.

- **minikube**: image is in minikube's daemon - verify `eval $(minikube docker-env) && docker images | grep <app>`.
- **k3d/kind**: re-run `jac start --scale`; the import step may have failed silently.
- **remote**: cluster's nodes need pull access to your registry. Check `imagePullSecrets` or set `[plugins.scale.kubernetes].image_registry` to a registry the cluster can reach.

## Pod `Running` but readiness probe failing

Pod is up but `/healthz/ready` isn't returning 200, so kube-proxy
excludes it from the Service.

```bash
kubectl describe pod -n <ns> <pod>          # look for "Readiness probe failed"
kubectl logs -n <ns> <pod>                  # look for startup errors
kubectl port-forward -n <ns> <pod> 8000:8000
curl http://localhost:8000/healthz/ready    # bypass Service, hit pod directly
```

Common causes: slow first-boot (jac compile + plugin init) crossing the
probe's `initialDelay`; bump `[plugins.scale.kubernetes].readiness_initial_delay`.

## Gateway 503 on every `/api/<svc>/*` request

Gateway is reachable (`/health` returns 200) but service routes 503.
Service pod isn't Ready, or its Service has no endpoints.

```bash
kubectl get pods -n <ns>                              # look for Ready 0/1
kubectl get endpoints <svc>-service -n <ns>           # empty means no Ready pod
kubectl logs -n <ns> -l app=<svc> --tail=80
```

If the gateway is brand new and the Ingress returns 503 too: NGINX
Ingress's upstream cache lags Service endpoints by 3-5s after a pod
becomes Ready. Wait or retry.

## Diagnostic flow

When the symptom doesn't match anything above:

```bash
# 1. What's in the namespace
kubectl get all,ingress,pvc -n <ns>

# 2. Pod events (image pull failures, scheduling, probes)
kubectl describe pods -n <ns>

# 3. Container logs (most recent restart)
kubectl logs -n <ns> -l managed=jac-scale --tail=100

# 4. Namespace-wide events sorted by time
kubectl get events -n <ns> --sort-by='.lastTimestamp'
```

## When the framework is the bug

If you've gone through the above and the failure is in the manifest
itself (e.g. an env var jac-scale should inject is missing, a probe is
misconfigured), file an issue with:

- `kubectl get deploy <name> -n <ns> -o yaml` (the rendered manifest)
- `kubectl describe pod <name> -n <ns>` (events + status)
- The relevant `[plugins.scale.microservices.*]` section of `jac.toml`
