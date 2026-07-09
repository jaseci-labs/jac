import os;
import platform as platform_mod;
import from pathlib { Path }
import from typing { Any, Optional, cast }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jaclang.runtimelib.client.mobile_dev_host {
    resolve_mobile_dev_host,
    resolve_mobile_server_port,
    resolve_mobile_vite_port
}
import from jaclang.runtimelib.client.mobile_setup_env {
    mobile_setup_platform_env_restore,
    mobile_setup_platform_env_swap
}
import from jaclang.runtimelib.client.targets.mobile.bundle {
    _build_android,
    _build_ios
}
import from jaclang.runtimelib.client.targets.mobile.common {
    DEFAULT_APP_ID,
    DEFAULT_APP_NAME,
    MOBILE_SETUP_MODES,
    _ensure_android_cleartext_for_lan_dev,
    _normalize_mobile_platform,
    _run_cap_cmd
}
import from jaclang.runtimelib.client.targets.mobile.config {
    _add_mobile_config,
    _load_mobile_config,
    _resolve_mobile_setup_mode
}
import from jaclang.runtimelib.client.targets.mobile.deps {
    _check_and_report_dependencies,
    _require_macos_for_ios,
    _try_check_mobile_dependencies
}
import from jaclang.runtimelib.client.targets.mobile.dev {
    _assert_mobile_port_available,
    _describe_cap_run_completion,
    _get_api_base_url_str,
    _inject_capacitor_dev_url,
    _mobile_ensure_watchdog,
    _mobile_read_dev_env,
    _mobile_setup_android_port_reverse,
    _mobile_start_backend_server,
    _restore_capacitor_config,
    _run_cap_run_live_reload,
    _warn_mobile_dev_api_url
}
import from jaclang.runtimelib.client.targets.mobile.scaffold {
    _ensure_capacitor_config,
    _ensure_capacitor_deps,
    _ensure_android_platform,
    _ensure_ios_platform,
    _ensure_placeholder_index
}
import from jaclang.runtimelib.client.targets.client_dev_common {
    _ClientHmrHandler,
    prepare_vite_dev_compilation,
    install_dev_signal_handlers,
    stop_dev_watcher,
    terminate_dev_processes
}

impl MobileTarget.setup(project_dir: Path) -> None {
    android_dir = project_dir / "android";
    ios_dir = project_dir / "ios";
    is_macos = platform_mod.system() == "Darwin";
    (setup_mode, explicit_setup_mode) = _resolve_mobile_setup_mode(
        project_dir, is_macos
    );
    platforms: list[str] = [];
    if setup_mode == "all" {
        if not is_macos and explicit_setup_mode {
            console.warning(
                "  iOS scaffold in --platform all requires macOS; using Android."
            );
        }
        platforms = ["android", "ios"] if is_macos else ["android"];
    } elif setup_mode == "android" {
        platforms = ["android"];
    } elif setup_mode == "ios" {
        if is_macos {
            platforms = ["ios"];
        } elif explicit_setup_mode {
            raise RuntimeError(
                "iOS scaffold setup requires macOS. "
                "Use --platform android on Linux/Windows."
            );
        } else {
            console.warning(
                "  default_platform is ios but host is not macOS; using Android scaffold."
            );
            platforms = ["android"];
        }
    } else {
        raise ValueError(
            f"Unsupported setup platform '{setup_mode}'. "
            f"Supported: {', '.join(MOBILE_SETUP_MODES)}"
        );
    }
    needs_android = "android" in platforms;
    needs_ios = "ios" in platforms;

    if (not needs_android or android_dir.exists())
    and (not needs_ios or ios_dir.exists()) {
        return;
    }

    console.print("\n📱 Setting up mobile target (Capacitor)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");

    try {
        checked: set[str] = set();
        for plat in platforms {
            if plat not in checked {
                _check_and_report_dependencies(plat);
                checked.add(plat);
            }
        }
    } except Exception as e {
        console.warning(f"  Dependency check encountered an issue: {e}");
        console.print(
            "  Setup will continue, but some dependencies may be missing.",
            style="muted"
        );
    }

    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    web_dist_dir.mkdir(parents=True, exist_ok=True);

