"""Kubernetes deployment target for microservice mode.

K1 (done): scaffold + image build + pod-spec stubs + factory dispatch.
K2 (done): full Deployment + ClusterIP Service manifests per service.
K3 (done): apply / destroy lifecycle via the kubernetes Python client.
K4 (done): runtime DNS adapter (KubernetesDeployer + get_sv_registry).
K5 (done): rolling-deploy correctness (RollingUpdate strategy +
readinessProbe/livenessProbe + terminationGracePeriodSeconds + preStop).

K6 (done): HorizontalPodAutoscaler + PodDisruptionBudget per service.

K7 scope (this file): per-service config layering. Knobs at
`[plugins.scale.microservices.services.NAME]` flow through the
manifest builders:

  - `replicas` (int)             -> Deployment.spec.replicas
  - `cpu_request`, `cpu_limit`   -> container resources (e.g. "100m")
  - `memory_request`,
    `memory_limit`               -> container resources (e.g. "128Mi")
  - `env` (dict[str,str])        -> extra container env vars (merged
                                    with JAC_SV_NAME, no override of it)
  - `image_tag` (str)            -> override the global image tag
                                    (useful for canary)
  - `hpa.enabled` (bool)         -> emit HPA at all (default true)
  - `hpa.min` / `hpa.max` /
    `hpa.cpu_target` (int)       -> HPA bounds + threshold
  - `pdb.enabled` (bool)         -> emit PDB at all (default true)
  - `pdb.max_unavailable` (int)  -> PDB tolerance

The gateway uses the same table keyed by GATEWAY_NAME ("__gateway__").
All knobs are optional - omit and you get the K5/K6 defaults.

K8 adds minikube e2e + CI workflow.
"""

import logging;
import from typing { Any }
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale._optdeps.kubernetes {
    client,
    config as k8s_cluster_config,
    ApiException,
    ConfigException
}
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists
}

glob logger = logging.getLogger(__name__);

"""Sentinel name used in pod_specs for the gateway pod-spec entry.

The gateway is just another pod in K8s mode (one Deployment, one
ClusterIP Service), but its name is reserved to avoid collision with
user-defined service modules.
"""
glob GATEWAY_NAME: str = "__gateway__";


