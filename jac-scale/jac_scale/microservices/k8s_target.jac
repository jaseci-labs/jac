"""K8s deployment target for microservice mode.

Thin orchestrator that wires image build + manifest build + apply +
destroy. The manifest building logic lives in
targets.kubernetes.microservice.manifest_builder.MicroserviceManifestBuilder;
this file owns:
  - image build override (_handle_image_registry, _auto_build_image)
  - database provisioning (_provision_databases - moves to its own class in C6)
  - kube-config loading
  - manifest apply (apply_manifests + _apply_or_replace_* helpers)
  - destroy

Per-service config knobs at `[plugins.scale.microservices.services.NAME]`
(and `__gateway__` for the gateway) flow through the manifest builder.
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
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    GATEWAY_NAME,
    k8s_safe_name
}

glob logger = logging.getLogger(__name__);


"""Fans one image out to one pod per microservice. Inherits image
build/push + namespace/secret machinery from KubernetesTarget. Routes
table is the source of truth for which services exist; each gets a
pod-spec differentiated by `JAC_SV_NAME`. Selected by _scale_pre_hook
when `[plugins.scale.microservices].enabled=true` + `--scale`."""
obj KubernetesMicroserviceTarget(KubernetesTarget) {
    # populated by _provision_databases (during deploy()) with
    # the wait-for-Mongo / wait-for-Redis init containers.
    # MicroserviceManifestBuilder reads this when constructing pod specs.
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
        import from jac_scale.microservices.images.auto_build { auto_build_and_distribute }

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

    """Build the manifest bundle by delegating to MicroserviceManifestBuilder.

    Threads target state (k8s_config, secrets, env_list from
    _provision_databases, init_containers from _provision_databases)
    into the builder. Tests that exercise manifest shape call this
    method directly with build=False; the env-var guard inside
    _handle_image_registry preserves their parent-behavior fallback.
    """
    def generate_manifests(app_config: AppConfig) -> dict[str, Any] {
        app_name = app_config.app_name or self.k8s_config.app_name;
        image = self._handle_image_registry(app_name, app_config);

        # fail loud on the python_image fallback in production
        # (`jac start --scale`) so users don't get a confusing silent
        # CrashLoopBackOff. The guard is opt-in via the env var so
        # existing tests (which use build=False with the fallback to
        # assert manifest shape) keep working.
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

        builder = MicroserviceManifestBuilder(
            k8s_config=self.k8s_config,
            secrets=self.secrets,
            env_list=getattr(self, "env_list", []) or [],
            init_containers=self._microservice_init_containers,
            logger=self.logger
        );
        return builder.generate_manifests(app_config, image);
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
        ingress_manifest: any = bundle.get("ingress");
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
        core_v1: any, namespace: str, manifest: dict[str, Any]
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
    def _apply_or_replace_pvc(core_v1: any, namespace: str, manifest: dict[str, Any]) {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_persistent_volume_claim(
                name=name, namespace=namespace
            );
            # Already exists - skip the patch. See docstring above.
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
        apps_v1: any, namespace: str, manifest: dict[str, Any]
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
        autoscaling_v2: any, namespace: str, manifest: dict[str, Any]
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
        policy_v1: any, namespace: str, manifest: dict[str, Any]
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
        networking_v1: any, namespace: str, manifest: dict[str, Any]
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
}
