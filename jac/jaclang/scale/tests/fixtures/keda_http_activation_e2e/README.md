# KEDA HTTP Add-on activation e2e fixture

Zero-replica `echo` Deployment (`hashicorp/http-echo`) plus its Service,
applied as a raw manifest so the e2e script can drive a real KEDA HTTP
Add-on scale-from-zero cycle against it.

```
keda_http_activation_e2e/
  fixture.yaml   Namespace + Deployment (replicas: 0) + Service
```

There is no `jac.toml` here: this fixture is not a Jac app, just the
Kubernetes objects the KEDA HTTP Add-on scales, so nothing builds or
runs a client for it.

## What the e2e covers

[`../deploy/keda_http_activation_real_e2e.sh`](../deploy/keda_http_activation_real_e2e.sh)
drives [`../deploy/keda_http_activation_verify.jac`](../deploy/keda_http_activation_verify.jac),
which calls `KEDAAutoscaler.apply_http_activation` / `destroy_http_activation`
directly against whatever cluster the current kubeconfig points at. No
mocking. The flow:

1. Apply this fixture; confirm `echo` starts at 0 replicas.
2. Call `apply_http_activation` twice: once to create the
   `InterceptorRoute` + `ScaledObject`, once more to exercise the
   get-then-patch branch against a real API server.
3. Poll both resources' `status.conditions[type=Ready]` until each
   reports Ready, so a reconciliation problem fails here with a clear
   message instead of surfacing later as an opaque interceptor timeout.
4. Port-forward the HTTP Add-on interceptor and send a request through
   it; this should block on the cold start, then return 200 once the
   target is Ready.
5. Wait for `echo` to scale 0 to 1 and become Available.
6. Stop traffic and wait for the cooldown period to elapse, then
   confirm `echo` scales back down to 0.

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
KEDA_HTTP_E2E_NAMESPACE=jac-http-e2e \
KEDA_HTTP_E2E_DEPLOYMENT=echo \
KEDA_HTTP_E2E_SERVICE=echo-svc \
KEDA_HTTP_E2E_ROUTE_HOST=echo.jac-http-e2e.local \
KEDA_HTTP_E2E_POLLING_INTERVAL=10 \
KEDA_HTTP_E2E_COOLDOWN_PERIOD=60 \
bash jac/jaclang/scale/tests/deploy/keda_http_activation_real_e2e.sh
```

Expected runtime: around a minute and a half with default settings
(observed ~100s on a local microk8s cluster), most of it spent waiting
out `KEDA_HTTP_E2E_COOLDOWN_PERIOD` for the scale-down check. The script
ends with `=== KEDA HTTP activation REAL e2e PASSED ===` on success.

### Testing the apply/destroy driver directly

The driver can also be invoked on its own against a live cluster,
without the surrounding e2e script:

```bash
cd jac
jac run jaclang/scale/tests/deploy/keda_http_activation_verify.jac apply
jac run jaclang/scale/tests/deploy/keda_http_activation_verify.jac destroy
```

`apply` prints the resolved `InterceptorRoute` and `ScaledObject` names;
`destroy` removes both. Both read their target namespace/name/host from
the same `KEDA_HTTP_E2E_*` env vars as the shell script, defaulting to
the values baked into `fixture.yaml`.

### Diagnostics on failure

On any failed step the script dumps pods, pod descriptions, events, the
target container's logs, the `InterceptorRoute` and `ScaledObject`
descriptions, and the HTTP Add-on interceptor/external-scaler logs from
the `keda` namespace before exiting.

## Cleanup

Cleanup runs unconditionally (trap on EXIT): it runs the driver's
`destroy` action, then deletes the `jac-http-e2e` namespace. If the run
failed, the namespace is kept for inspection by default; set
`E2E_KEEP_NS_ON_FAIL=0` to force cleanup even on failure.
