"""Manifest builder for K8s microservice mode. Produces the bundle
{deployments, services, autoscalers, pdbs, pod_specs, [pvcs, user_secret,
ingress]} that KubernetesMicroserviceTarget hands to apply_manifests."""

import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deploy_context { DeployContext }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.abstractions.autoscaler { DEFAULT_CPU_UTILIZATION_TARGET }


# Sentinel for the gateway pod-spec entry; reserved to avoid collision
# with user-defined service modules.
glob GATEWAY_NAME: str = "__gateway__",
     # +5s cushion lets uvicorn finish exiting AFTER our drain middleware
     # completes; without it, SIGKILL can arrive mid-drain.
     _UVICORN_EXIT_CUSHION_S: int = 5;


"""DNS-1123-valid K8s resource name. Module level so
K8sRuntimeServiceResolver.url_for + plugin.jac can reuse it."""
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
        # no-image mode: serve source from a ConfigMap + install jac at pod
        # startup on a generic Python base image (no docker build/push).
        no_image: bool = False,
        # no-image + experimental: the bootstrap git-clones the jaseci
        # repo/branch (k8s_config.jaseci_*) into a shared venv instead of
        # installing pinned releases from PyPI - run unreleased jac in-pod.
        experimental: bool = False,
        project_dir: str = "",
        # The app's [plugins.scale.microservices] config. When set (e.g. a
        # platform deploying a different app's fleet), it's used instead of the
        # deploying process's own jac.toml via get_scale_config().
        microservices_config: dict[str, any] = {};

    """The app's microservices config: injected when provided, else read from
    the running process's jac.toml."""
    def _ms_cfg -> dict[str, any] {
        if self.microservices_config {
            return self.microservices_config;
        }
        try {
            import from jac_scale.config_loader { get_scale_config }
            return get_scale_config().get_microservices_config();
        } except Exception {
            return {};
        }
    }

    """Lift pod-specs into full Deployment + Service + HPA + PDB
    bundle. Returns `{deployments, services, autoscalers, pdbs, pod_specs}`,
    plus optional `pvcs`, `user_secret`, `ingress`."""
    def generate_manifests(app_config: AppConfig, image: str) -> dict[str, any] {
        pod_specs = self.generate_service_pod_specs(app_config, image);
        deployments: dict[str, dict[str, any]] = {};
        services: dict[str, dict[str, any]] = {};
        autoscalers: dict[str, dict[str, any]] = {};
        pdbs: dict[str, dict[str, any]] = {};
        # Autoscaler / PDB / PVC / Secret / Ingress builders return None when
        # disabled or unconfigured; bundle only carries non-None entries.
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
        # no-image mode: pack local source into a ConfigMap mounted by every
        # pod's bootstrap initContainer (see _build_pod_spec).
        if self.no_image {
            import from jac_scale.targets.kubernetes.microservice.source_bundle {
                build_source_configmap
            }
            bundle["source_configmap"] = build_source_configmap(
                k8s_safe_name(self.k8s_config.app_name),
                self.k8s_config.namespace,
                self.project_dir or app_config.code_folder
            );
        }
        pvcs = self._build_shared_pvc_manifests();
        if pvcs {
            bundle["pvcs"] = pvcs;
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
        # Ops Console: read-only namespace Role + RoleBinding on the
        # gateway SA (opt-in). Mutation verbs only when ops_console_mutations.
        if getattr(self.k8s_config, "ops_console", False) {
            import from jac_scale.targets.kubernetes.microservice.ops_rbac {
                build_ops_rbac
            }
            bundle["ops_rbac"] = build_ops_rbac(
                self.k8s_config.app_name,
                self.k8s_config.namespace,
                self._service_account_name(),
                bool(getattr(self.k8s_config, "ops_console_mutations", False))
            );
        } elif getattr(self.k8s_config, "ops_console_mutations", False) {
            # Mutations need the parent flag; warn instead of shipping no Role.
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

    """Per-service pod-spec stubs keyed by service name (+ GATEWAY_NAME)."""
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
                "  my_service = \"/api/my\"\n"
                "where 'my_service' is the name of a .jac file in the "
                "project root and '/api/my' is the URL prefix the gateway "
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

    """drain_timeout_seconds (default 10s); sizes terminationGracePeriodSeconds."""
    def _drain_timeout -> int {
        try {
            ms_cfg = self._ms_cfg();
            return int(ms_cfg.get("drain_timeout_seconds", 10));
        } except Exception {
            return 10;
        }
    }

    """Per-service config from [...services.NAME]; {} on read failure."""
    def _service_config(svc_name: str) -> dict[str, any] {
        try {
            ms_cfg = self._ms_cfg();
            return dict(ms_cfg.get("services", {}).get(svc_name, {}));
        } except Exception {
            return {};
        }
    }

    """[...microservices.client].entry, else 'main.jac' when the project ships
    a client (fullstack), else '' (the gateway skips the client build)."""
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

    """True when project_dir ships a `.cl.jac` client - a fullstack app whose
    gateway must build + serve the SPA even if [...client].entry is unset."""
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

    """[[shared_volumes]] entries. PVC mode for cloud K8s, hostPath mode
    for single-node dev. `services` may include `__gateway__`."""
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

    """(volumes, volumeMounts) for svc_name from shared_volumes config."""
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
            mount_entry: dict[str, any] = {"name": vol_name, "mountPath": mount_path};
            sub_path = str(vol.get("sub_path", "")).strip();
            if sub_path {
                mount_entry["subPath"] = sub_path;
            }
            mounts.append(mount_entry);
        }
        return (volumes, mounts);
    }

    """PVC manifests for PVC-mode shared volumes. Default access_mode
    ReadWriteOnce; multi-node clusters set ReadWriteMany."""
    def _build_shared_pvc_manifests -> dict[str, dict[str, any]] {
        pvcs: dict[str, dict[str, any]] = {};
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

    """Secret manifest for [plugins.scale.secrets] (pre-interpolated).
    Returns None if no secrets."""
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
            # stringData (vs data) avoids client-side base64. Coerce values
            # to str: K8s rejects non-strings with HTTP 422 mid-apply,
            # leaving the bundle half-applied with pods crash-looping on
            # missing secret. TOML scalars (int/float/bool) get coerced.
            "stringData": {k: str(v) for (k, v) in self.secrets.items()}
        };
    }

    """Name of the Secret holding user `[plugins.scale.secrets]`."""
    def _user_secret_name -> str {
        return f"{self.k8s_config.app_name}-secrets";
    }

    """ServiceAccount; empty -> namespace default SA. Microservice mode
    does NOT auto-provision SA - apps point this at a pre-bound one."""
    def _service_account_name -> str {
        return str(getattr(self.k8s_config, "service_account_name", "") or "").strip();
    }

    """Routes table from [plugins.scale.microservices.routes]; used by
    _build_env for `JAC_SV_<PEER>_URL` injection. Returns {} on read failure."""
    def _microservice_routes -> dict[str, str] {
        try {
            ms_cfg = self._ms_cfg();
            return dict(ms_cfg.get("routes", {}));
        } except Exception {
            return {};
        }
    }

    """In-cluster DNS URL for a peer microservice (mirrors LocalDeployer
    via the headless Service)."""
    def _peer_dns_url(peer_name: str) -> str {
        import from jac_scale.microservices.runtime.util { k8s_service_dns_url }
        return k8s_service_dns_url(
            k8s_safe_name(peer_name),
            self.k8s_config.namespace,
            self.k8s_config.container_port
        );
    }

    """Env list: JAC_SV_NAME (sentinel), peer URLs (JAC_SV_<PEER>_URL),
    DB env from DeployContext, user env. sv_client._ensure_available
    checks JAC_SV_<PEER>_URL BEFORE invoking ensure_sv_service so sv-to-sv
    dispatch resolves via this fast-path; without it, sv calls silently
    fall back to local module imports inside the image."""
    def _build_env(svc_name: str, svc_cfg: dict[str, any]) -> list[dict[str, any]] {
        # K8S_APP_NAME / K8S_NAMESPACE: surfaced as ordinary env vars so
        # in-pod code (Loki URL builder, log shippers, etc.) can read them
        # without having to parse jac.toml templates. K-track is the source
        # of truth for both at deploy time.
        env: list[dict[str, any]] = [
            {"name": "JAC_SV_NAME", "value": svc_name},
            {"name": "K8S_APP_NAME", "value": self.k8s_config.app_name},
            {"name": "K8S_NAMESPACE", "value": self.k8s_config.namespace}
        ];

        # When tracing is enabled, point pods at the in-cluster Alloy OTLP
        # receiver. Added before user env so a per-service override wins.
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
        # Propagate the full routes table to every pod as JSON so the gateway
        # + get_sv_registry resolve prefixes/peers even when the in-cluster
        # jac.toml has no [routes] table (zero-config `--scale` deploys). The
        # config loader reads JAC_SV_ROUTES when its own routes are empty.
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

        # JAC_SV_NAME and JAC_SV_*_URL are protected - users can't shadow
        # the sentinel or override peer URLs via the per-service env table
        # (a stale override would silently route sv calls to the wrong place).
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

    """Container resources with Burstable-QoS defaults (128Mi req / 1Gi
    limit / 50m cpu req). BestEffort pods get evicted first under memory
    pressure, so tiny defaults bump QoS without constraining real
    workloads. The gateway defaults to a 2Gi limit instead: it loads the
    admin portal, LLM-telemetry, log wiring and runtime OpenAPI
    aggregation that service pods don't, so its startup working set rides
    right at 1Gi and OOM-kills there. Priority: per-service >
    [plugins.scale.kubernetes] > defaults. Empty string opts back to
    BestEffort."""
    def _build_resources(
        svc_cfg: dict[str, any], is_gateway: bool = False
    ) -> dict[str, any] {
        cfg = self.k8s_config;

        memory_request_val = svc_cfg.get("memory_request");
        if memory_request_val is None {
            memory_request_val = cfg.memory_request;
        }
        if memory_request_val is None {
            if self.no_image {
                memory_request_val = "2Gi" if is_gateway else "1Gi";
            } else {
                memory_request_val = "128Mi";
            }
        }
        memory_limit_val = svc_cfg.get("memory_limit");
        if memory_limit_val is None {
            memory_limit_val = cfg.memory_limit;
        }
        if memory_limit_val is None {
            if self.no_image {
                memory_limit_val = "8Gi" if is_gateway else "4Gi";
            } else {
                memory_limit_val = "2Gi" if is_gateway else "1Gi";
            }
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
        out: dict[str, any] = {};
        if requests {
            out["requests"] = requests;
        }
        if limits {
            out["limits"] = limits;
        }
        return out;
    }

    """Apply per-service image_tag override (handles registry-port colons)."""
    def _resolve_image(image: str, svc_cfg: dict[str, any]) -> str {
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

    """/healthz/ready; gates Endpoints. Tight cadence so pod drops out
    of rotation within ~15s of drain start."""
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

    """/healthz/live; gates pod restart. More lenient than readiness."""
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

    """Startup probe for no-image pods: they install jac (and, in experimental
    mode, git-clone + compile it) and run a first jaclang compile AT STARTUP,
    which easily exceeds the liveness grace. The startup probe suppresses
    liveness/readiness until the app first answers (~15min budget) so the slow
    first boot isn't SIGKILLed; once it passes, liveness governs."""
    def _build_startup_probe -> dict[str, any] {
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/live", "port": cfg.container_port},
            "periodSeconds": 10,
            "timeoutSeconds": 3,
            "failureThreshold": 90
        };
    }

    """PreStop sleep bridges the kube-proxy endpoint-propagation gap so
    the pod doesn't stop accepting work before remote nodes stop sending."""
    def _build_prestop_hook -> dict[str, any] {
        return {"exec": {"command": ["sh", "-c", "sleep 5"]}};
    }

    # Thin delegator to module-level k8s_safe_name (test ergonomics).
    def _k8s_safe_name(svc_name: str) -> str {
        return k8s_safe_name(svc_name);
    }

    """Deployment manifest. Replicas from [...services.NAME].replicas."""
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
                # surge=1, maxUnavailable=0 + drain + preStop on the pod
                # side gives no-downtime rolling updates.
                "strategy": {
                    "type": "RollingUpdate",
                    "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}
                },
                "selector": {"matchLabels": {"app": k8s_name}},
                "template": {"metadata": {"labels": labels}, "spec": pod_spec}
            }
        };
    }

    """ClusterIP Service. External traffic comes via the optional Ingress."""
    def _build_service_manifest(svc_name: str) -> dict[str, any] {
        k8s_name = self._k8s_safe_name(svc_name);
        port: int = self.k8s_config.container_port;
        spec: dict[str, any] = {
            "type": "ClusterIP",
            "selector": {"app": k8s_name},
            "ports": [{"protocol": "TCP", "port": port, "targetPort": port}]
        };
        # Gateway-only ClientIP stickiness so WS reconnects land on the same pod.
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

    """Autoscaler config for a service; None if autoscaling is disabled."""
    def _get_autoscaler_config(svc_name: str) -> dict[str, any] | None {
        svc: dict[str, any] = self._service_config(svc_name);
        # 'hpa' block name is historical — applies to whichever autoscaler_engine is active
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

    """Single Ingress -> gateway Service; controller-agnostic. Built from
    `[...ingress]`, or the deploy-wide `shared_ingress` (host=domain) when that
    table is unset. Returns None if neither is configured. Backend always points
    at gateway-service path "/" Prefix - the gateway owns /api/{svc}/* dispatch."""
    def _build_ingress_manifest(ingress_cfg: dict[str, any]) -> dict[str, any] | None {
        cfg = self.k8s_config;
        enabled: bool = bool(ingress_cfg.get("enabled", False));
        host: str = str(ingress_cfg.get("host", "")).strip();
        ingress_class: str = str(ingress_cfg.get("ingress_class_name", "")).strip();
        annotations: dict[str, str] = {};
        for (k, v) in ingress_cfg.get("annotations", {}).items() {
            annotations[str(k)] = str(v);
        }
        # Fall back to the deploy-wide shared ingress when [...ingress] is unset,
        # so a host-routed shared controller (an ALB/nginx PaaS subdomain) still
        # reaches the gateway. Caller annotations carry the ALB cert/group/scheme.
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
        # cert-manager (nginx) needs a spec.tls block to mint a per-host cert; an
        # ALB/ACM controller terminates TLS at the LB via its annotations and
        # gets none. Mirrors the monolith IngressDeployer.
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

    """PDB matching the Deployment; overrides at [...services.NAME.pdb].
    Returns None on `pdb.enabled=false`."""
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

    """Pod entrypoint: reads JAC_SV_NAME and runs `jac scale gateway`
    (gateway) or `jac start <name>.jac` (service). JAC_SV_SIBLING=1 is
    exported so the pre-hook skips local-mode orchestration."""
    def _pod_entrypoint -> dict[str, any] {
        gw_prefix = "";
        if self.no_image {
            client_entry = self._client_entry();
            if client_entry {
                # Build the fullstack client in-pod so the gateway serves it at
                # `/`. Non-fatal: the API + admin still come up if the FE build
                # fails (the SPA route just 404s, as it did before).
                gw_prefix = (
                    f'jac build "{client_entry}" '
                    f'|| echo "[jac-scale] client build failed; / will 404"; '
                );
            }
        }
        return {
            "command": ["sh", "-c"],
            "args": [
                "set -euo pipefail; "
                "export JAC_SV_SIBLING=1; "
                'if [ "$JAC_SV_NAME" = "__gateway__" ]; then '
                f"  {gw_prefix}"
                "  exec jac scale gateway; "
                "else "
                '  exec jac start "${JAC_SV_NAME}.jac"; '
                "fi"
            ]
        };
    }

    """Pod-spec for a service or the gateway (svc_name=GATEWAY_NAME).
    Includes probes, preStop, grace, SA, init containers, secrets."""
    def _build_pod_spec(svc_name: str, image: str) -> dict[str, any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(svc_name);
        entry = self._pod_entrypoint();
        # no-image mode runs on the generic Python base image; the per-service
        # image_tag override is meaningless without a built image.
        resolved_image: str = (
            self.k8s_config.python_image
                if self.no_image
                else self._resolve_image(image, svc_cfg)
        );
        # JAC_IMAGE_REF (B-01): the resolved ref incl. K-29's content-id
        # suffix, surfaced so an in-pod self-check can report "running build X"
        # with zero RBAC. Strip any user-set copy first so the rendered YAML
        # has a single, system-owned entry (no duplicate-env reliance).
        env_list = [
            e
            for e in self._build_env(svc_name, svc_cfg)
            if e["name"] != "JAC_IMAGE_REF"
        ];
        env_list.append({"name": "JAC_IMAGE_REF", "value": resolved_image});
        # Container name must be DNS-1123 (no underscores); JAC_SV_NAME
        # env carries the raw name.
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
        # no-image pods install + compile jac at startup (minutes), which the
        # liveness probe would SIGKILL; a startup probe holds it off until the
        # app first answers. Built-image pods boot fast and don't need it.
        if self.no_image {
            container["startupProbe"] = self._build_startup_probe();
        }
        resources = self._build_resources(svc_cfg, svc_name == GATEWAY_NAME);
        if resources {
            container["resources"] = resources;
        }
        (shared_vols, shared_mounts) = self._shared_volumes_for_service(svc_name);
        # no-image mode: run from the extracted source on a shared emptyDir,
        # resolving jac + deps the bootstrap initContainer installed under
        # PYDEPS_DIR (added to PATH/PYTHONPATH). entry["args"]'s `jac` then
        # resolves to the installed console script.
        no_image_mounts: list[dict[str, any]] = [];
        if self.no_image {
            import from jac_scale.targets.kubernetes.microservice.source_bundle {
                APP_VOLUME_NAME,
                APP_MOUNT_PATH,
                PYDEPS_DIR,
                VENV_DIR
            }
            container["workingDir"] = APP_MOUNT_PATH;
            if self.experimental {
                # Run out of the shared venv the experimental bootstrap built
                # (editable jac + plugins); no PYDEPS_DIR / PYTHONPATH override.
                env_list.append({"name": "VIRTUAL_ENV", "value": VENV_DIR});
                env_list.append(
                    {
                        "name": "PATH",
                        "value": f"{VENV_DIR}/bin:/usr/local/bin:/usr/bin:/bin"
                    }
                );
            } else {
                env_list.append({"name": "PYTHONPATH", "value": PYDEPS_DIR});
                env_list.append(
                    {
                        "name": "PATH",
                        "value": f"{PYDEPS_DIR}/bin:/usr/local/bin:/usr/bin:/bin"
                    }
                );
            }
            no_image_mounts.append(
                {"name": APP_VOLUME_NAME, "mountPath": APP_MOUNT_PATH}
            );
        }
        all_mounts = shared_mounts + no_image_mounts;
        if all_mounts {
            container["volumeMounts"] = all_mounts;
        }
        # envFrom for the user secret: created BEFORE Deployments in
        # apply_manifests so the secretRef resolves at pod startup.
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
        all_volumes = list(shared_vols);
        init_containers = list(self.deploy_context.init_containers);
        if self.no_image {
            import from jac_scale.targets.kubernetes.microservice.source_bundle {
                APP_VOLUME_NAME,
                SOURCE_VOLUME_NAME,
                source_configmap_name,
                build_bootstrap_init_container
            }
            all_volumes.append({"name": APP_VOLUME_NAME, "emptyDir": {}});
            all_volumes.append(
                {
                    "name": SOURCE_VOLUME_NAME,
                    "configMap": {
                        "name": source_configmap_name(
                            k8s_safe_name(self.k8s_config.app_name)
                        )
                    }
                }
            );
            # Bootstrap runs first: extract source + install jac before the
            # db-wait init containers (order is cosmetic; both must finish).
            init_containers = [
                build_bootstrap_init_container(
                    self.k8s_config.python_image,
                    experimental=self.experimental,
                    repo_url=self.k8s_config.jaseci_repo_url,
                    branch=self.k8s_config.jaseci_branch,
                    commit=self.k8s_config.jaseci_commit or ""
                )
            ] + init_containers;
        }
        if all_volumes {
            spec["volumes"] = all_volumes;
        }
        if init_containers {
            spec["initContainers"] = init_containers;
        }
        return spec;
    }

    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, any] {
        return self._build_pod_spec(svc_name, image);
    }

    def _build_gateway_pod_spec(image: str) -> dict[str, any] {
        return self._build_pod_spec(GATEWAY_NAME, image);
    }
}
