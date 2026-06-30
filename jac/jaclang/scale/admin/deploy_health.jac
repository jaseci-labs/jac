"""Deploy-health backend for the Ops Console.

Admin-auth-gated GET endpoint that reads the K8s API (namespace-scoped,
read-only) so operators can see pod/deployment health without kubectl:

  /admin/ops/deploy  - per deployment: desired/ready/available/updated
                       replicas + rollout status; per pod: phase, ready
                       containers, restart counts, node, and the per-
                       container spec image vs resolved imageID digest.

Needs the read-only Ops Console Role (see admin/k8s_ops.jac +
targets/.../ops_rbac.jac); degrades to a clean "unavailable" off-cluster.
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }

"""Mixin providing the in-admin deploy-health endpoint."""
obj JacAPIServerDeployHealth {
    def register_deploy_health_endpoints -> None;
}