    _ensure_capacitor_deps(project_dir);
    _ensure_capacitor_config(project_dir, web_dist_dir);

    if needs_android {
        _ensure_android_platform(project_dir, web_dist_dir);
    }
    if needs_ios {
        _ensure_ios_platform(project_dir, web_dist_dir);
    }

    mobile_cfg = _load_mobile_config(project_dir);
    app_name = mobile_cfg.get("app_name", DEFAULT_APP_NAME);
    app_id = mobile_cfg.get("app_id", DEFAULT_APP_ID);
    try {
        _add_mobile_config(project_dir, app_name, app_id);
    } except Exception as e {
        console.warning(f"  Failed to add [client.mobile] to jac.toml: {e}");
    }

    setup_label = ", ".join(platforms);
    console.success(f"Mobile target setup complete ({setup_label}).");
    console.print("\nNext steps:", style="bold");
    if needs_android {
        console.print("  Android:");
        console.print(
            "    Dev:   jac start main.jac --client mobile --dev", style="muted"
        );
        console.print("    Build: jac build --client mobile --platform android");
    }
    if needs_ios {
        console.print("  iOS:");
        console.print(
            "    Dev:   jac start main.jac --client mobile --dev --platform ios",
            style="muted"
        );
        console.print("    Build: jac build --client mobile --platform ios");
    }
}

impl MobileTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
    selected_platform = _normalize_mobile_platform(platform);
    mobile_cfg = _load_mobile_config(project_dir);

    console.print(
        f"\n📱 Building mobile app (Capacitor {selected_platform.capitalize()})",
        style="bold"
    );

    _try_check_mobile_dependencies(selected_platform);
    _require_macos_for_ios(selected_platform);

    prev_setup_platform = mobile_setup_platform_env_swap(selected_platform);
    try {
        self.setup(project_dir);
    } finally {
        mobile_setup_platform_env_restore(prev_setup_platform);
    }

    console.print("  Step 1: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);

    console.print(
        f"  Step 2: Syncing with Capacitor ({selected_platform})...", style="muted"
    );
    _run_cap_cmd(
        project_dir, ["sync", selected_platform], f"cap sync {selected_platform}"
    );
    console.print("  ✔ Capacitor sync complete", style="success");

    if selected_platform == "android" {
        artifact = _build_android(project_dir, mobile_cfg);
    } else {
        artifact = _build_ios(project_dir, mobile_cfg);
    }

    console.success(f"Mobile build complete: {artifact}");
    return artifact;
}

