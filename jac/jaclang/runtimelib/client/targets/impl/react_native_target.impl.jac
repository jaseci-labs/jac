import os;
import shutil;
import subprocess;
import platform as platform_mod;
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.runtime { JacRuntime as Jac }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jaclang.runtimelib.client.targets.react_native.common {
    DEFAULT_APP_ID,
    DEFAULT_APP_NAME,
    DEFAULT_APP_SLUG,
    resolve_rn_project_dir
}
import from jaclang.runtimelib.client.targets.react_native.scaffold {
    ensure_native_deps_installed,
    write_expo_scaffold
}
import from jaclang.runtimelib.client.targets.react_native.build {
    lint_native_incompatible_usage,
    lint_unmapped_tags,
    read_user_js_sources,
    run_expo_prebuild,
    run_gradle_assemble,
    run_eas_local_build,
    run_eas_update_opt_in,
    run_xcodebuild_ios,
    stage_native_image_assets,
    entry_module_for,
    stage_compiled_entry,
    strip_css_imports,
    write_native_entry
}
import from jaclang.runtimelib.client.config_loader { JacClientConfig }
import from jaclang.runtimelib.client.targets.react_native.config {
    _resolve_rn_android_builder,
    _resolve_rn_eas_profile,
    _resolve_rn_eas_update_branch,
    _resolve_rn_eas_update_enabled,
    _resolve_rn_eas_update_message,
    _resolve_rn_ios_builder,
    _resolve_rn_release
}
import from jaclang.runtimelib.client.targets.react_native.dev {
    inject_dev_api_base_url,
    resolve_metro_port,
    restore_app_json,
    rn_hmr_on_jac_changed,
    run_expo_start,
    setup_android_port_reverse,
    JAC_RN_DEV_HOST_ENV
}
import from jaclang.runtimelib.client.mobile_dev_host { detect_lan_ipv4 }
import from jaclang.runtimelib.client.targets.client_dev_common {
    ensure_watchdog_common,
    install_dev_signal_handlers,
    resolve_port_or_next_available,
    start_backend_server_common,
    stop_dev_watcher,
    terminate_dev_processes
}

impl ReactNativeTarget.setup(project_dir: Path) -> None {
    import from jaclang.runtimelib.client.targets.react_native.common {
        normalize_rn_platform
    }

    rn_dir = resolve_rn_project_dir(project_dir);
    console.print(
        f"\n📱 Setting up React Native target (Expo) at {rn_dir}", style="bold"
    );

    wrote_new = write_expo_scaffold(
        rn_dir,
        project_dir,
        app_name=DEFAULT_APP_NAME,
        app_slug=DEFAULT_APP_SLUG,
        app_id=DEFAULT_APP_ID
    );

    if wrote_new {
        try {
            ensure_native_deps_installed(rn_dir);
        } except Exception as e {
            console.warning(
                f"  npm install failed: {e}\n"
                "  Run `npm install` (or `bun install`) inside "
                f"{rn_dir} manually before running `jac build`."
            );
        }
    } else {
        console.print(
            "  ✔ Scaffold already current; skipping npm install", style="muted"
        );
    }

    console.success("React Native target setup complete.");
    console.print("\nNext steps:", style="bold");
    console.print(
        "  Build (Android): jac build --client react-native --platform android",
        style="muted"
    );
    console.print(
        "  Build (iOS):     jac build --client react-native --platform ios",
        style="muted"
    );
    console.print(
        "  Dev:             jac start --client react-native --dev", style="muted"
    );
    console.print(
        f"  EAS Build:       cd {rn_dir} && npx eas build --platform android",
        style="muted"
    );
    console.print(
        f"  EAS Update:      cd {rn_dir} && npx eas update --branch preview",
        style="muted"
    );
}

