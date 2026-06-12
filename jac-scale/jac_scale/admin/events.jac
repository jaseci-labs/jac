"""Events / resource-pressure backend for the Ops Console.

Admin-auth-gated, namespace-scoped, read-only:

  /admin/ops/events  - recent K8s events (Warning-first), so OOMKilled,
                       FailedScheduling / Insufficient memory, unbound-PVC
                       FailedBinding, ImagePullBackOff etc. surface without
                       kubectl. A `pressure` summary flags the high-signal
                       reasons.

Reuses the read-only Ops Console Role (admin/k8s_ops.jac).
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }

"""Mixin providing the in-admin events / resource-pressure view."""
obj JacAPIServerEvents {
    def register_events_endpoints -> None;
}
