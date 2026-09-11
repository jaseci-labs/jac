# KEDA HTTP Add-on automatic interceptor-routing e2e fixture

A two-service microservices app (`app.jac` at the gateway's root route, and
`worker.jac`, HTTP-activated and scaled to zero) proving jac-scale routes
traffic to a scaled-to-zero service through the KEDA HTTP Add-on interceptor
automatically -- no manual Ingress or gateway rewiring, and no Host header
set by the caller.

```
keda_http_activation_rpc_wake_e2e/
  app.jac     Root-routed service; its `trigger_ping` walker calls
              worker.ping() over sv-to-sv RPC.
  worker.jac  HTTP-activated, scale-to-zero service; a single `ping` walker.
  jac.toml    [apps.app] + [apps.worker] with per-app http_activation on
              `worker` only -- `app` stays warm, matching a real "frontend
              service in front of an occasionally-used backend" shape.
```

Unlike `../keda_http_activation_e2e/` (which curls the interceptor proxy
directly with a hand-set `Host` header, proving the KEDA HTTP Add-on itself
works once traffic is correctly routed to it), this fixture proves jac-scale
does that routing *for you*: every request in this e2e goes to the gateway's
own Service, exactly as a normal client would send it.

## What the e2e covers

[`../deploy/keda_http_activation_rpc_wake_real_e2e.sh`](../deploy/keda_http_activation_rpc_wake_real_e2e.sh)
drives the deploy against whatever cluster the current kubeconfig points at.
No mocking, no manually-set `Host` header anywhere in the script. The flow:

1. Deploy via `jac scale deploy app.jac` from this directory, then redeploy
   once more to confirm the `InterceptorRoute`/`ScaledObject` reconcile is
   idempotent.
2. Poll both resources' `status.conditions[type=Ready]` until Ready.
3. Wait for `worker` to reach 0 replicas. A fresh deploy starts it at 1
   replica; without this wait, the first wake test below could pass even
   with broken interceptor routing, simply because the pod was still warm.
4. Port-forward the **gateway's own Service** (not the interceptor).
5. **External wake**: `POST /worker/walker/ping` straight at the gateway,
   with no `Host` header set by the script. The gateway must resolve
   `worker`'s interceptor route and set that header itself for the request
   to succeed. Confirms `worker` scales 0 -> 1, then waits out the cooldown
   and confirms it scales back to 0.
6. **Internal RPC wake**: `POST /walker/trigger_ping` at the gateway (the
   `app` service, always warm). `app`'s handler calls `worker.ping()` over
   sv-to-sv RPC -- exercising the separate code path in `rpc.jac`, not the
   gateway's HTTP-forward path. Confirms `worker` scales 0 -> 1 again purely
   from that internal call, then waits out the cooldown and confirms it
   scales back to 0 a second time.

## Prerequisites

Same as `../keda_http_activation_e2e/README.md`: KEDA core and the HTTP
Add-on installed on the target cluster, and (on `kind`) an RWX-capable
`StorageClass` provisioned for the bundle PVC -- see that README for the
`helm install` and `StorageClass`/`PersistentVolume` commands, substituting
this fixture's `bundle_storage_class` (`jac-http-e2e-rwx`, same name, reused)
and namespace (`jac-http-rpc-wake-e2e`).

## Run

```bash
cd ~/jaseci
bash jac/jaclang/scale/tests/deploy/keda_http_activation_rpc_wake_real_e2e.sh \
     jac/jaclang/scale/tests/fixtures/keda_http_activation_rpc_wake_e2e
```

The fixture directory argument is optional; it defaults to this directory
when omitted. Same overrides as the sibling script
(`E2E_KEEP_NS_ON_FAIL`, `READY_TIMEOUT`, `DELETE_TIMEOUT`, `BUNDLE_STORAGE_CLASS`).

Expected runtime: roughly twice the sibling fixture's (~3 minutes), since
this script waits out the cooldown period twice -- once per wake path.

## Cleanup

Cleanup runs unconditionally (trap on EXIT): it deletes the
`jac-http-rpc-wake-e2e` namespace. If the run failed, the namespace is kept
for inspection by default; set `E2E_KEEP_NS_ON_FAIL=0` to force cleanup even
on failure.