impl ReactNativeTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    plat = (platform or "android").lower();
    if plat not in ["android", "ios"] {
        raise ValueError(
            f"Unsupported platform '{plat}' for --client react-native. "
            "Use --platform android or --platform ios."
        );
    }
    client_cfg = JacClientConfig(project_dir);
    rn_cfg = client_cfg.get_react_native_config();
    release = _resolve_rn_release(rn_cfg);
    build_label = "release" if release else "debug";
    ios_builder = _resolve_rn_ios_builder(rn_cfg);
    rn_dir = resolve_rn_project_dir(project_dir, client_cfg);

    console.print(
        f"\n📱 Building React Native app ({plat}, {build_label})", style="bold"
    );

    if plat == "ios" and platform_mod.system() != "Darwin" {
        if ios_builder == "xcodebuild" {
            raise RuntimeError(
                "iOS native build requested on non-macOS host.\n"
                "The default iOS builder is xcodebuild, which requires macOS + Xcode.\n"
                "Use one of:\n"
                "  1) Run `jac build --client react-native --platform ios` on macOS\n"
                "  2) Use EAS Build cloud from any OS:\n"
                "     npx eas build --platform ios --profile production --non-interactive\n"
                "  3) Set [client.react_native].ios_builder = \"eas\" and run "
                f"the same EAS command from {rn_dir}"
            );
        }
        raise RuntimeError(
            "iOS EAS local builds require macOS (Xcode toolchain).\n"
            "On Linux/Windows, use EAS Build cloud instead:\n"
            "  npx eas build --platform ios --profile production --non-interactive\n"
            f"Run that command inside {rn_dir}."
        );
    }

    if not (rn_dir / "package.json").exists() {
        console.print("  Scaffold not found — running setup first...", style="muted");
        self.setup(project_dir);
    }

    (_, compiled_dir) = self._compile_native_jac_modules(entry_file);

    js_sources = read_user_js_sources(compiled_dir);
    lint_unmapped_tags(compiled_dir, sources=js_sources);
    lint_native_incompatible_usage(compiled_dir, sources=js_sources);
    strip_css_imports(compiled_dir);

    entry_module: str = entry_module_for(entry_file, project_dir);
    stage_compiled_entry(compiled_dir, rn_dir, entry_module);
    stage_native_image_assets(rn_dir / "jac-src", rn_dir);
    write_native_entry(rn_dir);

    console.print(
        f"  Step 2: Running expo prebuild ({plat.capitalize()})...", style="muted"
    );
    run_expo_prebuild(rn_dir, plat);

    artifact: Path;
    if plat == "android" {
        android_builder = _resolve_rn_android_builder(rn_cfg);
        if android_builder == "eas" {
            eas_profile = _resolve_rn_eas_profile(rn_cfg, release);
            console.print(
                f"  Step 3: Building Android with EAS local (profile={eas_profile})...",
                style="muted"
            );
            artifact = run_eas_local_build(
                rn_dir, platform="android", profile=eas_profile, release=release
            );
        } else {
            console.print("  Step 3: Building Android with Gradle...", style="muted");
            artifact = run_gradle_assemble(rn_dir, release=release);
        }
    } elif ios_builder == "eas" {
        eas_profile = _resolve_rn_eas_profile(rn_cfg, release);
        console.print(
            f"  Step 3: Building iOS with EAS local (profile={eas_profile})...",
            style="muted"
        );
        artifact = run_eas_local_build(
            rn_dir, platform="ios", profile=eas_profile, release=release
        );
    } else {
        console.print("  Step 3: Building iOS with xcodebuild...", style="muted");
        artifact = run_xcodebuild_ios(rn_dir, release=release);
    }

    if _resolve_rn_eas_update_enabled(rn_cfg) {
        update_branch = _resolve_rn_eas_update_branch(rn_cfg, release);
        update_msg = _resolve_rn_eas_update_message(rn_cfg);
        run_eas_update_opt_in(
            rn_dir, platform=plat, branch=update_branch, message=update_msg
        );
    }

    console.success(f"React Native build complete: {artifact}");
    if plat == "android" {
        console.print("\nInstall with: adb install -r " + str(artifact), style="muted");
    } else {
        console.print(
            "\nInstall on a booted simulator with: " "xcrun simctl install booted " + str(
                artifact
            ) + "\n"
            "For signing/provisioning and real-device distribution, follow "
            "Expo iOS build docs:\n"
            "  https://docs.expo.dev/build-reference/ios-builds/",
            style="muted"
        );
    }
    return artifact;
}

