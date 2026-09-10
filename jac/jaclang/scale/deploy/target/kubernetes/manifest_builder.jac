import from jaclang.server { sv_client }
import from jaclang.server.settings { ServeSettings }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.config.config_loader {
    GATEWAY_POD_KEYS,
    get_scale_config,
    normalize_gateway_config
}
import from jaclang.scale.runtime.fleet { FleetSpec, fleet_from_config, solo_fleet }
import from jaclang.scale.models.deploy_context { DeployContext }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.autoscale.http_activation_config {
    build_http_activation_spec
}
import from enum { StrEnum }


glob GATEWAY_NAME: str = "__gateway__",
     CONFIG_REVISION_ANNOTATION: str = "jac-scale.config-revision",
     _EXIT_CUSHION_S: int = 5,
     _RFC1123_MAX_LEN: int = 253,
     _CLIENT_BUILD_ATTEMPTS: int = 3,
     _CLIENT_BUILD_RETRY_PAUSE_S: int = 3,
     _DEP_INSTALL_TIMEOUT_S: int = 900,
     _TRANSIENT_CLIENT_BUILD_MARKERS: tuple = (
         "dependency installation failed",
         "failed to install dependencies",
         "bun install failed",
         "econnreset",
         "econnrefused",
         "enotfound",
         "etimedout",
         "eai_again",
         "socket hang up",
         "i/o timeout",
         "network request failed",

     ),
     _VITE_BUILD_ENV_FILES: tuple = (
         ".env",
         ".env.local",
         ".env.production",
         ".env.production.local"
     ),
     _MEMBERSHIP_DIAGNOSIS_SHOWN: int = 3;


def _output_tail(result: any, lines: int = 15) -> str {
    combined = ((result.stdout or "") + "\n" + (result.stderr or "")).strip();
    return "\n".join(combined.splitlines()[-lines:]);
}


def _is_transient_client_build_failure(output: str) -> bool {
    lowered = output.lower();
    for marker in _TRANSIENT_CLIENT_BUILD_MARKERS {
        if marker in lowered {
            return True;
        }
    }
    return False;
}


enum ScalingMode(StrEnum) {
    NONE = "none",
    METRIC = "metric",
    HTTP_ACTIVATION = "http_activation"
}


def _membership_diagnosis(output: str, base: any, excluded: any) -> str {
    import re;
    import from pathlib { Path }
    base_prefix = str(base).replace("\\", "/").rstrip("/") + "/";
    lines: list[str] = [];
    seen: set[str] = set();
    tried: set[str] = set();
    for token in re.findall(r"[\w.\\/-]+", output) {
        cand = token.replace("\\", "/").rstrip(".");
        if cand.startswith(base_prefix) {
            cand = cand[len(base_prefix):];
        }
        if cand in tried {
            continue;
        }
        tried.add(cand);
        variants = [cand];
        if "/" not in cand and "." in cand and not cand.startswith(".") {
            stem = cand.replace(".", "/");
            variants.extend([f"{stem}.jac", f"{stem}.py", stem]);
        }
        for variant in variants {
            if not variant or variant.startswith("/") or ".." in variant.split("/") {
                continue;
            }
            rel = Path(variant);
            if rel.name == "jac.toml" or rel.as_posix() in seen {
                continue;
            }
            if not (base / rel).exists() or not excluded.excludes(rel) {
                continue;
            }
            if excluded.is_build_tree(rel) {
                continue;
            }
            seen.add(rel.as_posix());
            lines.append(f"  - {rel.as_posix()}: {excluded.exclusion_reason(rel)}");
            break;
        }
    }
    if not lines {
        return "";
    }
    shown = lines[:_MEMBERSHIP_DIAGNOSIS_SHOWN];
    if len(lines) > _MEMBERSHIP_DIAGNOSIS_SHOWN {
        shown.append(f"  ... and {len(lines) - _MEMBERSHIP_DIAGNOSIS_SHOWN} more");
    }
    return (
        "\nThe client build ran on the bundle's staged sources, and these "
        "files named in its output never ship:\n"
        + "\n".join(shown)
        + "\nDrop the exclusion or remove the reference. Values the client "
        "needs at build time belong under [client.vite.define] in jac.toml; "
        "secrets stay server-side in [scale.secrets] or pod env and never "
        "reach the client."
    );
}


def _vite_env_keys(base: any) -> dict[str, list[str]] {
    import from pathlib { Path }
    found: dict[str, list[str]] = {};
    for name in _VITE_BUILD_ENV_FILES {
        env_file: Path = Path(base, name);
        if not env_file.is_file() {
            continue;
        }
        keys: list[str] = [];
        text: str = env_file.read_text(encoding="utf-8", errors="replace");
        for raw in text.splitlines() {
            line: str = raw.strip();
            if line.startswith("export ") {
                line = line[len("export "):].lstrip();
            }
            if not line or line.startswith("#") or "=" not in line {
                continue;
            }
            key = line.split("=", 1)[0].strip();
            if key.startswith("VITE_") and key not in keys {
                keys.append(key);
            }
        }
        if keys {
            found[name] = keys;
        }
    }
    return found;
}


def k8s_safe_name(svc_name: str) -> str {
    if svc_name == GATEWAY_NAME {
        return "gateway";
    }
    import re;
    if "${" in svc_name {
        raise ValueError(
            f"'{svc_name}' still contains an unresolved ${{...}} placeholder, so "
            f"the environment variable it names was not set where this deploy "
            f"ran. Export it, or replace it with a literal name."
        );
    }
    safe = re.sub(r"[^a-z0-9.-]", "-", svc_name.lower().replace("_", "-"));
    safe = re.sub(r"^[^a-z0-9]+|[^a-z0-9]+$", "", safe)[:_RFC1123_MAX_LEN];
    safe = re.sub(r"[^a-z0-9]+$", "", safe);
    if not safe {
        raise ValueError(
            f"'{svc_name}' has no characters usable in a Kubernetes name; names "
            f"must contain at least one letter or digit."
        );
    }
    return safe;
}


