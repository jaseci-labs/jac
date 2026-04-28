"""Kubernetes deployment target for microservice mode.

K1 scope: scaffold KubernetesMicroserviceTarget(KubernetesTarget) and
wire it into the existing `jac start <file> --scale` flow. The target
reuses KubernetesTarget's image build/push pipeline and iterates over
`sv import`-discovered services to emit per-service pod-spec stubs.

K1 deliberately stops at "build image + emit pod-spec dicts" - it
returns them in the DeploymentResult.details for inspection, but does
NOT generate K8s manifests or call kubectl.

K2 will turn the stubs into Deployment + ClusterIP Service manifests.
K3 will apply them via kubectl.
K4 wires the runtime DNS adapter (KubernetesDeployer + get_sv_registry).
K5 adds RollingUpdate + readiness + grace + preStop for no-downtime deploys.
"""

import logging;
import from typing { Any }
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }

glob logger = logging.getLogger(__name__);

"""Sentinel name used in pod_specs for the gateway pod-spec entry.

The gateway is just another pod in K8s mode (one Deployment, one
ClusterIP Service), but its name is reserved to avoid collision with
user-defined service modules.
"""
glob GATEWAY_NAME: str = "__gateway__";


"""K8s target that fans a single image out to one pod per microservice.

Inherits from `KubernetesTarget` to reuse:
    - image build + push (`_handle_image_registry` -> registry.build_and_push)
    - namespace, secret, env-loading machinery
    - probe / resource / service config builders

The microservice-specific extension is per-service iteration: the
project's `[plugins.scale.microservices.routes]` table is the source of
truth for "which services exist." Each gets a pod-spec dict pointing at
the same image, differentiated by env `JAC_SV_NAME`.

Selected automatically by `_scale_pre_hook` when
`[plugins.scale.microservices].enabled = true` AND the user passes
`--scale` to `jac start`. Registered with `DeploymentTargetFactory`
under the type name `"kubernetes-microservice"`.
"""
obj KubernetesMicroserviceTarget(KubernetesTarget) {

    """Build the image and emit per-service pod-spec stubs (K1 scope).

    K1 returns the pod-specs in `DeploymentResult.details["pod_specs"]`
    instead of applying anything. K2/K3 will replace this with manifest
    generation + kubectl apply. The early-return shape lets us validate
    the dispatch wiring (factory + pre-hook) before any K8s API calls.
    """
    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        if self.logger {
            self.logger.info(
                f"Deploying microservice app '{app_name}' to Kubernetes "
                f"(K1 scaffold; K2-K3 will add manifest gen + apply)",
                {"namespace": self.k8s_config.namespace}
            );
        }

        try {
            specs = self.generate_service_pod_specs(app_config);
        } except Exception as e {
            return DeploymentResult(
                success=False,
                message=f"K1 pod-spec generation failed: {e}"
            );
        }

        svc_count = len(specs) - 1;
        return DeploymentResult(
            success=True,
            message=(
                f"K1 scaffold complete: built image, emitted pod-spec stubs "
                f"for 1 gateway + {svc_count} service(s). Manifest generation "
                f"lands in K2; kubectl apply lands in K3."
            ),
            details={"pod_specs": specs}
        );
    }

    """Build the image once and emit per-service pod-spec stubs.

    Returns a dict keyed by service name (plus `GATEWAY_NAME` for the
    gateway). Each value is a partial PodSpec (container list with
    image, env, ports). K2 will lift these into full Deployment +
    Service manifests.

    The image build path delegates to `_handle_image_registry` from
    `KubernetesTarget`, so `app_config.build = False` short-circuits to
    the configured python_image fallback (handy for tests).
    """
    def generate_service_pod_specs(
        app_config: AppConfig
    ) -> dict[str, dict[str, Any]] {
        app_name = app_config.app_name or self.k8s_config.app_name;
        image: str = self._handle_image_registry(app_name, app_config);

        import from jac_scale.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        routes: dict[str, str] = ms_cfg.get("routes", {});

        specs: dict[str, dict[str, Any]] = {};
        for svc_name in routes.keys() {
            specs[svc_name] = self._build_service_pod_spec(svc_name, image);
        }
        specs[GATEWAY_NAME] = self._build_gateway_pod_spec(image);

        if self.logger {
            self.logger.info(
                f"Generated {len(specs)} pod-spec stubs "
                f"(1 gateway + {len(routes)} services)",
                {"image": image, "namespace": self.k8s_config.namespace}
            );
        }
        return specs;
    }

    """Per-service pod-spec stub. K2 will surround with Deployment metadata."""
    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, Any] {
        return {
            "containers": [{
                "name": svc_name,
                "image": image,
                "env": [{"name": "JAC_SV_NAME", "value": svc_name}],
                "ports": [{"containerPort": self.k8s_config.container_port}]
            }]
        };
    }

    """Gateway pod-spec stub. Same image as services; the entrypoint
    selects gateway-mode based on JAC_SV_NAME = GATEWAY_NAME."""
    def _build_gateway_pod_spec(image: str) -> dict[str, Any] {
        return {
            "containers": [{
                "name": "gateway",
                "image": image,
                "env": [{"name": "JAC_SV_NAME", "value": GATEWAY_NAME}],
                "ports": [{"containerPort": self.k8s_config.container_port}]
            }]
        };
    }
}