impl ReactNativeTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    rn_dir = resolve_rn_project_dir(project_dir);
    if not (rn_dir / "package.json").exists() {
        raise RuntimeError(
            "React Native scaffold not found. Run `jac setup react-native` "
            "before `jac start --client react-native --dev`."
        );
    }

    requested_api = api_port if api_port > 0 else port;
    requested_metro = resolve_metro_port();
    metro_port = resolve_port_or_next_available(requested_metro, "Metro");
    api_eff = resolve_port_or_next_available(
        requested_api, "API", reserved=[metro_port]
    );

    host_override = os.environ.get(JAC_RN_DEV_HOST_ENV, "").strip();
    visible_host: str;
    if host_override {
        visible_host = host_override;
    } else {
        lan = detect_lan_ipv4();
        visible_host = lan or "127.0.0.1";
    }

    console.print(
        f"\nReact Native dev (Expo + Metro Fast Refresh) — host {visible_host}",
        style="bold"
    );

    (jac_compiler, compiled_dir) = self._compile_native_jac_modules(entry_file);
    js_sources = read_user_js_sources(compiled_dir);
    lint_unmapped_tags(compiled_dir, sources=js_sources);
    lint_native_incompatible_usage(compiled_dir, sources=js_sources);
    strip_css_imports(compiled_dir);

    entry_module: str = entry_module_for(entry_file, project_dir);
    stage_compiled_entry(compiled_dir, rn_dir, entry_module);
    stage_native_image_assets(rn_dir / "jac-src", rn_dir);
    write_native_entry(rn_dir);

    dev_api_url = f"http://{visible_host}:{api_eff}";
    original_app_json = inject_dev_api_base_url(rn_dir, dev_api_url);

    setup_android_port_reverse(metro_port, api_eff);

    backend_p: any = None;
    watcher_p: any = None;

    def cleanup {
        console.print("\n  Stopping Metro, backend, and watcher…", style="muted");
        stop_dev_watcher(watcher_p);
        terminate_dev_processes([backend_p]);
        restore_app_json(rn_dir, original_app_json);
        console.print("  ✔ Stopped", style="success");
    }

    install_dev_signal_handlers();

    try {
        console.print(
            f"  Starting Jac API backend on port {api_eff}...", style="muted"
        );
        backend_p = start_backend_server_common(entry_file, project_dir, api_eff);

        if ensure_watchdog_common("the device") {
            import from jaclang.runtimelib.watcher { JacFileWatcher }

            hmr_handler = _RNHmrHandler(
                compiler=jac_compiler,
                entry_file=entry_file,
                project_dir=project_dir,
                rn_dir=rn_dir,
                entry_module=entry_module
            );
            watcher_p = JacFileWatcher(watch_paths=[str(project_dir.resolve())]);
            watcher_p.add_callback(hmr_handler.on_event);
            watcher_p.start();
        }

        console.print(
            f"\n📱 React Native dev ready.\n"
            f"   Metro     : http://{visible_host}:{metro_port}\n"
            f"   API       : {dev_api_url}\n"
            f"   Edit .cl.jac files — Metro will Fast Refresh on save.\n",
            style="bold green"
        );

        rc = run_expo_start(rn_dir, metro_port, clear_cache=True);
        if rc != 0 {
            console.warning(
                f"  expo start exited with code {rc} — see Metro output above."
            );
        }
    } except KeyboardInterrupt {
        console.print("\n  Interrupted.", style="muted");
    } finally {
        cleanup();
    }
}