def pdb_spec(
    replica_floor: int, max_unavailable: int, min_available: (int | None) = None
) -> dict[str, any] | None {
    if min_available is not None {
        return {"minAvailable": min_available};
    }
    if max_unavailable >= replica_floor {
        return None;
    }
    return {"maxUnavailable": max_unavailable};
}


def _is_named_list(items: list) -> bool {
    if not items {
        return False;
    }
    for item in items {
        if not isinstance(item, dict) or "name" not in item {
            return False;
        }
    }
    return True;
}


def merge_manifest_overlay(base: any, overlay: any) -> any {
    if isinstance(base, dict) and isinstance(overlay, dict) {
        merged = dict(base);
        for (key, value) in overlay.items() {
            merged[key] = merge_manifest_overlay(base.get(key), value)
                if key in base
                else value;
        }
        return merged;
    }
    if (
        isinstance(base, list)
        and isinstance(overlay, list)
        and _is_named_list(base)
        and _is_named_list(overlay)
    ) {
        overlay_by_name = {item["name"]: item for item in overlay};
        merged_list: list = [];
        for item in base {
            item_name = item["name"];
            if item_name in overlay_by_name {
                merged_list.append(
                    merge_manifest_overlay(item, overlay_by_name.pop(item_name))
                );
            } else {
                merged_list.append(item);
            }
        }
        for item in overlay {
            if item["name"] in overlay_by_name {
                merged_list.append(item);
            }
        }
        return merged_list;
    }
    return overlay;
}


def with_config_revision(manifest: dict[str, any], revision: str) -> dict[str, any] {
    if not revision {
        return manifest;
    }
    return dict(
        merge_manifest_overlay(
            manifest,
            {
                "spec": {
                    "template": {
                        "metadata": {
                            "annotations": {CONFIG_REVISION_ANNOTATION: str(revision)}
                        }
                    }
                }
            }
        )
    );
}


