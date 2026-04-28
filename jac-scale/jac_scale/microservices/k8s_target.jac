"""Kubernetes deployment target for microservice mode.

K1 scope (done): scaffold KubernetesMicroserviceTarget(KubernetesTarget),
wire into `jac start <file> --scale`, build image + emit pod-spec stubs.

K2 scope (this file): turn pod-spec stubs into full Deployment +
ClusterIP Service manifests per service. `generate_manifests` returns
a structured bundle with `deployments`, `services`, and the original
`pod_specs` (kept for inspection + back-compat with K1 tests).

K2 still does NOT call kubectl - that's K3's job. Returning the manifest
dicts lets K3 just iterate them and apply, and lets us verify the
manifest shape via unit tests without a live cluster.

K4 wires the runtime DNS adapter (KubernetesDeployer + get_sv_registry).
K5 adds RollingUpdate + readiness + grace + preStop for no-downtime deploys.
K6 adds HPA + PodDisruptionBudget per service.
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

    """Generate K8s manifests for the microservice topology (K2 scope).

    Returns a `DeploymentResult` whose `details` carry the manifest
    bundle: `deployments` + `services` keyed by service name, plus the
    raw `pod_specs` from K1. K3 will iterate this bundle and call
    `kubectl apply` in dependency order.
    """
    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        if self.logger {
            self.logger.info(
                f"Deploying microservice app '{app_name}' to Kubernetes "
                f"(K2 manifest gen; K3 will add kubectl apply)",
                {"namespace": self.k8s_config.namespace}
            );
        }

        try {
            bundle = self.generate_manifests(app_config);
        } except Exception as e {
            return DeploymentResult(
                success=False,
                message=f"manifest generation failed: {e}"
            );
        }

        svc_count = len(bundle["pod_specs"]) - 1;
        return DeploymentResult(
            success=True,
            message=(
                f"K2 manifests generated: {svc_count} service Deployment+Service "
                f"pair(s) plus 1 gateway. K3 will apply via kubectl."
            ),
            details=bundle
        );
    }

    """Lift K1 pod-specs into full Deployment + Service manifests.

    Returns `{"deployments": {svc: manifest}, "services": {svc: manifest},
    "pod_specs": {svc: spec}}`. The `pod_specs` entry is the same dict
    K1 returned; deployments wrap each pod-spec in a Deployment template
    (replicas=1 for now; K6 will make per-service-configurable), and
    services emit a paired ClusterIP Service so kube-proxy can route
    inter-service traffic.
    """
    def generate_manifests(app_config: AppConfig) -> dict[str, Any] {
        pod_specs = self.generate_service_pod_specs(app_config);
        deployments: dict[str, dict[str, Any]] = {};
        services: dict[str, dict[str, Any]] = {};
        for (svc_name, pod_spec) in pod_specs.items() {
            deployments[svc_name] = self._build_deployment_manifest(
                svc_name, pod_spec
            );
            services[svc_name] = self._build_service_manifest(svc_name);
        }
        return {
            "deployments": deployments,
            "services": services,
            "pod_specs": pod_specs
        };
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

    """Map a service name to a DNS-1123-valid K8s resource name.

    `GATEWAY_NAME` ("__gateway__") is mapped to "gateway" because K8s
    resource names must match the DNS-1123 regex
    `[a-z0-9]([-a-z0-9]*[a-z0-9])?` (no underscores, no leading hyphens).
    Other names are lowercased and have underscores replaced with
    hyphens; the caller is responsible for ensuring the result is short
    enough (<=63 chars) and otherwise compliant.
    """
    def _k8s_safe_name(svc_name: str) -> str {
        if svc_name == GATEWAY_NAME {
            return "gateway";
        }
        return svc_name.lower().replace("_", "-");
    }

    """Build a Deployment manifest wrapping the K1 pod-spec.

    `replicas: 1` is a placeholder; K6 will source per-service replica
    counts from `[plugins.scale.microservices.services.NAME].replicas`.
    Labels match the convention used by `KubernetesTarget` for the
    monolith path so existing operator dashboards / Prometheus scrapes
    discover microservice pods the same way.
    """
    def _build_deployment_manifest(
        svc_name: str, pod_spec: dict[str, Any]
    ) -> dict[str, Any] {
        k8s_name = self._k8s_safe_name(svc_name);
        role: str = "gateway" if svc_name == GATEWAY_NAME else "microservice";
        labels: dict[str, str] = {
            "app": k8s_name,
            "managed": "jac-scale",
            "jac-scale.role": role
        };
        return {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {
                "name": f"{k8s_name}-deployment",
                "namespace": self.k8s_config.namespace,
                "labels": labels
            },
            "spec": {
                "replicas": 1,
                "selector": {"matchLabels": {"app": k8s_name}},
                "template": {
                    "metadata": {"labels": labels},
                    "spec": pod_spec
                }
            }
        };
    }

    """Build a ClusterIP Service manifest paired with the Deployment.

    Stays ClusterIP - inter-service traffic stays inside the cluster and
    external traffic comes through the gateway via the NGINX Ingress
    (added in K3). Selector matches the Deployment's pod labels so
    kube-proxy routes to ready pods only.
    """
    def _build_service_manifest(svc_name: str) -> dict[str, Any] {
        k8s_name = self._k8s_safe_name(svc_name);
        port: int = self.k8s_config.container_port;
        return {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {
                "name": f"{k8s_name}-service",
                "namespace": self.k8s_config.namespace,
                "labels": {"app": k8s_name, "managed": "jac-scale"}
            },
            "spec": {
                "type": "ClusterIP",
                "selector": {"app": k8s_name},
                "ports": [
                    {
                        "protocol": "TCP",
                        "port": port,
                        "targetPort": port
                    }
                ]
            }
        };
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
