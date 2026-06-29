import logging;
import from jac_scale.deploy.target.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.config.app_config { AppConfig }
import from jac_scale.models.deployment_result { DeploymentResult }
import from jac_scale.models.deploy_context { DeployContext }
import from jac_scale._optdeps.kubernetes {
    client,
    config as k8s_cluster_config,
    ApiException,
    ConfigException
}
import from jac_scale.deploy.target.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists,
    create_k8s_secret,
    get_cluster_provider
}
import from jac_scale.deploy.target.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    GATEWAY_NAME,
    k8s_safe_name
}
import from jac_scale.deploy.target.kubernetes.microservice.database_provisioner {
    MicroserviceDatabaseProvisioner
}
import from jac_scale.deploy.autoscale.factory { AutoscalerFactory }
import from jac_scale.deploy.autoscale.autoscaler {
    AutoscalerSpec,
    Trigger,
    TriggerAuth,
    DEFAULT_CPU_UTILIZATION_TARGET
}
import from jac_scale.deploy.target.kubernetes.monitoring { MonitoringDeployer }
import from jac_scale.config.config_loader { get_scale_config }

glob logger = logging.getLogger(__name__);


obj KubernetesMicroserviceTarget(KubernetesTarget) {
    has _deploy_context: DeployContext = DeployContext(),
        no_image: bool = True,
        microservices_config: dict[str, any] = {};

    def _ms_cfg -> dict[str, any] {
        if self.microservices_config {
            return self.microservices_config;
        }
        try {
            import from jac_scale.config.config_loader { get_scale_config }
            return get_scale_config().get_microservices_config();
        } except Exception {
            return {};
        }
    }

    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        if self.logger {
            self.logger.info(
                f"Deploying microservice app '{app_name}' to Kubernetes",
                {"namespace": self.k8s_config.namespace}
            );
        }

        try {
            self._deploy_context = MicroserviceDatabaseProvisioner(
                k8s_target=self, logger=self.logger, enabled=self.no_image
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

        try {
            self._wait_for_fleet_rollout(bundle);
        } except Exception as e {
            return DeploymentResult(
                success=False,
                message=f"fleet did not become ready: {e}",
                details=bundle
            );
        }

        svc_count = len(bundle["pod_specs"]) - 1;
        success_msg = (
            f"Applied {svc_count} service Deployment+Service pair(s) "
            f"plus 1 gateway in namespace '{self.k8s_config.namespace}'."
        );

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

    def _wait_for_fleet_rollout(bundle: dict[str, any], timeout: int = 1200) -> None {
        import time;
        import from kubernetes { client }
        import from jaclang.cli.console { console }
        names: list[str] = [];
        for dep in bundle.get("deployments", {}).values() {
            names.append(dep["metadata"]["name"]);
        }
        if not names {
            return;
        }
        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        ns = self.k8s_config.namespace;
        total = len(names);
        elapsed = 0;
        ready = 0;

        with console.status(f"Rolling out fleet: 0/{total} services ready...") as st {
            while elapsed < timeout {
                ready = 0;
                for name in names {
                    try {
                        d = apps_v1.read_namespaced_deployment(name=name, namespace=ns);
                        if (d.status.ready_replicas or 0) >= 1 {
                            ready += 1;
                        }
                    } except Exception {
                        _ = 0;
                    }
                }
                if ready == total {
                    if self.logger {
                        self.logger.info(
                            f"Fleet ready: {ready}/{total} deployments serving"
                        );
                    }
                    return;
                }

                crash = "";
                phases: list[str] = [];
                try {
                    for p in core_v1.list_namespaced_pod(namespace=ns).items {
                        for cs in (p.status.container_statuses or []) {
                            if (cs.restart_count or 0) >= 3 {
                                crash = (
                                    f"pod '{p.metadata.name}' crash-looping "
                                    f"({cs.restart_count} restarts)"
                                );
                            }
                        }
                        labels = p.metadata.labels or {};
                        app = str(labels.get("app", ""));
                        if app {
                            phases.append(f"{app}={p.status.phase or '?'}");
                        }
                    }
                } except Exception {
                    _ = 0;
                }
                if crash {
                    raise Exception(crash);
                }
                detail = ", ".join(phases) if phases else "scheduling pods";
                st.update(
                    f"Rolling out fleet: {ready}/{total} ready - {elapsed}s "
                    f"elapsed ({detail}) - pods install jac + start the app"
                );
                time.sleep(10);
                elapsed += 10;
            }
        }
        raise Exception(
            f"timed out after {timeout}s ({ready}/{total} deployments ready)"
        );
    }

    def _deploy_observability(app_name: str) -> None {
        logs_cfg = self._read_microservices_logs_config();
        tracing_cfg = self._read_microservices_tracing_config();
        if not logs_cfg.get("enabled", False)
        and not tracing_cfg.get("enabled", False) {
            return;
        }

        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();

        provider = get_cluster_provider();

        obs_config = self._build_observability_config();

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

    def _build_observability_config -> KubernetesConfig {
        overrides: dict[str, Any] = dict(self.k8s_config.to_dict());
        overrides["monitoring_enabled"] = True;

        overrides["loki_enabled"] = self._read_microservices_logs_config().get(
            "enabled", False
        );
        overrides["tracing_enabled"] = self._read_microservices_tracing_config().get(
            "enabled", False
        );
        return KubernetesConfig.from_dict(KubernetesConfig, overrides);
    }

    def _read_microservices_logs_config -> dict[str, Any] {
        try {
            ms_cfg = self._ms_cfg();
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

    def _read_microservices_tracing_config -> dict[str, Any] {
        try {
            ms_cfg = self._ms_cfg();
            return dict(ms_cfg.get("tracing", {}));
        } except Exception as e {
            if self.logger {
                self.logger.warn(
                    f"Could not read [plugins.scale.microservices.tracing] - "
                    f"tracing stack will not be deployed: {e}"
                );
            }
            return {};
        }
    }

    def generate_manifests(app_config: AppConfig) -> dict[str, any] {
        builder = MicroserviceManifestBuilder(
            k8s_config=self.k8s_config,
            secrets=self.secrets,
            deploy_context=self._deploy_context,
            logger=self.logger,
            no_image=True,
            experimental=app_config.experimental,
            project_dir=app_config.code_folder,
            microservices_config=self.microservices_config
        );
        return builder.generate_manifests(app_config, self.k8s_config.python_image);
    }

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

    def apply_manifests(bundle: dict[str, any]) {
        self._load_kube_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        policy_v1 = client.PolicyV1Api();
        networking_v1 = client.NetworkingV1Api();
        namespace: str = self.k8s_config.namespace;

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

        ops_rbac = bundle.get("ops_rbac");
        if ops_rbac {
            self._apply_ops_rbac(namespace, ops_rbac);
        }

        for (pvc_name, pvc_manifest) in bundle.get("pvcs", {}).items() {
            self._apply_or_replace_pvc(core_v1, namespace, pvc_manifest);
            if self.logger {
                self.logger.info(
                    f"Applied PVC for shared volume '{pvc_name}'",
                    {"name": pvc_manifest["metadata"]["name"]}
                );
            }
        }

        injector = bundle.get("injector");
        if injector is not None {
            injector.seed(k8s_safe_name(self.k8s_config.app_name), namespace);
            if self.logger {
                self.logger.info(
                    "Seeded source bundle onto the bundle PVC",
                    {"app_name": k8s_safe_name(self.k8s_config.app_name)}
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

        for svc_name in bundle.get("autoscalers", {}).keys() {
            k8s_name = k8s_safe_name(svc_name);
            cfg = dict(bundle.get("autoscalers", {}).get(svc_name, {}));
            autoscaler = AutoscalerFactory.create(
                self.k8s_config.autoscaler_engine,
                self.k8s_config.to_dict(),
                self.logger
            );
            triggers = [];

            is_gateway = svc_name == GATEWAY_NAME;
            effective_extra = self.k8s_config.extra_triggers if is_gateway else [];
            if not cfg.get("triggers", []) and not effective_extra {
                triggers = [
                    Trigger(
                        type="cpu",
                        metadata={
                            "averageUtilization": str(
                                cfg.get("cpu_target", DEFAULT_CPU_UTILIZATION_TARGET)
                            )
                        }
                    )
                ];
            }
            for raw in cfg.get("triggers", []) {
                t = Trigger(
                    type=str(raw.get("type", "")),
                    metadata=dict(raw.get("metadata", {})),
                    name=raw.get("name")
                );
                raw_auth = raw.get("auth");
                if raw_auth {
                    t.auth = TriggerAuth(
                        secret_refs=dict(raw_auth.get("secret_refs", {}))
                    );
                }
                triggers.append(t);
            }
            for raw in effective_extra {
                t = Trigger(
                    type=str(raw.get("type", "")),
                    metadata=dict(raw.get("metadata", {})),
                    name=raw.get("name")
                );
                raw_auth = raw.get("auth");
                if raw_auth {
                    t.auth = TriggerAuth(
                        secret_refs=dict(raw_auth.get("secret_refs", {}))
                    );
                }
                triggers.append(t);
            }
            autoscaler_name = autoscaler.resource_name_for(k8s_name);
            autoscaler_applied = autoscaler.apply(
                AutoscalerSpec(
                    scale_target_name=f"{k8s_name}-deployment",
                    autoscaler_name=autoscaler_name,
                    app_name=k8s_name,
                    namespace=namespace,
                    min_replicas=int(cfg.get("min", 1)),
                    max_replicas=int(cfg.get("max", 3)),
                    idle_replicas=self.k8s_config.idle_replicas,
                    polling_interval=self.k8s_config.autoscaler_polling_interval,
                    cooldown_period=self.k8s_config.autoscaler_cooldown,
                    initial_cooldown_period=self.k8s_config.autoscaler_initial_cooldown,
                    triggers=triggers
                )
            );

            if self.logger and autoscaler_applied {
                self.logger.info(
                    f"Applied autoscaler for '{svc_name}'", {"name": autoscaler_name}
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

    def _apply_ops_rbac(namespace: str, ops_rbac: dict[str, any]) {
        try {
            rbac_v1 = client.RbacAuthorizationV1Api();
            role = ops_rbac["role"];
            binding = ops_rbac["role_binding"];
            role_name: str = role["metadata"]["name"];
            binding_name: str = binding["metadata"]["name"];

            try {
                rbac_v1.read_namespaced_role(name=role_name, namespace=namespace);
                rbac_v1.replace_namespaced_role(
                    name=role_name, namespace=namespace, body=role
                );
            } except ApiException as e {
                if e.status == 404 {
                    rbac_v1.create_namespaced_role(namespace=namespace, body=role);
                } else {
                    raise;
                }
            }

            try {
                rbac_v1.read_namespaced_role_binding(
                    name=binding_name, namespace=namespace
                );
                rbac_v1.replace_namespaced_role_binding(
                    name=binding_name, namespace=namespace, body=binding
                );
            } except ApiException as e {
                if e.status == 404 {
                    rbac_v1.create_namespaced_role_binding(
                        namespace=namespace, body=binding
                    );
                } else {
                    raise;
                }
            }

            if self.logger {
                subj = binding["subjects"][0]["name"];
                self.logger.info(
                    f"Applied Ops Console RBAC (read-only Role + RoleBinding)",
                    {"name": role_name, "serviceAccount": subj}
                );
            }
        } except Exception as e {
            if self.logger {
                self.logger.warning(
                    f"Ops Console RBAC not applied ({e}); the in-admin "
                    f"deploy-health pages will render a 403 until the Role is "
                    f"bound to the gateway ServiceAccount."
                );
            }
        }
    }

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

    def _apply_or_replace_configmap(
        core_v1: any, namespace: str, manifest: dict[str, any]
    ) {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_config_map(name=name, namespace=namespace);
            core_v1.replace_namespaced_config_map(
                name=name, namespace=namespace, body=manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                core_v1.create_namespaced_config_map(
                    namespace=namespace, body=manifest
                );
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
            AutoscalerFactory.create(
                self.k8s_config.autoscaler_engine,
                self.k8s_config.to_dict(),
                self.logger
            ).destroy_collection(
                namespace, ms_selector
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

        try {
            core_v1.delete_collection_namespaced_config_map(
                namespace=namespace,
                label_selector="managed=jac-scale,jac-scale.role=source"
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }

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
