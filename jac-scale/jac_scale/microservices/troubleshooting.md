# Troubleshooting jac-scale microservice deploys

Failure modes you'll actually hit when running `jac start <file> --scale`
against a Kubernetes cluster, in roughly the order most users hit them.
Each section: **what you'll see** → **what's wrong** → **how to fix**.

If your symptom isn't here, the [diagnostic flow](#diagnostic-flow) at
the bottom is the systematic walk.

---

## "Could not load Kubernetes config..."

**Symptom**

```
RuntimeError: Could not load Kubernetes config from either kubeconfig
or in-cluster ServiceAccount.
If you're deploying from a laptop:
  - Start a local cluster:  minikube start
  - Verify kubectl works:   kubectl get nodes
  ...
```

**What's wrong**

`jac start --scale` couldn't find a cluster to talk to. Either no
kubeconfig (laptop case) or the pod doesn't have a working ServiceAccount
(in-cluster case).

**Fix — laptop**

```bash
minikube start --driver=docker
kubectl get nodes        # must show at least one Ready node
```

If you already had minikube running and this still fails, your kubeconfig
is pointing at a stopped cluster:

```bash
kubectl config current-context
minikube status          # if "Stopped", `minikube start` again
```

**Fix — remote cluster (EKS/GKE/AKS)**

```bash
# AWS EKS
aws eks update-kubeconfig --name <cluster-name> --region <region>

# Google GKE
gcloud container clusters get-credentials <cluster-name> \
    --zone <zone> --project <project>

# Azure AKS
az aks get-credentials --resource-group <rg> --name <cluster-name>
```

Verify before re-running:

```bash
kubectl cluster-info     # must print API server URL
```

**Fix — inside a pod**

