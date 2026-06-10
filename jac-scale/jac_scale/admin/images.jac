"""Image / build freshness backend for the Ops Console (V-06).

Admin-auth-gated, namespace-scoped, read-only:

  /admin/ops/images  - per app (deployment) the running image: spec image
                       tag vs the resolved `imageID` sha256 digest, cross-
                       replica digest consistency, plus the B-01 build
                       identity (JAC_IMAGE_REF / JAC_BUILD_SHA) injected
                       into pod env. The truth-teller for image-caching
                       bugs ("did my deploy actually update?").

Reuses the read-only Ops Console Role (admin/k8s_ops.jac).
"""
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jac_scale.jserver.jserver { HTTPMethod, JEndPoint }

"""Mixin providing the in-admin image-freshness view (V-06)."""
obj JacAPIServerImages {
    def register_images_endpoints -> None;
}