impl MobileTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    hot_watcher: any = None;
    (host_override, plat_mode) = _mobile_read_dev_env();
    vite_port = resolve_mobile_vite_port(project_dir, port);
    effective_api = api_port if api_port > 0 else port + 1;
    mobile_cfg = _load_mobile_config(project_dir);
    if plat_mode and plat_mode != "auto" {
        plat = _normalize_mobile_platform(plat_mode);
    } else {
        plat = _normalize_mobile_platform(
            mobile_cfg.get("default_platform", "android")
        );
    }

    console.print(
        f"\nMobile dev (Capacitor + Vite HMR) - {plat.capitalize()}", style="bold"
    );
    _try_check_mobile_dependencies(plat);
    _require_macos_for_ios(plat);
    _warn_mobile_dev_api_url(project_dir);
    prev_setup_platform = mobile_setup_platform_env_swap(plat);
    try {
        self.setup(project_dir);
    } finally {
        mobile_setup_platform_env_restore(prev_setup_platform);
    }

    visible_host = cast(str, resolve_mobile_dev_host(plat, host_override));

    if plat == "android" {
        _ensure_android_cleartext_for_lan_dev(project_dir);
    }

    (bundler, compiler) = prepare_vite_dev_compilation(project_dir, entry_file);

    toml_base_url = _get_api_base_url_str(project_dir);
    server_port = cast(int, resolve_mobile_server_port(toml_base_url, effective_api));

    _assert_mobile_port_available(vite_port, "Vite");
    if server_port != vite_port {
        _assert_mobile_port_available(server_port, "API");
    }

    if plat == "android" {
        _mobile_setup_android_port_reverse(vite_port, server_port);
    }

    cast(Any, bundler).create_vite_config(
        entry_file,
        api_base_url_override="",
        is_dev=True,
        api_port=server_port,
        for_mobile_dev=True,
        mobile_hmr_host=visible_host,
        mobile_hmr_port=vite_port
    );

    console.print(f"  Starting Vite dev server (port {vite_port})…", style="muted");
    vite_process = bundler.start_dev_server(
        port=vite_port, suppress_initial_output=True, host=visible_host
    );
    if not vite_process {
        raise RuntimeError("Failed to start Vite dev server");
    }

    if _mobile_ensure_watchdog() {
        import from jaclang.runtimelib.watcher { JacFileWatcher }

        hmr_handler = _ClientHmrHandler(
            compiler=compiler, entry_file=entry_file, project_dir=project_dir
        );
        hot_watcher = JacFileWatcher(watch_paths=[str(project_dir.resolve())]);
        hot_watcher.add_callback(hmr_handler.on_event);
        hot_watcher.start();
    }

    server_process = _mobile_start_backend_server(entry_file, project_dir, server_port);

    vite_p = vite_process;
    srv_p = server_process;

    def cleanup_servers {
        console.print("\n  Stopping Vite and API server…", style="muted");
        stop_dev_watcher(hot_watcher);
        terminate_dev_processes([vite_p, srv_p]);
        console.print("  ✔ Stopped", style="success");
    }

    install_dev_signal_handlers();

    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);
    _ensure_placeholder_index(web_dist_dir);

    dev_url = f"http://{visible_host}:{vite_port}";
    original_cap_config = _inject_capacitor_dev_url(project_dir, dev_url);

    try {
        _run_cap_cmd(project_dir, ["sync", plat], f"cap sync {plat}");
        rc = _run_cap_run_live_reload(project_dir, plat, visible_host, vite_port);
        outcome = _describe_cap_run_completion(rc, dev_url);
        msg_style = "bold green" if outcome["ok"] else "bold yellow";
        for i in range(len(outcome["messages"])) {
            line = outcome["messages"][i];
            style = msg_style if i == 0 else "muted";
            console.print(f"\n  {line}" if i == 0 else f"  {line}", style=style);
        }
        console.print("");
        import from time { sleep }
        while True {
            sleep(1);
        }
    } except KeyboardInterrupt {
        console.print("\n  Interrupted.", style="muted");
    } finally {
        _restore_capacitor_config(project_dir, original_cap_config);
        cleanup_servers();
    }
}

impl MobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

    if api_port != 8000 {
        console.print(
            f"  Note: --port {api_port} applies to `jac start` flows; "
            "`cap run` uses the baked web bundle only.",
            style="muted"
        );
    }
    plat_mode = os.environ.get("JAC_MOBILE_PLATFORM", "auto");
    mobile_cfg = _load_mobile_config(project_dir);
    if plat_mode and plat_mode != "auto" {
        plat = _normalize_mobile_platform(plat_mode);
    } else {
        plat = mobile_cfg.get("default_platform", "android");
        plat = _normalize_mobile_platform(plat);
    }

    console.print(
        f"\n📱 Starting mobile app (Capacitor {plat.capitalize()})", style="bold"
    );
    _try_check_mobile_dependencies(plat);
    _require_macos_for_ios(plat);
    prev_setup_platform = mobile_setup_platform_env_swap(plat);
    try {
        self.setup(project_dir);
    } finally {
        mobile_setup_platform_env_restore(prev_setup_platform);
    }
    console.print("  Building web bundle…", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle: {web_bundle_path}", style="success");

    bundler = ViteBundler(project_dir=project_dir);
    web_dist_dir = Path(bundler.output_dir).resolve();
    _ensure_capacitor_config(project_dir, web_dist_dir);

    _run_cap_cmd(project_dir, ["sync", plat], f"cap sync {plat}");
    _run_cap_cmd(project_dir, ["run", plat], f"cap run {plat}");
}
