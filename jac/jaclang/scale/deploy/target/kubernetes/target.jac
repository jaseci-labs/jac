import logging;
import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTargetBase
}
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.deploy_context { DeployContext }
import from jaclang.scale._optdeps.kubernetes { client, ApiException }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    ensure_namespace_exists,
    create_k8s_secret,
    delete_if_exists,
    get_cluster_provider,
    _resolve_current_rs_hashes,
    _refresh_rs_hashes
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    with_config_revision,
    CONFIG_REVISION_ANNOTATION,
    ManifestBuilder,
    GATEWAY_NAME,
    k8s_safe_name,
    ScalingMode
}
import from jaclang.scale.deploy.target.kubernetes.database_provisioner {
    DatabaseProvisioner
}
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerSpec,
    Trigger,
    TriggerAuth,
    DEFAULT_CPU_UTILIZATION_TARGET,
    DEFAULT_MEMORY_UTILIZATION_TARGET
}
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.http_activation_config {
    apply_http_activation_for_target,
    destroy_http_activation_for_target
}
import from jaclang.scale.deploy.target.kubernetes.monitoring { MonitoringDeployer }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.injector.pvc_injector { bundle_keys_from_pod_spec }

glob logger = logging.getLogger(__name__),
     REVISION_ANNOTATION: str = "deployment.kubernetes.io/revision",
     FLEET_SELECTOR: str = "managed=jac-scale,jac-scale.role in (microservice,gateway)";


def _revision_sort_key(item: dict[str, any]) -> int {
    return int(item.get("revision", 0));
}


def fleet_revert_order(names: list[str]) -> list[str] {
    gateway = f"{k8s_safe_name(GATEWAY_NAME)}-deployment";
    services: list[str] = [];
    has_gateway = False;
    for name in sorted(set(names)) {
        if str(name) == gateway {
            has_gateway = True;
        } else {
            services.append(str(name));
        }
    }
    return services + ([gateway] if has_gateway else []);
}


def app_bundle_digest(bundle_keys: list[str]) -> str {
    for key in bundle_keys {
        text = str(key);
        if text.startswith("bundles/") and text.endswith(".jab") {
            return text.rsplit("/", 1)[-1][:-len(".jab")];
        }
    }
    return "";
}


def releases_from_revisions(entries: list[dict[str, any]]) -> list[dict[str, any]] {
    by_digest: dict[str, dict[str, any]] = {};
    for item in entries {
        digest = str(item.get("bundle_digest", "") or "");
        if not digest {
            continue;
        }
        name = str(item.get("deployment", "") or "");
        revision = int(item.get("revision", 0) or 0);
        if digest not in by_digest {
            by_digest[digest] = {
                "bundle_digest": digest,
                "revision": revision,
                "created": str(item.get("created", "") or ""),
                "deployments": {}
            };
        }
        release = by_digest[digest];
        if revision > int(release["deployments"].get(name, 0) or 0) {
            release["deployments"][name] = revision;
        }
        if revision > int(release["revision"]) {
            release["revision"] = revision;
            release["created"] = str(item.get("created", "") or "");
        }
    }
    return sorted(by_digest.values(), key=_revision_sort_key, reverse=True);
}


def fleet_targets_for_release(
    releases: list[dict[str, any]], revision: int, expected: list[str]
) -> dict[str, any] {
    for release in releases {
        if int(release.get("revision", 0) or 0) != int(revision) {
            continue;
        }
        held = dict(release.get("deployments", {}) or {});
        missing = [
            name
            for name in expected
            if name not in held
        ];
        if missing {
            return {"ok": False, "missing": sorted(missing), "targets": {}};
        }
        return {"ok": True, "missing": [], "targets": held};
    }
    return {"ok": False, "missing": list(expected), "targets": {}};
}


def deployment_rollout_complete(dep: any) -> bool {
    try {
        status = dep.status;
        if status is None {
            return False;
        }
        if int(status.observed_generation or 0) < int(dep.metadata.generation or 0) {
            return False;
        }
        desired = dep.spec.replicas;
        wanted = int(desired) if desired is not None else 1;
        updated = int(status.updated_replicas or 0);
        current = int(status.replicas or 0);
        available = int(status.available_replicas or 0);
    } except Exception {
        return False;
    }
    return updated >= wanted and current <= updated and available >= updated;
}


def restorable_pod_template(template: dict[str, any]) -> dict[str, any] {
    cleaned = dict(template);
    metadata = dict(cleaned.get("metadata") or {});
    labels = dict(metadata.get("labels") or {});
    labels.pop("pod-template-hash", None);
    annotations = dict(metadata.get("annotations") or {});
    annotations.pop(CONFIG_REVISION_ANNOTATION, None);
    metadata["labels"] = labels;
    if annotations {
        metadata["annotations"] = annotations;
    } else {
        metadata.pop("annotations", None);
    }
    cleaned["metadata"] = metadata;
    return cleaned;
}

def apply_http_activations_for_bundle(
    bundle: dict[str, any], namespace: str, keda: KEDAAutoscaler
) {
    scaling: dict[str, any] = bundle.get("scaling", {});
    for svc_name in scaling.keys() {
        plan: dict[str, any] = dict(scaling.get(svc_name, {}));
        if plan.get("mode") != ScalingMode.HTTP_ACTIVATION {
            continue;
        }
        apply_http_activation_for_target(
            dict(plan.get("http_activation", {})),
            str(plan.get("scale_target_name", "")),
            namespace,
            str(plan.get("service_name", "")),
            keda
        );
    }
}


