"""K8s deployment target for microservice mode.

Fans a single image out to one Deployment + ClusterIP Service + HPA +
PDB per microservice, plus the gateway. Inherits image build/push from
KubernetesTarget; adds per-service iteration over
`[plugins.scale.microservices.routes]`, a DNS adapter
(KubernetesDeployer) for `sv import` peer resolution, and an optional
Ingress to the gateway. Per-service config knobs at
`[plugins.scale.microservices.services.NAME]` (and `__gateway__` for
the gateway) flow through the manifest builders - see docs.md.
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
    ensure_namespace_exists,
    create_k8s_secret
}
import from jac_scale.microservices._util { k8s_service_dns_url }

glob logger = logging.getLogger(__name__);

"""Sentinel name used in pod_specs for the gateway pod-spec entry.

The gateway is just another pod in K8s mode (one Deployment, one
ClusterIP Service), but its name is reserved to avoid collision with
user-defined service modules.
"""
glob GATEWAY_NAME: str = "__gateway__";

# +5s cushion lets uvicorn finish exiting AFTER our drain middleware
# completes; without it, SIGKILL can arrive mid-drain.
glob _UVICORN_EXIT_CUSHION_S: int = 5;


"""Map a service name to a DNS-1123-valid K8s resource name.
`__gateway__` -> "gateway"; others lowercased with `_` -> `-`. Module
level so KubernetesDeployer.url_for can reuse it."""
def k8s_safe_name(svc_name: str) -> str {
    if svc_name == GATEWAY_NAME {
        return "gateway";
    }
    return svc_name.lower().replace("_", "-");
}


"""Fans one image out to one pod per microservice. Inherits image
build/push + namespace/secret machinery from KubernetesTarget. Routes
table is the source of truth for which services exist; each gets a
pod-spec differentiated by `JAC_SV_NAME`. Selected by _scale_pre_hook
when `[plugins.scale.microservices].enabled=true` + `--scale`."""
obj KubernetesMicroserviceTarget(KubernetesTarget) {
    # populated by _provision_databases (during deploy()) with
    # the wait-for-Mongo / wait-for-Redis init containers. Service +
    # gateway pod-specs read this via getattr() and attach as
    # initContainers so pods don't crash-loop until the DBs are reachable.
    has _microservice_init_containers: list[dict[str, Any]] = [];

    """Auto-build override when `_JAC_SCALE_AUTO_BUILD=1` is set (production
    `jac start --scale` path). Returns the user's pre-built docker_image_name
    if set, else hands off to auto_build_and_distribute which detects
    cluster type and builds+loads/pushes the image. Falls through to
    parent behavior when the env var is unset (preserves unit-test
    manifest-shape contracts that pass build=False)."""
    def _handle_image_registry(app_name: str, app_config: AppConfig) -> str {
        import os;
        if os.environ.get("_JAC_SCALE_AUTO_BUILD") == "1" {
            user_image = self.k8s_config.docker_image_name;
            if user_image and user_image != f"{app_name}:latest" {
                # User explicitly set a non-default image -> trust it
                if self.logger {
                    self.logger.info(
                        f"Using pre-built image: {user_image}",
                        {"source": "jac.toml docker_image_name"}
                    );
                }
                return user_image;
            }
            # Auto-build path
            return self._auto_build_image(app_name, app_config);
        }
        # Default: parent behavior (existing build_via_registry / fallback)
        return KubernetesTarget._handle_image_registry(self, app_name, app_config);
    }

    """Orchestrate the auto-build for a microservice deploy.

    Resolves the registry URL from raw config (avoids adding a new field
    to KubernetesConfig - users put `image_registry` directly under
    `[plugins.scale.kubernetes]` and we read it here). Hands off to the
    auto-build pipeline which knows how to talk to minikube/k3d/kind/
    remote registries.
    """
    def _auto_build_image(app_name: str, app_config: AppConfig) -> str {
        import from pathlib { Path }
        import from jac_scale.microservices._image_build { auto_build_and_distribute }

        # Read image_registry directly from raw [plugins.scale.kubernetes]
        # config; KubernetesConfig.from_dict drops unknown keys, so going
        # via the typed view would lose this. Empty/missing -> None,
        # which is fine for local clusters and signals "needs registry"
        # for remote.
        registry_url: str | None = None;
        try {
            import from jac_scale.config_loader { get_scale_config }
            raw = get_scale_config().load();
            k8s_raw = raw.get("kubernetes", {});
            reg = str(k8s_raw.get("image_registry", "")).strip();
            registry_url = reg;
        } except Exception {
            registry_url = None;
        }

        project_dir = Path(app_config.code_folder).resolve();
        if self.logger {
            self.logger.info(
                f"Auto-building image for microservice deploy",
                {"project_dir": str(project_dir), "app_name": app_name}
            );
        }
        image_tag = auto_build_and_distribute(
            app_name=app_name, project_dir=project_dir, registry_url=registry_url
        );
        if self.logger {
            self.logger.info(f"Auto-built image: {image_tag}", {"app_name": app_name});
        }
        return image_tag;
    }

    """Build image -> generate manifests -> apply via kubernetes Python
    client. Kubeconfig from outside, in-cluster SA from inside.
    `DeploymentResult.details` keeps the manifest bundle."""
    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        if self.logger {
            self.logger.info(
                f"Deploying microservice app '{app_name}' to Kubernetes",
                {"namespace": self.k8s_config.namespace}
            );
        }

        # provision MongoDB + Redis BEFORE generate_manifests so
        # the env_list (with MONGODB_URI/REDIS_URL secretKeyRef entries)
        # and init_containers populate every microservice pod-spec.
        # Skipped silently in tests (no kube config / not on a real cluster);
        # the provisioning helper is idempotent for re-deploys.
        try {
            self._provision_databases(app_name);
        } except Exception as e {
            return DeploymentResult(
                success=False, message=f"database provisioning failed: {e}"
            );
        }

        try {
            bundle = self.generate_manifests(app_config);
        } except Exception as e {
            return DeploymentResult(
                success=False, message=f"manifest generation failed: {e}"
            );
        }

        try {
            self.apply_manifests(bundle);
        } except Exception as e {
            return DeploymentResult(
                success=False, message=f"manifest apply failed: {e}", details=bundle
            );
        }

        svc_count = len(bundle["pod_specs"]) - 1;
        return DeploymentResult(
            success=True,
            message=(
                f"Applied {svc_count} service Deployment+Service pair(s) "
                f"plus 1 gateway in namespace '{self.k8s_config.namespace}'."
            ),
            details=bundle
        );
    }

    """Provision MongoDB + Redis (when enabled), populating self.env_list
    + self._microservice_init_containers so every pod gets connection
    envs + waits for the DBs. Reuses the parent's StatefulSet machinery;
    idempotent. Off when both `[...kubernetes].mongodb_enabled` and
    `redis_enabled` are false (both default true)."""
    def _provision_databases(app_name: str) -> None {
        import os;

        # Reset before each deploy so re-running doesn't accumulate
        # duplicate env entries (the parent's _deploy_databases appends).
        self.env_list = [];
        self._microservice_init_containers = [];

        # Same env-var gate as the auto-build path: only fires on the
        # production `jac start --scale` path (where _scale_pre_hook sets it).
        # Unit tests that exercise deploy() directly don't set the env
        # so they skip cluster-touching work entirely.
        if os.environ.get("_JAC_SCALE_AUTO_BUILD") != "1" {
            return;
        }

        mongo_on = self.k8s_config.mongodb_enabled;
        redis_on = self.k8s_config.redis_enabled;
        if not (mongo_on or redis_on) {
            if self.logger {
                self.logger.info(
                    "Database provisioning skipped (mongodb_enabled=false, "
                    "redis_enabled=false)",
                    {"app_name": app_name}
                );
            }
            return;
        }

        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        namespace: str = self.k8s_config.namespace;
        ensure_namespace_exists(namespace);

        # Apply DB StatefulSets + Services + Secrets + ServiceAccounts.
        # `cluster_env` is unused by _deploy_databases for our case
        # (it's a monolith-only knob); pass empty string.
        if self.logger {
            self.logger.info(
                f"Provisioning databases for '{app_name}': "
                f"mongodb={mongo_on}, redis={redis_on}",
                {"namespace": namespace}
            );
        }
        self._deploy_databases(app_name, namespace, apps_v1, core_v1, "");

        # Collect wait-for-DB init containers; service pods reuse them
        # to block startup until Mongo/Redis Endpoints are reachable.
        # Without this, pods crash-loop with connection-refused on
        # every restart until the DB happens to win the race.
        self._microservice_init_containers = self._get_database_init_containers(
            app_name
        );

        if self.logger {
            self.logger.info(
                f"Database env injected ({len(self.env_list)} vars), "
                f"init containers ({len(self._microservice_init_containers)})",
                {"app_name": app_name}
            );
        }
    }

    """Load kubeconfig, fall back to in-cluster, re-raise with actionable
    instructions if both fail (default ConfigException message is
    unhelpful)."""
    def _load_kube_config {
        kubeconfig_failed: bool = False;
        try {
            k8s_cluster_config.load_kube_config();
        } except ConfigException {
            kubeconfig_failed = True;
        }
        if not kubeconfig_failed {
            return;
        }
        try {
            k8s_cluster_config.load_incluster_config();
        } except ConfigException as e {
            raise ConfigException(
                "Could not load Kubernetes config from either kubeconfig "
                "or in-cluster ServiceAccount.\n"
                "If you're deploying from a laptop:\n"
                "  - Start a local cluster:  minikube start\n"
                "  - Verify kubectl works:   kubectl get nodes\n"
                "  - For a remote cluster:   set KUBECONFIG or run "
                "`aws eks update-kubeconfig` / `gcloud container clusters get-credentials`\n"
                "If you're deploying from inside a pod, the pod needs a "
                "ServiceAccount with cluster API access (the default "
                "ServiceAccount usually does, but a restricted one may not).\n"
                f"Original error from in-cluster load: {e}"
            );
        }
    }

    """Apply manifests in order: namespace -> Services -> Deployments
    -> HPAs -> PDBs -> Ingress. Services first so DNS resolves as soon
    as pods are Ready; HPAs/PDBs after Deployments so the targetRef
    isn't transiently unresolved. Each apply is read-then-patch-or-create."""
    def apply_manifests(bundle: dict[str, Any]) {
        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        autoscaling_v2 = client.AutoscalingV2Api();
        policy_v1 = client.PolicyV1Api();
        networking_v1 = client.NetworkingV1Api();
        namespace: str = self.k8s_config.namespace;

        # probe the API server early so an unreachable cluster
        # surfaces a clean error here rather than mid-apply with a
        # half-baked manifest set. `list_namespace` is the cheapest
        # cluster-scoped read (every cluster has at least kube-system),
        # and any failure here is universally bad for what follows.
        try {
            core_v1.list_namespace(_request_timeout=5);
        } except Exception as e {
            raise RuntimeError(
                f"Kubernetes API server is unreachable.\n"
                f"  - Verify cluster: kubectl cluster-info\n"
                f"  - For minikube:   minikube status\n"
                f"  - For EKS/GKE:    re-run your kubeconfig refresh "
                f"(aws eks update-kubeconfig / gcloud container clusters get-credentials)\n"
                f"Original error: {e}"
            );
        }

        ensure_namespace_exists(namespace);

        # PVCs first so Deployments referencing them don't hit
        # `persistentvolumeclaim "X" not found` and back off. PVCs in
        # "Pending" state are fine - kube-scheduler waits for binding.
        for (pvc_name, pvc_manifest) in bundle.get("pvcs", {}).items() {
            self._apply_or_replace_pvc(core_v1, namespace, pvc_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied PVC for shared volume '{pvc_name}'",
                    {"name": pvc_manifest["metadata"]["name"]}
                );
            }
        }

        # user-secret BEFORE Deployments so envFrom: secretRef
        # resolves at pod startup. Reuses parent's create_k8s_secret
        # helper which handles the create-or-replace idempotency
        # (409 -> replace_namespaced_secret).
        user_secret = bundle.get("user_secret");
        if user_secret {
            create_k8s_secret(
                core_v1,
                namespace,
                user_secret["metadata"]["name"],
                user_secret["stringData"]
            );
            if self.logger {
                self.logger.info(
                    f"Applied Secret for user-defined [plugins.scale.secrets] "
                    f"({len(user_secret['stringData'])} keys)",
                    {"name": user_secret["metadata"]["name"]}
                );
            }
        }

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
        # a rolling update via the K8s Deployment controller (using the
        # RollingUpdate + readiness + grace + preStop config below).
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
        # Deployments exist. Default: min=1, max=3, cpu=70%.
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
        # Default: maxUnavailable=1.
        for (svc_name, pdb_manifest) in bundle.get("pdbs", {}).items() {
            self._apply_or_replace_pdb(policy_v1, namespace, pdb_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied PDB for '{svc_name}'",
                    {"name": pdb_manifest["metadata"]["name"]}
                );
            }
        }

        # Ingress, applied LAST. References gateway-service by
        # name; the Ingress controller (nginx, ALB, etc.) will resolve
        # the Service the moment it sees the Ingress object regardless
        # of order, but applying after gateway-service exists avoids a
        # transient "no backend" event.
        ingress_manifest: Any = bundle.get("ingress");
        if ingress_manifest {
            self._apply_or_replace_ingress(networking_v1, namespace, ingress_manifest);
            if self.logger {
                self.logger.info(
                    "Applied Ingress for gateway",
                    {"name": ingress_manifest["metadata"]["name"]}
                );
            }
        }
    }

    """Idempotent Service apply - read first, patch on hit, create on 404."""
    def _apply_or_replace_service(
        core_v1: Any, namespace: str, manifest: dict[str, Any]
    ) {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_service(name=name, namespace=namespace);
            core_v1.patch_namespaced_service(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_service(namespace=namespace, body=manifest);
            } else {
                raise;
            }
        }
    }

    """Idempotent PVC apply: create on 404, otherwise no-op (PVCs are
    mostly immutable post-bind; patch would error or orphan the PV).
    To resize/rebind, delete the PVC or `--scale --destroy`."""
    def _apply_or_replace_pvc(core_v1: Any, namespace: str, manifest: dict[str, Any]) {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_persistent_volume_claim(
                name=name, namespace=namespace
            );
            # Already exists - skip the patch. See docstring above.
            # Surface the no-op so a user editing `size` or
            # `storage_class` in jac.toml sees that their change was
            # ignored. Otherwise the deploy succeeds silently and the
            # PVC stays at its bound configuration with no signal.
            if self.logger {
                self.logger.info(
                    f"PVC '{name}' already exists; skipping patch (PVCs "
                    f"are mostly immutable post-bind). To apply size / "
                    f"storage-class changes, delete the PVC manually "
                    f"first or run `jac start --scale --destroy`."
                );
            }
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_persistent_volume_claim(
                    namespace=namespace, body=manifest
                );
            } else {
                raise;
            }
        }
    }

    """Idempotent Deployment apply: read -> patch on hit, create on 404."""
    def _apply_or_replace_deployment(
        apps_v1: Any, namespace: str, manifest: dict[str, Any]
    ) {
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
    ) {
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
    ) {
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

    """Idempotent Ingress apply - mirrors the deployment shape."""
    def _apply_or_replace_ingress(
        networking_v1: Any, namespace: str, manifest: dict[str, Any]
    ) {
        name: str = manifest["metadata"]["name"];
        try {
            networking_v1.read_namespaced_ingress(name=name, namespace=namespace);
            networking_v1.patch_namespaced_ingress(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                networking_v1.create_namespaced_ingress(
                    namespace=namespace, body=manifest
                );
            } else {
                raise;
            }
        }
    }

    """Tear down all microservice resources by label selector
    (`managed=jac-scale,jac-scale.role in (microservice,gateway)`) so
    renamed services in jac.toml still get cleaned up. `app_name`/
    `component` are signature-only (whole topology is torn down)."""
    def destroy(app_name: str, component: str = "") {
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

        # also clean up HPAs and PDBs we applied.
        autoscaling_v2 = client.AutoscalingV2Api();
        policy_v1 = client.PolicyV1Api();
        # Ingress cleanup.
        networking_v1 = client.NetworkingV1Api();

        # Label selector matches anything this target has ever applied.
        # `in (...)` syntax is K8s set-based selector grammar. PDBs use
        # the role-less label selector since they only carry the basic
        # `managed=jac-scale` label (PDBs select pods by app=<name>, not
        # role; the role label is only on Deployments + their templates).
        selector: str = "managed=jac-scale,jac-scale.role in (microservice,gateway)";
        ms_selector: str = "managed=jac-scale";

        # Deployments first - delete_collection_namespaced_deployment
        # is batched. Pods stop receiving traffic as the Deployment
        # controller scales them down; the pod-spec preStop hooks
        # bridge the kube-proxy propagation gap.
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

        # Ingresses - batched. Same `managed=jac-scale` selector
        # since the Ingress carries that label too.
        try {
            networking_v1.delete_collection_namespaced_ingress(
                namespace=namespace, label_selector=ms_selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # Services - no batched delete_collection helper for v1.Service,
        # so list-then-delete by name. Use the role-LESS selector since
        # Service manifests only carry `app=<name>` + `managed=jac-scale`,
        # not the `jac-scale.role` label that's only on Deployments and
        # their pod templates. (Found by CI: the strict selector left
        # Services orphaned because they don't match it.)
        try {
            services = core_v1.list_namespaced_service(
                namespace=namespace, label_selector=ms_selector
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

    """Lift pod-specs into full Deployment + Service + HPA + PDB
    bundle. Returns `{deployments, services, hpas, pdbs, pod_specs}`."""
    def generate_manifests(app_config: AppConfig) -> dict[str, Any] {
        pod_specs = self.generate_service_pod_specs(app_config);
        deployments: dict[str, dict[str, Any]] = {};
        services: dict[str, dict[str, Any]] = {};
        hpas: dict[str, dict[str, Any]] = {};
        pdbs: dict[str, dict[str, Any]] = {};
        for (svc_name, pod_spec) in pod_specs.items() {
            deployments[svc_name] = self._build_deployment_manifest(svc_name, pod_spec);
            services[svc_name] = self._build_service_manifest(svc_name);
            # HPA / PDB builders return None when the user opts out
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

        # Optional Ingress at [...microservices.ingress]. Default
        # off; user opts in to get an external URL.
        bundle: dict[str, Any] = {
            "deployments": deployments,
            "services": services,
            "hpas": hpas,
            "pdbs": pdbs,
            "pod_specs": pod_specs
        };
        # PVCs for any PVC-mode shared_volumes. Empty when no
        # shared_volumes configured or all entries use host_path.
        pvcs = self._build_shared_pvc_manifests();
        if pvcs {
            bundle["pvcs"] = pvcs;
        }
        # K8s Secret holding `[plugins.scale.secrets]` values
        # (already env-interpolated by jaclang core's
        # apply_env_interpolation). pod-spec builders inject envFrom
        # referencing this Secret's name. None when the user defined
        # no secrets - back-compat with apps that never had any.
        user_secret = self._build_user_secret_manifest();
        if user_secret is not None {
            bundle["user_secret"] = user_secret;
        }
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            ingress_cfg: dict[str, Any] = ms_cfg.get("ingress", {});
        } except Exception {
            ingress_cfg = {};
        }
        ingress = self._build_ingress_manifest(ingress_cfg);
        if ingress is not None {
            bundle["ingress"] = ingress;
        }
        return bundle;
    }

    """Read drain_timeout_seconds (default 10s); used to size
    terminationGracePeriodSeconds + uvicorn exit cushion."""
    def _drain_timeout -> int {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return int(ms_cfg.get("drain_timeout_seconds", 10));
        } except Exception {
            return 10;
        }
    }

    """Per-service config from [...services.NAME]; {} on read failure."""
    def _service_config(svc_name: str) -> dict[str, Any] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return dict(ms_cfg.get("services", {}).get(svc_name, {}));
        } except Exception {
            return {};
        }
    }

    """Read [[plugins.scale.microservices.shared_volumes]] entries.

    Each entry declares a volume mounted at the same path on every
    listed service. PVC mode (`size`, `access_mode`, `storage_class`)
    for cloud K8s; hostPath mode (`host_path`) for single-node dev.
    `services` may include `__gateway__`. Returns [] on read failure."""
    def _shared_volumes_config -> list[dict[str, Any]] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            raw = ms_cfg.get("shared_volumes", []);
            if not isinstance(raw, list) {
                return [];
            }
            out: list[dict[str, Any]] = [];
            for entry in raw {
                if isinstance(entry, dict) {
                    out.append(dict(entry));
                }
            }
            return out;
        } except Exception {
            return [];
        }
    }

    """Build (volumes, volumeMounts) additions for `svc_name` from
    shared_volumes config. Existing entries on the pod-spec are left
    untouched. Volume names are k8s_safe_name'd to DNS-1123."""
    def _shared_volumes_for_service(
        svc_name: str
    ) -> tuple[list[dict[str, Any]], list[dict[str, Any]]] {
        volumes: list[dict[str, Any]] = [];
        mounts: list[dict[str, Any]] = [];
        for vol in self._shared_volumes_config() {
            services = vol.get("services", []);
            if not isinstance(services, list) {
                continue;
            }
            if svc_name not in services {
                continue;
            }
            name = str(vol.get("name", "")).strip();
            mount_path = str(vol.get("mount_path", "")).strip();
            if not name or not mount_path {
                continue;
            }
            vol_name = k8s_safe_name(name);
            host_path = str(vol.get("host_path", "")).strip();
            if host_path {
                # hostPath mode (dev clusters only - all pods must land
                # on the same node for actual file sharing).
                volumes.append(
                    {
                        "name": vol_name,
                        "hostPath": {"path": host_path, "type": "DirectoryOrCreate"}
                    }
                );
            } else {
                # PVC mode (production). PVC manifest emitted separately
                # by _build_shared_pvc_manifests; here we just reference
                # it by name.
                volumes.append(
                    {"name": vol_name, "persistentVolumeClaim": {"claimName": vol_name}}
                );
            }
            mount_entry: dict[str, Any] = {"name": vol_name, "mountPath": mount_path};
            sub_path = str(vol.get("sub_path", "")).strip();
            if sub_path {
                mount_entry["subPath"] = sub_path;
            }
            mounts.append(mount_entry);
        }
        return (volumes, mounts);
    }

    """PVC manifests for PVC-mode shared volumes. Skips hostPath/empty
    entries. PVC name = k8s_safe_name(vol.name). Default access_mode
    ReadWriteOnce; multi-node clusters set ReadWriteMany."""
    def _build_shared_pvc_manifests -> dict[str, dict[str, Any]] {
        pvcs: dict[str, dict[str, Any]] = {};
        for vol in self._shared_volumes_config() {
            name = str(vol.get("name", "")).strip();
            if not name {
                continue;
            }
            # Mirror the validation _shared_volumes_for_service does -
            # an entry the pod-spec helper would skip should NOT result
            # in an orphan PVC nobody mounts.
            mount_path = str(vol.get("mount_path", "")).strip();
            if not mount_path {
                continue;
            }
            services = vol.get("services", []);
            if not isinstance(services, list) or not services {
                continue;
            }
            # hostPath mode skips PVC creation entirely.
            if str(vol.get("host_path", "")).strip() {
                continue;
            }
            size = str(vol.get("size", "1Gi")).strip() or "1Gi";
            access_mode = str(vol.get("access_mode", "ReadWriteOnce")).strip()
            or "ReadWriteOnce";
            storage_class = str(vol.get("storage_class", "")).strip();
            pvc_name = k8s_safe_name(name);

            spec: dict[str, Any] = {
                "accessModes": [access_mode],
                "resources": {"requests": {"storage": size}}
            };
            if storage_class {
                spec["storageClassName"] = storage_class;
            }
            pvcs[pvc_name] = {
                "apiVersion": "v1",
                "kind": "PersistentVolumeClaim",
                "metadata": {
                    "name": pvc_name,
                    "namespace": self.k8s_config.namespace,
                    "labels": {
                        "app": "jac-scale-shared",
                        "managed": "jac-scale",
                        "jac-scale.role": "shared-volume"
                    }
                },
                "spec": spec
            };
        }
        return pvcs;
    }

    """Build the K8s Secret manifest for `[plugins.scale.secrets]`.
    `self.secrets` is pre-interpolated by `_scale_pre_hook` so
    `${VAR}` is already expanded. Returns None if no secrets."""
    def _build_user_secret_manifest -> dict[str, Any] | None {
        if not self.secrets {
            return None;
        }
        return {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {
                "name": f"{self.k8s_config.app_name}-secrets",
                "namespace": self.k8s_config.namespace,
                "labels": {
                    "app": "jac-scale-user-secrets",
                    "managed": "jac-scale",
                    "jac-scale.role": "user-secrets"
                }
            },
            "type": "Opaque",
            # stringData (vs data) so we don't have to base64-encode
            # values on the client - K8s accepts plaintext here and
            # encodes server-side. Identical to parent's create_k8s_secret.
            #
            # Coerce every value to str: TOML natively supports int /
            # float / bool, and tomllib preserves those types. K8s
            # Secret.stringData REJECTS non-strings with HTTP 422
            # mid-apply, which leaves the bundle half-applied
            # (Deployments + Services created, Secret missing) and pods
            # crash-loop on "secret not found". `${ENV_VAR}` paths
            # always produce strings, but a user writing
            # `MAX_RETRIES = 3` literally under `[plugins.scale.secrets]`
            # would otherwise blow up the deploy.
            "stringData": {k: str(v) for (k, v) in self.secrets.items()}
        };
    }

    """Name of the Secret holding user `[plugins.scale.secrets]`."""
    def _user_secret_name -> str {
        return f"{self.k8s_config.app_name}-secrets";
    }

    """ServiceAccount for every service + gateway pod; empty -> namespace
    `default` SA. Microservice mode does NOT auto-provision the SA -
    apps that need cluster API access point this at a pre-bound SA."""
    def _service_account_name -> str {
        return str(getattr(self.k8s_config, "service_account_name", "") or "").strip();
    }

    """Routes table from [plugins.scale.microservices.routes]; used by
    _build_env for `JAC_SV_<PEER>_URL` injection. Returns {} on read failure."""
    def _microservice_routes -> dict[str, str] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return dict(ms_cfg.get("routes", {}));
        } except Exception {
            return {};
        }
    }

    """In-cluster DNS URL for a peer microservice (mirrors LocalDeployer
    via the headless Service)."""
    def _peer_dns_url(peer_name: str) -> str {
        return k8s_service_dns_url(
            k8s_safe_name(peer_name),
            self.k8s_config.namespace,
            self.k8s_config.container_port
        );
    }

    """Env list in order: JAC_SV_NAME (sentinel, never overridable),
    DB env (MONGODB_URI/REDIS_URL via secretKeyRef), peer URLs, user env."""
    def _build_env(svc_name: str, svc_cfg: dict[str, Any]) -> list[dict[str, Any]] {
        env: list[dict[str, Any]] = [{"name": "JAC_SV_NAME", "value": svc_name}];

        # peer URL env vars (mirrors LocalDeployer's pattern at
        # process_manager.impl.jac:138-139). Every microservice + gateway
        # pod gets `JAC_SV_<PEER>_URL` set to the K8s DNS URL of every
        # other peer in the routes table. sv_client._ensure_available
        # checks this env var BEFORE invoking ensure_sv_service, so
        # sv-to-sv dispatch resolves via this fast-path without depending
        # on the runtime hookimpl populating sv_client._registry.
        # Without this, builder_sv -> jac_coder_sv calls silently fall
        # back to local module imports (the source files are in the
        # image), making the microservice split theatre at runtime.
        # The env-var key uses raw module_name.upper() (matching
        # sv_client.jac:115 `f"JAC_SV_{module_name.upper()}_URL"`); the
        # URL host uses k8s_safe_name to satisfy DNS-1123. Self is
        # skipped (no point); GATEWAY_NAME is skipped because it is the
        # ingress front, not an sv-import target.
        routes: dict[str, str] = self._microservice_routes();
        seen_peer_keys: set = set();
        for peer_name in routes {
            if peer_name == svc_name {
                continue;
            }
            if peer_name == GATEWAY_NAME {
                continue;
            }
            key = f"JAC_SV_{peer_name.upper()}_URL";
            if key in seen_peer_keys {
                continue;  # defensive against duplicate route entries
            }
            seen_peer_keys.add(key);
            env.append({"name": key, "value": self._peer_dns_url(peer_name)});
        }

        # database env injected by _provision_databases (Mongo +
        # Redis URIs from K8s Secrets). Empty if databases disabled
        # or _provision_databases hasn't run yet (e.g. unit tests).
        db_env: list = getattr(self, "env_list", []) or [];
        for entry in db_env {
            env.append(entry);
        }

        extra: dict[str, Any] = svc_cfg.get("env", {});
        for (k, v) in extra.items() {
            if k == "JAC_SV_NAME" {
                continue;  # protected; users can't shadow the sentinel
            }
            if k.startswith("JAC_SV_") and k.endswith("_URL") {
                # Protected: peer-URL env vars are computed from the
                # routes table; users can't override them via
                # `[plugins.scale.microservices.services.<name>.env]`
                # because a stale override would silently route
                # sv-to-sv calls to the wrong place.
                continue;
            }
            env.append({"name": k, "value": str(v)});
        }
        return env;
    }

    """Container resources with Burstable-QoS defaults (128Mi req / 1Gi
    limit / 50m cpu req, no cpu limit). BestEffort pods get evicted
    first under memory pressure, so tiny defaults bump QoS without
    constraining real workloads. Per-service config overrides; set
    values to "" or "0" to opt back to BestEffort."""
    def _build_resources(svc_cfg: dict[str, Any]) -> dict[str, Any] {
        # Priority chain: per-service > [plugins.scale.kubernetes]
        # > Burstable-QoS floor (128Mi/1Gi/50m). Empty string ("")
        # still means "opt out of any request/limit" (back to BestEffort).
        cfg = self.k8s_config;

        memory_request_val = svc_cfg.get("memory_request");
        if memory_request_val is None {
            memory_request_val = cfg.memory_request;
        }
        if memory_request_val is None {
            memory_request_val = "128Mi";
        }
        memory_limit_val = svc_cfg.get("memory_limit");
        if memory_limit_val is None {
            memory_limit_val = cfg.memory_limit;
        }
        if memory_limit_val is None {
            memory_limit_val = "1Gi";
        }
        cpu_request_val = svc_cfg.get("cpu_request");
        if cpu_request_val is None {
            cpu_request_val = cfg.cpu_request;
        }
        if cpu_request_val is None {
            cpu_request_val = "50m";
        }
        cpu_limit_val = svc_cfg.get("cpu_limit");
        if cpu_limit_val is None {
            cpu_limit_val = cfg.cpu_limit;
        }
        # cpu_limit: still omitted by default if also unset on cfg.
        requests: dict[str, str] = {};
        limits: dict[str, str] = {};
        if cpu_request_val {
            requests["cpu"] = str(cpu_request_val);
        }
        if memory_request_val {
            requests["memory"] = str(memory_request_val);
        }
        if cpu_limit_val {
            limits["cpu"] = str(cpu_limit_val);
        }
        if memory_limit_val {
            limits["memory"] = str(memory_limit_val);
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

    """Apply per-service image_tag override (handles registry-port colons)."""
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

    """Readiness probe -> /healthz/ready; gates Endpoints. Tight cadence
    so pod drops out of rotation within ~15s of drain start."""
    def _build_readiness_probe -> dict[str, Any] {
        # Cadences from [plugins.scale.kubernetes].readiness_*.
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/ready", "port": cfg.container_port},
            "initialDelaySeconds": cfg.readiness_initial_delay,
            "periodSeconds": cfg.readiness_period,
            "timeoutSeconds": 3,
            "failureThreshold": 3
        };
    }

    """Liveness probe -> /healthz/live; gates pod restart. More lenient
    than readiness (restart cascades hurt; only fail on a hung process).
    """
    def _build_liveness_probe -> dict[str, Any] {
        # Cadences from [plugins.scale.kubernetes].liveness_*.
        # Real apps with slow first-boot (jacBuilder: jac compile +
        # heavy imports take 60-90s) need to bump initial_delay; without
        # this they'd be killed before reaching Ready.
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/live", "port": cfg.container_port},
            "initialDelaySeconds": cfg.liveness_initial_delay,
            "periodSeconds": cfg.liveness_period,
            "timeoutSeconds": 3,
            "failureThreshold": cfg.liveness_failure_threshold
        };
    }

    """PreStop sleep bridges the kube-proxy endpoint-propagation gap so
    the pod doesn't stop accepting work before remote nodes stop sending."""
    def _build_prestop_hook -> dict[str, Any] {
        return {"exec": {"command": ["sh", "-c", "sleep 5"]}};
    }

    """Build the image once, emit per-service pod-spec stubs keyed by
    service name (+ GATEWAY_NAME). `generate_manifests` lifts these
    into full Deployment + Service manifests."""
    def generate_service_pod_specs(app_config: AppConfig) -> dict[str, dict[str, Any]] {
        app_name = app_config.app_name or self.k8s_config.app_name;

        import from jac_scale.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        routes: dict[str, str] = ms_cfg.get("routes", {});

        # actionable error when the user runs `jac start --scale`
        # against a project that has microservice mode enabled but no
        # services declared. Without this check, generation succeeds with
        # only a gateway pod and the user gets a confusing "what is this
        # gateway routing to?" deploy.
        if not routes {
            raise ValueError(
                "[plugins.scale.microservices.routes] is empty in jac.toml. "
                "Microservice mode needs at least one declared service.\n"
                "Add to your jac.toml:\n"
                "  [plugins.scale.microservices.routes]\n"
                "  my_service = \"/api/my\"\n"
                "where 'my_service' is the name of a .jac file in the "
                "project root and '/api/my' is the URL prefix the gateway "
                "will route to it."
            );
        }

        image: str = self._handle_image_registry(app_name, app_config);

        # fail loud on the python_image fallback in production
        # (`jac start --scale`) so users don't get a confusing silent
        # CrashLoopBackOff. The guard is opt-in via the `_K8S_GUARD_FALLBACK`
        # env var so existing tests (which use build=False with the fallback
        # to assert manifest shape, and call generate_service_pod_specs
        # directly without going through `jac start`) keep working.
        # `_scale_pre_hook` will set this env var before invoking deploy.
        import os;
        if os.environ.get("_JAC_SCALE_GUARD_FALLBACK_IMAGE") == "1" {
            fallback_image = self.k8s_config.python_image;
            if image == fallback_image or image.startswith("python:") {
                raise RuntimeError(
                    f"Microservice mode deploy fell back to '{image}', which "
                    f"doesn't have jac/jac-scale installed - all pods would "
                    f"CrashLoopBackOff with 'jac: command not found'.\n\n"
                    f"Likely causes:\n"
                    f"  - No Dockerfile in your project root and no "
                    f"auto-build path configured.\n"
                    f"  - You're running `jac start --scale` from a fixture "
                    f"dir meant for the e2e script, not direct deploy.\n\n"
                    f"Fix: drop a `Dockerfile.microservice` in your project root, "
                    f"or pre-set [plugins.scale.kubernetes].docker_image_name "
                    f"in jac.toml if the image is already built."
                );
            }
        }

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

    """Thin method delegator to module-level `k8s_safe_name` (test ergonomics)."""
    def _k8s_safe_name(svc_name: str) -> str {
        return k8s_safe_name(svc_name);
    }

    """Deployment manifest wrapping the pod-spec. Replicas from
    [...services.NAME].replicas (default 1). Labels match the monolith
    convention so existing dashboards discover microservice pods."""
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
        # per-service replicas override; default 1.
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
                # surge a new pod before terminating an old one,
                # never go below the current replica count during
                # rollout. With drain + preStop on the pod side, this
                # gives no-downtime rolling updates.
                "strategy": {
                    "type": "RollingUpdate",
                    "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}
                },
                "selector": {"matchLabels": {"app": k8s_name}},
                "template": {"metadata": {"labels": labels}, "spec": pod_spec}
            }
        };
    }

    """ClusterIP Service paired with the Deployment. External traffic
    comes through the gateway via the optional Ingress."""
    def _build_service_manifest(svc_name: str) -> dict[str, Any] {
        k8s_name = self._k8s_safe_name(svc_name);
        port: int = self.k8s_config.container_port;
        spec: dict[str, Any] = {
            "type": "ClusterIP",
            "selector": {"app": k8s_name},
            "ports": [{"protocol": "TCP", "port": port, "targetPort": port}]
        };
        # Gateway-only ClientIP stickiness so WS reconnects land on the
        # same pod. Service pods stay round-robin (stateless wrt conn).
        if svc_name == GATEWAY_NAME {
            spec["sessionAffinity"] = "ClientIP";
            spec["sessionAffinityConfig"] = {"clientIP": {"timeoutSeconds": 10800}};
        }
        return {
            "apiVersion": "v1",
            "kind": "Service",
            "metadata": {
                "name": f"{k8s_name}-service",
                "namespace": self.k8s_config.namespace,
                "labels": {"app": k8s_name, "managed": "jac-scale"}
            },
            "spec": spec
        };
    }

    """HPA targeting the Deployment; overrides at [...services.NAME.hpa].
    Returns None on `hpa.enabled=false` (opt out for leader-only/stateful)."""
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
                            "target": {"type": "Utilization", "averageUtilization": cpu}
                        }
                    }
                ]
            }
        };
    }

    """Single Ingress -> gateway Service; HTTP only; controller-agnostic
    (user sets `ingress_class_name` and any controller-specific
    annotations). Returns None if `[...ingress].enabled` is unset."""
    def _build_ingress_manifest(ingress_cfg: dict[str, Any]) -> dict[str, Any] | None {
        if not ingress_cfg.get("enabled", False) {
            return None;
        }
        host: str = str(ingress_cfg.get("host", "")).strip();
        ingress_class: str = str(ingress_cfg.get("ingress_class_name", "")).strip();
        annotations: dict[str, str] = {};
        for (k, v) in ingress_cfg.get("annotations", {}).items() {
            annotations[str(k)] = str(v);
        }

        # Backend always points at the gateway Service. Gateway path is
        # always "/" with Prefix matching - the gateway itself owns
        # /api/{svc}/* dispatch internally.
        backend: dict[str, Any] = {
            "service": {
                "name": "gateway-service",
                "port": {"number": self.k8s_config.container_port}
            }
        };
        path_entry: dict[str, Any] = {
            "path": "/",
            "pathType": "Prefix",
            "backend": backend
        };

        # `host` is optional in K8s Ingress: omitted means "match any
        # host." Useful for clusters without DNS automation, dev minikube,
        # or apps fronted by an external LB that does its own host routing.
        rule: dict[str, Any] = {"http": {"paths": [path_entry]}};
        if host {
            rule["host"] = host;
        }

        metadata: dict[str, Any] = {
            "name": "gateway-ingress",
            "namespace": self.k8s_config.namespace,
            "labels": {
                "app": "gateway",
                "managed": "jac-scale",
                "jac-scale.role": "gateway"
            }
        };
        if annotations {
            metadata["annotations"] = annotations;
        }

        spec: dict[str, Any] = {"rules": [rule]};
        if ingress_class {
            spec["ingressClassName"] = ingress_class;
        }

        return {
            "apiVersion": "networking.k8s.io/v1",
            "kind": "Ingress",
            "metadata": metadata,
            "spec": spec
        };
    }

    """PDB matching the Deployment; overrides at [...services.NAME.pdb].
    Returns None on `pdb.enabled=false`."""
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

    """Pod entrypoint: reads JAC_SV_NAME and runs `jac scale gateway`
    (gateway) or `jac start <name>.jac` (service). JAC_SV_SIBLING=1 is
    exported so the pre-hook skips local-mode orchestration."""
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

    """Build pod-spec for a service or the gateway (svc_name=GATEWAY_NAME).
    Both share one builder; the gateway differs only in which
    _service_config / _build_env / _shared_volumes_for_service lookup
    fires. Includes probes, preStop, grace, SA, init containers, secrets."""
    def _build_pod_spec(svc_name: str, image: str) -> dict[str, Any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(svc_name);
        entry = self._pod_entrypoint();
        # Container name must follow DNS-1123 label rules (no underscores).
        # Use the K8s-safe form so e.g. `orders_app` -> `orders-app` (and
        # GATEWAY_NAME -> "gateway"). JAC_SV_NAME env still carries the
        # raw name; only the K8s resource identifier is normalized.
        container: dict[str, Any] = {
            "name": k8s_safe_name(svc_name),
            "image": self._resolve_image(image, svc_cfg),
            "command": entry["command"],
            "args": entry["args"],
            "env": self._build_env(svc_name, svc_cfg),
            "ports": [{"containerPort": self.k8s_config.container_port}],
            "readinessProbe": self._build_readiness_probe(),
            "livenessProbe": self._build_liveness_probe(),
            "lifecycle": {"preStop": self._build_prestop_hook()}
        };
        resources = self._build_resources(svc_cfg);
        if resources {
            container["resources"] = resources;
        }
        # shared volumes from [[microservices.shared_volumes]].
        # Apps that pass file paths between services (e.g. jacBuilder's
        # IDE workspace) need the same mount on each pod that touches
        # the data. Gateway opts in by listing GATEWAY_NAME in the
        # volume's `services` list.
        (shared_vols, shared_mounts) = self._shared_volumes_for_service(svc_name);
        if shared_mounts {
            container["volumeMounts"] = shared_mounts;
        }
        # inject every key from the user-secret as an env var via
        # envFrom (single line vs N per-key entries). Same Secret for
        # services and gateway - SSO client_ids, JWT signing keys, etc.
        # land in both. The Secret is created in apply_manifests BEFORE
        # Deployments so envFrom doesn't trip "secret not found" at pod
        # startup. Empty self.secrets => no envFrom (back-compat).
        if self.secrets {
            container["envFrom"] = [{"secretRef": {"name": self._user_secret_name()}}];
        }
        spec: dict[str, Any] = {
            "containers": [container],
            "terminationGracePeriodSeconds": drain_t + _UVICORN_EXIT_CUSHION_S
        };
        # opt into a pre-bound ServiceAccount when configured.
        # Gateway and services share the same SA so any cluster API
        # calls from gateway middleware inherit the same RBAC.
        sa_name = self._service_account_name();
        if sa_name {
            spec["serviceAccountName"] = sa_name;
        }
        if shared_vols {
            spec["volumes"] = shared_vols;
        }
        # wait-for-Mongo / wait-for-Redis init containers so
        # pods don't crash-loop on startup before the database
        # StatefulSet is reachable. Only attached when the parent's DB
        # provisioning ran (apply_manifests stage).
        init_containers = getattr(self, "_microservice_init_containers", []) or [];
        if init_containers {
            spec["initContainers"] = list(init_containers);
        }
        return spec;
    }

    """Per-service pod-spec (thin delegator)."""
    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, Any] {
        return self._build_pod_spec(svc_name, image);
    }

    """Gateway pod-spec (same image, entrypoint selects via JAC_SV_NAME)."""
    def _build_gateway_pod_spec(image: str) -> dict[str, Any] {
        return self._build_pod_spec(GATEWAY_NAME, image);
    }
}
