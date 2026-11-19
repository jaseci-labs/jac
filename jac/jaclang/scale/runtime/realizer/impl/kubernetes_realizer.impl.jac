impl pinned_deploy_argv(
    jac_bin: str,
    filename: str,
    target: str,
    enable_tls: bool = False,
    from_build: str = "",
    plan_out: str = ""
) -> list[str] {
    argv = [jac_bin, "scale", "deploy", filename, "--target", target];
    if from_build {
        argv.extend(["--from-build", from_build]);
    }
    if plan_out {
        argv.extend(["--plan-out", plan_out]);
    }
    if enable_tls {
        argv.append("--enable-tls");
    }
    return argv;
}

impl pinned_build_argv(
    jac_bin: str, filename: str, target: str, out_dir: str, arch: str
) -> list[str] {
    return [
        jac_bin,
        "scale",
        "build",
        filename,
        "--target",
        target,
        "--out",
        out_dir,
        "--arch",
        arch
    ];
}

impl KubernetesRealizer._pinned_jac(filename: str) -> str {
    if os.environ.get(DELEGATED_ENV) == "1" {
        return "";
    }
    return host_toolchain_path(os.path.dirname(filename) or ".");
}

impl KubernetesRealizer._run_pinned(pinned: str, argv: list[str]) -> int {
    import subprocess;

    console.print(
        "Deploying with the jac release this app pins, not the one "
        f"running this deploy ({pinned})."
    );
    env = release_binary_env();
    env[DELEGATED_ENV] = "1";
    code = subprocess.run(argv, env=env).returncode;
    if code != 0 {
        console.error(
            f"The deploy ran on the pinned jac ({pinned}) and exited {code}.",
            emoji=False
        );
    }
    return code;
}

impl KubernetesRealizer._deploy_on_pinned_jac(
    filename: str,
    target: str,
    enable_tls: bool,
    dry_run: bool,
    from_build: str = "",
    plan_out: str = ""
) -> (int | None) {
    if dry_run {
        return None;
    }
    pinned = self._pinned_jac(filename);
    if not pinned {
        return None;
    }
    return self._run_pinned(
        pinned,
        pinned_deploy_argv(pinned, filename, target, enable_tls, from_build, plan_out)
    );
}

impl KubernetesRealizer._resolve_fleet(code_folder: str) -> (FleetSpec | None) {
    if self.fleet is not None {
        return self.fleet;
    }

    cfg = get_config_for_dir(code_folder);
    if cfg is None or not cfg.is_workspace {
        return None;
    }
    root_dir = str(cfg.project_root) if cfg.project_root else code_folder;
    return fleet_from_config(
        cfg, self.served_app, project_root=root_dir, relative_to=code_folder
    );
}

impl KubernetesRealizer._print_fleet_banner(fleet: FleetSpec | None) -> None {
    if fleet is None or not fleet.service_names() {
        console.print(
            "No service apps in this workspace; deploying the app as a "
            "single pod behind a gateway.",
            style="cyan"
        );
        return;
    }
    count = len(fleet.service_names());
    plural = "s" if count != 1 else "";
    console.print(
        f"Deploying {count} service app{plural} plus '{fleet.root_app}' "
        "behind a gateway.",
        style="cyan"
    );
    for line in format_fleet_lines(fleet) {
        console.print(f"  {line}", style="muted");
    }
}

impl KubernetesRealizer._deployed_tree(filename: str, target: str) -> tuple[str, str] {
    if not os.path.exists(filename) {
        raise FileNotFoundError(f"File not found: '{filename}'");
    }
    (code_folder, entry_file) = deployed_tree(filename);
    if target in _K8S_TARGETS {
        self.fleet = self._resolve_fleet(code_folder);
        self._print_fleet_banner(self.fleet);
    }
    return (code_folder, entry_file);
}

impl KubernetesRealizer._open_target(
    target: str, dry_run: bool
) -> tuple[any, dict[str, any], any] {
    scale_config = get_scale_config();
    logger = UtilityFactory.create_logger('standard');
    if target in _K8S_TARGETS {
        target_config = scale_config.get_kubernetes_config();
    } else {
        target_config = scale_config.get_section(target);
    }
    deployment_target = DeploymentTargetFactory.create(
        target, target_config, logger, dry_run=dry_run
    );
    if isinstance(deployment_target, KubernetesTarget) {
        deployment_target.fleet = self.fleet;
        deployment_target.gateway_config = self.gateway_config;
    }
    return (deployment_target, target_config, scale_config);
}

impl KubernetesRealizer._app_config(
    deployment_target: any, scale_config: any, code_folder: str, entry_file: str
) -> AppConfig {
    if isinstance(deployment_target, KubernetesTargetBase) {
        deployment_target.secrets = scale_config.get_secrets_config();
    }
    return AppConfig(
        code_folder=pathlib.Path(os.path.relpath(code_folder)).as_posix(),
        file_name=entry_file,
        served_app=self.served_app
    );
}

