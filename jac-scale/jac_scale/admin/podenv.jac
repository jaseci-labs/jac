"""Pod environment panel for the Ops Console.

Admin-auth-gated, namespace-scoped, read-only. The MOST sensitive Ops
Console surface, so it is allowlist-redacted by design: only keys matching
a known-safe prefix (OTEL_*/JAC_*/K8S_*/POD_*/KUBERNETES_*/TRACING_* + a
few backend URLs) show their value; every other key shows its NAME with a
masked value. Allowlist (not denylist) so a key we didn't anticipate is
masked, not leaked.

  /admin/ops/podenv  - this pod's own process env (the /proc/1/environ
                       analog) + each pod's CONFIGURED spec env. secretRef
                       / configMapRef values are never resolved (shown as
                       `(from secret)` etc.), so no secret material leaves
                       the cluster regardless of the allowlist.

Reuses the read-only Ops Console Role (admin/k8s_ops.jac).
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }

"""Mixin providing the in-admin pod-env panel."""
obj JacAPIServerPodEnv {
    def register_podenv_endpoints -> None;
}
