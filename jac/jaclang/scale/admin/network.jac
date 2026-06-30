"""Network/storage view backend for the Ops Console.

Admin-auth-gated, namespace-scoped, read-only:

  /admin/ops/network  - services (+ ready backing endpoints), the ingress
                        rules and resolved load-balancer/backend, and PVC
                        status with claimant pods.

Reuses the read-only Ops Console Role (admin/k8s_ops.jac); degrades to a
clean "unavailable" off-cluster.
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver { HTTPMethod, JEndPoint }

"""Mixin providing the in-admin endpoints/ingress/PVC view."""
obj JacAPIServerNetwork {
    def register_network_endpoints -> None;
}
