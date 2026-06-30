import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.models.deploy_context { DeployContext }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.autoscale.autoscaler { DEFAULT_CPU_UTILIZATION_TARGET }


glob GATEWAY_NAME: str = "__gateway__",
     _UVICORN_EXIT_CUSHION_S: int = 5;


def k8s_safe_name(svc_name: str) -> str {
    if svc_name == GATEWAY_NAME {
        return "gateway";
    }
    return svc_name.lower().replace("_", "-");
}


obj MicroserviceManifestBuilder {
    has k8s_config: KubernetesConfig,
        secrets: dict[str, str] = {},
        deploy_context: DeployContext = DeployContext(),
        logger: any = None,
        no_image: bool = True,
        experimental: bool = False,
        project_dir: str = "",
        _bundle_object_key: str = "",
        _toolchain_object_key: str = "",
        _ship_binary: bool = False,
        microservices_config: dict[str, any] = {};

    def _ms_cfg -> dict[str, any] {
        if self.microservices_config {
            return self.microservices_config;
        }
        try {
            import from jaclang.scale.config.config_loader { get_scale_config }
            return get_scale_config().get_microservices_config();
        } except Exception {
            return {};
        }
    }

    def _injector_object_key -> str {
        return self._bundle_object_key;
    }

    def _prepare_injector(app_config: AppConfig) -> PvcInjector {
        import from jaclang.scale.injector.binary_injector { select_injector }
        import from jaclang.scale.injector.pvc_injector { PvcInjector }
        selection = select_injector(
            self.experimental,
            self.k8s_config.bundle_storage_class,
            k8s_safe_name(self.k8s_config.app_name),
            self.k8s_config.namespace,
            self.project_dir or app_config.code_folder
        );
        injector: PvcInjector = selection[0];
        self._ship_binary = bool(selection[1]);
        self._toolchain_object_key = str(selection[2]);
        return injector;
    }

    def generate_manifests(app_config: AppConfig, image: str) -> dict[str, any] {
        injector = self._prepare_injector(app_config);
        self._bundle_object_key = injector._object_key;

        pod_specs = self.generate_service_pod_specs(app_config, image);
        deployments: dict[str, dict[str, any]] = {};
        services: dict[str, dict[str, any]] = {};
        autoscalers: dict[str, dict[str, any]] = {};
        pdbs: dict[str, dict[str, any]] = {};

        for (svc_name, pod_spec) in pod_specs.items() {
            deployments[svc_name] = self._build_deployment_manifest(svc_name, pod_spec);
            services[svc_name] = self._build_service_manifest(svc_name);
            autoscaler_cfg = self._get_autoscaler_config(svc_name);
            if autoscaler_cfg is not None {
                autoscalers[svc_name] = autoscaler_cfg;
            }
            pdb = self._build_pdb_manifest(svc_name);
            if pdb is not None {
                pdbs[svc_name] = pdb;
            }
        }

        bundle: dict[str, any] = {
            "deployments": deployments,
            "services": services,
            "autoscalers": autoscalers,
            "pdbs": pdbs,
            "pod_specs": pod_specs
        };

        bundle["injector"] = injector;
        for manifest in injector.extra_manifests(
            k8s_safe_name(self.k8s_config.app_name), self.k8s_config.namespace
        ) {
            if manifest.get("kind") == "PersistentVolumeClaim" {
                pvcs_from_injector = bundle.get("pvcs", {});
                pvcs_from_injector[manifest["metadata"]["name"]] = manifest;
                bundle["pvcs"] = pvcs_from_injector;
            }
        }

        shared_pvcs = self._build_shared_pvc_manifests();
        if shared_pvcs {
            merged_pvcs = bundle.get("pvcs", {});
            merged_pvcs.update(shared_pvcs);
            bundle["pvcs"] = merged_pvcs;
        }
        user_secret = self._build_user_secret_manifest();
        if user_secret is not None {
            bundle["user_secret"] = user_secret;
        }
        try {
            ms_cfg = self._ms_cfg();
            ingress_cfg: dict[str, any] = ms_cfg.get("ingress", {});
        } except Exception {
            ingress_cfg = {};
        }
        ingress = self._build_ingress_manifest(ingress_cfg);
        if ingress is not None {
            bundle["ingress"] = ingress;
        }

        if getattr(self.k8s_config, "ops_console", False) {
            import from jaclang.scale.deploy.target.kubernetes.microservice.ops_rbac {
                build_ops_rbac
            }
            bundle["ops_rbac"] = build_ops_rbac(
                self.k8s_config.app_name,
                self.k8s_config.namespace,
                self._service_account_name(),
                bool(getattr(self.k8s_config, "ops_console_mutations", False))
            );
        } elif getattr(self.k8s_config, "ops_console_mutations", False) {
            if self.logger {
                self.logger.warning(
                    "[plugins.scale.kubernetes].ops_console_mutations is set but "
                    "ops_console is false; no Ops Console RBAC will be provisioned. "
                    "Set ops_console = true to enable it."
                );
            }
        }
        return bundle;
    }

    def generate_service_pod_specs(
        app_config: AppConfig, image: str
    ) -> dict[str, dict[str, any]] {
        app_name = app_config.app_name or self.k8s_config.app_name;

        ms_cfg = self._ms_cfg();
        routes: dict[str, str] = ms_cfg.get("routes", {});

        if not routes {
            raise ValueError(
                "[plugins.scale.microservices.routes] is empty in jac.toml. "
                "Microservice mode needs at least one declared service.\n"
                "Add to your jac.toml:\n"
                "  [plugins.scale.microservices.routes]\n"
                "  my_service = \"/my\"\n"
                "where 'my_service' is the name of a .jac file in the "
                "project root and '/my' is the URL prefix the gateway "
                "will route to it."
            );
        }

        specs: dict[str, dict[str, any]] = {};
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

    def _drain_timeout -> int {
        try {
            ms_cfg = self._ms_cfg();
            return int(ms_cfg.get("drain_timeout_seconds", 10));
        } except Exception {
            return 10;
        }
    }

    def _service_config(svc_name: str) -> dict[str, any] {
        try {
            ms_cfg = self._ms_cfg();
            return dict(ms_cfg.get("services", {}).get(svc_name, {}));
        } except Exception {
            return {};
        }
    }

    def _client_entry -> str {
        try {
            ms_cfg = self._ms_cfg();
            explicit = str(dict(ms_cfg.get("client", {})).get("entry", "")).strip();
            if explicit {
                return explicit;
            }
            if self._has_client_source() {
                return "main.jac";
            }
            return "";
        } except Exception {
            return "";
        }
    }

    def _has_client_source -> bool {
        root_dir = self.project_dir;
        if not root_dir {
            return False;
        }
        import os;
        import glob;
        if not os.path.isdir(root_dir) {
            return False;
        }
        matches = glob.glob(os.path.join(root_dir, "**", "*.cl.jac"), recursive=True);
        return len(matches) > 0;
    }

    def _shared_volumes_config -> list[dict[str, any]] {
        try {
            ms_cfg = self._ms_cfg();
            raw = ms_cfg.get("shared_volumes", []);
            if not isinstance(raw, list) {
                return [];
            }
            out: list[dict[str, any]] = [];
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

    def _shared_volumes_for_service(
        svc_name: str
    ) -> tuple[list[dict[str, any]], list[dict[str, any]]] {
        volumes: list[dict[str, any]] = [];
        mounts: list[dict[str, any]] = [];
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
                volumes.append(
                    {
                        "name": vol_name,
                        "hostPath": {"path": host_path, "type": "DirectoryOrCreate"}
                    }
                );
            } else {
                volumes.append(
                    {"name": vol_name, "persistentVolumeClaim": {"claimName": vol_name}}
                );
            }
            mount_entry: dict[str, any] = {"name": vol_name, "mountPath": mount_path};
            sub_path = str(vol.get("sub_path", "")).strip();
            if sub_path {
                mount_entry["subPath"] = sub_path;
            }
            mounts.append(mount_entry);
        }
        return (volumes, mounts);
    }

    def _build_shared_pvc_manifests -> dict[str, dict[str, any]] {
        pvcs: dict[str, dict[str, any]] = {};
        for vol in self._shared_volumes_config() {
            name = str(vol.get("name", "")).strip();
            if not name {
                continue;
            }

            mount_path = str(vol.get("mount_path", "")).strip();
            if not mount_path {
                continue;
            }
            services = vol.get("services", []);
            if not isinstance(services, list) or not services {
                continue;
            }

            if str(vol.get("host_path", "")).strip() {
                continue;
            }
            size = str(vol.get("size", "1Gi")).strip() or "1Gi";
            access_mode = str(vol.get("access_mode", "ReadWriteOnce")).strip()
            or "ReadWriteOnce";
            storage_class = str(vol.get("storage_class", "")).strip();
            pvc_name = k8s_safe_name(name);

            spec: dict[str, any] = {
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

    def _build_user_secret_manifest -> dict[str, any] | None {
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
            "stringData": {k: str(v) for (k, v) in self.secrets.items()}
        };
    }

    def _user_secret_name -> str {
        return f"{self.k8s_config.app_name}-secrets";
    }

    def _service_account_name -> str {
        return str(getattr(self.k8s_config, "service_account_name", "") or "").strip();
    }

    def _microservice_routes -> dict[str, str] {
        try {
            ms_cfg = self._ms_cfg();
            return dict(ms_cfg.get("routes", {}));
        } except Exception {
            return {};
        }
    }

    def _peer_dns_url(peer_name: str) -> str {
        import from jaclang.scale.runtime.context.util { k8s_service_dns_url }
        return k8s_service_dns_url(
            k8s_safe_name(peer_name),
            self.k8s_config.namespace,
            self.k8s_config.container_port
        );
    }

    def _build_env(svc_name: str, svc_cfg: dict[str, any]) -> list[dict[str, any]] {
        env: list[dict[str, any]] = [
            {"name": "JAC_SV_NAME", "value": svc_name},
            {"name": "K8S_APP_NAME", "value": self.k8s_config.app_name},
            {"name": "K8S_NAMESPACE", "value": self.k8s_config.namespace}
        ];

        ms_trace_cfg: dict = dict(self._ms_cfg().get("tracing", {}));
        if ms_trace_cfg.get("enabled", False) {
            env.append(
                {
                    "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
                    "value": f"http://{self.k8s_config.app_name}-alloy-service:4318"
                }
            );
        }

        routes: dict[str, str] = self._microservice_routes();

        if routes {
            import json;
            env.append({"name": "JAC_SV_ROUTES", "value": json.dumps(dict(routes))});
        }
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
                continue;
            }
            seen_peer_keys.add(key);
            env.append({"name": key, "value": self._peer_dns_url(peer_name)});
        }

        for entry in self.deploy_context.env_list {
            env.append(entry);
        }

        extra: dict[str, any] = svc_cfg.get("env", {});
        for (k, v) in extra.items() {
            if k == "JAC_SV_NAME" {
                continue;
            }
            if k.startswith("JAC_SV_") and k.endswith("_URL") {
                continue;
            }
            env.append({"name": k, "value": str(v)});
        }
        return env;
    }

    def _build_resources(
        svc_cfg: dict[str, any], is_gateway: bool = False
    ) -> dict[str, any] {
        cfg = self.k8s_config;

        memory_request_val = svc_cfg.get("memory_request");
        if memory_request_val is None {
            memory_request_val = cfg.memory_request;
        }
        if memory_request_val is None {
            memory_request_val = "2Gi" if is_gateway else "1Gi";
        }
        memory_limit_val = svc_cfg.get("memory_limit");
        if memory_limit_val is None {
            memory_limit_val = cfg.memory_limit;
        }
        if memory_limit_val is None {
            memory_limit_val = "8Gi" if is_gateway else "4Gi";
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
        out: dict[str, any] = {};
        if requests {
            out["requests"] = requests;
        }
        if limits {
            out["limits"] = limits;
        }
        return out;
    }

    def _build_readiness_probe -> dict[str, any] {
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/ready", "port": cfg.container_port},
            "initialDelaySeconds": cfg.readiness_initial_delay,
            "periodSeconds": cfg.readiness_period,
            "timeoutSeconds": 3,
            "failureThreshold": 3
        };
    }

    def _build_liveness_probe -> dict[str, any] {
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/live", "port": cfg.container_port},
            "initialDelaySeconds": cfg.liveness_initial_delay,
            "periodSeconds": cfg.liveness_period,
            "timeoutSeconds": 3,
            "failureThreshold": cfg.liveness_failure_threshold
        };
    }

    def _build_startup_probe -> dict[str, any] {
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/live", "port": cfg.container_port},
            "periodSeconds": 10,
            "timeoutSeconds": 3,
            "failureThreshold": 90
        };
    }

    def _build_prestop_hook -> dict[str, any] {
        return {"exec": {"command": ["sh", "-c", "sleep 5"]}};
    }

    def _k8s_safe_name(svc_name: str) -> str {
        return k8s_safe_name(svc_name);
    }

    def _build_deployment_manifest(
        svc_name: str, pod_spec: dict[str, any]
    ) -> dict[str, any] {
        k8s_name = self._k8s_safe_name(svc_name);
        role: str = "gateway" if svc_name == GATEWAY_NAME else "microservice";
        labels: dict[str, str] = {
            "app": k8s_name,
            "managed": "jac-scale",
            "jac-scale.role": role
        };
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
                "strategy": {
                    "type": "RollingUpdate",
                    "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}
                },
                "selector": {"matchLabels": {"app": k8s_name}},
                "template": {"metadata": {"labels": labels}, "spec": pod_spec}
            }
        };
    }

    def _build_service_manifest(svc_name: str) -> dict[str, any] {
        k8s_name = self._k8s_safe_name(svc_name);
        port: int = self.k8s_config.container_port;
        spec: dict[str, any] = {
            "type": "ClusterIP",
            "selector": {"app": k8s_name},
            "ports": [{"protocol": "TCP", "port": port, "targetPort": port}]
        };

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

    def _get_autoscaler_config(svc_name: str) -> dict[str, any] | None {
        svc: dict[str, any] = self._service_config(svc_name);

        hpa: dict[str, any] = svc.get("hpa", {});
        if not hpa.get("enabled", True) {
            return None;
        }
        raw_triggers: list[dict[str, any]] = [];
        for item in svc.get("triggers", []) {
            if isinstance(item, dict) {
                raw_triggers.append(dict(item));
            }
        }
        return {
            "min": int(hpa.get("min", 1)),
            "max": int(hpa.get("max", 3)),
            "cpu_target": int(hpa.get("cpu_target", DEFAULT_CPU_UTILIZATION_TARGET)),
            "triggers": raw_triggers
        };
    }

    def _build_ingress_manifest(ingress_cfg: dict[str, any]) -> dict[str, any] | None {
        cfg = self.k8s_config;
        enabled: bool = bool(ingress_cfg.get("enabled", False));
        host: str = str(ingress_cfg.get("host", "")).strip();
        ingress_class: str = str(ingress_cfg.get("ingress_class_name", "")).strip();
        annotations: dict[str, str] = {};
        for (k, v) in ingress_cfg.get("annotations", {}).items() {
            annotations[str(k)] = str(v);
        }

        use_shared: bool = (not enabled) and cfg.shared_ingress and bool(cfg.domain);
        if use_shared {
            enabled = True;
            if not host {
                host = cfg.domain;
            }
            if not ingress_class {
                ingress_class = cfg.shared_ingress_class;
            }
            if not annotations {
                for (k, v) in cfg.shared_ingress_annotations.items() {
                    annotations[str(k)] = str(v);
                }
            }
        }
        if not enabled {
            return None;
        }

        backend: dict[str, any] = {
            "service": {
                "name": "gateway-service",
                "port": {"number": cfg.container_port}
            }
        };
        path_entry: dict[str, any] = {
            "path": "/",
            "pathType": "Prefix",
            "backend": backend
        };

        rule: dict[str, any] = {"http": {"paths": [path_entry]}};
        if host {
            rule["host"] = host;
        }

        metadata: dict[str, any] = {
            "name": "gateway-ingress",
            "namespace": cfg.namespace,
            "labels": {
                "app": "gateway",
                "managed": "jac-scale",
                "jac-scale.role": "gateway"
            }
        };
        if annotations {
            metadata["annotations"] = annotations;
        }

        spec: dict[str, any] = {"rules": [rule]};
        if ingress_class {
            spec["ingressClassName"] = ingress_class;
        }

        cert_manager_managed: bool = (
            "cert-manager.io/cluster-issuer" in cfg.shared_ingress_annotations
            or "cert-manager.io/issuer" in cfg.shared_ingress_annotations
        );
        if use_shared and cfg.shared_ingress_tls and host and cert_manager_managed {
            spec["tls"] = [{"hosts": [host], "secretName": "gateway-tls"}];
        }

        return {
            "apiVersion": "networking.k8s.io/v1",
            "kind": "Ingress",
            "metadata": metadata,
            "spec": spec
        };
    }

    def _build_pdb_manifest(svc_name: str) -> dict[str, any] | None {
        cfg: dict[str, any] = self._service_config(svc_name).get("pdb", {});
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

    def _pod_entrypoint -> dict[str, any] {
        import from jaclang.scale.injector.bundle { APP_MOUNT_PATH }
        gw_prefix = "";
        client_entry = self._client_entry();
        if client_entry {
            gw_prefix = (
                f'jac build "{client_entry}" '
                f'|| echo "[jac-scale] client build failed; / will 404"; '
            );
        }
        return {
            "command": ["bash", "-c"],
            "args": [
                "set -euo pipefail; "
                f"cd {APP_MOUNT_PATH}; "
                "export JAC_SV_SIBLING=1; "
                'if [ "$JAC_SV_NAME" = "__gateway__" ]; then '
                f"  {gw_prefix}"
                "  exec jac scale gateway; "
                "else "
                '  SV_FILE="$(find . -name "${JAC_SV_NAME}.jac" -not -path "*/.*" -print 2>/dev/null | head -n1)"; '
                '  exec jac start "${SV_FILE:-${JAC_SV_NAME}.jac}"; '
                "fi"
            ]
        };
    }

    def _build_pod_spec(svc_name: str, image: str) -> dict[str, any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(svc_name);
        entry = self._pod_entrypoint();

        resolved_image: str = self.k8s_config.python_image;
        env_list = self._build_env(svc_name, svc_cfg);

        container: dict[str, any] = {
            "name": k8s_safe_name(svc_name),
            "image": resolved_image,
            "command": entry["command"],
            "args": entry["args"],
            "env": env_list,
            "ports": [{"containerPort": self.k8s_config.container_port}],
            "readinessProbe": self._build_readiness_probe(),
            "livenessProbe": self._build_liveness_probe(),
            "lifecycle": {"preStop": self._build_prestop_hook()}
        };

        container["startupProbe"] = self._build_startup_probe();
        resources = self._build_resources(svc_cfg, svc_name == GATEWAY_NAME);
        if resources {
            container["resources"] = resources;
        }
        (shared_vols, shared_mounts) = self._shared_volumes_for_service(svc_name);

        import from jaclang.scale.injector.bundle { APP_MOUNT_PATH }
        import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
            runtime_container_env
        }
        container["workingDir"] = APP_MOUNT_PATH;
        env_list.extend(runtime_container_env());
        if shared_mounts {
            container["volumeMounts"] = shared_mounts;
        }

        if self.secrets {
            container["envFrom"] = [{"secretRef": {"name": self._user_secret_name()}}];
        }
        spec: dict[str, any] = {
            "containers": [container],
            "terminationGracePeriodSeconds": drain_t + _UVICORN_EXIT_CUSHION_S
        };
        sa_name = self._service_account_name();
        if sa_name {
            spec["serviceAccountName"] = sa_name;
        }
        spec["volumes"] = list(shared_vols);
        spec["initContainers"] = list(self.deploy_context.init_containers);

        import from jaclang.scale.injector.pvc_injector { PvcInjector }
        injector: PvcInjector = PvcInjector(
            storage_class=self.k8s_config.bundle_storage_class
        );
        if self._ship_binary {
            import from jaclang.scale.injector.binary_injector { BinaryInjector }
            bin_inj = BinaryInjector(
                storage_class=self.k8s_config.bundle_storage_class
            );
            bin_inj._toolchain_object_key = self._toolchain_object_key;
            injector = bin_inj;
        }
        injector._object_key = self._injector_object_key();
        spec["_jac_meta"] = {
            "app_name": k8s_safe_name(self.k8s_config.app_name),
            "namespace": self.k8s_config.namespace
        };
        spec = injector.mutate_pod_spec(spec, self.k8s_config.python_image);
        spec.pop("_jac_meta", None);

        import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
            build_bootstrap_init_container
        }
        spec["initContainers"].append(
            build_bootstrap_init_container(
                self.k8s_config,
                self.experimental,
                self.k8s_config.python_image,
                self._ship_binary
            )
        );
        return spec;
    }

    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, any] {
        return self._build_pod_spec(svc_name, image);
    }

    def _build_gateway_pod_spec(image: str) -> dict[str, any] {
        return self._build_pod_spec(GATEWAY_NAME, image);
    }
}