impl ReactNativeTarget._compile_native_jac_modules(
    entry_file: Path
) -> tuple[(any, Path)] {
    console.print("  Step 1: Compiling Jac modules + native runtime...", style="muted");

    builder = Jac.get_client_bundle_builder();
    if builder is None {
        raise RuntimeError(
            "Client bundle builder is unavailable — the jac-client compiler "
            "stack is required for react-native builds. Ensure "
            "`jaclang.runtimelib.client` is installed and importable."
        );
    }
    vite_compiler = builder._get_compiler();
    jac_compiler = vite_compiler.jac_client_compiler;
    compiled_dir = jac_compiler.compiled_dir;
    if compiled_dir is None {
        raise RuntimeError(
            "JacClientCompiler.compiled_dir is None; project config likely "
            "missing. Run `jac setup react-native` first."
        );
    }
    compiled_dir.mkdir(parents=True, exist_ok=True);
    (_, mod, _) = jac_compiler.jac_compiler.compile_module(entry_file);
    if not mod {
        raise RuntimeError(f"Failed to compile client entry module: {entry_file}");
    }
    jac_compiler.compile(mod, entry_file, target_name="react-native");
    console.print("  ✔ Jac modules compiled with native runtime", style="success");
    return (jac_compiler, compiled_dir);
}

impl ReactNativeTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jaclang.runtimelib.client.targets.react_native.common {
        normalize_rn_platform
    }

    rn_cfg = JacClientConfig(project_dir).get_react_native_config();
    default_plat = str(rn_cfg.get("default_platform", "") or "android").strip().lower();
    plat = normalize_rn_platform(default_plat);

    artifact = self.build(entry_file, project_dir, platform=plat);

    if plat == "ios" {
        _start_ios(artifact, project_dir);
    } else {
        _start_android(artifact, project_dir);
    }
}

impl _RNHmrHandler.on_event(evt: FileChangeEvent) -> None {
    rn_hmr_on_jac_changed(
        evt,
        self.compiler,
        self.entry_file,
        self.project_dir,
        self.rn_dir,
        self.entry_module
    );
}

def _start_android(apk_path: Path, project_dir: Path) -> None {
    import json;
    adb = shutil.which("adb");
    if not adb {
        console.warning(
            "  adb not found on PATH. APK built successfully but "
            "auto-install skipped.\n"
            f"  Install manually: adb install -r {apk_path}"
        );
        return;
    }

    rn_dir = resolve_rn_project_dir(project_dir);
    pkg_name: str | None = None;
    try {
        app_cfg = json.loads((rn_dir / "app.json").read_text(encoding="utf-8"));
        pkg_name = app_cfg["expo"]["android"]["package"];
    } except Exception as e {
        console.warning(
            f"  Failed to read android.package from app.json ({e}); "
            "skipping auto-launch. APK is installed though."
        );
    }

    console.print(
        f"  Installing APK on device: adb install -r {apk_path}", style="muted"
    );
    subprocess.run([adb, "install", "-r", str(apk_path)], check=True);

    if pkg_name {
        pkg_str: str = str(pkg_name);
        console.print(f"  Launching: {pkg_str}", style="muted");
        launch_cmd: list[str] = [
            adb,
            "shell",
            "monkey",
            "-p",
            pkg_str,
            "-c",
            "android.intent.category.LAUNCHER",
            "1"
        ];
        subprocess.run(launch_cmd, check=False, capture_output=True);
    }
    console.success("App installed and launched.");
}