"""Map a service name to a DNS-1123-valid K8s resource name.

`GATEWAY_NAME` ("__gateway__") is mapped to "gateway" because K8s
resource names must match the DNS-1123 regex
`[a-z0-9]([-a-z0-9]*[a-z0-9])?` (no underscores, no leading hyphens).
Other names are lowercased and have underscores replaced with hyphens;
the caller is responsible for ensuring the result is short enough
(<=63 chars) and otherwise compliant.

Module-level helper (not on `KubernetesMicroserviceTarget`) so K4's
`KubernetesDeployer.url_for` can reuse it without re-implementing.
The method `KubernetesMicroserviceTarget._k8s_safe_name` delegates here.
"""
def k8s_safe_name(svc_name: str) -> str {
    if svc_name == GATEWAY_NAME {
        return "gateway";
    }
    return svc_name.lower().replace("_", "-");
}


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

    """Generate K8s manifests AND apply them to the cluster (K3 scope).

    deploy() now: build image -> generate manifests -> apply via the
    kubernetes Python client. Kube config is loaded from kubeconfig
    when running outside the cluster (e.g. during `jac start --scale`
    from a developer laptop) and from in-cluster service-account
    config when running inside a pod (e.g. an admin sidecar).

    The returned `DeploymentResult.details` keeps the manifest bundle
    so callers can inspect what was applied.
    """
    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        if self.logger {
            self.logger.info(
                f"Deploying microservice app '{app_name}' to Kubernetes "
                f"(K3 apply; K5 will add rolling-deploy correctness)",
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

        try {
            self.apply_manifests(bundle);
        } except Exception as e {
            return DeploymentResult(
                success=False,
                message=f"manifest apply failed: {e}",
                details=bundle
            );
        }

        svc_count = len(bundle["pod_specs"]) - 1;
        return DeploymentResult(
            success=True,
            message=(
                f"K3 applied: {svc_count} service Deployment+Service pair(s) "
                f"plus 1 gateway in namespace '{self.k8s_config.namespace}'. "
                "K5 will add rolling-deploy correctness."
            ),
            details=bundle
        );
    }

    """Load kubernetes config: kubeconfig first, fall back to in-cluster.

    Same pattern as KubernetesTarget.destroy() and the rest of the K8s
    target machinery. Splitting out as a helper so apply_manifests +
    destroy can both call it without duplicating the try/except.
    """
    def _load_kube_config -> None {
        try {
            k8s_cluster_config.load_kube_config();
        } except ConfigException {
            k8s_cluster_config.load_incluster_config();
        }
    }

    """Apply the K2 + K6 manifest bundle to the cluster.

    Order: namespace exists -> Services -> Deployments -> HPAs -> PDBs.
    Services first so DNS resolution works the moment a Deployment's
    first pod becomes ready. HPAs and PDBs come AFTER Deployments because
    they reference Deployment names in scaleTargetRef / selector match;
    the K8s controllers re-resolve when the targets show up so out-of-
    order apply still eventually-converges, but applying after avoids
    a transient "no targets" warning. Each apply is idempotent (read ->
    patch on exists; create on 404).
    """
    def apply_manifests(bundle: dict[str, Any]) -> None {
        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        autoscaling_v2 = client.AutoscalingV2Api();
        policy_v1 = client.PolicyV1Api();
        namespace: str = self.k8s_config.namespace;

        ensure_namespace_exists(namespace);

        # Services first - their endpoints registry is empty until the
        # paired Deployment's first pod becomes ready, but DNS for the
        # Service hostname needs to exist BEFORE pods boot so any
        # cross-service `sv import` calls resolve at startup.
        for (svc_name, svc_manifest) in bundle["services"].items() {
            self._apply_or_replace_service(core_v1, namespace, svc_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied Service for '{svc_name}'",
                    {"name": svc_manifest["metadata"]["name"]}
                );
            }
        }

        # Deployments next - patching an existing Deployment kicks off
        # a rolling update via K8s Deployment controller (K5
        # RollingUpdate + readiness + grace + preStop).
        for (svc_name, dep_manifest) in bundle["deployments"].items() {
            self._apply_or_replace_deployment(apps_v1, namespace, dep_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied Deployment for '{svc_name}'",
                    {"name": dep_manifest["metadata"]["name"]}
                );
            }
        }

        # HPAs - target Deployments by name; safe to apply after the
        # Deployments exist. K6 default: min=1, max=3, cpu=70%.
        for (svc_name, hpa_manifest) in bundle.get("hpas", {}).items() {
            self._apply_or_replace_hpa(autoscaling_v2, namespace, hpa_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied HPA for '{svc_name}'",
                    {"name": hpa_manifest["metadata"]["name"]}
                );
            }
        }

        # PDBs - select pods by label, safe to apply alongside HPAs.
        # K6 default: maxUnavailable=1.
        for (svc_name, pdb_manifest) in bundle.get("pdbs", {}).items() {
            self._apply_or_replace_pdb(policy_v1, namespace, pdb_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied PDB for '{svc_name}'",
                    {"name": pdb_manifest["metadata"]["name"]}
                );
            }
        }
    }

    """Idempotent Service apply - read first, patch on hit, create on 404."""
    def _apply_or_replace_service(
        core_v1: Any, namespace: str, manifest: dict[str, Any]
    ) -> None {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_service(name=name, namespace=namespace);
            core_v1.patch_namespaced_service(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(
                    namespace=namespace, body=manifest
                );
            } else {
                raise;
            }
        }
    }

    """Idempotent Deployment apply - read first, patch on hit, create on 404.

    A patch on an existing Deployment triggers the K8s Deployment
    controller's rolling update. K5 added the explicit
    RollingUpdate { maxSurge: 1, maxUnavailable: 0 } config so this
    surges a new pod before terminating the old one.
    """
    def _apply_or_replace_deployment(
        apps_v1: Any, namespace: str, manifest: dict[str, Any]
    ) -> None {
        name: str = manifest["metadata"]["name"];
        try {
            apps_v1.read_namespaced_deployment(name=name, namespace=namespace);
            apps_v1.patch_namespaced_deployment(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                apps_v1.create_namespaced_deployment(
                    namespace=namespace, body=manifest
                );
            } else {
                raise;
            }
        }
    }

    """Idempotent HPA apply - mirrors _apply_or_replace_deployment shape."""
    def _apply_or_replace_hpa(
        autoscaling_v2: Any, namespace: str, manifest: dict[str, Any]
    ) -> None {
        name: str = manifest["metadata"]["name"];
        try {
            autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(
                name=name, namespace=namespace
            );
            autoscaling_v2.patch_namespaced_horizontal_pod_autoscaler(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                autoscaling_v2.create_namespaced_horizontal_pod_autoscaler(
                    namespace=namespace, body=manifest
                );
            } else {
                raise;
            }
        }
    }

    """Idempotent PDB apply - mirrors _apply_or_replace_deployment shape."""
    def _apply_or_replace_pdb(
        policy_v1: Any, namespace: str, manifest: dict[str, Any]
    ) -> None {
        name: str = manifest["metadata"]["name"];
        try {
            policy_v1.read_namespaced_pod_disruption_budget(
                name=name, namespace=namespace
            );
            policy_v1.patch_namespaced_pod_disruption_budget(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                policy_v1.create_namespaced_pod_disruption_budget(
                    namespace=namespace, body=manifest
                );
            } else {
                raise;
            }
        }
    }

    """Tear down all microservice Deployments + Services in the namespace.

    Uses a label selector (`managed=jac-scale,jac-scale.role in
    (microservice,gateway)`) instead of per-name deletion so it
    handles drift recovery: services that were renamed in jac.toml
    still get cleaned up because the label selector matches anything
    we've ever deployed via this target.

    `app_name` and `component` are accepted to satisfy the parent
    `DeploymentTarget.destroy` signature; they're ignored in
    microservice mode (we always tear down the whole label-selected
    set, not individual components).
    """
    def destroy(app_name: str, component: str = "") -> None {
        if self.logger {
            self.logger.info(
                f"Destroying microservice topology in namespace "
                f"'{self.k8s_config.namespace}'",
                {"app_name": app_name}
            );
        }

        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        namespace: str = self.k8s_config.namespace;

        # K6: also clean up HPAs and PDBs we applied.
        autoscaling_v2 = client.AutoscalingV2Api();
        policy_v1 = client.PolicyV1Api();

        # Label selector matches anything this target has ever applied.
        # `in (...)` syntax is K8s set-based selector grammar. PDBs use
        # the role-less label selector since they only carry the basic
        # `managed=jac-scale` label (PDBs select pods by app=<name>, not
        # role; the role label is only on Deployments + their templates).
        selector: str = (
            "managed=jac-scale,jac-scale.role in (microservice,gateway)"
        );
        ms_selector: str = "managed=jac-scale";

        # Deployments first - delete_collection_namespaced_deployment
        # is batched. Pods stop receiving traffic as the Deployment
        # controller scales them down; K5's preStop hooks bridge the
        # kube-proxy propagation gap.
        try {
            apps_v1.delete_collection_namespaced_deployment(
                namespace=namespace, label_selector=selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # HPAs - batched.
        try {
            autoscaling_v2.delete_collection_namespaced_horizontal_pod_autoscaler(
                namespace=namespace, label_selector=ms_selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # PDBs - batched.
        try {
            policy_v1.delete_collection_namespaced_pod_disruption_budget(
                namespace=namespace, label_selector=ms_selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # Services - no batched delete_collection helper for v1.Service,
        # so list-then-delete by name. Idempotent: ignore 404s.
        try {
            services = core_v1.list_namespaced_service(
                namespace=namespace, label_selector=selector
            );
            for svc in services.items {
                try {
                    core_v1.delete_namespaced_service(
                        name=svc.metadata.name, namespace=namespace
                    );
                } except ApiException as e {
                    if e.status != 404 {
                        raise;
                    }
                }
            }
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
    }

    """Lift K1 pod-specs into full Deployment + Service + HPA + PDB
    manifests.

    Returns `{"deployments": {svc: manifest}, "services": {svc: manifest},
    "hpas": {svc: manifest}, "pdbs": {svc: manifest},
    "pod_specs": {svc: spec}}`. The `pod_specs` entry is the same dict
    K1 returned; deployments wrap each pod-spec; services emit a paired
    ClusterIP Service for kube-proxy. K6 adds the per-service HPA
    (autoscaling/v2) and PDB (policy/v1) entries.
    """
    def generate_manifests(app_config: AppConfig) -> dict[str, Any] {
        pod_specs = self.generate_service_pod_specs(app_config);
        deployments: dict[str, dict[str, Any]] = {};
        services: dict[str, dict[str, Any]] = {};
        hpas: dict[str, dict[str, Any]] = {};
        pdbs: dict[str, dict[str, Any]] = {};
        for (svc_name, pod_spec) in pod_specs.items() {
            deployments[svc_name] = self._build_deployment_manifest(
                svc_name, pod_spec
            );
            services[svc_name] = self._build_service_manifest(svc_name);
            # K7: HPA / PDB builders return None when the user opts out
            # via [...services.NAME.{hpa,pdb}].enabled = false. Skip
            # those so the bundle only carries enabled entries (which
            # apply_manifests + destroy can iterate without nil checks).
            hpa = self._build_hpa_manifest(svc_name);
            if hpa is not None {
                hpas[svc_name] = hpa;
            }
            pdb = self._build_pdb_manifest(svc_name);
            if pdb is not None {
                pdbs[svc_name] = pdb;
            }
        }
        return {
            "deployments": deployments,
            "services": services,
            "hpas": hpas,
            "pdbs": pdbs,
            "pod_specs": pod_specs
        };
    }

    """K5: read drain_timeout_seconds from config (defaults to 10s).

    Used to size `terminationGracePeriodSeconds` on the pod spec so K8s
    waits at least as long as our drain middleware needs to flush
    in-flight requests, plus a 5s cushion for uvicorn to exit AFTER
    drain returns.
    """
    def _drain_timeout -> int {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return int(ms_cfg.get("drain_timeout_seconds", 10));
        } except Exception {
            return 10;
        }
    }

    """K7: read per-service config from [...services.NAME], or {} if unset.

    Returns a defensive dict copy. Read failure (e.g. no jac.toml in
    tests) returns {} so the manifest builders fall through to defaults.
    """
    def _service_config(svc_name: str) -> dict[str, Any] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return dict(ms_cfg.get("services", {}).get(svc_name, {}));
        } except Exception {
            return {};
        }
    }

    """K7: extra env vars merged with the auto-set JAC_SV_NAME.

    JAC_SV_NAME ALWAYS comes first and is never overrideable (it's
    what the entrypoint uses to pick the service). User-defined keys
    follow. List shape matches the K8s container.env schema.
    """
    def _build_env(svc_name: str, svc_cfg: dict[str, Any]) -> list[dict[str, str]] {
        env: list[dict[str, str]] = [
            {"name": "JAC_SV_NAME", "value": svc_name}
        ];
        extra: dict[str, Any] = svc_cfg.get("env", {});
        for (k, v) in extra.items() {
            if k == "JAC_SV_NAME" {
                continue;  # protected; users can't shadow the sentinel
            }
            env.append({"name": k, "value": str(v)});
        }
        return env;
    }

    """K7: container resources (requests + limits).

    Returns the K8s `resources: {requests: {...}, limits: {...}}` dict
    or {} if no overrides set. Empty resources field is omitted from
    the container so we don't emit invalid manifests.
    """
    def _build_resources(svc_cfg: dict[str, Any]) -> dict[str, Any] {
        requests: dict[str, str] = {};
        limits: dict[str, str] = {};
        if svc_cfg.get("cpu_request") {
            requests["cpu"] = str(svc_cfg["cpu_request"]);
        }
        if svc_cfg.get("memory_request") {
            requests["memory"] = str(svc_cfg["memory_request"]);
        }
        if svc_cfg.get("cpu_limit") {
            limits["cpu"] = str(svc_cfg["cpu_limit"]);
        }
        if svc_cfg.get("memory_limit") {
            limits["memory"] = str(svc_cfg["memory_limit"]);
        }
        out: dict[str, Any] = {};
        if requests {
            out["requests"] = requests;
        }
        if limits {
            out["limits"] = limits;
        }
        return out;
    }

    """K7: apply per-service `image_tag` override if set.

    Replaces the tag part of `repo/name:tag` URLs. Careful: registry
    hostnames can have ports like `myregistry.io:5000/name:tag`, so
    split on the LAST colon, then verify the part after it has no `/`
    (that would mean it's actually a registry-port colon, not a tag).
    """
    def _resolve_image(image: str, svc_cfg: dict[str, Any]) -> str {
        tag = svc_cfg.get("image_tag");
        if not tag {
            return image;
        }
        if ":" not in image {
            return f"{image}:{tag}";
        }
        idx: int = image.rindex(":");
        after: str = image[idx + 1:];
        if "/" in after {
            # The colon was a registry port, not a tag separator.
            return f"{image}:{tag}";
        }
        return f"{image[:idx]}:{tag}";
    }

    """K5: standard probe pointing at /healthz on the container port.

    Used for both readinessProbe AND livenessProbe in K5 v1. Future:
    split /healthz into /healthz/ready (gates traffic) and /healthz/live
    (gates restart) so liveness doesn't trip on dependency degradation.
    """
    def _build_probe -> dict[str, Any] {
        return {
            "httpGet": {
                "path": "/healthz",
                "port": self.k8s_config.container_port
            },
            "initialDelaySeconds": 5,
            "periodSeconds": 5,
            "timeoutSeconds": 3,
            "failureThreshold": 3
        };
    }

    """K5: preStop hook that sleeps before SIGTERM-induced shutdown.

    Bridges the kube-proxy endpoint-propagation gap. Kubelet sends
    SIGTERM and updates the Endpoints object simultaneously, but
    other nodes' kube-proxy tables don't reflect the removal for
    a few seconds; without this sleep, the pod stops accepting work
    BEFORE remote kube-proxy stops sending work, producing 503s.
    """
    def _build_prestop_hook -> dict[str, Any] {
        return {"exec": {"command": ["sh", "-c", "sleep 5"]}};
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

    """Thin delegator to module-level `k8s_safe_name`.

    Kept as a method so existing tests calling `target._k8s_safe_name(...)`
    keep working without churn. The K4 `KubernetesDeployer` uses the
    module-level helper directly to avoid needing a target instance.
    """
    def _k8s_safe_name(svc_name: str) -> str {
        return k8s_safe_name(svc_name);
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
        # K7: per-service replicas override; default 1.
        svc_cfg = self._service_config(svc_name);
        replicas: int = int(svc_cfg.get("replicas", 1));
        return {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {
                "name": f"{k8s_name}-deployment",
                "namespace": self.k8s_config.namespace,
                "labels": labels
            },
            "spec": {
                "replicas": replicas,
                # K5: surge a new pod before terminating an old one,
                # never go below the current replica count during
                # rollout. With drain + preStop on the pod side, this
                # gives no-downtime rolling updates.
                "strategy": {
                    "type": "RollingUpdate",
                    "rollingUpdate": {
                        "maxSurge": 1,
                        "maxUnavailable": 0
                    }
                },
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

    """K6: Build an HPA targeting the Deployment. K7 layers per-service
    overrides at `[...services.NAME.hpa]`.

    Returns None when `hpa.enabled = false` so the user can opt OUT of
    autoscaling for services that need fixed replica counts (e.g. a
    leader-only worker, or a stateful service tied to PVCs that don't
    multiplex).
    """
    def _build_hpa_manifest(svc_name: str) -> dict[str, Any] | None {
        cfg: dict[str, Any] = self._service_config(svc_name).get("hpa", {});
        if not cfg.get("enabled", True) {
            return None;
        }
        k8s_name = self._k8s_safe_name(svc_name);
        min_r: int = int(cfg.get("min", 1));
        max_r: int = int(cfg.get("max", 3));
        cpu: int = int(cfg.get("cpu_target", 70));
        return {
            "apiVersion": "autoscaling/v2",
            "kind": "HorizontalPodAutoscaler",
            "metadata": {
                "name": f"{k8s_name}-hpa",
                "namespace": self.k8s_config.namespace,
                "labels": {"app": k8s_name, "managed": "jac-scale"}
            },
            "spec": {
                "scaleTargetRef": {
                    "apiVersion": "apps/v1",
                    "kind": "Deployment",
                    "name": f"{k8s_name}-deployment"
                },
                "minReplicas": min_r,
                "maxReplicas": max_r,
                "metrics": [
                    {
                        "type": "Resource",
                        "resource": {
                            "name": "cpu",
                            "target": {
                                "type": "Utilization",
                                "averageUtilization": cpu
                            }
                        }
                    }
                ]
            }
        };
    }

    """K6: Build a PodDisruptionBudget matching the Deployment pods.
    K7 layers per-service overrides at `[...services.NAME.pdb]`.

    Returns None when `pdb.enabled = false`. Useful for services that
    are explicitly OK with full eviction during node maintenance, or
    for single-replica services where a PDB just blocks routine
    cluster operations without giving real HA value.
    """
    def _build_pdb_manifest(svc_name: str) -> dict[str, Any] | None {
        cfg: dict[str, Any] = self._service_config(svc_name).get("pdb", {});
        if not cfg.get("enabled", True) {
            return None;
        }
        k8s_name = self._k8s_safe_name(svc_name);
        max_u: int = int(cfg.get("max_unavailable", 1));
        return {
            "apiVersion": "policy/v1",
            "kind": "PodDisruptionBudget",
            "metadata": {
                "name": f"{k8s_name}-pdb",
                "namespace": self.k8s_config.namespace,
                "labels": {"app": k8s_name, "managed": "jac-scale"}
            },
            "spec": {
                "maxUnavailable": max_u,
                "selector": {"matchLabels": {"app": k8s_name}}
            }
        };
    }

    """K9: pod entrypoint dispatch.

    Each pod runs the same image with `JAC_SV_NAME` env set; this
    container command reads the env at runtime and routes:
      __gateway__ -> `jac scale gateway`  (K9.2; gateway-only mode)
      <svc_name>  -> `jac start <name>.jac`

    `JAC_SV_SIBLING=1` is exported BEFORE the dispatch so the
    JacScalePlugin pre-hook skips its local-mode orchestrator block
    (which would try to spawn peers). DNS-based peer URL resolution is
    handled by K4's get_sv_registry hookimpl + K9.1's sv_service_call
    routing through that hookspec.

    Returns the K8s container `command` + `args` pair. Image must have
    `jac` + `jac-scale[deploy]` installed; see the Dockerfile template
    in `jac-scale/jac_scale/microservices/scripts/`.
    """
    def _pod_entrypoint -> dict[str, Any] {
        return {
            "command": ["sh", "-c"],
            "args": [
                "set -euo pipefail; "
                "export JAC_SV_SIBLING=1; "
                'if [ "$JAC_SV_NAME" = "__gateway__" ]; then '
                "  exec jac scale gateway; "
                "else "
                '  exec jac start "${JAC_SV_NAME}.jac"; '
                "fi"
            ]
        };
    }

    """Per-service pod-spec.

    K2 wraps in Deployment metadata. K5 adds readiness/liveness probes,
    preStop hook, and grace period. K7 layers per-service config:
    image_tag override, resources, extra env vars. K9 sets command/args
    so pods actually start the right service / gateway based on
    JAC_SV_NAME.
    """
    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, Any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(svc_name);
        entry = self._pod_entrypoint();
        container: dict[str, Any] = {
            "name": svc_name,
            "image": self._resolve_image(image, svc_cfg),
            "command": entry["command"],
            "args": entry["args"],
            "env": self._build_env(svc_name, svc_cfg),
            "ports": [{"containerPort": self.k8s_config.container_port}],
            "readinessProbe": self._build_probe(),
            "livenessProbe": self._build_probe(),
            "lifecycle": {"preStop": self._build_prestop_hook()}
        };
        resources = self._build_resources(svc_cfg);
        if resources {
            container["resources"] = resources;
        }
        return {
            "containers": [container],
            # +5s cushion lets uvicorn finish exiting AFTER our drain
            # middleware completes; without it, SIGKILL can arrive
            # mid-drain.
            "terminationGracePeriodSeconds": drain_t + 5
        };
    }

    """Gateway pod-spec. Same image as services; entrypoint selects
    gateway-mode based on JAC_SV_NAME = GATEWAY_NAME. K7 lets the
    user tune the gateway via [...services.__gateway__] just like a
    regular service.
    """
    def _build_gateway_pod_spec(image: str) -> dict[str, Any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(GATEWAY_NAME);
        entry = self._pod_entrypoint();
        container: dict[str, Any] = {
            "name": "gateway",
            "image": self._resolve_image(image, svc_cfg),
            "command": entry["command"],
            "args": entry["args"],
            "env": self._build_env(GATEWAY_NAME, svc_cfg),
            "ports": [{"containerPort": self.k8s_config.container_port}],
            "readinessProbe": self._build_probe(),
            "livenessProbe": self._build_probe(),
            "lifecycle": {"preStop": self._build_prestop_hook()}
        };
        resources = self._build_resources(svc_cfg);
        if resources {
            container["resources"] = resources;
        }
        return {
            "containers": [container],
            "terminationGracePeriodSeconds": drain_t + 5
        };
    }
}
