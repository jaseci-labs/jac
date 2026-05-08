"""Kubernetes deployment target for microservice mode.

Fans a single container image out to one Deployment + ClusterIP Service
+ HorizontalPodAutoscaler + PodDisruptionBudget per microservice, plus
a gateway. The image build + push is delegated to the parent
`KubernetesTarget`; this subclass adds per-service iteration over the
project's `[plugins.scale.microservices.routes]` table, a runtime DNS
adapter (`KubernetesDeployer`) for `sv import` peer URL resolution,
and an optional Ingress manifest pointing at the gateway.

Per-service config layering at `[plugins.scale.microservices.services.NAME]`
flows through the manifest builders:

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
All knobs are optional - omit and you get the defaults.
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

`GATEWAY_NAME` ("__gateway__") is mapped to "gateway" because K8s
resource names must match the DNS-1123 regex
`[a-z0-9]([-a-z0-9]*[a-z0-9])?` (no underscores, no leading hyphens).
Other names are lowercased and have underscores replaced with hyphens;
the caller is responsible for ensuring the result is short enough
(<=63 chars) and otherwise compliant.

Module-level helper (not on `KubernetesMicroserviceTarget`) so
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
    # populated by _provision_databases (during deploy()) with
    # the wait-for-Mongo / wait-for-Redis init containers. Service +
    # gateway pod-specs read this via getattr() and attach as
    # initContainers so pods don't crash-loop until the DBs are reachable.
    has _microservice_init_containers: list[dict[str, Any]] = [];

    """Auto-build override: front-load the image-build decision.

    Activated only when `_JAC_SCALE_AUTO_BUILD=1` is set in env (the
    `_scale_pre_hook` in plugin.jac sets this on the production
    `jac start --scale` path; tests that exercise lower-level builders
    don't, so they get the parent's existing behavior). When active:

      1. If user pre-set `[plugins.scale.kubernetes].docker_image_name`,
         trust they pre-built it - return that tag.
      2. Otherwise, hand off to `auto_build_and_distribute` which detects
         cluster type from kubeconfig + builds + loads the image into the
         cluster (minikube/k3d/kind) or pushes to a configured registry
         (remote). Returns the resolved image tag for the manifest builder.

    When the env var is unset, falls through to KubernetesTarget's
    behavior - which preserves the existing unit-test contracts that pass
    `build=False` and assert manifest shape against the python_image
    fallback.
    """
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

    """Generate K8s manifests AND apply them to the cluster.

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

    """Provision MongoDB + Redis (when enabled in jac.toml) and
    populate `self.env_list` + `self._microservice_init_containers` so
    every microservice pod gets the connection-string envs and waits
    for the DBs to be reachable before starting.

    Reuses the parent `KubernetesTarget._deploy_databases` machinery
    that monolith mode already uses - same StatefulSet + ServiceAccount
    + Secret per database, same `valueFrom: secretKeyRef` env injection
    pattern. Idempotent across re-deploys (parent does read-then-create).

    Off when `[plugins.scale.kubernetes].mongodb_enabled = false` AND
    `redis_enabled = false`. The defaults are both true (we ship a
    sensible "stateful microservices work out of the box" UX), but
    users running stateless / external-DB setups can opt out.
    """
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

    """Load kubernetes config: kubeconfig first, fall back to in-cluster.

    Same pattern as KubernetesTarget.destroy() and the rest of the K8s
    target machinery. Splitting out as a helper so apply_manifests +
    destroy can both call it without duplicating the try/except.

    When BOTH paths fail (common for new users running locally
    without minikube/kubectl set up), the kubernetes client raises a
    ConfigException whose default message is unhelpful ("Service host/port
    is not set"). Re-raise with actionable instructions so the user
    knows what to do instead of paging through stack traces.
    """
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

    """Apply the manifest bundle to the cluster.

    Order: namespace exists -> Services -> Deployments -> HPAs -> PDBs.
    Services first so DNS resolution works the moment a Deployment's
    first pod becomes ready. HPAs and PDBs come AFTER Deployments because
    they reference Deployment names in scaleTargetRef / selector match;
    the K8s controllers re-resolve when the targets show up so out-of-
    order apply still eventually-converges, but applying after avoids
    a transient "no targets" warning. Each apply is idempotent (read ->
    patch on exists; create on 404).
    """
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

    """Idempotent PVC apply - create on 404, otherwise no-op.

    PVCs are mostly immutable (size/access_mode/storage_class can't be
    changed after binding without recreating). We deliberately do NOT
    patch existing PVCs on subsequent deploys - patching a bound PVC
    fails (`spec.accessModes is immutable`) and even if it didn't, a
    storage-class change would orphan the underlying PV. So existing
    PVCs are left as-is. Users who need to resize/rebind delete the
    PVC manually (or use `jac start --scale --destroy`).
    """
    def _apply_or_replace_pvc(core_v1: Any, namespace: str, manifest: dict[str, Any]) {
        name: str = manifest["metadata"]["name"];
        try {
            core_v1.read_namespaced_persistent_volume_claim(
                name=name, namespace=namespace
            );
            # Already exists - skip the patch. See docstring above.
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

    """Idempotent Deployment apply - read first, patch on hit, create on 404.

    A patch on an existing Deployment triggers the K8s Deployment
    controller's rolling update. The explicit
    RollingUpdate { maxSurge: 1, maxUnavailable: 0 } in the manifest
    surges a new pod before terminating the old one.
    """
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
    manifests.

    Returns `{"deployments": {svc: manifest}, "services": {svc: manifest},
    "hpas": {svc: manifest}, "pdbs": {svc: manifest},
    "pod_specs": {svc: spec}}`. The `pod_specs` entry is the dict
    `generate_service_pod_specs` returned; deployments wrap each
    pod-spec; services emit a paired ClusterIP Service for kube-proxy.
    Per-service HPA (autoscaling/v2) and PDB (policy/v1) entries are
    emitted alongside.
    """
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

    """Read drain_timeout_seconds from config (defaults to 10s).

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

    """Read per-service config from [...services.NAME], or {} if unset.

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

    """Read shared_volumes from [[plugins.scale.microservices.shared_volumes]].

    Each entry declares a volume that gets mounted at the same path on
    every named service. Two backing modes are supported:

      - PVC (production / cloud K8s):
            [[plugins.scale.microservices.shared_volumes]]
            name = "jac-ide-projects"
            mount_path = "/root/.jac-ide/projects"
            services = ["builder_sv", "jac_coder_sv"]
            size = "10Gi"
            access_mode = "ReadWriteMany"   # default ReadWriteOnce
            storage_class = ""              # default cluster default

      - hostPath (single-node dev clusters: k3d, kind, minikube):
            [[plugins.scale.microservices.shared_volumes]]
            name = "jac-ide-projects"
            mount_path = "/root/.jac-ide/projects"
            services = ["builder_sv", "jac_coder_sv"]
            host_path = "/var/lib/jacbuilder/projects"

    Use case: services that intentionally share filesystem state (e.g.
    jacBuilder's IDE workspace passed by path between builder_sv and
    jac_coder_sv). Without this, microservice-mode deploys force apps
    to either pass file content via RPC payload or hand-roll PVC
    manifests outside `jac start --scale`.

    `services` may include "__gateway__" for the gateway pod.

    Read failures (no jac.toml, malformed config) return [] - any
    service that doesn't appear in any volume's `services` list just
    gets no extra mounts (current default behavior preserved).
    """
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

    """Build (volumes, volumeMounts) for the named service from
    shared_volumes config.

    Returns the additions to inject - existing volume/mount entries
    on the pod-spec / container are left untouched. Service name must
    match what the user wrote in jac.toml's `services` list (e.g.
    "builder_sv", "__gateway__"). Volume name in the K8s spec is the
    user-provided `name` field, sanitized to DNS-1123 (k8s_safe_name)
    so kebab-case names round-trip correctly.
    """
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

    """Build PVC manifests for every PVC-mode shared volume.

    Skips hostPath entries (no PVC needed) and entries with empty
    name. Each PVC is named after the shared-volume's `name` (passed
    through k8s_safe_name) so the volume references in pod specs
    match. Default access_mode is ReadWriteOnce (works on every cluster
    OOTB); users on multi-node clusters set ReadWriteMany when their
    storage class supports it (NFS/EFS/Filestore).
    """
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

    """K8s Secret manifest for user-defined `[plugins.scale.secrets]`.

    Same shape the parent KubernetesTarget already uses for monolith
    deploys. Reuses parent's create_k8s_secret in apply_manifests; this
    builder just produces the manifest dict so the microservice bundle
    can own it (dry-run / inspection / destroy filtering).

    `self.secrets` is populated upstream by `_scale_pre_hook` (in
    plugin.jac) which calls `scale_config.get_secrets_config()` - that
    in turn returns jaclang-core-interpolated values from
    `[plugins.scale.secrets]`. So `${OPENAI_API_KEY}` etc. are already
    expanded by the time we get here.

    Returns None when `self.secrets` is empty - no Secret created, no
    `envFrom` injected. Apps with no secrets get a pod spec without
    any secret references (back-compat).
    """
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
            "stringData": dict(self.secrets)
        };
    }

    """Name of the Secret holding user `[plugins.scale.secrets]`.

    Centralized so _build_user_secret_manifest, _build_service_pod_spec
    (envFrom), and apply_manifests all reference the same name string
    instead of recomputing it.
    """
    def _user_secret_name -> str {
        return f"{self.k8s_config.app_name}-secrets";
    }

    """ServiceAccount name to attach to every microservice
    Deployment + the gateway Deployment. Empty string means "fall back
    to the namespace's `default` SA".

    The parent (non-microservice) kubernetes target auto-creates
    `<app_name>-sa` and binds it; microservice mode does not
    provision the SA itself. Apps that need cluster API access
    (sandbox-spawning, operator-style controllers) point this at a
    pre-bound SA in the target namespace.
    """
    def _service_account_name -> str {
        return str(getattr(self.k8s_config, "service_account_name", "") or "").strip();
    }

    """Routes table from [plugins.scale.microservices.routes].

    Used by _build_env to inject `JAC_SV_<PEER>_URL` env vars on every
    pod, mirroring what LocalDeployer's process_manager does for
    subprocesses (process_manager.impl.jac:138-139). sv_client's
    _ensure_available reads the env var BEFORE invoking
    ensure_sv_service, so dispatch to peer pods works without depending
    on the runtime hookimpl populating the registry first.

    Returns {} on config-read failure (unit tests / jac.toml absent),
    matching the defensive pattern used by _drain_timeout / _service_config.
    """
    def _microservice_routes -> dict[str, str] {
        try {
            import from jac_scale.config_loader { get_scale_config }
            ms_cfg = get_scale_config().get_microservices_config();
            return dict(ms_cfg.get("routes", {}));
        } except Exception {
            return {};
        }
    }

    """Build the in-cluster DNS URL for a peer microservice.

    Mirrors LocalDeployer.url_for (loopback URL for local subprocesses)
    but in K8s we resolve via the headless Service's DNS name. The host
    name uses k8s_safe_name (DNS-1123 — `jac_coder_sv` -> `jac-coder-sv`)
    while the env-var key keeps the raw module name with .upper() because
    sv_client._ensure_available computes the env var as
    `JAC_SV_{module_name.upper()}_URL` against the same raw name.
    """
    def _peer_dns_url(peer_name: str) -> str {
        return k8s_service_dns_url(
            k8s_safe_name(peer_name),
            self.k8s_config.namespace,
            self.k8s_config.container_port
        );
    }

    """Extra env vars merged with the auto-set JAC_SV_NAME.

    Order:
      1. JAC_SV_NAME - sentinel that picks the service at pod startup.
         Always first, never overrideable.
      2. Database env (MONGODB_URI, REDIS_URL) - added by
         `_provision_databases` during apply_manifests, stored on
         self.env_list. These use `valueFrom: secretKeyRef` so the
         connection string lives in a K8s Secret, not as plaintext.
      3. User-defined env from [...services.NAME.env] - last so users
         can override database env names if they have a custom Mongo.
    """
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

    """Container resources with sane defaults so pods are
    Burstable QoS, not BestEffort.

    Without resource requests, K8s assigns BestEffort QoS class. Under
    node memory pressure (especially during transient peaks like jac
    runtime compile, which briefly hits 1-2GB per process), kubelet
    evicts BestEffort pods FIRST - even if the node has spare capacity
    overall. We saw this empirically on a 2 vCPU / 7.6GB EC2 box: all
    3 service pods crash-looping for ~25min before stabilizing because
    the eviction storm kept restarting them faster than they could
    settle.

    The fix: emit small but real default requests/limits unless the
    user explicitly overrides via per-service config. Defaults are
    intentionally tiny (won't constrain real workloads) but enough to
    bump QoS to Burstable, which kubelet evicts AFTER BestEffort.

    Defaults:
      memory_request: 128Mi  (bumps QoS to Burstable)
      memory_limit:   1Gi    (caps runaway services from taking node)
      cpu_request:    50m    (~5% of one vCPU - tiny floor)
      cpu_limit:      omitted (CPU limits are usually counterproductive
                               vs. just letting cgroups fair-share;
                               see "kubernetes cpu limits considered
                               harmful" for the standard argument)

    Per-service config in jac.toml still overrides. To get back to
    BestEffort (e.g. dev clusters where you want predictable scheduling
    without resource accounting), set every value to "" or "0":
      [plugins.scale.microservices.services.NAME]
      memory_request = ""
      memory_limit = ""
      cpu_request = ""
    """
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

    """Apply per-service `image_tag` override if set.

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

    """Readiness probe pointing at /healthz/ready.

    Gates Endpoints membership (kube-proxy traffic). Tight cadence so
    the pod is removed from rotation within ~10s of `is_draining()`
    flipping true, which lets in-flight requests finish without new
    arrivals. Tuning matches the local-mode drain_timeout_seconds
    expectation: 5s period * 3 fails = ~15s before the pod is fully
    out of Endpoints, well inside our default 60s graceful window.
    """
    def _build_readiness_probe -> dict[str, Any] {
        # Read cadences from KubernetesConfig so jac.toml's
        # `[plugins.scale.kubernetes].readiness_initial_delay` /
        # `readiness_period` actually take effect. Default values on
        # KubernetesConfig (5/5) match the previously-hardcoded values,
        # so no behavior change for users on default config.
        cfg = self.k8s_config;
        return {
            "httpGet": {"path": "/healthz/ready", "port": cfg.container_port},
            "initialDelaySeconds": cfg.readiness_initial_delay,
            "periodSeconds": cfg.readiness_period,
            "timeoutSeconds": 3,
            "failureThreshold": 3
        };
    }

    """Liveness probe pointing at /healthz/live.

    Gates pod restart. Liveness is deliberately MORE lenient than
    readiness because restarting a pod is expensive and can cascade
    (a bad release where every replica trips liveness restarts the
    whole service mid-flight). Liveness should only fail when the
    process is genuinely hung - which is why /healthz/live checks
    nothing other than dispatcher responsiveness. Longer initialDelay
    + period give cold-start traffic a chance to settle.
    """
    def _build_liveness_probe -> dict[str, Any] {
        # read cadences from KubernetesConfig so jac.toml's
        # `[plugins.scale.kubernetes].liveness_initial_delay` /
        # `liveness_period` / `liveness_failure_threshold` take effect.
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

    """PreStop hook that sleeps before SIGTERM-induced shutdown.

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
    image, env, ports). `generate_manifests` lifts these into full
    Deployment + Service manifests.

    The image build path delegates to `_handle_image_registry` from
    `KubernetesTarget`, so `app_config.build = False` short-circuits to
    the configured python_image fallback (handy for tests).
    """
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
                    f"Fix:\n"
                    f"  - For testing the microservice deployer itself, use the bundled script:\n"
                    f"      bash jac-scale/scripts/k8s_microservice_real_e2e.sh\n"
                    f"  - For your own app, see the 'Pods deploy but "
                    f"kubectl logs shows jac: command not found' section "
                    f"in jac-scale/jac_scale/microservices/troubleshooting.md\n"
                    f"  - Pre-set [plugins.scale.kubernetes].docker_image_name "
                    f"in jac.toml if you've already built an image."
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

    """Thin delegator to module-level `k8s_safe_name`.

    Kept as a method so existing tests calling `target._k8s_safe_name(...)`
    keep working without churn. `KubernetesDeployer` uses the
    module-level helper directly to avoid needing a target instance.
    """
    def _k8s_safe_name(svc_name: str) -> str {
        return k8s_safe_name(svc_name);
    }

    """Build a Deployment manifest wrapping the pod-spec.

    Replica count comes from `[plugins.scale.microservices.services.NAME].replicas`,
    defaulting to 1. Labels match the convention used by
    `KubernetesTarget` for the monolith path so existing operator
    dashboards / Prometheus scrapes discover microservice pods the
    same way.
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

    """Build a ClusterIP Service manifest paired with the Deployment.

    Stays ClusterIP - inter-service traffic stays inside the cluster and
    external traffic comes through the gateway via the optional Ingress.
    Selector matches the Deployment's pod labels so kube-proxy routes
    to ready pods only.
    """
    def _build_service_manifest(svc_name: str) -> dict[str, Any] {
        k8s_name = self._k8s_safe_name(svc_name);
        port: int = self.k8s_config.container_port;
        spec: dict[str, Any] = {
            "type": "ClusterIP",
            "selector": {"app": k8s_name},
            "ports": [{"protocol": "TCP", "port": port, "targetPort": port}]
        };
        # gateway-only sticky sessions for WebSocket traffic.
        # Without sessionAffinity, kube-proxy round-robins TCP
        # connections across gateway replicas, which breaks WS reconnects
        # (the new connection lands on a different pod that doesn't have
        # session state). ClientIP-based stickiness is the standard fix
        # and the only one that works at the Service layer; for true
        # cookie-based stickiness users need an Ingress controller that
        # supports it (annotation-driven, controller-specific).
        # Service pods stay round-robin since their handlers are
        # stateless wrt connections (each request is independent through
        # the gateway).
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

    """Build an HPA targeting the Deployment. Per-service
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
                            "target": {"type": "Utilization", "averageUtilization": cpu}
                        }
                    }
                ]
            }
        };
    }

    """Build an Ingress manifest pointing at the gateway Service.

    Returns None unless `[plugins.scale.microservices.ingress].enabled
    = true` in jac.toml (default off so existing deployments don't grow
    an Ingress unexpectedly).

    Scope is intentionally narrow:
      - One Ingress for the gateway, NOT per-service. All external
        traffic flows through the gateway, which dispatches to services
        internally via ClusterIP DNS.
      - HTTP only. TLS automation (cert-manager + Let's Encrypt or ACM)
        is P-track work because it requires installing controllers and
        configuring Issuers - too cluster-specific to bake in here.
      - Controller-agnostic. Users set `ingress_class_name` to nginx /
        alb / gce / traefik / etc. We don't emit controller-specific
        annotations; users add them via the `annotations` map for any
        controller-specific knobs (proxy-body-size, scheme, etc).

    Config schema at [plugins.scale.microservices.ingress]:
      enabled            bool        opt-in
      host               str         optional - omits the host clause
                                     entirely if unset (Ingress matches
                                     any host)
      ingress_class_name str         e.g. "nginx", "alb", "gce"
      annotations        dict        controller-specific annotations
    """
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

    """Build a PodDisruptionBudget matching the Deployment pods.
    Per-service overrides at `[...services.NAME.pdb]`.

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

    """Pod entrypoint dispatch.

    Each pod runs the same image with `JAC_SV_NAME` env set; this
    container command reads the env at runtime and routes:
      __gateway__ -> `jac scale gateway`  (gateway-only mode)
      <svc_name>  -> `jac start <name>.jac`

    `JAC_SV_SIBLING=1` is exported BEFORE the dispatch so the
    JacScalePlugin pre-hook skips its local-mode orchestrator block
    (which would try to spawn peers). DNS-based peer URL resolution
    is handled by the `get_sv_registry` hookimpl + `sv_service_call`
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

    """Build the pod-spec for one entry in the routes table OR the
    gateway. The gateway differs from a regular service only in
    `svc_name` (== GATEWAY_NAME), which fans out into different
    `_service_config`, `_build_env`, and `_shared_volumes_for_service`
    lookups; the rest of the spec (probes, preStop, grace period,
    SA, init containers, secrets envFrom) is identical, so the two
    paths share one builder.

    Includes readiness/liveness probes, preStop hook, grace period,
    per-service config (image_tag override, resources, extra env vars),
    and the entrypoint command/args that select service vs gateway
    mode at pod startup based on JAC_SV_NAME.
    """
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

    """Per-service pod-spec. Thin delegator to `_build_pod_spec`.

    Kept as a separate method so existing tests that exercise
    `_build_service_pod_spec` directly keep working without churn.
    """
    def _build_service_pod_spec(svc_name: str, image: str) -> dict[str, Any] {
        return self._build_pod_spec(svc_name, image);
    }

    """Gateway pod-spec. Thin delegator to `_build_pod_spec`.

    Same image as services; entrypoint selects gateway-mode based on
    `JAC_SV_NAME == GATEWAY_NAME`. The user can tune the gateway via
    `[...services.__gateway__]` just like a regular service.
    """
    def _build_gateway_pod_spec(image: str) -> dict[str, Any] {
        return self._build_pod_spec(GATEWAY_NAME, image);
    }
}