def reap_stale_scaling_resources_for_bundle(
    bundle: dict[str, any], namespace: str, autoscaler: any, keda: KEDAAutoscaler
) {
    scaling: dict[str, any] = bundle.get("scaling", {});
    for svc_name in scaling.keys() {
        plan: dict[str, any] = dict(scaling.get(svc_name, {}));
        mode = plan.get("mode");
        scale_target_name = str(plan.get("scale_target_name", ""));
        if mode != ScalingMode.METRIC {
            autoscaler.destroy(k8s_safe_name(svc_name), namespace);
        }
        if mode != ScalingMode.HTTP_ACTIVATION {
            destroy_http_activation_for_target(scale_target_name, namespace, keda);
        }
    }
}


obj KubernetesTarget(KubernetesTargetBase) {
    has _deploy_context: DeployContext = DeployContext(),
        microservices_config: (dict[str, any] | None) = None;

    def _ms_cfg -> dict[str, any] {
        if self.microservices_config is not None {
            return self.microservices_config;
        }
        try {
            import from jaclang.scale.config.config_loader { get_scale_config }
            return get_scale_config().get_microservices_config();
        } except Exception {
            return {};
        }
    }

    def deploy(app_config: AppConfig) -> DeploymentResult {
        app_name = app_config.app_name or self.k8s_config.app_name;
        if self.k8s_config.shared_ingress and not self.k8s_config.domain {
            return DeploymentResult(
                success=False,
                message="shared_ingress=True requires a domain: set 'domain' "
                "under [scale.kubernetes] in jac.toml."
            );
        }
        import from jaclang.scale.injector.binary { deploy_generation_refusal }
        refusal = deploy_generation_refusal(app_config.code_folder);
        if refusal {
            return DeploymentResult(success=False, message=refusal);
        }
        if self.logger {
            self.logger.info(
                f"Deploying app '{app_name}' to Kubernetes",
                {"namespace": self.k8s_config.namespace}
            );
        }

        if not self.dry_run {
            self._emit("runtime", "start", "Resolving the pod jac runtime");
            try {
                import from jaclang.scale.config.dev_config { resolve_dev_channel }
                import from jaclang.scale.injector.binary {
                    node_arch,
                    preflight_pod_runtime
                }
                self._load_cluster_config();
                pinned = preflight_pod_runtime(
                    app_config.code_folder,
                    resolve_dev_channel(app_config.code_folder).value,
                    node_arch()
                );
            } except Exception as e {
                self._emit("runtime", "error", str(e));
                return DeploymentResult(success=False, message=str(e));
            }
            self._emit(
                "runtime",
                "ok",
                f"Pod runtime jac {pinned}" if pinned else "Pod runtime resolved"
            );
        }

        self._emit("provision", "start", "Provisioning backends");
        try {
            self._deploy_context = DatabaseProvisioner(
                k8s_target=self, logger=self.logger
            ).provision(
                app_name
            );
        } except Exception as e {
            self._emit("provision", "error", f"database provisioning failed: {e}");
            return DeploymentResult(
                success=False, message=f"database provisioning failed: {e}"
            );
        }
        self._emit("provision", "ok", "Backends provisioned");

        self._emit("bundle", "start", "Generating manifests");
        try {
            bundle = self.generate_manifests(app_config);
        } except Exception as e {
            self._emit("bundle", "error", f"manifest generation failed: {e}");
            return DeploymentResult(
                success=False, message=f"manifest generation failed: {e}"
            );
        }
        self._emit(
            "bundle",
            "ok",
            "Manifests generated",
            detail={"services": len(bundle.get("pod_specs", {}))}
        );

        self._emit("apply", "start", "Applying manifests to the cluster");
        try {
            self.apply_manifests(bundle);
        } except Exception as e {
            self._emit("apply", "error", f"manifest apply failed: {e}");
            return DeploymentResult(
                success=False, message=f"manifest apply failed: {e}", details=bundle
            );
        }
        self._emit("apply", "ok", "Manifests applied");

        observability_err: str = "";
        try {
            self._deploy_observability(app_name);
        } except Exception as e {
            observability_err = str(e);
            bundle["observability_error"] = observability_err;
            self._emit(
                "observability", "warn", f"observability stack deploy failed: {e}"
            );
            if self.logger {
                self.logger.warn(
                    f"Observability stack deploy reported a non-fatal error: {e}",
                    {"app_name": app_name}
                );
            }
        }

        self._emit("rollout", "start", "Waiting for the fleet to become ready");
        try {
            self._wait_for_fleet_rollout(bundle);
        } except Exception as e {
            self._emit("rollout", "error", f"fleet did not become ready: {e}");
            return DeploymentResult(
                success=False,
                message=f"fleet did not become ready: {e}",
                details=bundle
            );
        }
        self._emit("rollout", "ok", "Fleet is ready");

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

    def _scan_for_crash_loop(
        core_v1: any,
        ns: str,
        current_hashes: set,
        fleet_app_names: set,
        companion_app_names: set | None = None
    ) -> dict[str, any] {
        imagepull_reasons: set = {
            "ImagePullBackOff",
            "ErrImagePull",
            "InvalidImageName"
        };
        transient_reasons: set = {"PodInitializing", "ContainerCreating"};
        crash = "";
        crash_pod = None;
        pulls: dict[str, any] = {};
        creating: dict[str, any] = {};
        phases: list[str] = [];
        states: list[str] = [];
        try {
            for p in core_v1.list_namespaced_pod(namespace=ns).items {
                if p.metadata?.deletion_timestamp is not None {
                    continue;
                }
                pod_name = str(p.metadata.name);
                labels = p.metadata.labels or {};
                app = str(labels.get("app", ""));
                in_fleet = (app in fleet_app_names) if fleet_app_names else True;
                if current_hashes and app in fleet_app_names {
                    pod_hash = labels.get("pod-template-hash");
                    if pod_hash is not None and pod_hash not in current_hashes {
                        continue;
                    }
                }
                phase = str(p.status.phase or '?');
                statuses = list(p.status.init_container_statuses or []) + list(
                    p.status.container_statuses or []
                );
                pod_reason = "";
                pod_crash = "";
                pod_crash_restarts = 0;
                pod_pull = "";
                pod_pull_reason = "";
                for cs in statuses {
                    waiting = cs.state.waiting if cs.state else None;
                    reason = (waiting.reason if waiting else "") or "";
                    restarts = cs.restart_count or 0;
                    states.append(f"{pod_name}/{cs.name}={phase}/{reason}/{restarts}");
                    if reason and reason not in transient_reasons {
                        pod_reason = reason;
                    }

                    owned = in_fleet
                    or (companion_app_names is not None and app in companion_app_names);
                    crashing = (
                        owned and restarts >= 3 and reason not in imagepull_reasons
                    );
                    if crashing and not pod_crash {
                        pod_crash = str(cs.name);
                        pod_crash_restarts = restarts;
                    } elif reason in imagepull_reasons and not pod_pull and in_fleet {
                        pod_pull = str(cs.name);
                        pod_pull_reason = reason;
                    }
                }
                if pod_pull {
                    pulls[pod_name] = (pod_pull, pod_pull_reason, p);
                }

                reasons = [
                    str(
                        (
                            cs.state.waiting.reason
                                if cs.state and cs.state.waiting
                                else ""
                        )
                        or ""
                    ) for cs in statuses
                ];
                stuck_creating = (
                    bool(statuses)
                    and not pod_reason
                    and not pod_pull
                    and ("ContainerCreating" in reasons)
                    and ("PodInitializing" not in reasons)
                );
                if phase == "Pending" and stuck_creating and in_fleet {
                    creating[pod_name] = p;
                }
                if pod_crash and not crash {
                    crash = (
                        f"pod '{pod_name}' container '{pod_crash}' "
                        f"crash-looping ({pod_crash_restarts} restarts)"
                    );
                    crash_pod = p;
                }
                if app {
                    token = f"{app}={phase}";
                    if pod_reason {
                        token = f"{app}={phase}/{pod_reason}";
                    }
                    phases.append(token);
                }
            }
        } except Exception {
            _ = 0;
        }
        return {
            "crash": crash,
            "crash_pod": crash_pod,
            "pulls": pulls,
            "creating": creating,
            "phases": phases,
            "states": states
        };
    }

    def _pod_mount_wedged(core_v1: any, ns: str, pod_name: str) -> bool {
        import from datetime { datetime, timezone }
        try {
            evs = core_v1.list_namespaced_event(
                namespace=ns, field_selector=f"involvedObject.name={pod_name}"
            ).items;
        } except Exception {
            return False;
        }
        now = datetime.now(timezone.utc);
        for e in evs {
            if str(e.reason or "") not in {"FailedMount", "FailedAttachVolume"} {
                continue;
            }

            ts = e.last_timestamp or e.event_time or e.first_timestamp;
            if ts is None {
                continue;
            }
            try {
                age = (now - ts).total_seconds();
            } except Exception {
                continue;
            }
            if age <= 360 {
                return True;
            }
        }
        return False;
    }

    def _try_self_heal(
        core_v1: any, ns: str, pod: any, why: str, healed_apps: dict[str, int]
    ) -> bool {
        app = str((pod.metadata.labels or {}).get("app", "")) or str(pod.metadata.name);
        if healed_apps.get(app, 0) >= 1 or sum(healed_apps.values()) >= 3 {
            return False;
        }
        pod_name = str(pod.metadata.name);
        try {
            core_v1.delete_namespaced_pod(name=pod_name, namespace=ns);
        } except Exception {
            return False;
        }
        healed_apps[app] = healed_apps.get(app, 0) + 1;
        if self.logger {
            self.logger.warn(
                f"Self-heal: deleted wedged pod '{pod_name}' ({why}); "
                f"its ReplicaSet schedules a replacement. One retry per "
                f"service, then the rollout fails as usual.",
                {"namespace": ns, "app": app}
            );
        }
        return True;
    }

    def _wait_for_fleet_rollout(
        bundle: dict[str, any], timeout: int = 1200, require_full: bool = False
    ) -> None {
        import time;
        import sys;
        import from kubernetes { client }
        import from jaclang.cli.console { console }

        scaling: dict[str, any] = bundle.get("scaling", {});
        http_activation_svc_names: set = {
            str(svc_name)
            for svc_name in scaling.keys()
            if dict(scaling.get(svc_name, {})).get("mode") == ScalingMode.HTTP_ACTIVATION
        };
        names: list[str] = [];
        app_labels: list[str] = [];
        for (svc_name, dep) in bundle.get("deployments", {}).items() {
            app: str = "";
            try {
                app = str(dep["spec"]["selector"]["matchLabels"]["app"]);
            } except Exception { }
            if not app {
                try {
                    app = str((dep["metadata"].get("labels") or {}).get("app") or "");
                } except Exception { }
            }
            if app {
                app_labels.append(app);
            }
            if svc_name not in http_activation_svc_names {
                names.append(str(dep["metadata"]["name"]));
            }
        }
        if not names {
            self._load_cluster_config();
            core_v1 = client.CoreV1Api();
            ns = self.k8s_config.namespace;
            crash = self._scan_for_crash_loop(core_v1, ns, set(), set(app_labels))[
                "crash"
            ];
            if crash {
                raise Exception(
                    "Deployment failed: application pods are restarting "
                    "(crash loop / bad image); not marking the fleet ready."
                );
            }
            if self.logger {
                self.logger.info(
                    "Fleet ready: all services use HTTP activation "
                    "(scale to zero until first request); pods healthy."
                );
            }
            return;
        }
        self._load_cluster_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        ns = self.k8s_config.namespace;
        total = len(names);
        elapsed = 0;
        ready = 0;
        interactive = bool(sys.stdout.isatty());
        fleet_apps: set = set(app_labels);

        app_name = str(self.k8s_config.app_name or "");
        companion_apps: set = (
            {f"{app_name}-redis", f"{app_name}-mongodb"} if app_name else set()
        );
        pod_selector = "app in ({})".format(", ".join(app_labels))
            if app_labels
            else None;
        imagepull_streak: dict[str, int] = {};
        creating_streak: dict[str, int] = {};
        healed_apps: dict[str, int] = {};
        last_sig = "";
        last_heartbeat = -90;

        current_hashes: set = set();
        if pod_selector {
            try {
                current_hashes = _resolve_current_rs_hashes(ns, pod_selector);
            } except Exception as exc {
                console.print(
                    f"[warn] RS hash lookup failed, falling back to broad pod "
                    f"scan: {exc}"
                );
            }
        }

        with console.status(f"Rolling out fleet: 0/{total} services ready...") as st {
            while elapsed < timeout {
                ready = 0;
                for name in names {
                    try {
                        d = apps_v1.read_namespaced_deployment(name=name, namespace=ns);
                        complete = deployment_rollout_complete(d)
                            if require_full
                            else (d.status.ready_replicas or 0) >= 1;
                        if complete {
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

                scan = self._scan_for_crash_loop(
                    core_v1, ns, current_hashes, fleet_apps, companion_apps
                );
                phase_tokens = scan["phases"];
                state_tokens = scan["states"];
                crash_failure = scan["crash"];
                crash_pod = scan["crash_pod"];

                if crash_failure and pod_selector {
                    refreshed = _refresh_rs_hashes(ns, pod_selector, current_hashes);
                    current_hashes = refreshed or set();
                    recheck = self._scan_for_crash_loop(
                        core_v1, ns, current_hashes, fleet_apps, companion_apps
                    );
                    crash_failure = recheck["crash"];
                    crash_pod = recheck["crash_pod"];
                }

                pulls = scan["pulls"];
                imagepull_streak = {k: imagepull_streak.get(k, 0) + 1 for k in pulls};
                pull_failure = "";
                pull_pod = None;
                for (pod_name, info) in pulls.items() {
                    if imagepull_streak.get(pod_name, 0) >= 2 {
                        if self._try_self_heal(
                            core_v1,
                            ns,
                            info[2],
                            f"container '{info[0]}' cannot pull image ({info[1]})",
                            healed_apps
                        ) {
                            imagepull_streak.pop(pod_name, None);
                            continue;
                        }
                        pull_failure = (
                            f"pod '{pod_name}' container '{info[0]}' "
                            f"cannot pull image ({info[1]})"
                        );
                        pull_pod = info[2];
                        break;
                    }
                }
                creating_now = scan.get("creating", {});
                creating_streak = {
                    k: creating_streak.get(k, 0) + 1 for k in creating_now
                };
                for (pod_name, pod) in creating_now.items() {
                    if creating_streak.get(pod_name, 0) >= 30
                    and self._pod_mount_wedged(core_v1, ns, pod_name) {
                        if self._try_self_heal(
                            core_v1,
                            ns,
                            pod,
                            "stuck >5min with FailedMount events",
                            healed_apps
                        ) {
                            creating_streak.pop(pod_name, None);
                        }
                    }
                }

                failure = crash_failure or pull_failure;
                failed_pod = crash_pod if crash_failure else pull_pod;
                if failure and failed_pod is not None {
                    detail = self._pod_failure_detail(
                        core_v1, ns, str(failed_pod.metadata.name), failed_pod
                    );
                    raise Exception(f"{failure}.{detail}");
                }

                summary = ", ".join(phase_tokens)
                    if phase_tokens
                    else "scheduling pods";
                line = (
                    f"Rolling out fleet: {ready}/{total} ready - {elapsed}s "
                    f"elapsed ({summary}) - pods install jac + start the app"
                );
                st.update(line);

                sig = f"{ready}/{total}|" + "|".join(sorted(state_tokens));
                if sig != last_sig or (elapsed - last_heartbeat) >= 90 {
                    if not interactive {
                        console.print(line);
                    }
                    last_sig = sig;
                    last_heartbeat = elapsed;
                }
                time.sleep(10);
                elapsed += 10;
            }
        }
        timeout_detail = "";
        try {
            stuck = core_v1.list_namespaced_pod(
                namespace=ns, label_selector=pod_selector
            ).items
                if pod_selector
                else [];
            for p in stuck {
                timeout_detail += (
                    f" [pod {p.metadata.name}]" + self._pod_failure_detail(
                        core_v1, ns, str(p.metadata.name), p
                    )
                );
            }
        } except Exception {
            _ = 0;
        }
        raise Exception(
            f"timed out after {timeout}s ({ready}/{total} deployments ready)."
            f"{timeout_detail}"
        );
    }

    def _pod_failure_detail(
        core_v1: any, namespace: str, pod_name: str, pod: any = None
    ) -> str {
        import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
            describe_pod_status
        }
        detail = describe_pod_status(core_v1, namespace, pod_name, pod);
        term_lines: list[str] = [];
        try {
            if pod is None {
                pod = core_v1.read_namespaced_pod(pod_name, namespace);
            }
            statuses = (pod.status.init_container_statuses or []) + (
                pod.status.container_statuses or []
            );
            for cs in statuses {
                states: list = [];
                if cs.state and cs.state.terminated {
                    states.append(("terminated", cs.state.terminated));
                }
                if cs.last_state and cs.last_state.terminated {
                    states.append(("last-terminated", cs.last_state.terminated));
                }
                for (label, term) in states {
                    message = (term.message or "").strip();
                    if message or term.reason {
                        term_lines.append(
                            f"container '{cs.name}' {label}: "
                            f"{term.reason or '?'} (exit={term.exit_code}) {message}"
                        );
                    }
                }
            }
        } except Exception {
            _ = 0;
        }
        if term_lines {
            detail = detail + " " + "; ".join(term_lines);
        }
        return detail;
    }

    def _deploy_observability(app_name: str) -> None {
        logs_cfg = self._read_microservices_logs_config();
        tracing_cfg = self._read_microservices_tracing_config();
        if not logs_cfg.get("enabled", False)
        and not tracing_cfg.get("enabled", False) {
            return;
        }

        self._load_cluster_config();
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
        monitoring.deploy(
            app_name,
            obs_config.namespace,
            apps_v1,
            core_v1,
            provider,
            scrape_target_service="gateway-service"
        );
    }

    def ensure_alb_readiness_gates(core_v1: any, namespace: str) -> None {
        cfg = self.k8s_config;
        is_alb = bool(getattr(cfg, "shared_ingress", False))
        and str(getattr(cfg, "shared_ingress_class", "")).lower() == "alb";
        if not is_alb {
            return;
        }
        gate_label = "elbv2.k8s.aws/pod-readiness-gate-inject";
        try {
            ns = core_v1.read_namespace(name=namespace);
            labels: dict = dict(getattr(ns.metadata, "labels", {}) or {});
            if labels.get(gate_label) == "enabled" {
                return;
            }
            core_v1.patch_namespace(
                name=namespace, body={"metadata": {"labels": {gate_label: "enabled"}}}
            );
            if self.logger {
                self.logger.info(
                    f"Labeled namespace '{namespace}' for ALB pod readiness "
                    f"gates: rollouts now wait for the new pod's ALB target to "
                    f"pass health checks before retiring the old pod.",
                    {"label": gate_label}
                );
            }
        } except Exception as e {
            if self.logger {
                self.logger.warn(
                    f"Could not label namespace '{namespace}' for ALB pod "
                    f"readiness gates ({e}); rollouts may briefly serve 502s "
                    f"from the ALB while new targets pass health checks.",
                    {"label": gate_label}
                );
            }
        }
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
                    f"Could not read [scale.microservices.logs] - "
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
                    f"Could not read [scale.microservices.tracing] - "
                    f"tracing stack will not be deployed: {e}"
                );
            }
            return {};
        }
    }

    def generate_manifests(app_config: AppConfig) -> dict[str, any] {
        import from jaclang.scale.injector.binary { resolve_pod_base_image }
        self.k8s_config.python_image = resolve_pod_base_image(
            app_config.code_folder, self.k8s_config.python_image, probe=not self.dry_run
        );
        builder = ManifestBuilder(
            k8s_config=self.k8s_config,
            secrets=self.secrets,
            deploy_context=self._context_with_env(),
            logger=self.logger,
            project_dir=app_config.code_folder,
            microservices_config=self.microservices_config,
            dry_run=self.dry_run
        );
        return builder.generate_manifests(app_config, self.k8s_config.python_image);
    }

    def _context_with_env -> DeployContext {
        if not self.env {
            return self._deploy_context;
        }
        ctx = DeployContext(
            env_list=list(self._deploy_context.env_list),
            init_containers=self._deploy_context.init_containers
        );
        present = {entry.get("name") for entry in ctx.env_list};
        for (env_name, env_value) in self.env.items() {
            if env_name not in present {
                ctx.env_list.append({"name": env_name, "value": str(env_value)});
            }
        }
        return ctx;
    }

    def _resolve_service_triggers(svc_name: str, cfg: dict[str, any]) -> list[Trigger] {
        is_gateway = svc_name == GATEWAY_NAME;
        has_memory_request = bool(cfg.get("has_memory_request", True));
        effective_extra = self.k8s_config.extra_triggers if is_gateway else [];
        triggers: list[Trigger] = [];
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
            if has_memory_request {
                triggers.append(
                    Trigger(
                        type="memory",
                        metadata={
                            "averageUtilization": str(
                                cfg.get(
                                    "memory_target", DEFAULT_MEMORY_UTILIZATION_TARGET
                                )
                            )
                        }
                    )
                );
            }
        }
        for raw in cfg.get("triggers", []) + effective_extra {
            t = Trigger(
                type=str(raw.get("type", "")),
                metadata=dict(raw.get("metadata", {})),
                name=raw.get("name")
            );
            if t.type == "memory" and not has_memory_request {
                if self.logger {
                    self.logger.warn(
                        f"Skipping 'memory' trigger for '{svc_name}': "
                        "memory_request resolves empty (explicitly set to "
                        "\"\"); HPA cannot compute memory utilization "
                        "without a request baseline"
                    );
                }
                continue;
            }
            raw_auth = raw.get("auth");
            if raw_auth {
                t.auth = TriggerAuth(secret_refs=dict(raw_auth.get("secret_refs", {})));
            }
            triggers.append(t);
        }
        return triggers;
    }

    def _autoscaler_spec(
        svc_name: str, plan: dict[str, any], autoscaler: any, namespace: str
    ) -> AutoscalerSpec {
        """Build the AutoscalerSpec for a METRIC-mode service from its already-
        resolved scaling plan, so the scale target here is the same Deployment
        name apply_manifests actually applied -- never re-derived from svc_name,
        which is exactly the drift that caused apply_http_activation to 404 on
        a real cluster before _resolve_scaling existed.
        """;
        k8s_name = k8s_safe_name(svc_name);
        cfg: dict[str, any] = dict(plan.get("autoscaler", {}));
        return AutoscalerSpec(
            scale_target_name=str(plan.get("scale_target_name", "")),
            autoscaler_name=autoscaler.resource_name_for(k8s_name),
            app_name=k8s_name,
            namespace=namespace,
            min_replicas=int(cfg.get("min", 1)),
            max_replicas=int(cfg.get("max", 3)),
            idle_replicas=self.k8s_config.idle_replicas,
            polling_interval=self.k8s_config.autoscaler_polling_interval,
            cooldown_period=self.k8s_config.autoscaler_cooldown,
            initial_cooldown_period=self.k8s_config.autoscaler_initial_cooldown,
            scale_up_stabilization=self.k8s_config.autoscaler_scale_up_stabilization,
            scale_up_max_pods=self.k8s_config.autoscaler_scale_up_max_pods,
            triggers=self._resolve_service_triggers(svc_name, cfg),
            behavior_overlay=cfg.get("behavior", {})
        );
    }

    def render_autoscaler_manifests(bundle: dict[str, any]) -> list[dict[str, any]] {
        out: list[dict[str, any]] = [];
        scaling: dict[str, any] = bundle.get("scaling", {});
        for svc_name in scaling.keys() {
            plan: dict[str, any] = dict(scaling.get(svc_name, {}));
            if plan.get("mode") != ScalingMode.METRIC {
                continue;
            }
            autoscaler = AutoscalerFactory.create(
                self.k8s_config.autoscaler_engine, self.k8s_config.to_dict(), None
            );
            out.extend(
                autoscaler._build_manifests(
                    self._autoscaler_spec(
                        svc_name, plan, autoscaler, self.k8s_config.namespace
                    )
                )
            );
        }
        return out;
    }

    def apply_manifests(bundle: dict[str, any]) {
        self._load_cluster_config();
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
        self.ensure_alb_readiness_gates(core_v1, namespace);

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

        config_revision: str = "";
        user_secret = bundle.get("user_secret");
        if user_secret {
            config_revision = create_k8s_secret(
                core_v1,
                namespace,
                user_secret["metadata"]["name"],
                user_secret["stringData"]
            );
            if not config_revision {
                raise RuntimeError(
                    f"Applied the Secret for '{self.k8s_config.app_name}' but "
                    "could not read the "
                    "revision it returned, so a config change could not be made "
                    "to reach running pods. Refusing to deploy workloads rather "
                    "than reporting a success that leaves the old config live."
                );
            }
            if self.logger {
                self.logger.info(
                    f"Applied Secret for user-defined [scale.secrets] "
                    f"({len(user_secret['stringData'])} keys)",
                    {"name": user_secret["metadata"]["name"]}
                );
            }
        }

        for (svc_name, svc_manifest) in bundle["services"].items() {
            self._apply_or_replace(
                core_v1,
                "read_namespaced_service",
                "patch_namespaced_service",
                "create_namespaced_service",
                namespace,
                svc_manifest
            );
            if self.logger {
                self.logger.info(
                    f"Applied Service for '{svc_name}'",
                    {"name": svc_manifest["metadata"]["name"]}
                );
            }
        }

        scaling: dict[str, any] = bundle.get("scaling", {});

        deployments: dict[str, dict[str, any]] = bundle["deployments"];
        for (svc_name, raw_manifest) in deployments.items() {
            dep_manifest = with_config_revision(raw_manifest, config_revision);
            patch_body = None;
            if dict(scaling.get(svc_name, {})).get("mode") == ScalingMode.HTTP_ACTIVATION {
                patch_body = dict(dep_manifest);
                patch_body["spec"] = {
                    k: v
                    for (k, v) in dep_manifest["spec"].items()
                    if k != "replicas"
                };
            }
            self._apply_or_replace(
                apps_v1,
                "read_namespaced_deployment",
                "patch_namespaced_deployment",
                "create_namespaced_deployment",
                namespace,
                dep_manifest,
                patch_body
            );
            if self.logger {
                self.logger.info(
                    f"Applied Deployment for '{svc_name}'",
                    {"name": dep_manifest["metadata"]["name"]}
                );
            }
        }

        self.reap_superseded_deployments(apps_v1, namespace, bundle);

        reap_stale_scaling_resources_for_bundle(
            bundle,
            namespace,
            AutoscalerFactory.create(
                self.k8s_config.autoscaler_engine,
                self.k8s_config.to_dict(),
                self.logger
            ),
            KEDAAutoscaler(logger=self.logger)
        );

        for svc_name in scaling.keys() {
            plan: dict[str, any] = dict(scaling.get(svc_name, {}));
            if plan.get("mode") != ScalingMode.METRIC {
                continue;
            }
            autoscaler = AutoscalerFactory.create(
                self.k8s_config.autoscaler_engine,
                self.k8s_config.to_dict(),
                self.logger
            );
            spec = self._autoscaler_spec(svc_name, plan, autoscaler, namespace);
            autoscaler_applied = autoscaler.apply(spec);

            if self.logger and autoscaler_applied {
                self.logger.info(
                    f"Applied autoscaler for '{svc_name}'",
                    {"name": spec.autoscaler_name}
                );
            }
        }

        apply_http_activations_for_bundle(
            bundle, namespace, KEDAAutoscaler(logger=self.logger)
        );

        pdbs: dict[str, dict[str, any]] = bundle.get("pdbs", {}) or {};
        for (svc_name, pdb_manifest) in pdbs.items() {
            self._apply_or_replace(
                policy_v1,
                "read_namespaced_pod_disruption_budget",
                "patch_namespaced_pod_disruption_budget",
                "create_namespaced_pod_disruption_budget",
                namespace,
                pdb_manifest
            );
            if self.logger {
                self.logger.info(
                    f"Applied PDB for '{svc_name}'",
                    {"name": pdb_manifest["metadata"]["name"]}
                );
            }
        }

        ingress_manifest: any = bundle.get("ingress");
        if ingress_manifest {
            self._apply_or_replace(
                networking_v1,
                "read_namespaced_ingress",
                "patch_namespaced_ingress",
                "create_namespaced_ingress",
                namespace,
                ingress_manifest
            );
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

    def reap_superseded_deployments(
        apps_v1: any, namespace: str, bundle: dict[str, any]
    ) {
        applied: dict[str, str] = {};
        for dep in bundle.get("deployments", {}).values() {
            try {
                selector = str(dep["spec"]["selector"]["matchLabels"]["app"]);
                applied[selector] = str(dep["metadata"]["name"]);
            } except Exception {
                continue;
            }
        }
        if not applied {
            return;
        }

        try {
            existing = apps_v1.list_namespaced_deployment(namespace=namespace).items;
        } except Exception as e {
            if self.logger {
                self.logger.warn(
                    f"Could not list Deployments to reap superseded ones: {e}",
                    {"namespace": namespace}
                );
            }
            return;
        }

        for dep in existing {
            try {
                name = str(dep.metadata.name);
                labels = dict(dep.metadata.labels or {});
                selector = str((dep.spec.selector.match_labels or {}).get("app", ""));
            } except Exception {
                continue;
            }
            if labels.get("managed") != "jac-scale" {
                continue;
            }
            current = applied.get(selector);
            if current is None or current == name {
                continue;
            }
            delete_if_exists(
                apps_v1.delete_namespaced_deployment, name, namespace, "Deployment"
            );
            self._emit(
                "apply",
                "ok",
                f"Removed superseded Deployment '{name}'",
                detail={"superseded_by": current, "selector": selector}
            );
            if self.logger {
                self.logger.info(
                    f"Removed superseded Deployment '{name}'; '{current}' now "
                    f"solely backs the 'app={selector}' Service",
                    {"namespace": namespace}
                );
            }
        }
    }

    def _fleet_deployment_names(apps_v1: any, namespace: str) -> list[str] {
        names: list[str] = [];
        try {
            listed = apps_v1.list_namespaced_deployment(
                namespace=namespace, label_selector=FLEET_SELECTOR
            );
            for dep in list(listed?.items or []) {
                try {
                    names.append(str(dep.metadata.name));
                } except Exception {
                    continue;
                }
            }
        } except Exception {
            return [];
        }
        return fleet_revert_order(names);
    }

    def _owned_replica_sets(
        apps_v1: any, namespace: str, strict: bool = False
    ) -> list[any] {
        owned: list[str] = self._fleet_deployment_names(apps_v1, namespace);
        try {
            listed = list(
                apps_v1.list_namespaced_replica_set(
                    namespace=namespace, label_selector="managed=jac-scale"
                ).items
            );
            scoped: list[any] = [];
            for rs in listed {
                rs_any: any = rs;
                try {
                    owners = list(rs_any.metadata.owner_references or []);
                } except Exception {
                    continue;
                }
                if owners and str(owners[0].name) in owned {
                    scoped.append(rs_any);
                }
            }
            return scoped;
        } except Exception as e {
            if strict {
                raise;
            }
            if self.logger {
                self.logger.warn(
                    f"Could not list ReplicaSets: {e}", {"namespace": namespace}
                );
            }
            return [];
        }
    }

    def _revision_entries(strict: bool = False) -> list[dict[str, any]] {
        self._load_cluster_config();
        apps_v1 = client.AppsV1Api();
        namespace: str = self.k8s_config.namespace;
        serializer = client.ApiClient();
        revisions: list[dict[str, any]] = [];

        for rs in self._owned_replica_sets(apps_v1, namespace, strict=strict) {
            try {
                annotations = dict(rs.metadata.annotations or {});
                raw_revision = annotations.get(REVISION_ANNOTATION);
                if raw_revision is None {
                    continue;
                }
                owners = list(rs.metadata.owner_references or []);
                deployment = str(owners[0].name) if owners else "";
                pod_spec = serializer.sanitize_for_serialization(rs.spec.template.spec);
                created = rs.metadata.creation_timestamp;
                revisions.append(
                    {
                        "deployment": deployment,
                        "revision": int(raw_revision),
                        "replica_set": str(rs.metadata.name),
                        "bundle_keys": bundle_keys_from_pod_spec(dict(pod_spec)),
                        "bundle_digest": app_bundle_digest(
                            bundle_keys_from_pod_spec(dict(pod_spec))
                        ),
                        "created": created.isoformat() if created else "",
                        "replicas": int(rs.spec.replicas or 0)
                    }
                );
            } except Exception {
                continue;
            }
        }
        return revisions;
    }

    def _assert_own_app(app_name: str) {
        mine = str(self.k8s_config.app_name or "");
        if app_name and mine and str(app_name) != mine {
            detail = f"configured for '{mine}', asked about '{app_name}'";
            raise ValueError(
                "This target cannot report or revert another app's revisions " + f"({detail}). Build a target for that app."
            );
        }
    }

    def list_revisions(app_name: str) -> list[dict[str, any]] {
        self._assert_own_app(app_name);
        return releases_from_revisions(self._revision_entries());
    }

    def referenced_bundle_keys(app_name: str) -> set[str] {
        self._assert_own_app(app_name);
        keys: set[str] = set();
        for item in self._revision_entries(strict=True) {
            for key in item.get("bundle_keys", []) {
                keys.add(str(key));
            }
        }
        return keys;
    }

    def _restore_templates(
        apps_v1: any, namespace: str, names: list[str], undo: dict[str, any]
    ) -> list[str] {
        stranded: list[str] = [];
        for name in reversed(names) {
            template = undo.get(name);
            if template is None {
                continue;
            }
            try {
                apps_v1.patch_namespaced_deployment(
                    name=name,
                    namespace=namespace,
                    body=[
                        {"op": "replace", "path": "/spec/template", "value": template}
                    ]
                );
            } except Exception {
                stranded.append(name);
            }
        }
        return stranded;
    }

    def rollback_to(app_name: str, revision: int) -> DeploymentResult {
        self._assert_own_app(app_name);
        self._load_cluster_config();
        apps_v1 = client.AppsV1Api();
        namespace: str = self.k8s_config.namespace;
        serializer = client.ApiClient();

        expected: list[str] = self._fleet_deployment_names(apps_v1, namespace);
        resolved = fleet_targets_for_release(
            self.list_revisions(app_name), revision, expected
        );
        if not resolved.get("ok", False) {
            missing = list(resolved.get("missing", []));
            return DeploymentResult(
                success=False,
                message=(
                    f"Cannot roll '{app_name}' back to revision {revision} in "
                    f"'{namespace}': no retained revision for "
                    f"{', '.join(missing)}. It is older than "
                    f"revision_history_limit "
                    f"({self.k8s_config.revision_history_limit}), was never "
                    "deployed, or the service set changed between releases."
                ),
                details={"missing": missing}
            );
        }

        wanted: dict[str, any] = dict(resolved.get("targets", {}) or {});
        by_name: dict[str, any] = {};
        for rs in self._owned_replica_sets(apps_v1, namespace) {
            try {
                owners = list(rs.metadata.owner_references or []);
                ann = dict(rs.metadata.annotations or {});
            } except Exception {
                continue;
            }
            if not owners {
                continue;
            }
            name = str(owners[0].name);
            if name in wanted and ann.get(REVISION_ANNOTATION) == str(wanted[name]) {
                by_name[name] = rs;
            }
        }
        targets = by_name;

        if len(targets) != len(wanted) {
            return DeploymentResult(
                success=False,
                message=(
                    f"Refusing a partial rollback of '{app_name}': "
                    f"{len(targets)} of {len(wanted)} deployment(s) resolved. "
                    "A half reverted app serves two versions at once."
                )
            );
        }

        reverted: list[str] = [];
        undo: dict[str, any] = {};
        selectors: dict[str, any] = {};
        for name in expected {
            if name not in targets {
                continue;
            }
            rs = targets[name];
            template = restorable_pod_template(
                dict(serializer.sanitize_for_serialization(rs.spec.template))
            );
            try {
                live = apps_v1.read_namespaced_deployment(
                    name=name, namespace=namespace
                );
                undo[name] = dict(
                    serializer.sanitize_for_serialization(live.spec.template)
                );
                selectors[name] = dict(
                    serializer.sanitize_for_serialization(live.spec.selector)
                );
                apps_v1.patch_namespaced_deployment(
                    name=name,
                    namespace=namespace,
                    body=[
                        {"op": "replace", "path": "/spec/template", "value": template}
                    ]
                );
            } except Exception as e {
                stranded = self._restore_templates(apps_v1, namespace, reverted, undo);
                detail = (
                    f" {len(stranded)} deployment(s) are still on revision "
                    f"{revision} and the app is serving two versions: "
                    f"{', '.join(stranded)}."
                        if stranded
                        else " The already reverted deployments were put back."
                );
                return DeploymentResult(
                    success=False,
                    message=(
                        f"Reverting '{name}' to revision {revision} failed: {e}."
                        f"{detail}"
                    ),
                    details={"reverted": reverted, "stranded": stranded}
                );
            }
            reverted.append(name);
        }

        wait_bundle: dict[str, any] = {"deployments": {}};
        for name in reverted {
            wait_bundle["deployments"][name] = {
                "metadata": {"name": name},
                "spec": {"selector": selectors.get(name, {})}
            };
        }
        try {
            self._wait_for_fleet_rollout(wait_bundle, require_full=True);
        } except Exception as e {
            return DeploymentResult(
                success=False,
                message=(
                    f"Reverted {len(reverted)} deployment(s) to revision "
                    f"{revision}, but the fleet did not come back: {e}"
                ),
                details={"reverted": reverted, "revision": revision}
            );
        }
        return DeploymentResult(
            success=True,
            message=(f"Reverted {len(reverted)} deployment(s) to revision {revision}"),
            details={"reverted": reverted, "revision": revision}
        );
    }

    def _apply_or_replace(
        api: any,
        read: str,
        update: str,
        create: str,
        namespace: str,
        manifest: dict[str, any],
        patch_body: (dict[str, any] | None) = None
    ) {
        """patch_body, when given, is sent to `update` instead of `manifest` --
        e.g. a copy with `spec.replicas` stripped so a strategic-merge PATCH
        leaves an externally-scaled field (KEDA's ScaledObject) alone, while a
        fresh `create` still gets the full manifest including that field.
        HTTP activation relies on exactly this: KEDA owns `replicas` once a
        Deployment scales via HTTP_ACTIVATION, and the strategic-merge PATCH
        this omission produces is what keeps this apply from resetting the
        live value KEDA set.
        """;
        name: str = manifest["metadata"]["name"];
        try {
            getattr(api, read)(name=name, namespace=namespace);
            getattr(api, update)(
                name=name, namespace=namespace, body=patch_body or manifest
            );
        } except ApiException as e {
            if e.status == 404 {
                getattr(api, create)(namespace=namespace, body=manifest);
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

    def destroy(app_name: str, component: str = "") {
        if self.logger {
            self.logger.info(
                f"Destroying microservice topology in namespace "
                f"'{self.k8s_config.namespace}'",
                {"app_name": app_name}
            );
        }

        self._load_cluster_config();
        apps_v1 = client.AppsV1Api();
        core_v1 = client.CoreV1Api();
        policy_v1 = client.PolicyV1Api();
        networking_v1 = client.NetworkingV1Api();
        namespace: str = self.k8s_config.namespace;

        selector: str = FLEET_SELECTOR;
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

        if self.k8s_config.autoscaler_engine != "keda" {
            try {
                KEDAAutoscaler(logger=self.logger).destroy_collection(
                    namespace, ms_selector, best_effort=True
                );
            } except ApiException as e {
                if e.status != 404 {
                    raise;
                }
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
