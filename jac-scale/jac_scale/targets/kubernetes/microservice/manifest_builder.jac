"""Manifest builder for K8s microservice mode. Produces the bundle
{deployments, services, hpas, pdbs, pod_specs, [pvcs, user_secret,
ingress]} that KubernetesMicroserviceTarget hands to apply_manifests."""

import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deploy_context { DeployContext }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }


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
        logger: any = None;

    """Lift pod-specs into full Deployment + Service + HPA + PDB
    bundle. Returns `{deployments, services, hpas, pdbs, pod_specs}`,
    plus optional `pvcs`, `user_secret`, `ingress`."""
    def generate_manifests(app_config: AppConfig, image: str) -> dict[str, any] {
        pod_specs = self.generate_service_pod_specs(app_config, image);
        deployments: dict[str, dict[str, any]] = {};
        services: dict[str, dict[str, any]] = {};
        hpas: dict[str, dict[str, any]] = {};
        pdbs: dict[str, dict[str, any]] = {};
        # HPA / PDB / PVC / Secret / Ingress builders return None when
        # disabled or unconfigured; bundle only carries non-None entries.
        for (svc_name, pod_spec) in pod_specs.items() {
            deployments[svc_name] = self._build_deployment_manifest(svc_name, pod_spec);
            services[svc_name] = self._build_service_manifest(svc_name);
            hpa = self._build_hpa_manifest(svc_name);
            if hpa is not None {
                hpas[svc_name] = hpa;
            }
            pdb = self._build_pdb_manifest(svc_name);
            if pdb is not None {
                pdbs[svc_name] = pdb;
            }
        }

        bundle: dict[str, any] = {
            "deployments": deployments,
            "services": services,
            "hpas": hpas,
            "pdbs": pdbs,
            "pod_specs": pod_specs
        };
        pvcs = self._build_shared_pvc_manifests();
        if pvcs {
            bundle["pvcs"] = pvcs;
        }
        user_secret = self._build_user_secret_manifest();
        if user_secret is not None {
            bundle["user_secret"] = user_secret;
        }
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            ingress_cfg: dict[str, any] = ms_cfg.get("ingress", {});
        } except Exception {
            ingress_cfg = {};
        }
        ingress = self._build_ingress_manifest(ingress_cfg);
        if ingress is not None {
            bundle["ingress"] = ingress;
        }
        return bundle;
    }

    """Per-service pod-spec stubs keyed by service name (+ GATEWAY_NAME)."""
    def generate_service_pod_specs(
        app_config: AppConfig, image: str
    ) -> dict[str, dict[str, any]] {
        app_name = app_config.app_name or self.k8s_config.app_name;

        import from jac_scale.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
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
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return int(ms_cfg.get("drain_timeout_seconds", 10));
        } except Exception {
            return 10;
        }
    }

    """Per-service config from [...services.NAME]; {} on read failure."""
    def _service_config(svc_name: str) -> dict[str, any] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return dict(ms_cfg.get("services", {}).get(svc_name, {}));
        } except Exception {
            return {};
        }
    }

    """[[shared_volumes]] entries. PVC mode for cloud K8s, hostPath mode
    for single-node dev. `services` may include `__gateway__`."""
    def _shared_volumes_config -> list[dict[str, any]] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
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
    workloads. Priority: per-service > [plugins.scale.kubernetes] >
    defaults. Empty string opts back to BestEffort."""
    def _build_resources(svc_cfg: dict[str, any]) -> dict[str, any] {
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

    """HPA; overrides at [...services.NAME.hpa]. None on hpa.enabled=false."""
    def _build_hpa_manifest(svc_name: str) -> dict[str, any] | None {
        cfg: dict[str, any] = self._service_config(svc_name).get("hpa", {});
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

    """Single Ingress -> gateway Service; HTTP only; controller-agnostic.
    Returns None if `[...ingress].enabled` is unset. Backend always points
    at gateway-service with path "/" Prefix - the gateway owns /api/{svc}/*
    dispatch internally. `host` is optional (omitted = match any host)."""
    def _build_ingress_manifest(ingress_cfg: dict[str, any]) -> dict[str, any] | None {
        if not ingress_cfg.get("enabled", False) {
            return None;
        }
        host: str = str(ingress_cfg.get("host", "")).strip();
        ingress_class: str = str(ingress_cfg.get("ingress_class_name", "")).strip();
        annotations: dict[str, str] = {};
        for (k, v) in ingress_cfg.get("annotations", {}).items() {
            annotations[str(k)] = str(v);
        }

        backend: dict[str, any] = {
            "service": {
                "name": "gateway-service",
                "port": {"number": self.k8s_config.container_port}
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

        spec: dict[str, any] = {"rules": [rule]};
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

    """Pod-spec for a service or the gateway (svc_name=GATEWAY_NAME).
    Includes probes, preStop, grace, SA, init containers, secrets."""
    def _build_pod_spec(svc_name: str, image: str) -> dict[str, any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(svc_name);
        entry = self._pod_entrypoint();
        # Container name must be DNS-1123 (no underscores); JAC_SV_NAME
        # env carries the raw name.
        container: dict[str, any] = {
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
        (shared_vols, shared_mounts) = self._shared_volumes_for_service(svc_name);
        if shared_mounts {
            container["volumeMounts"] = shared_mounts;
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
        if shared_vols {
            spec["volumes"] = shared_vols;
        }
        if self.deploy_context.init_containers {
            spec["initContainers"] = list(self.deploy_context.init_containers);
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
