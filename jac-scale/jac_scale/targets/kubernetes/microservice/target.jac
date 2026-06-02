"""K8s deployment target for microservice mode. Thin orchestrator over
MicroserviceManifestBuilder + MicroserviceDatabaseProvisioner + the
auto_build_and_distribute image pipeline. Registered as
`kubernetes-microservice` in DeploymentTargetFactory."""

import logging;
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.abstractions.models.deploy_context { DeployContext }
import from jac_scale._optdeps.kubernetes {
    client,
    config as k8s_cluster_config,
    ApiException,
    ConfigException
}
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists,
    create_k8s_secret,
    get_cluster_provider
}
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    GATEWAY_NAME,
    k8s_safe_name
}
import from jac_scale.targets.kubernetes.microservice.database_provisioner {
    MicroserviceDatabaseProvisioner
}
import from jac_scale.targets.kubernetes.monitoring { MonitoringDeployer }
import from jac_scale.config_loader { get_scale_config }

glob logger = logging.getLogger(__name__);


"""Fans one image out to one pod per microservice. Routes table is the
source of truth for which services exist; each gets a pod-spec
differentiated by `JAC_SV_NAME`. Selected by _scale_pre_hook when
`[plugins.scale.microservices].enabled=true` + `--scale`."""
obj KubernetesMicroserviceTarget(KubernetesTarget) {
    # Populated by MicroserviceDatabaseProvisioner in deploy(); threaded
    # into MicroserviceManifestBuilder. Default empty so direct
    # generate_manifests() callers (tests) work without prior provision.
    has _deploy_context: DeployContext = DeployContext(),
        # _scale_pre_hook flips these on the production `jac start --scale`
        # path. Test path keeps them False -> parent KubernetesTarget
        # behavior (build_via_registry / python_image fallback).
        auto_build: bool = False,
        guard_fallback_image: bool = False;

    """Auto-build path when `auto_build=True`: prefer user's pre-built
    docker_image_name, else auto_build_and_distribute. Else parent behavior."""
    def _handle_image_registry(app_name: str, app_config: AppConfig) -> str {
        if self.auto_build {
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

    """Reads image_registry from raw config (KubernetesConfig.from_dict
    drops unknown keys so we can't go via the typed view) and hands off
    to the cluster-aware auto-build pipeline."""
    def _auto_build_image(app_name: str, app_config: AppConfig) -> str {
        import from pathlib { Path }
        import from jac_scale.microservices.images.auto_build {
            auto_build_and_distribute
        }

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
        # the DeployContext (with MONGODB_URI/REDIS_URL secretKeyRef entries
        # and wait-for-DB init containers) populates every microservice
        # pod-spec. Skipped silently in tests (no kube config / not on a
        # real cluster); the provisioning helper is idempotent for re-deploys.
        try {
            self._deploy_context = MicroserviceDatabaseProvisioner(
                k8s_target=self, logger=self.logger, enabled=self.auto_build
            ).provision(
                app_name
            );
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

        # Observability stack (M-14.a): opt-in centralised logs via
        # `[plugins.scale.microservices.logs].enabled`. Surfaces a failure
        # in `details` but does not fail the deploy - the app is healthy
        # without logs; the operator can re-run once Loki settles.
        observability_err: str = "";
        try {
            self._deploy_observability(app_name);
        } except Exception as e {
            observability_err = str(e);
            bundle["observability_error"] = observability_err;
            if self.logger {
                self.logger.warn(
                    f"Observability stack deploy reported a non-fatal error: {e}",
                    {"app_name": app_name}
                );
            }
        }

        svc_count = len(bundle["pod_specs"]) - 1;
        success_msg = (
            f"Applied {svc_count} service Deployment+Service pair(s) "
            f"plus 1 gateway in namespace '{self.k8s_config.namespace}'."
        );
        # Append the observability error to the message so a user
        # watching stdout sees the failure instead of assuming
        # everything worked. The deploy is still success=True because
        # the app pods are healthy without logs.
        if observability_err {
            success_msg = (
                f"{success_msg} "
                f"NOTE: observability stack deploy failed - "
                f"`{observability_err}`. The app is running but pod logs "
                f"are not being shipped to Loki. Re-run `jac start --scale` "
                f"once the underlying issue is fixed."
            );
        }
        return DeploymentResult(success=True, message=success_msg, details=bundle);
    }

    """M-14.a: deploy Loki + Grafana Alloy (+ the surrounding Prometheus
    / Grafana stack the Pod Logs dashboard depends on) when
    `[plugins.scale.microservices.logs].enabled = true`. No-op otherwise.

    Reuses the same `MonitoringDeployer` the monolith target uses, so
    microservice mode is the second caller of one builder. The
    monitoring stack is gated on `KubernetesConfig.monitoring_enabled`
    and Loki specifically on `loki_enabled`; the deploy path hands
    `MonitoringDeployer` a fresh `KubernetesConfig` clone with both
    flags set (see `_build_observability_config`). The destroy path
    deletes resources by name unconditionally so it stays idempotent
    regardless of the toggle state at teardown time."""
    def _deploy_observability(app_name: str) -> None {
        logs_cfg = self._read_microservices_logs_config();
        if not logs_cfg.get("enabled", False) {
            return;
        }

        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        # MonitoringDeployer.deploy expects a ClusterProvider object
        # (Strategy refactor in 5840.feature.md), not the legacy
        # `cluster_type()` string. Use the factory so prometheus /
        # grafana can read provider.prometheus_scrape_port,
        # provider.service_type, etc.
        provider = get_cluster_provider();

        obs_config = self._build_observability_config();
        # node-exporter + Alloy DaemonSets need hostPath volumes
        # (`/proc`, `/sys`, `/var/log/pods`). Pod Security Admission
        # `baseline` enforcement blocks hostPath, so namespaces that
        # default to baseline (vanilla minikube, fresh EKS, etc.) reject
        # the DaemonSet pods and the deploy stalls with `FailedCreate`.
        # Stamp the `privileged` label when the namespace has no policy
        # set yet so common-case deploys just work. Existing policy
        # values (restricted / baseline / privileged / etc.) are left
        # untouched - downgrading them would be a security regression;
        # we warn instead and let the operator relabel by hand.
        self._ensure_privileged_namespace(core_v1, obs_config.namespace);
        if self.logger {
            self.logger.info(
                f"Deploying observability stack (Prometheus + Grafana + "
                f"Loki + Alloy) for '{app_name}'",
                {"namespace": obs_config.namespace, "provider": type(provider).__name__}
            );
        }
        monitoring = MonitoringDeployer(obs_config, self.logger);
        monitoring.deploy(app_name, obs_config.namespace, apps_v1, core_v1, provider);
    }

    """Label namespace `pod-security.kubernetes.io/enforce=privileged` so
    hostPath-using DaemonSets (node-exporter, Alloy) can schedule. Only
    stamps the label when it's MISSING - any existing value (including
    `restricted` / `baseline` set by a compliance policy) is left alone
    and surfaces as a warning telling the operator the manual relabel
    command. Never downgrade a stricter policy silently.

    API errors are also non-fatal and warn-only so a sealed-namespace
    cluster doesn't break the deploy - the operator will see the
    FailedCreate event anyway and can label the namespace by hand."""
    def _ensure_privileged_namespace(core_v1: any, namespace: str) -> None {
        try {
            ns = core_v1.read_namespace(name=namespace);
            labels: dict = dict(getattr(ns.metadata, "labels", {}) or {});
            current: str = labels.get("pod-security.kubernetes.io/enforce", "");
            if current {
                if self.logger {
                    self.logger.warn(
                        f"namespace '{namespace}' has "
                        f"pod-security.kubernetes.io/enforce={current}; "
                        f"hostPath DaemonSets (node-exporter, Alloy) may be "
                        f"rejected. Relabel manually with `kubectl label "
                        f"namespace {namespace} "
                        f"pod-security.kubernetes.io/enforce=privileged "
                        f"--overwrite` if you want to enable them."
                    );
                }
                return;
            }
            patch = {
                "metadata": {
                    "labels": {"pod-security.kubernetes.io/enforce": "privileged"}
                }
            };
            core_v1.patch_namespace(name=namespace, body=patch);
            if self.logger {
                self.logger.info(
                    f"Labeled namespace '{namespace}' with "
                    "pod-security.kubernetes.io/enforce=privileged "
                    "(required for hostPath DaemonSets)"
                );
            }
        } except Exception as e {
            if self.logger {
                self.logger.warn(
                    f"Could not label namespace '{namespace}' privileged - "
                    f"hostPath DaemonSets may be rejected by PodSecurity. "
                    f"Run `kubectl label namespace {namespace} "
                    f"pod-security.kubernetes.io/enforce=privileged "
                    f"--overwrite` manually. Cause: {e}"
                );
            }
        }
    }

    """Clone `self.k8s_config` with `monitoring_enabled` and `loki_enabled`
    forced to True. logs.enabled implies the full monitoring stack so
    Grafana can host the Pod Logs dashboard; cloning preserves user-set
    knobs (probes, replicas, dashboard creds, ...) without mutating the
    shared config object for the rest of the deploy() call path."""
    def _build_observability_config -> KubernetesConfig {
        overrides: dict[str, Any] = dict(self.k8s_config.to_dict());
        overrides["monitoring_enabled"] = True;
        overrides["loki_enabled"] = True;
        return KubernetesConfig.from_dict(KubernetesConfig, overrides);
    }

    """Read `[plugins.scale.microservices.logs]`. Empty dict on any
    failure (missing block, malformed TOML, loader exception)."""
    def _read_microservices_logs_config -> dict[str, Any] {
        try {
            ms_cfg = get_scale_config().get_microservices_config();
            return dict(ms_cfg.get("logs", {}));
        } except Exception as e {
            if self.logger {
                self.logger.warn(
                    f"Could not read [plugins.scale.microservices.logs] - "
                    f"observability stack will not be deployed: {e}"
                );
            }
            return {};
        }
    }

    """Delegates to MicroserviceManifestBuilder. deploy() populates
    _deploy_context first; direct callers (tests) get an empty context
    which produces pod specs without DB env / init containers."""
    def generate_manifests(app_config: AppConfig) -> dict[str, any] {
        app_name = app_config.app_name or self.k8s_config.app_name;
        image = self._handle_image_registry(app_name, app_config);

        # Fail loud on python_image fallback so users don't get a silent
        # CrashLoopBackOff (the image has no jac/jac-scale installed).
        # Opt-in via the constructor flag to preserve manifest-shape tests.
        if self.guard_fallback_image {
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
            deploy_context=self._deploy_context,
            logger=self.logger
        );
        return builder.generate_manifests(app_config, image);
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

    """Apply order: PVCs -> Secrets -> Services -> Deployments -> HPAs ->
    PDBs -> Ingress. Services first so DNS resolves before pods boot
    (cross-service `sv import` calls need it at startup); HPAs/PDBs after
    Deployments so the targetRef isn't transiently unresolved; Ingress
    last to avoid a transient `no backend` event."""
    def apply_manifests(bundle: dict[str, any]) {
        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        autoscaling_v2 = client.AutoscalingV2Api();
        policy_v1 = client.PolicyV1Api();
        networking_v1 = client.NetworkingV1Api();
        namespace: str = self.k8s_config.namespace;

        # Probe API server early so an unreachable cluster surfaces a clean
        # error here rather than mid-apply with a half-baked manifest set.
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

        for (pvc_name, pvc_manifest) in bundle.get("pvcs", {}).items() {
            self._apply_or_replace_pvc(core_v1, namespace, pvc_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied PVC for shared volume '{pvc_name}'",
                    {"name": pvc_manifest["metadata"]["name"]}
                );
            }
        }

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

        for (svc_name, svc_manifest) in bundle["services"].items() {
            self._apply_or_replace_service(core_v1, namespace, svc_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied Service for '{svc_name}'",
                    {"name": svc_manifest["metadata"]["name"]}
                );
            }
        }

        for (svc_name, dep_manifest) in bundle["deployments"].items() {
            self._apply_or_replace_deployment(apps_v1, namespace, dep_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied Deployment for '{svc_name}'",
                    {"name": dep_manifest["metadata"]["name"]}
                );
            }
        }

        for (svc_name, hpa_manifest) in bundle.get("hpas", {}).items() {
            self._apply_or_replace_hpa(autoscaling_v2, namespace, hpa_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied HPA for '{svc_name}'",
                    {"name": hpa_manifest["metadata"]["name"]}
                );
            }
        }

        for (svc_name, pdb_manifest) in bundle.get("pdbs", {}).items() {
            self._apply_or_replace_pdb(policy_v1, namespace, pdb_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied PDB for '{svc_name}'",
                    {"name": pdb_manifest["metadata"]["name"]}
                );
            }
        }

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

    # _apply_or_replace_* family: idempotent read-then-patch-or-create on 404.
    # PVC is the exception: create-on-404, otherwise no-op (PVCs are mostly
    # immutable post-bind; patch would error or orphan the PV).
    def _apply_or_replace_service(
        core_v1: any, namespace: str, manifest: dict[str, any]
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

    def _apply_or_replace_pvc(core_v1: any, namespace: str, manifest: dict[str, any]) {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_persistent_volume_claim(
                name=name, namespace=namespace
            );
            if self.logger {
                self.logger.info(
                    f"PVC '{name}' already exists; skipping patch. To apply "
                    f"size/storage-class changes, delete the PVC manually or "
                    f"run `jac start --scale --destroy`."
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

    def _apply_or_replace_deployment(
        apps_v1: any, namespace: str, manifest: dict[str, any]
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

    def _apply_or_replace_hpa(
        autoscaling_v2: any, namespace: str, manifest: dict[str, any]
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

    def _apply_or_replace_pdb(
        policy_v1: any, namespace: str, manifest: dict[str, any]
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

    def _apply_or_replace_ingress(
        networking_v1: any, namespace: str, manifest: dict[str, any]
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

    """Tear down by label selector so renamed services still get cleaned
    up. app_name/component are signature-only (whole topology torn down)."""
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
        autoscaling_v2 = client.AutoscalingV2Api();
        policy_v1 = client.PolicyV1Api();
        networking_v1 = client.NetworkingV1Api();
        namespace: str = self.k8s_config.namespace;

        selector: str = "managed=jac-scale,jac-scale.role in (microservice,gateway)";
        ms_selector: str = "managed=jac-scale";

        try {
            apps_v1.delete_collection_namespaced_deployment(
                namespace=namespace, label_selector=selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        try {
            autoscaling_v2.delete_collection_namespaced_horizontal_pod_autoscaler(
                namespace=namespace, label_selector=ms_selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        try {
            policy_v1.delete_collection_namespaced_pod_disruption_budget(
                namespace=namespace, label_selector=ms_selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        try {
            networking_v1.delete_collection_namespaced_ingress(
                namespace=namespace, label_selector=ms_selector
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

        # Services use the role-LESS selector since Service manifests
        # only carry `app=<name>` + `managed=jac-scale`, not the role
        # label (CI-found bug: strict selector left Services orphaned).
        # No batched delete_collection for v1.Service - list-then-delete.
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

        # M-14.a: tear down the observability stack symmetrically to
        # `_deploy_observability`. Unconditional (mirroring the monolith
        # destroy at kubernetes_target.jac) because MonitoringDeployer
        # treats every API not-found as a no-op; calling it on a stack
        # that was never deployed is harmless.
        try {
            monitoring = MonitoringDeployer(self.k8s_config, self.logger);
            monitoring.destroy(app_name, namespace, apps_v1, core_v1);
        } except Exception as e {
            if self.logger {
                self.logger.info(
                    f"Observability stack destroy reported a non-fatal error: {e}",
                    {"app_name": app_name}
                );
            }
        }
    }
}