def _start_ios(artifact_path: Path, project_dir: Path) {
    import json;
    rn_dir = resolve_rn_project_dir(project_dir);
    if platform_mod.system() != "Darwin" {
        raise RuntimeError(
            "iOS install & launch requires macOS with Xcode.\n"
            "On Linux/Windows, use EAS Build cloud and TestFlight:\n"
            "  npx eas build --platform ios --profile preview\n"
            "  npx eas submit --platform ios\n"
            f"Run inside {rn_dir}."
        );
    }

    xcrun = shutil.which("xcrun");
    if not xcrun {
        raise RuntimeError(
            "xcrun not found. Install Xcode CLI tools:\n" "  xcode-select --install"
        );
    }

    bundle_id: str | None = None;
    try {
        app_cfg = json.loads((rn_dir / "app.json").read_text(encoding="utf-8"));
        bundle_id = app_cfg["expo"]["ios"]["bundleIdentifier"];
    } except Exception as e {
        console.warning(
            f"  Failed to read ios.bundleIdentifier from app.json ({e}); "
            "will attempt install without auto-launch."
        );
    }

    sim_result = subprocess.run(
        [xcrun, "simctl", "list", "devices", "-j"],
        capture_output=True,
        text=True,
        check=True
    );
    import json as json_mod;
    sim_data = json_mod.loads(sim_result.stdout);
    devices = sim_data.get("devices", {});

    booted_udid: str | None = None;
    for (runtime_key, device_list) in devices.items() {
        for dev in device_list {
            if dev.get("isAvailable") and dev.get("state") == "Booted" {
                booted_udid = dev["udid"];
                break;
            }
        }
        if booted_udid {
            break;
        }
    }

    if not booted_udid {
        target_udid: str | None = None;
        for (runtime_key, device_list) in devices.items() {
            if "iOS" not in runtime_key {
                continue;
            }
            for dev in device_list {
                if dev.get("isAvailable") and "iPhone" in dev.get("name", "") {
                    target_udid = dev["udid"];
                    break;
                }
            }
            if target_udid {
                break;
            }
        }
        if target_udid {
            console.print(f"  Booting simulator {target_udid}...", style="muted");
            subprocess.run(
                [xcrun, "simctl", "boot", target_udid], check=True, capture_output=True
            );
            booted_udid = target_udid;
        } else {
            raise RuntimeError(
                "No iOS simulator available. Open Xcode > Window > Devices "
                "and Simulators to create one."
            );
        }
    }

    install_target: Path = artifact_path;
    if artifact_path.is_file() and artifact_path.suffix == ".ipa" {
        import tempfile;
        import zipfile;
        console.print(f"  Extracting .app from {artifact_path.name}...", style="muted");
        with tempfile.TemporaryDirectory() as tmp {
            temp_root = Path(tmp);
            with zipfile.ZipFile(artifact_path) as zf {
                zf.extractall(temp_root);
            }
            payload_dir = temp_root / "Payload";
            app_candidates = [
                f
                for f in payload_dir.glob("*.app")
                if f.is_dir()
            ];
            if not app_candidates {
                raise RuntimeError(
                    f"No .app bundle found inside {artifact_path} "
                    "(expected Payload/*.app)."
                );
            }
            install_target = app_candidates[0];
            _simctl_install_and_launch(xcrun, booted_udid, install_target, bundle_id);
        }
    } else {
        _simctl_install_and_launch(xcrun, booted_udid, install_target, bundle_id);
    }
    console.success("iOS app installed and launched on simulator.");
}

def _simctl_install_and_launch(
    xcrun: str, udid: str, app_path: Path, bundle_id: str | None
) {
    console.print(
        f"  Installing .app on simulator {udid}: {app_path.name}", style="muted"
    );
    subprocess.run(
        [xcrun, "simctl", "install", udid, str(app_path)],
        check=True,
        capture_output=True
    );
    if bundle_id {
        bid: str = str(bundle_id);
        console.print(f"  Launching: {bid}", style="muted");
        subprocess.run(
            [xcrun, "simctl", "launch", udid, bid], check=False, capture_output=True
        );
    }
}
