"""Manifest builder for K8s microservice mode.

Extracted from microservices/k8s_target.jac. Pure function-style class:
takes config + per-deploy state in the constructor, produces a manifest
bundle dict. Stateless beyond what's passed in.

The bundle dict has keys: deployments, services, hpas, pdbs, pod_specs,
and optionally pvcs, user_secret, ingress. KubernetesMicroserviceTarget
hands this to apply_manifests().
"""

import from typing { Any }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }


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
level so K8sRuntimeServiceResolver.url_for and plugin.jac can reuse it."""
def k8s_safe_name(svc_name: str) -> str {
    if svc_name == GATEWAY_NAME {
        return "gateway";
    }
    return svc_name.lower().replace("_", "-");
}


"""Builds the full K8s manifest bundle for a microservice deploy.

Stateless beyond the per-deploy inputs threaded through the constructor:
  - k8s_config: KubernetesConfig (namespace, container_port, defaults)
  - secrets: dict[str, str] of env-interpolated user secrets
  - env_list: env entries to inject (DB URIs from DatabaseProvisioner)
  - init_containers: wait-for-DB init containers from DatabaseProvisioner
  - logger: optional structured logger
"""
obj MicroserviceManifestBuilder {
    has k8s_config: KubernetesConfig,
        secrets: dict[str, str] = {},
        env_list: list[dict[str, Any]] = [],
        init_containers: list[dict[str, Any]] = [],
        logger: any = None;

    """Lift pod-specs into full Deployment + Service + HPA + PDB
    bundle. Returns `{deployments, services, hpas, pdbs, pod_specs}`,
    plus optional `pvcs`, `user_secret`, `ingress`."""
    def generate_manifests(app_config: AppConfig, image: str) -> dict[str, Any] {
        pod_specs = self.generate_service_pod_specs(app_config, image);
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

    """Emit per-service pod-spec stubs keyed by service name (+ GATEWAY_NAME).
    `generate_manifests` lifts these into full Deployment + Service manifests."""
    def generate_service_pod_specs(
        app_config: AppConfig, image: str
    ) -> dict[str, dict[str, Any]] {
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
        import from jac_scale.microservices._util { k8s_service_dns_url }
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
        for entry in self.env_list {
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
    than readiness (restart cascades hurt; only fail on a hung process)."""
    def _build_liveness_probe -> dict[str, Any] {
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
        if self.init_containers {
            spec["initContainers"] = list(self.init_containers);
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
