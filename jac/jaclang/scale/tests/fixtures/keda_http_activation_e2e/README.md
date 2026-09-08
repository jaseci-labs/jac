# KEDA HTTP Add-on activation e2e fixture

A minimal Jac app (`app.jac`) deployed via `jac scale deploy`, with
`[scale.kubernetes.http_activation]` enabled in `jac.toml` so the deploy
wires up the KEDA HTTP Add-on's `InterceptorRoute` + `ScaledObject` for real
scale-to-zero activation (#7475).

```
keda_http_activation_e2e/
  app.jac    A single public walker (`echo`) reporting a JSON message.
  jac.toml   [scale.kubernetes.http_activation] config; deploys as app "echo".
```

This fixture is a real Jac app deployed through the normal CLI path, not a
raw manifest -- `jac scale deploy` builds the Deployment/Service and, from
the `http_activation` config, the `InterceptorRoute`/`ScaledObject` too. See
`../http_activation_toml_e2e/` for the sibling fixture this one follows the
same pattern as.

## What the e2e covers

[`../deploy/keda_http_activation_real_e2e.sh`](../deploy/keda_http_activation_real_e2e.sh)
drives the deploy against whatever cluster the current kubeconfig points at.
No mocking. The flow:

1. Deploy via `jac scale deploy app.jac` from this directory.
2. Redeploy once more, to confirm the `InterceptorRoute`/`ScaledObject`
   reconcile is idempotent (get-then-patch, not create-or-duplicate) against
   a real API server.
3. Poll both resources' `status.conditions[type=Ready]` until each reports
   Ready, so a reconciliation problem fails here with a clear message
   instead of surfacing later as an opaque interceptor timeout.
4. Port-forward the HTTP Add-on interceptor and `POST /walker/echo` through
   it; this should block on the cold start, then return 200 once the target
   is Ready.
5. Wait for `echo` to scale 0 to 1 and become Available.
6. Stop traffic and wait for the cooldown period to elapse, then confirm
   `echo` scales back down to 0.

## Prerequisites

KEDA core and the HTTP Add-on must already be installed on the target
cluster; the script only checks for them, it does not install them.

Before installing the HTTP Add-on, ensure you have:

- A Kubernetes cluster (tested against the three most recent minor
  versions)
- Supported architectures: amd64, arm64, or s390x (CI-tested on amd64
  and arm64)
- Helm 3
- KEDA core installed

If you have not installed KEDA yet:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install keda kedacore/keda --namespace keda --create-namespace
```

Then install the HTTP Add-on into the same namespace as KEDA:

```bash
helm repo add kedacore https://kedacore.github.io/charts
helm repo update
helm install http-add-on kedacore/keda-add-ons-http --namespace keda
```

Verify the installation:

```bash
kubectl get pods -n keda
```

You should see pods for the operator, interceptor, and scaler
components in a Running state.

The script also preflight-checks for the `interceptorroutes.http.keda.sh`
CRD and fails immediately with the commands above if it is missing.

`jac.toml`'s `[dev] jaclang_source` points at this checkout's own `jac/`
source, so the deploy runs your in-tree code, not a published release.

On `kind`, the cluster has no RWX-capable default `StorageClass` for the
bundle PVC (its built-in `standard` class is `ReadWriteOnce`), so you need
to provision one first:

```bash
kubectl apply -f - <<YAML
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: jac-http-e2e-rwx
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: Immediate
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jac-http-e2e-rwx-bundle-pv
  labels:
    managed: jac-scale-e2e
spec:
  capacity:
    storage: 20Gi
  accessModes: ["ReadWriteMany"]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: jac-http-e2e-rwx
  hostPath:
    path: /var/jac-http-e2e-rwx-bundle
    type: DirectoryOrCreate
YAML
```

`jac.toml` already sets `bundle_storage_class = "jac-http-e2e-rwx"` under
`[scale.kubernetes]` to match. Clusters with a working default
`StorageClass` (microk8s, minikube, EKS, ...) need no such override.

## Run

```bash
cd ~/jaseci
bash jac/jaclang/scale/tests/deploy/keda_http_activation_real_e2e.sh \
     jac/jaclang/scale/tests/fixtures/keda_http_activation_e2e
```

The fixture directory argument is optional; it defaults to this
directory when omitted.

Useful overrides (all optional, defaults shown):

```bash
E2E_KEEP_NS_ON_FAIL=1 \
READY_TIMEOUT=90 \
DELETE_TIMEOUT=120 \
bash jac/jaclang/scale/tests/deploy/keda_http_activation_real_e2e.sh
```

Namespace, route host, and the KEDA polling interval / cooldown period are
no longer shell-configurable -- they live in `jac.toml` as the single source
of truth (same model as `http_activation_toml_e2e`); edit that file to
change them.

Expected runtime: around a minute and a half with default settings
(observed ~100s on a local microk8s cluster), most of it spent waiting
out the `cooldown_period` for the scale-down check. The script ends with
`=== KEDA HTTP activation REAL e2e PASSED ===` on success.

### Diagnostics on failure

On any failed step the script dumps pods, pod descriptions, events, the
target container's logs, the `InterceptorRoute` and `ScaledObject`
descriptions, and the HTTP Add-on interceptor/external-scaler logs from
the `keda` namespace before exiting.

## Cleanup

Cleanup runs unconditionally (trap on EXIT): it deletes the `jac-http-e2e`
namespace, which sweeps the Deployment/Service and the namespaced
`InterceptorRoute`/`ScaledObject` together. If the run failed, the namespace
is kept for inspection by default; set `E2E_KEEP_NS_ON_FAIL=0` to force
cleanup even on failure.