The pod needs a ServiceAccount with cluster API permissions. The default
`default` ServiceAccount usually has `get/list/watch` on its own namespace
but NOT cluster-wide; for `jac start --scale` to apply manifests it
needs at least the verbs in [P4.3 RBAC scope](#p43-rbac-deferred). Until
P4.3 lands, run from a laptop or use a cluster-admin ServiceAccount.

---

## "Kubernetes API server is unreachable"

**Symptom**

```
RuntimeError: Kubernetes API server is unreachable.
  - Verify cluster: kubectl cluster-info
  - For minikube:   minikube status
  ...
Original error: HTTPSConnectionPool(host='192.168.49.2', port=8443):
  Max retries exceeded with url: /api/v1/namespaces (Caused by
  NewConnectionError(...)
```

**What's wrong**

kubeconfig loaded fine, but the cluster behind it is unreachable. Cluster
stopped, network partition, expired credentials, or firewall.

**Fix**

```bash
# minikube
minikube status             # "Running" expected
minikube start              # if stopped

# remote cluster - re-fetch credentials first
aws eks update-kubeconfig ...   # or gcloud / az equivalent
kubectl cluster-info            # confirms API server is responsive

# corporate firewall blocking 6443/8443
# fix: VPN / proxy / port allowlist with your sec team
```

This error is "fail-fast" — we hit `list_namespace` once at the start of
apply, not after applying half the manifests. If you got here, no
manifests were applied; nothing to clean up.

---

## "[plugins.scale.microservices.routes] is empty"

**Symptom**

```
ValueError: [plugins.scale.microservices.routes] is empty in jac.toml.
Microservice mode needs at least one declared service.
Add to your jac.toml:
  [plugins.scale.microservices.routes]
  my_service = "/api/my"
```

**What's wrong**

Microservice mode is enabled but you haven't told it which services
exist. Without routes, the gateway has nothing to forward to.

**Fix**

For each `.jac` file under your project root that should be its own
service, add a route entry:

```toml
[plugins.scale.microservices]
enabled = true

[plugins.scale.microservices.routes]
products_app = "/api/products"      # products_app.jac → /api/products/*
orders_app   = "/api/orders"
cart_app     = "/api/cart"
```

The key (`products_app`) is the module name (file basename without
`.jac`). The value (`/api/products`) is the URL prefix the gateway will
route to that service.

---

## Pod stuck in `ImagePullBackOff` / `ErrImagePull`

**Symptom**

```
$ kubectl get pods -n jac-e2e
NAME                                 READY   STATUS             RESTARTS
products-app-deployment-abc-123      0/1     ImagePullBackOff   0
```

`jac start --scale` returned success but the deploy never actually runs.

**What's wrong**

The K8s nodes can't pull the container image. Three common shapes:

1. **Built locally, didn't push to a registry the cluster can reach.**
   minikube uses its own Docker daemon; if you built against your host
   Docker (not minikube's), the image lives on your laptop but not in
   the cluster.

2. **Image tag wrong** in jac.toml or the registry config.

3. **Private registry, no imagePullSecret** on the ServiceAccount.

**Fix — minikube local image**

Re-run the build with minikube's docker context:

```bash
eval $(minikube docker-env)        # point host docker at minikube's daemon
jac start app.jac --scale          # rebuild image inside minikube
eval $(minikube docker-env -u)     # restore host docker context
```

The bundled `k8s_microservice_real_e2e.sh` does this automatically when
it detects minikube; only relevant for manual deploys.

**Fix — remote registry**

Verify the tag is what the cluster sees:

```bash
kubectl describe pod <pod-name> -n <namespace> | grep "Image:"
docker pull <that-image-tag>       # from your laptop, see if it works
```

If `docker pull` from your laptop works but the cluster can't, the
cluster nodes need credentials. For ECR / GCR, the node IAM role usually
handles this; for Docker Hub private repos, create an `imagePullSecret`
and reference it in the ServiceAccount.

---

## Pod `Running` but readiness probe failing

**Symptom**

```
$ kubectl get pods -n jac-e2e
NAME                              READY   STATUS    RESTARTS
products-app-deployment-...       0/1     Running   0
$ kubectl describe pod ...
  Warning  Unhealthy  ... Readiness probe failed: HTTP probe failed
  with statuscode: 404
```

**What's wrong**

The container started but `/healthz/ready` (K5 v2) isn't responding 200.
Either the app failed to bind the port, or it bound but isn't routing
the probe path.

**Fix — check logs**

```bash
kubectl logs <pod-name> -n <namespace>
```

Common shapes:

- **`ModuleNotFoundError`** → your Dockerfile didn't install
  `jac-scale[deploy]` or your service file isn't in `/app`.

- **Port mismatch** → container `containerPort: 8000` but your code
  binds 8080. Fix in jac.toml:
  ```toml
  [plugins.scale.kubernetes]
  container_port = 8080
  ```

- **`/healthz/ready` returns 404** → you're running an OLD jac-scale
  that doesn't have K5 v2 endpoints. Either update your image or hit
  `/healthz` (the legacy alias still works).

---

## Gateway 503 on every `/api/<svc>/*` request

**Symptom**

Pods are all `Ready`, gateway `/health` returns 200, but
`/api/products/walker/list_products` returns 503.

**What's wrong**

This was [the K9 bug](#layered-bugs-from-k-track-iteration) —
`start_gateway_only` skipped LocalDeployer, so registry entries stayed
in `REGISTERED` status, and `handle_proxy` short-circuited everything to
503.

If you're on a release that has the fix (any tag with K9.x), this should
not happen. If you ARE seeing this with a recent build:

**Fix**

```bash
# Confirm gateway pod is the right image
kubectl describe pod -l app=gateway -n <ns> | grep Image
# Should show your build tag, not a stale one
```

Then check the gateway log for any "service unhealthy" lines:

```bash
kubectl logs -l app=gateway -n <ns> --tail=100
```

If you see `handle_proxy: svc.status not HEALTHY`, that's the bug; bump
to a release with the fix.

---

## "FAIL: <N> non-2xx responses during rolling restart"

**Symptom**

Real-app e2e (`k8s_microservice_real_e2e.sh`) fails phase 1 or phase 2
zero-downtime check.

**What's wrong**

K5's four wires are misconfigured for the workload:

1. **`RollingUpdate{maxSurge: 1, maxUnavailable: 0}`** — surge a new
   pod BEFORE killing the old one. Set on the Deployment manifest.
2. **`readinessProbe` on `/healthz/ready`** — gates Endpoints membership.
3. **`terminationGracePeriodSeconds`** — must be > drain_timeout + 5.
4. **`preStop: sleep 5`** — bridges kube-proxy endpoint propagation.

**Fix — diagnose which wire**

Print the histogram from the failed run:

```
gateway response-code histogram:
   1245  200
      3  503
```

503s during rollout almost always mean the readiness probe fired too
slow. Lower `periodSeconds` to 3 (from 5) on `_build_readiness_probe` to
get the rolling-out pod out of Endpoints faster.

000s (connection errors) almost always mean the preStop sleep is too
short for your kube-proxy refresh cadence. Bump from 5 to 10 in
`_build_prestop_hook`.

If neither helps, the upstream jaclang drain middleware may not be
flipping `is_draining()` correctly — check `kubectl logs` for the
"drain: started" log line on the terminating pod; if missing, the
SIGTERM-handler chain isn't wired.

---

## Diagnostic flow

When stuck, walk this checklist in order:

```
1. kubectl cluster-info
   → if fails, fix config/connectivity (above)

2. kubectl get pods -n <ns>
   → all pods should be Running + Ready
   → if Pending: kubectl describe pod <name> | tail
   → if ImagePullBackOff: image push / registry creds (above)
   → if CrashLoopBackOff: kubectl logs <name>

3. kubectl get endpoints <gateway-service> -n <ns>
   → must show at least one IP
   → if empty: readinessProbe failing (above)

4. kubectl port-forward svc/gateway-service 8000:8000 -n <ns>
5. curl http://localhost:8000/healthz/live
   → must return 200 always
6. curl http://localhost:8000/healthz/ready
   → must return 200 (or 503 only during drain)
7. curl http://localhost:8000/health
   → must return 200 with registry summary

8. curl http://localhost:8000/api/<svc>/walker/__missing__
   → 404 = HEALTHY service that doesn't have this walker (success shape)
   → 503 = gateway can't reach service (registry / Endpoints issue)
   → 000 = transport error (port-forward died, retry)
```

Most failures terminate at one of these steps with a clear next action.

---

## When the framework itself is the bug

If you've walked the flow and everything looks correct but it still
doesn't work, capture this snapshot and file an issue:

```bash
kubectl get pods,svc,endpoints,deploy,hpa,pdb,ingress -n <ns> -o yaml \
    > snapshot.yaml
kubectl describe pods -n <ns> > describe.txt
kubectl logs -l managed=jac-scale -n <ns> --tail=200 > logs.txt
jac --version > version.txt
```

`describe.txt` and `logs.txt` are usually enough; `snapshot.yaml` is the
backup detail dump.

---

## Notes referenced above

### Layered bugs from K-track iteration

The CI iteration that landed K1-K10 caught three bugs that local unit
tests didn't catch. They're documented in the release notes for
historical context but should not recur on any release post-K9:

1. Gateway `/healthz` was in `_BUILTIN_EXACT` → 404 from passthrough
   when the registry was empty.
2. `start_gateway_only` (K8s mode) didn't pre-mark services HEALTHY →
   `handle_proxy` 503'd everything.
3. `get_microservices_config` didn't pass the `ingress` block through
   → K10 Ingress object was silently never applied.

All three now have unit-test regression coverage; you should never see
them on a current build.

### P4.3 RBAC (deferred)

Today, `jac start --scale` from a pod requires a cluster-admin-equivalent
ServiceAccount. P4.3 will introduce a least-privilege RBAC manifest for
in-cluster admin pods. Until then, if you must run admin commands from
inside a pod, use the `cluster-admin` role bound to a dedicated SA, not
the default one.