impl KubernetesRealizer.build(
    filename: str, target: str = "kubernetes", out_dir: str = "", arch: str = ""
) -> int {
    if target not in _K8S_TARGETS {
        console.error(
            f"jac scale build builds for the kubernetes targets, not '{target}'.",
            emoji=False
        );
        return 2;
    }
    named = arch or os.environ.get("JAC_NODE_ARCH", "");
    pod_arch = release_arch(named);
    if pod_arch not in _POD_ARCHS {
        console.error(
            "jac scale build never asks the cluster for its node architecture; "
            "name it with --arch amd64|arm64 or JAC_NODE_ARCH"
                + (f" ('{named}' is neither)." if named else "."),
            emoji=False
        );
        return 2;
    }
    if not out_dir {
        console.error(
            "jac scale build needs --out <dir> to write bundle.jab and build.json into.",
            emoji=False
        );
        return 2;
    }
    out_dir = os.path.abspath(out_dir);
    reset_deploy_version_cache();
    (code_folder, entry_file) = self._deployed_tree(filename, target);
    pinned = self._pinned_jac(filename);
    if pinned {
        return self._run_pinned(
            pinned, pinned_build_argv(pinned, filename, target, out_dir, pod_arch)
        );
    }
    load_project_env(code_folder);
    (deployment_target, _, scale_config) = self._open_target(target, False);
    app_config = self._app_config(
        deployment_target, scale_config, code_folder, entry_file
    );
    deployment_target.pod_arch = pod_arch;
    try {
        record = deployment_target.build(app_config, out_dir);
    } except Exception as e {
        console.error(f"Build failed: {e}", emoji=False);
        return 1;
    }
    console.print(
        f"Built {record['bundle_object_key']} for {pod_arch} nodes into {out_dir}. "
        f"Apply it with `jac scale deploy {filename} --from-build {out_dir}`."
    );
    return 0;
}

impl KubernetesRealizer.realize(
    filename: str,
    target: str = "kubernetes",
    enable_tls: bool = False,
    dry_run: bool = False,
    show_yaml: bool = False,
    from_build: str = "",
    plan_out: str = ""
) -> int {
    reset_deploy_version_cache();
    if from_build and target not in _K8S_TARGETS {
        console.error(
            f"--from-build deploys to the kubernetes targets, not '{target}'.",
            emoji=False
        );
        return 2;
    }
    from_build = os.path.abspath(from_build) if from_build else "";
    plan_out = os.path.abspath(plan_out) if plan_out else "";
    (code_folder, entry_file) = self._deployed_tree(filename, target);
    delegated = self._deploy_on_pinned_jac(
        filename, target, enable_tls, dry_run, from_build, plan_out
    );
    if delegated is not None {
        return delegated;
    }
    load_project_env(code_folder);
    if dry_run {
        import from jaclang.scale.injector.binary { deploy_generation_refusal }
        refusal = deploy_generation_refusal(code_folder, offline=True);
        if refusal {
            console.error(refusal, emoji=False);
            return 2;
        }
    }
    (deployment_target, target_config, scale_config) = self._open_target(
        target, dry_run
    );
    if isinstance(deployment_target, KubernetesTarget) {
        deployment_target.from_build = from_build;
        deployment_target.plan_out = plan_out;
    }
    if enable_tls and dry_run {
        console.warning(
            "--dry-run ignores --enable-tls: issuing certificates would "
            "modify the cluster. Re-run without --dry-run to enable TLS."
        );
    } elif enable_tls {
        if not target_config.get('domain', '') {
            raise ValueError(
                "No domain configured. Set 'domain' under [scale.kubernetes] in jac.toml before running --enable-tls."
            );
        }
        if not target_config.get('cert_manager_email', '') {
            raise ValueError(
                "No cert_manager_email configured. Set 'cert_manager_email' under [scale.kubernetes] in jac.toml before running --enable-tls."
            );
        }
        app_name = target_config.get('app_name', 'jaseci');
        if not isinstance(deployment_target, KubernetesTargetBase) {
            raise ValueError(
                f"--enable-tls is only supported on kubernetes targets, not '{target}'."
            );
        }
        deployment_target.enable_tls(app_name);
        return 0;
    }

    app_config = self._app_config(
        deployment_target, scale_config, code_folder, entry_file
    );
    console.warning(
        "Copying local source into the cluster via PVC and installing "
        "jac at pod startup. Keep secrets in [scale.secrets] "
        "(synced as a K8s Secret) or in .env, never inline in source."
    );
    console.print("Preparing deployment...");

    if dry_run {
        try {
            import from jaclang.scale.runtime.cli.plan { print_plan }
            import from jaclang.scale.runtime.cli.diagnostics { has_errors }
            (bundle, diagnostics) = print_plan(
                deployment_target, app_config, show_yaml=show_yaml
            );
            if isinstance(deployment_target, KubernetesTarget) {
                deployment_target.write_plan(bundle);
            }
            exit_code = 2 if has_errors(diagnostics) else 0;
        } except Exception as e {
            console.error(f"--dry-run failed: {e}", emoji=False);
            return 1;
        }
        return exit_code;
    }

    try {
        result = deployment_target.deploy(app_config);
    } except Exception as e {
        console.error(f"Deployment failed: {e}", emoji=False);
        return 1;
    }
    if not result.success {
        console.error(
            f"Deployment failed: {result.message or 'unknown error'}", emoji=False
        );
        return 1;
    }
    if result.service_url {
        console.print(
            f"Deployment complete! Service available at: {result.service_url}"
        );
    } elif result.access_hint {
        console.print(f"Deployment complete! {result.access_hint}");
    }
    return 0;
}