obj ManifestBuilder {
    has k8s_config: KubernetesConfig,
        secrets: dict[str, str] = {},
        deploy_context: DeployContext = DeployContext(),
        logger: any = None,
        project_dir: str = "",
        _bundle_object_key: str = "",
        _toolchain_object_key: str = "",
        fleet: (FleetSpec | None) = None,
        gateway_config: (dict[str, any] | None) = None,
        app_overrides: dict[str, dict[str, any]] = {},
        client_entry: (str | None) = None,
        dry_run: bool = False,
        _bundle_files_cache: (dict[str, str] | None) = None,
        _serve_settings_cache: (ServeSettings | None) = None,
        _minted_secret: str = "";

    def _gateway_cfg -> dict[str, any] {
        if self.gateway_config is not None {
            return normalize_gateway_config(self.gateway_config);
        }
        return get_scale_config().get_gateway_config();
    }

    def _project_config -> any {
        import os;
        if not self.project_dir or not os.path.isdir(self.project_dir) {
            return None;
        }
        import from jaclang.scale.injector.bundle { _project_config }
        return _project_config(self.project_dir);
    }

    def _derive_fleet(app_config: AppConfig) -> FleetSpec {
        cfg = self._project_config();
        if cfg is not None and cfg.is_workspace {
            root_dir = str(cfg.project_root) if cfg.project_root else self.project_dir;
            fleet = fleet_from_config(
                cfg,
                app_config.served_app,
                project_root=root_dir,
                relative_to=self.project_dir
            );
        } else {
            name = app_config.app_name or self.k8s_config.app_name;
            if not name {
                raise ValueError(
                    "Cannot name the app's pod: no app_name is set. Set "
                    "[project].name in jac.toml."
                );
            }
            fleet = solo_fleet(
                name, app_config.file_name, client=self._has_client_source()
            );
        }
        for (app, cfg_over) in self.app_overrides.items() {
            merged = dict(fleet.overrides.get(app, {}));
            merged.update(dict(cfg_over) if isinstance(cfg_over, dict) else {});
            fleet.overrides[app] = merged;
        }
        return fleet;
    }

    def _fleet(app_config: AppConfig) -> FleetSpec {
        if self.fleet is None {
            self.fleet = self._derive_fleet(app_config);
        }
        return self.fleet;
    }

    def _injector_object_key -> str {
        return self._bundle_object_key;
    }

    def _prepare_injector(app_config: AppConfig) -> PvcInjector {
        import from jaclang.scale.injector.binary_injector { select_injector }
        import from jaclang.scale.injector.pvc_injector { PvcInjector }
        proj = self.project_dir or app_config.code_folder;
        self.project_dir = proj;
        fleet = self._fleet(app_config);
        self._build_client_bundle(proj);
        selection = select_injector(
            self.k8s_config.bundle_storage_class,
            k8s_safe_name(self.k8s_config.app_name),
            self.k8s_config.namespace,
            proj,
            dry_run=self.dry_run,
            access_mode=self.k8s_config.bundle_access_mode,
            fleet=fleet
        );
        injector: PvcInjector = selection[0];
        self._toolchain_object_key = str(selection[1]);
        return injector;
    }

    def _install_app_deps(
        project_dir: str, jac_bin: str, env: (dict[str, str] | None)
    ) -> str {
        import subprocess;
        import from jaclang.cli.console { console }
        console.print("Installing the app's dependencies on the build host.");
        try {
            result = subprocess.run(
                [jac_bin, "install"],
                cwd=project_dir,
                capture_output=True,
                text=True,
                timeout=_DEP_INSTALL_TIMEOUT_S,
                env=env
            );
        } except subprocess.TimeoutExpired {
            return f"'jac install' timed out after {_DEP_INSTALL_TIMEOUT_S}s";
        } except OSError as exc {
            return f"'jac install' could not run: {exc}";
        }
        if result.returncode != 0 {
            return f"'jac install' exited {result.returncode}:\n{_output_tail(result)}";
        }
        return "";
    }

    def _build_client_bundle(project_dir: str) {
        import os;
        import shutil;
        import subprocess;
        import from pathlib { Path }
        import from jaclang.cli.console { console }
        import from jaclang.scale.injector.binary { host_toolchain_path }
        import from jaclang.scale.injector.bundle {
            _stage_app,
            release_binary_env,
            remove_stage_root,
            sanitized_jac_toml,
            source_filter_for
        }
        import from jaclang.scale.runtime.context.util { jac_executable }
        client_entry = self._client_entry();
        if client_entry
            and not self._declared_client_entry()
            and not self._has_client_source() {
            client_entry = "";
        }
        if not client_entry {
            if self.client_entry is not None {
                console.print(
                    "The deploy declares no client entry (client_entry = \"\"); "
                    "skipping the client build."
                );
            } else {
                console.print(
                    "The served app has no client target and the project has no "
                    "client source (no pages/ or components/ directory, no "
                    "[client] table in jac.toml); skipping the client build."
                );
            }
            return;
        }
        base = Path(project_dir);
        entry_rel = Path(client_entry);
        if entry_rel.is_absolute() {
            try {
                entry_rel = entry_rel.relative_to(base);
            } except ValueError {
                raise ValueError(
                    f"The client entry '{client_entry}' is outside the project "
                    f"tree, so the bundle cannot ship it. Point the served app's "
                    f"entry-point at a path inside the project root."
                );
            }
        }
        if ".." in entry_rel.parts {
            raise ValueError(
                f"The client entry '{client_entry}' reaches outside the project "
                f"tree, so the bundle cannot ship it. Point the served app's "
                f"entry-point at a path inside the project root."
            );
        }
        if not (base / entry_rel).is_file() {
            if self._declared_client_entry() {
                raise ValueError(
                    f"The client entry '{client_entry}' does not exist under "
                    f"{base}, so the deploy would ship a served app with no "
                    f"client to serve. Fix the app's entry-point, or set "
                    f"client_entry = \"\" to deploy without a client."
                );
            }
            console.print(
                f"No client entry is declared and '{client_entry}' does not "
                f"exist; skipping the client build. Give the served app a client "
                f"by making its kind one that ships a client (web-app, "
                f"web-static, desktop, or mobile under [project] or "
                f"[apps.<name>]) to build one."
            );
            return;
        }
        excluded = source_filter_for(base);
        if excluded.excludes(entry_rel) {
            raise ValueError(
                f"The client entry '{entry_rel.as_posix()}' never ships: "
                f"{excluded.exclusion_reason(entry_rel)}. The client build runs "
                f"on exactly what the bundle ships, so it cannot build from "
                f"this file. Drop the exclusion, or point the served app's "
                f"entry-point at a module the bundle ships."
            );
        }
        for (env_name, keys) in _vite_env_keys(base).items() {
            console.warning(
                f"'{env_name}' declares {', '.join(keys)}, and the client build "
                f"runs on the bundle's staged sources, which never include "
                f".env files, so those compile to undefined in the served JS. "
                f"Values the client needs at build time belong under "
                f"[client.vite.define] in jac.toml; secrets stay server-side "
                f"and never reach the client."
            );
        }
        if self.dry_run {
            console.print(
                f"dry-run: skipped the host client bundle build ({client_entry})."
            );
            return;
        }
        import time;
        pinned = host_toolchain_path(project_dir);
        jac_bin = pinned or jac_executable();
        jac_env = release_binary_env() if pinned else None;
        if pinned {
            console.print(
                "Building with the jac release this app pins, not the one "
                f"running this deploy ({pinned})."
            );
        }
        stage_root = _stage_app(base, sanitized_jac_toml(base));
        stage = str(stage_root / "app");
        dist_candidates = self._client_dist_candidates(stage, entry_rel);
        try {
            for stale in dist_candidates {
                shutil.rmtree(stale, ignore_errors=True);
            }
            dep_error = self._install_app_deps(stage, jac_bin, jac_env);
            if dep_error {
                console.warning(
                    f"The app's dependencies did not install on the build host, "
                    f"so the client build may fail on a missing import. "
                    f"{dep_error}"
                );
            }
            console.print(
                f"Building the client bundle on the host, from the bundle's "
                f"staged sources ({client_entry})."
            );
            attempt = 0;
            while True {
                attempt += 1;
                try {
                    result = subprocess.run(
                        [jac_bin, "build", "--as", "client", entry_rel.as_posix()],
                        cwd=stage,
                        capture_output=True,
                        text=True,
                        timeout=900,
                        env=jac_env
                    );
                } except subprocess.TimeoutExpired {
                    if attempt >= _CLIENT_BUILD_ATTEMPTS {
                        raise RuntimeError(
                            f"client build timed out ({client_entry}) on all "
                            f"{_CLIENT_BUILD_ATTEMPTS} attempts. The pod serves "
                            f"the bundle built here and never rebuilds it - fix "
                            f"the client build and redeploy."
                        );
                    }
                    console.print(
                        f"Client build timed out (attempt {attempt} of "
                        f"{_CLIENT_BUILD_ATTEMPTS}); retrying."
                    );
                    time.sleep(_CLIENT_BUILD_RETRY_PAUSE_S);
                    continue;
                }
                if result.returncode == 0 {
                    break;
                }
                output = ((result.stdout or "") + "\n" + (result.stderr or "")).strip();
                tail = _output_tail(result);
                if (
                    attempt < _CLIENT_BUILD_ATTEMPTS
                    and _is_transient_client_build_failure(output)
                ) {
                    console.print(
                        f"Client build hit a transient install/network failure "
                        f"(attempt {attempt} of {_CLIENT_BUILD_ATTEMPTS}); "
                        f"retrying.\n{tail}"
                    );
                    time.sleep(_CLIENT_BUILD_RETRY_PAUSE_S);
                    continue;
                }
                cause = (
                    f"\nIts dependencies did not install on this host first, "
                    f"which is the likely cause: {dep_error}"
                        if dep_error
                        else ""
                );
                parked = _membership_diagnosis(output, base, excluded);
                raise RuntimeError(
                    f"client build failed ({client_entry}, exit "
                    f"{result.returncode}). The pod serves the bundle built "
                    f"here and never rebuilds it - fix the client build and "
                    f"redeploy.\n{tail}{cause}{parked}"
                );
            }
            dist = "";
            for candidate in dist_candidates {
                if os.path.isfile(os.path.join(candidate, "index.html")) {
                    dist = candidate;
                    break;
                }
            }
            if not dist {
                looked = ", ".join(
                    [os.path.relpath(d, stage) for d in dist_candidates]
                );
                raise RuntimeError(
                    f"client build produced no index.html under {looked} "
                    f"({client_entry}); the gateway would have nothing to serve."
                );
            }
            target = os.path.join(project_dir, ".jac", "client", "dist");
            incoming = target + ".incoming";
            outgoing = target + ".outgoing";
            os.makedirs(os.path.dirname(target), exist_ok=True);
            shutil.rmtree(incoming, ignore_errors=True);
            shutil.rmtree(outgoing, ignore_errors=True);
            shutil.copytree(dist, incoming);
            if os.path.isdir(target) {
                os.replace(target, outgoing);
            }
            os.replace(incoming, target);
            shutil.rmtree(outgoing, ignore_errors=True);
        } finally {
            remove_stage_root(stage_root);
        }
        console.print("Client bundle built; shipping it to the gateway pod.");
    }

    def _client_dist_candidates(stage: str, entry_rel: any) -> list[str] {
        import os;
        client_dir = os.path.join(stage, ".jac", "client");
        candidates: list[str] = [];
        cfg = self._project_config();
        if cfg is not None {
            import from jaclang.client.targets.registry { client_workspace_app }
            app = client_workspace_app(
                cfg, os.path.join(self.project_dir, entry_rel.as_posix())
            );
            if app is not None {
                candidates.append(os.path.join(client_dir, app.name, "dist"));
            }
        }
        candidates.append(os.path.join(client_dir, "dist"));
        return candidates;
    }

    def generate_manifests(app_config: AppConfig, image: str) -> dict[str, any] {
        self.project_dir = self.project_dir or app_config.code_folder;
        fleet = self._fleet(app_config);
        self._bundle_files();
        injector = self._prepare_injector(app_config);
        self._bundle_object_key = injector._object_key;

        pod_specs = self.generate_service_pod_specs(app_config, image);
        deployments: dict[str, dict[str, any]] = {};
        services: dict[str, dict[str, any]] = {};
        scaling: dict[str, dict[str, any]] = {};
        pdbs: dict[str, dict[str, any]] = {};

        for (svc_name, pod_spec) in pod_specs.items() {
            deployments[svc_name] = self._build_deployment_manifest(svc_name, pod_spec);
            services[svc_name] = self._build_service_manifest(svc_name);
            scaling[svc_name] = self._resolve_scaling(
                svc_name, deployments[svc_name], services[svc_name]
            );
            pdb = self._build_pdb_manifest(svc_name, scaling[svc_name].get("mode"));
            if pdb is not None {
                pdbs[svc_name] = pdb;
            }
        }
        self._validate_http_activation_rules(scaling);

        bundle: dict[str, any] = {
            "deployments": deployments,
            "services": services,
            "scaling": scaling,
            "pdbs": pdbs,
            "pod_specs": pod_specs,
            "fleet": fleet,
            "gateway_config": self._gateway_cfg()
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
        ingress_cfg: dict[str, any] = self._gateway_cfg().get("ingress", {});
        ingress = self._build_ingress_manifest(ingress_cfg);
        if ingress is not None {
            bundle["ingress"] = ingress;
        }

        if getattr(self.k8s_config, "ops_console", False) {
            import from jaclang.scale.deploy.target.kubernetes.ops_rbac {
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
                    "[scale.kubernetes].ops_console_mutations is set but "
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
        fleet = self._fleet(app_config);
        if fleet.is_empty() {
            raise ValueError(
                "Nothing to deploy: the fleet has no apps. Declare [apps] in "
                "jac.toml or set [project].name."
            );
        }

        specs: dict[str, dict[str, any]] = {};
        for svc_name in fleet.names() {
            specs[svc_name] = self._build_service_pod_spec(svc_name, image);
        }
        specs[GATEWAY_NAME] = self._build_gateway_pod_spec(image);

        if self.logger {
            self.logger.info(
                f"Generated {len(specs)} pod-spec stubs "
                f"(1 gateway + {len(fleet.members)} apps)",
                {"image": image, "namespace": self.k8s_config.namespace}
            );
        }
        return specs;
    }

    def _serve_settings -> ServeSettings {
        if self._serve_settings_cache is None {
            project = get_scale_config().get_jac_config();
            self._serve_settings_cache = ServeSettings.load(
                str(project.project_root or self.project_dir or '.'), config=project
            );
        }
        return self._serve_settings_cache;
    }

    def _drain_timeout -> int {
        return int(self._serve_settings().timeouts.drain);
    }

    def _signing_secret -> str {
        import secrets;
        configured = str(self.secrets.get("JAC_SERVE_AUTH_SECRET") or "").strip();
        if configured {
            return configured;
        }
        from_project = self._serve_settings().auth.secret.strip();
        if from_project {
            return from_project;
        }
        if not self._minted_secret {
            self._minted_secret = secrets.token_urlsafe(48);
        }
        return self._minted_secret;
    }

    def _serve_env(svc_name: str, svc_cfg: dict[str, any]) -> list[dict[str, any]] {
        settings = self._serve_settings();
        workers = str(svc_cfg.get("workers") or settings.workers.count);
        env: list[dict[str, any]] = [
            {"name": "JAC_SERVE_WORKERS", "value": workers},
            {"name": "JAC_SERVE_ACCESS_LOG_FORMAT", "value": "json"},
            {"name": "JAC_SERVE_ACCESS_LOG_SUPPRESS_HEALTH", "value": "1"},
            {"name": "JAC_SERVE_DRAIN_TIMEOUT", "value": str(self._drain_timeout())}
        ];
        threads = svc_cfg.get("threads");
        if threads is not None {
            env.append({"name": "JAC_SERVE_THREADS", "value": str(threads)});
        }
        trusted = list(settings.proxy.trusted);
        if svc_name != GATEWAY_NAME {
            trusted = trusted or ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"];
        }
        if trusted {
            env.append({"name": "JAC_SERVE_PROXY_TRUSTED", "value": ",".join(trusted)});
        }
        return env;
    }

    def _service_config(svc_name: str) -> dict[str, any] {
        merged: dict[str, any] = {};
        if svc_name == GATEWAY_NAME {
            gw = self._gateway_cfg();
            merged.update(
                {
                    key: gw[key]
                    for key in GATEWAY_POD_KEYS
                    if key in gw
                }
            );
        }
        if self.fleet is not None {
            merged.update(self.fleet.app_config(svc_name));
        }
        extra = self.app_overrides.get(svc_name);
        if isinstance(extra, dict) {
            merged.update(extra);
        }
        return merged;
    }

    def _bundle_files -> dict[str, str] {
        if self._bundle_files_cache is None {
            import from jaclang.scale.injector.bundle { resolve_fleet_entries }
            self._bundle_files_cache = (
                resolve_fleet_entries(self.project_dir, self.fleet)
                    if self.project_dir and self.fleet is not None
                    else {}
            );
        }
        return self._bundle_files_cache;
    }

    def _declared_client_entry -> str {
        if self.client_entry is not None {
            return self.client_entry.strip();
        }
        root_member = self.fleet.root_member() if self.fleet is not None else None;
        if root_member is not None and root_member.client {
            return root_member.file;
        }
        return "";
    }

    def _client_entry -> str {
        if self.client_entry is not None {
            return self.client_entry.strip();
        }
        declared = self._declared_client_entry();
        if declared {
            return declared;
        }
        cfg = self._project_config();
        if cfg is not None and cfg.is_workspace {
            return "";
        }
        if cfg is not None {
            entry_point = str(cfg.project.entry_point or "").strip();
            import os;
            import from jaclang.project.apps { resolve_entry_path }
            return os.path.relpath(
                resolve_entry_path(entry_point or "main", self.project_dir),
                self.project_dir
            );
        }
        root_member = self.fleet.root_member() if self.fleet is not None else None;
        if root_member is not None and root_member.file {
            return root_member.file;
        }
        return "main.jac";
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
        for probe in ("pages", "components") {
            if os.path.isdir(os.path.join(root_dir, probe)) {
                return True;
            }
        }

        import tomllib;
        try {
            with open(os.path.join(root_dir, "jac.toml"), "rb") as fh {
                return isinstance(tomllib.load(fh).get("client"), dict);
            }
        } except Exception {
            return False;
        }
    }

    def _shared_volumes_config -> list[dict[str, any]] {
        raw = self._gateway_cfg().get("shared_volumes", []);
        if not isinstance(raw, list) {
            return [];
        }
        out: list[dict[str, any]] = [];
        for `entry in raw {
            if isinstance(`entry, dict) {
                out.append(dict(`entry));
            }
        }
        return out;
    }

    def _shared_volumes_for_service(
        svc_name: str
    ) -> tuple[list[dict[str, any]], list[dict[str, any]]] {
        volumes: list[dict[str, any]] = [];
        mounts: list[dict[str, any]] = [];
        for vol in self._shared_volumes_config() {
            apps = vol.get("apps", []);
            if not isinstance(apps, list) {
                continue;
            }
            if svc_name not in apps {
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
            apps = vol.get("apps", []);
            if not isinstance(apps, list) or not apps {
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
                        "jac-scale.role": "shared-volume",
                        "jac-scale.owner": k8s_safe_name(self.k8s_config.app_name)
                    }
                },
                "spec": spec
            };
        }
        return pvcs;
    }

    def _build_user_secret_manifest -> dict[str, any] | None {
        data: dict[str, str] = {k: str(v) for (k, v) in self.secrets.items()};
        data["JAC_SERVE_AUTH_SECRET"] = self._signing_secret();
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
            "stringData": data
        };
    }

    def _user_secret_name -> str {
        return f"{self.k8s_config.app_name}-secrets";
    }

    def _owner_labels -> dict[str, str] {
        return {
            str(k): str(v) for (k, v) in dict(self.k8s_config.labels or {}).items()
        };
    }

    def _service_account_name -> str {
        return str(getattr(self.k8s_config, "service_account_name", "") or "").strip();
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
            {"name": "JAC_SV_SIBLING", "value": "1"},
            {"name": "K8S_APP_NAME", "value": self.k8s_config.app_name},
            {"name": "K8S_NAMESPACE", "value": self.k8s_config.namespace}
        ];
        svc_file: str = self._bundle_files().get(svc_name, "");
        if not svc_file and self.fleet is not None {
            member = self.fleet.member(svc_name);
            svc_file = member.file if member is not None else "";
        }
        if svc_file {
            env.append({"name": "JAC_SV_FILE", "value": svc_file});
        }

        trace_cfg: dict = dict(self._gateway_cfg().get("tracing", {}));
        if trace_cfg.get("enabled", False) {
            env.append(
                {
                    "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
                    "value": f"http://{self.k8s_config.app_name}-alloy-service:4318"
                }
            );
        }

        import from jaclang.scale.runtime.fleet { FLEET_ENV }
        peers: list[str] = [];
        if self.fleet is not None and not self.fleet.is_empty() {
            env.append({"name": FLEET_ENV, "value": self.fleet.to_env()});
            peers = self.fleet.names();
        }
        seen_peer_keys: set = set();
        for peer_name in peers {
            if peer_name == svc_name or peer_name == GATEWAY_NAME {
                continue;
            }
            key = sv_client.peer_url_env_key(peer_name);
            if key in seen_peer_keys {
                continue;
            }
            seen_peer_keys.add(key);
            env.append({"name": key, "value": self._peer_dns_url(peer_name)});
        }

        for `entry in self.deploy_context.env_list {
            env.append(`entry);
        }
        env.extend(self._serve_env(svc_name, svc_cfg));

        extra: dict[str, any] = svc_cfg.get("env", {});
        for (k, v) in extra.items() {
            if k in ("JAC_SV_NAME", "JAC_SV_FILE", "JAC_SV_SIBLING", FLEET_ENV) {
                continue;
            }
            if k.startswith("JAC_APP_")
                and (k.endswith("_URL") or k.endswith("_ROUTE")) {
                continue;
            }
            env.append({"name": k, "value": str(v)});
        }
        return env;
    }

    def _resolved_memory_request(svc_cfg: dict[str, any], is_gateway: bool) -> str {
        val = svc_cfg.get("memory_request");
        if val is None {
            val = self.k8s_config.memory_request;
        }
        if val is None {
            val = "2Gi" if is_gateway else "1Gi";
        }
        return str(val) if val else "";
    }

    def _build_resources(
        svc_cfg: dict[str, any], is_gateway: bool = False
    ) -> dict[str, any] {
        cfg = self.k8s_config;

        memory_request_val = self._resolved_memory_request(svc_cfg, is_gateway);
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

    def _alb_deregistration_cushion -> int {
        cfg = self.k8s_config;
        is_alb = bool(getattr(cfg, "shared_ingress", False))
            and str(getattr(cfg, "shared_ingress_class", "")).lower() == "alb";
        return 20 if is_alb else 0;
    }

    def _build_prestop_hook -> dict[str, any] {
        cushion = 5 + self._alb_deregistration_cushion();
        return {"exec": {"command": ["sh", "-c", f"sleep {cushion}"]}};
    }

    def _build_deployment_manifest(
        svc_name: str, pod_spec: dict[str, any]
    ) -> dict[str, any] {
        k8s_name = k8s_safe_name(svc_name);
        role: str = "gateway" if svc_name == GATEWAY_NAME else "microservice";
        labels: dict[str, str] = {
            ** self._owner_labels(),
            "app": k8s_name,
            "managed": "jac-scale",
            "jac-scale.role": role
        };
        svc_cfg = self._service_config(svc_name);
        replicas: int = int(svc_cfg.get("replicas", 1));
        manifest: dict[str, any] = {
            "apiVersion": "apps/v1",
            "kind": "Deployment",
            "metadata": {
                "name": f"{k8s_name}-deployment",
                "namespace": self.k8s_config.namespace,
                "labels": labels
            },
            "spec": {
                "replicas": replicas,
                "revisionHistoryLimit": self.k8s_config.revision_history_limit,
                "strategy": {
                    "type": "RollingUpdate",
                    "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}
                },
                "selector": {"matchLabels": {"app": k8s_name}},
                "template": {"metadata": {"labels": labels}, "spec": pod_spec}
            }
        };
        overlay = svc_cfg.get("deployment_overlay");
        if isinstance(overlay, dict) and overlay {
            manifest = merge_manifest_overlay(manifest, overlay);

            manifest["metadata"]["name"] = f"{k8s_name}-deployment";
            manifest["metadata"]["namespace"] = self.k8s_config.namespace;
            meta_labels = manifest["metadata"].get("labels", {});
            meta_labels.update(labels);
            manifest["metadata"]["labels"] = meta_labels;
            manifest["spec"]["selector"] = {"matchLabels": {"app": k8s_name}};
            tmpl_labels = manifest["spec"]["template"]["metadata"].get("labels", {});
            tmpl_labels.update({"app": k8s_name, "managed": "jac-scale"});
            manifest["spec"]["template"]["metadata"]["labels"] = tmpl_labels;
        }
        return manifest;
    }

    def _build_service_manifest(svc_name: str) -> dict[str, any] {
        k8s_name = k8s_safe_name(svc_name);
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
                "labels": {
                    ** self._owner_labels(),
                    "app": k8s_name,
                    "managed": "jac-scale"
                }
            },
            "spec": spec
        };
    }

    def _resolve_scaling(
        svc_name: str, deployment: dict[str, any], service: dict[str, any]
    ) -> dict[str, any] {
        """Resolve a service's single, mutually-exclusive scaling decision.

        The one place a service's scaling mode is decided. The scale-target
        name is read from the Deployment manifest just built (never rebuilt
        from svc_name), so build, apply, and `jac plan` can never disagree on
        it. The gateway is forced out of HTTP_ACTIVATION here: it is the
        ingress entry point and must stay warm, so it must never inherit the
        shared scale-to-zero default.
        """;
        scale_target: str = deployment["metadata"]["name"];
        service_name: str = service["metadata"]["name"];
        http: dict[str, any] | None = self._get_http_activation_config(svc_name);
        if http is not None and svc_name == GATEWAY_NAME {
            if self.logger {
                self.logger.warn(
                    "Ignoring http_activation for the gateway: it is the ingress "
                    "entry point and must stay warm. Set http_activation "
                    "per-service instead of relying on the shared default."
                );
            }
            http = None;
        }
        if http is not None {
            try {
                build_http_activation_spec(
                    http, scale_target, self.k8s_config.namespace, service_name
                );
            } except ValueError as e {
                raise ValueError(f"[service '{svc_name}'] {e}") from e;
            }
            return {
                "mode": ScalingMode.HTTP_ACTIVATION,
                "scale_target_name": scale_target,
                "service_name": service_name,
                "autoscaler": {},
                "http_activation": http
            };
        }
        metric: dict[str, any] | None = self._get_autoscaler_config(svc_name);
        if metric is not None {
            return {
                "mode": ScalingMode.METRIC,
                "scale_target_name": scale_target,
                "service_name": service_name,
                "autoscaler": metric,
                "http_activation": {}
            };
        }
        return {
            "mode": ScalingMode.NONE,
            "scale_target_name": scale_target,
            "service_name": service_name,
            "autoscaler": {},
            "http_activation": {}
        };
    }

    def _canonical_rules_fingerprint(rules: list[dict[str, any]]) -> str {
        """A rules fingerprint that ignores list ordering, so two services
        with the same match criteria collide in _validate_http_activation_rules
        even when `hosts`/`paths`/`headers`, or the rules themselves, are
        written in a different order -- fields within a rule are AND'd and
        separate rules are OR'd, so reordering never changes what a rule set
        actually matches.
        """;
        import json;
        canonical_rules = [];
        for rule in rules {
            headers = [
                (str(h.get("name", "")), str(h.get("value", "")))
                for h in rule.get("headers", [])
            ];
            canonical_rules.append(
                {
                    "hosts": sorted(str(h) for h in rule.get("hosts", [])),
                    "paths": sorted(str(p) for p in rule.get("paths", [])),
                    "headers": sorted(headers)
                }
            );
        }
        canonical_rules.sort(key=lambda (r) { json.dumps(r, sort_keys=True); });
        return json.dumps(canonical_rules, sort_keys=True);
    }

    def _validate_http_activation_rules(scaling: dict[str, dict[str, any]]) {
        """Two services sharing the top-level http_activation default with no
        per-service override resolve to identical routing rules; the interceptor
        then has no way to tell which target a matching request belongs to.
        """;
        by_rules: dict[str, list[str]] = {};
        for (svc_name, plan) in scaling.items() {
            if plan.get("mode") != ScalingMode.HTTP_ACTIVATION {
                continue;
            }
            rules = plan.get("http_activation", {}).get("rules", []);
            if not rules {
                continue;
            }
            fingerprint = self._canonical_rules_fingerprint(rules);
            by_rules.setdefault(fingerprint, []).append(svc_name);
        }
        for svc_names in by_rules.values() {
            if len(svc_names) > 1 {
                names = ", ".join(sorted(svc_names));
                raise ValueError(
                    f"[http_activation] {names} resolve to identical routing "
                    f"rules, most likely all inheriting "
                    f"[scale.kubernetes.http_activation]'s rules unchanged. The "
                    f"KEDA HTTP Add-on interceptor can't tell which target a "
                    f"matching request belongs to when two InterceptorRoutes "
                    f"share the same match criteria. Set a distinct "
                    f"[services.NAME.http_activation.rules] for at least all "
                    f"but one of these services."
                );
            }
        }
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
        behavior = hpa.get("behavior", {});
        if not isinstance(behavior, dict) {
            if self.logger {
                self.logger.warning(
                    f"Ignoring malformed hpa.behavior for '{svc_name}': expected "
                    f"a table, got {type(behavior).__name__}"
                );
            }
            behavior = {};
        }
        cfg = self.k8s_config;
        return {
            "min": int(hpa.get("min", cfg.min_replicas)),
            "max": int(hpa.get("max", cfg.max_replicas)),
            "cpu_target": int(hpa.get("cpu_target", cfg.cpu_utilization_target)),
            "memory_target": int(
                hpa.get("memory_target", cfg.memory_utilization_target)
            ),
            "has_memory_request": bool(
                self._resolved_memory_request(svc, svc_name == GATEWAY_NAME)
            ),
            "triggers": raw_triggers,
            "behavior": dict(behavior)
        };
    }

    def _get_http_activation_config(svc_name: str) -> dict[str, any] | None {
        svc: dict[str, any] = self._service_config(svc_name);
        per_service: dict[str, any] = svc.get("http_activation", {});
        merged: dict[str, any] = dict(self.k8s_config.http_activation);
        merged.update(per_service);
        if not merged.get("enabled", False) {
            return None;
        }
        return merged;
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

    def _replica_floor(svc_name: str) -> int {
        svc_cfg = self._service_config(svc_name);
        hpa: dict[str, any] = dict(svc_cfg.get("hpa", {}));
        if hpa.get("enabled", True) {
            return int(hpa.get("min", 1));
        }
        return int(svc_cfg.get("replicas", 1));
    }

    def _build_pdb_manifest(
        svc_name: str, mode: (ScalingMode | None) = None
    ) -> dict[str, any] | None {
        cfg: dict[str, any] = self._service_config(svc_name).get("pdb", {});
        if not cfg.get("enabled", True) {
            return None;
        }
        if mode == ScalingMode.HTTP_ACTIVATION {
            if self.logger and cfg {
                self.logger.warn(
                    f"No PodDisruptionBudget emitted for '{svc_name}': it is "
                    f"HTTP-activated and legitimately scales to zero replicas, "
                    f"so a floor-based budget (pdb.max_unavailable / "
                    f"min_available) doesn't apply. Disable it explicitly with "
                    f"pdb.enabled = false to silence this warning."
                );
            }
            return None;
        }
        floor = self._replica_floor(svc_name);
        raw_min = cfg.get("min_available", None);
        spec = pdb_spec(
            floor,
            int(cfg.get("max_unavailable", 1)),
            None if raw_min is None else int(raw_min)
        );
        if spec is None {
            if self.logger and cfg {
                self.logger.warn(
                    f"No PodDisruptionBudget emitted for '{svc_name}': "
                    f"max_unavailable={int(cfg.get('max_unavailable', 1))} at a "
                    f"replica floor of {floor} would permit evicting every "
                    f"replica, so the budget would protect nothing. Raise "
                    f"hpa.min, or set pdb.min_available to refuse voluntary "
                    f"disruption instead."
                );
            }
            return None;
        }
        k8s_name = k8s_safe_name(svc_name);
        spec["selector"] = {"matchLabels": {"app": k8s_name}};
        return {
            "apiVersion": "policy/v1",
            "kind": "PodDisruptionBudget",
            "metadata": {
                "name": f"{k8s_name}-pdb",
                "namespace": self.k8s_config.namespace,
                "labels": {"app": k8s_name, "managed": "jac-scale"}
            },
            "spec": spec
        };
    }

    def _pod_entrypoint -> dict[str, any] {
        import from jaclang.scale.injector.bundle { APP_MOUNT_PATH }
        import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
            build_service_apt_prefix
        }
        apt_prefix = build_service_apt_prefix(self.k8s_config);
        return {
            "command": ["bash", "-c"],
            "args": [
                "set -euo pipefail; "
                f"cd {APP_MOUNT_PATH}; "
                f"{apt_prefix}"
                'if [ "$JAC_SV_NAME" = "__gateway__" ]; then '
                "  exec jac scale gateway; "
                "else "
                '  SV_FILE="${JAC_SV_FILE:-}"; '
                '  if [ -z "$SV_FILE" ]; then '
                '    echo "jac-scale boot: JAC_SV_FILE is not set on this pod ($JAC_SV_NAME); the deploy bakes it into every service pod, so check for an edited manifest or an overlay that dropped it." >&2; '
                "    exit 1; "
                "  fi; "
                '  if [ ! -f "$SV_FILE" ]; then '
                '    echo "jac-scale boot: app $JAC_SV_NAME resolves to $SV_FILE, which the shipped bundle does not contain; check [apps] in jac.toml and re-deploy." >&2; '
                "    exit 1; "
                "  fi; "
                '  exec jac run --serve "$SV_FILE"; '
                "fi"
            ]
        };
    }

    def _build_pod_spec(svc_name: str, image: str) -> dict[str, any] {
        drain_t: int = self._drain_timeout();
        svc_cfg = self._service_config(svc_name);
        `entry = self._pod_entrypoint();

        resolved_image: str = self.k8s_config.python_image;
        env_list = self._build_env(svc_name, svc_cfg);

        container: dict[str, any] = {
            "name": k8s_safe_name(svc_name),
            "image": resolved_image,
            "command": `entry["command"],
            "args": `entry["args"],
            "env": env_list,
            "ports": [{"containerPort": self.k8s_config.container_port}],
            "readinessProbe": self._build_readiness_probe(),
            "livenessProbe": self._build_liveness_probe(),
            "lifecycle": {"preStop": self._build_prestop_hook()}
        };
        import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
            image_pull_policy
        }
        pull_policy = image_pull_policy(resolved_image);
        if pull_policy {
            container["imagePullPolicy"] = pull_policy;
        }

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

        container["envFrom"] = [{"secretRef": {"name": self._user_secret_name()}}];
        spec: dict[str, any] = {
            "containers": [container],
            "terminationGracePeriodSeconds": drain_t
                + _EXIT_CUSHION_S
                + self._alb_deregistration_cushion()
        };
        sa_name = self._service_account_name();
        if sa_name {
            spec["serviceAccountName"] = sa_name;
        }
        spec["volumes"] = list(shared_vols);
        spec["initContainers"] = list(self.deploy_context.init_containers);
        if shared_mounts {
            import from jaclang.scale.injector.pvc_injector {
                VOLUME_PERMS_NAME,
                build_volume_perms_init_container,
                runtime_pod_security_context
            }
            spec["initContainers"].insert(
                0,
                build_volume_perms_init_container(
                    VOLUME_PERMS_NAME, resolved_image, shared_mounts
                )
            );
            spec["securityContext"] = runtime_pod_security_context();
        }

        import from jaclang.scale.injector.binary_injector { BinaryInjector }
        injector: BinaryInjector = BinaryInjector(
            storage_class=self.k8s_config.bundle_storage_class
        );
        injector._toolchain_object_key = self._toolchain_object_key;
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
                self.k8s_config, self.k8s_config.python_image
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
