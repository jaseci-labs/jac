import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.desktop.plugin.webview_lib {
    libwebview_name
}
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    _find_webview_dir,
    _jac_bin,
    _jac_subprocess_env,
    _stage_pyembed_shim,
    _bundle_runtime,
}
import from jaclang.runtimelib.client.targets.desktop._host_bootstrap {
    _generate_host_source
}
import from jaclang.runtimelib.client.targets.desktop._dev_launch {
    ensure_dev_build_env,
    desktop_app_runtime_env
}

def _ensure_libwebview(webview_dir: Path) -> Path {
    lib = webview_dir / libwebview_name();
    if lib.exists() {
        return lib;
    }
    console.print(f"  Building {libwebview_name()} (one-time)...", style="muted");
    res = subprocess.run([str(webview_dir / "build_libwebview.sh")]);
    if res.returncode != 0 or not lib.exists() {
        raise RuntimeError(
            f"Failed to build {libwebview_name()} - is WebKitGTK + a C toolchain installed? "
            "See jaclang/runtimelib/client/targets/desktop/native/webview/README.md."
        );
    }
    return lib;
}

impl NativeDesktopTarget.setup(project_dir: Path) -> None { }

def _assemble_native_host(
    entry_file: Path, project_dir: Path, output_dir: Path, dist_dir: Optional[Path]
) -> Path {
    import from jaclang.runtimelib.client.desktop_config { get_desktop_config }

    cfg = get_desktop_config(project_dir);
    cfg.validate();
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    dispatch = cfg.get_dispatch_config();
    plugin_configs = cfg.get_plugin_configs();
    app_name = ident.name or "app";

    if output_dir.exists() {
        shutil.rmtree(output_dir);
    }
    output_dir.mkdir(parents=True, exist_ok=True);

    if dist_dir is not None {
        shutil.copytree(dist_dir, output_dir / "dist");
    }
    webview_dir = _find_webview_dir();
    lib = _ensure_libwebview(webview_dir);
    out_lib_name = libwebview_name();
    shutil.copy2(lib, output_dir / out_lib_name);
    shutil.copy2(webview_dir / "webview.na.jac", output_dir / "webview.na.jac");

    sv_root = entry_file.parent;
    sv_stage = output_dir / "sv";
    sv_ignore = shutil.ignore_patterns(
        ".jac",
        ".git",
        "node_modules",
        ".venv*",
        "__pycache__",
        "*.pyc",
        ".env",
        ".env.*",
        "*.env",
        "*.sqlite",
        "*.sqlite3",
        "*.db",
        "*.key",
        "*.pem",
        "*.p12",
        "*.pfx"
    );
    shutil.copytree(sv_root, sv_stage, ignore=sv_ignore);
    sv_entry_rel = str(entry_file.name);

    _stage_pyembed_shim(output_dir);
    host_src = _generate_host_source(
        win.title or app_name,
        win.width,
        win.height,
        str(app_name),
        sv_entry_rel,
        dispatch.timeout_s,
        dispatch.max_queue,
        dispatch.debug,
        plugin_configs
    );
    (output_dir / "host.na.jac").write_text(host_src);

    console.print("  Compiling native host (jac nacompile)...", style="muted");
    binary = output_dir / app_name;
    res = subprocess.run(
        [_jac_bin(), "nacompile", str(output_dir / "host.na.jac"), "-o", str(binary)],
        cwd=str(output_dir),
        env=_jac_subprocess_env()
    );
    if res.returncode != 0 or not binary.exists() {
        raise RuntimeError("Native host compilation failed.");
    }

    _bundle_runtime(binary);
    stray = project_dir / app_name;
    if stray.exists() and stray.resolve() != binary.resolve() {
        stray.unlink();
    }
    launcher = output_dir / f"{app_name}-launch.sh";
    launcher.write_text(
        "#!/bin/sh\n"
        "cd \"$(dirname \"$0\")\" || exit 1\n"
        "export GDK_BACKEND=\"${GDK_BACKEND:-x11}\"\n"
        "export WEBKIT_DISABLE_DMABUF_RENDERER=\"${WEBKIT_DISABLE_DMABUF_RENDERER:-1}\"\n"
        "export WEBKIT_DISABLE_COMPOSITING_MODE=\"${WEBKIT_DISABLE_COMPOSITING_MODE:-1}\"\n"
        f"exec ./{app_name} \"$@\"\n"
    );
    os.chmod(launcher, 0o755);
    return binary;
}

impl NativeDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    ensure_dev_build_env();

    console.print("\n🖥️  Building desktop app (Jac-native webview)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    binary = _assemble_native_host(
        entry_file, project_dir, project_dir / self.output_dir, web_bundle.parent
    );
    console.print(f"\n✅ Desktop app built: {binary}", style="bold green");
    console.print(
        f"   run: (cd {binary.parent} && ./{binary.name}-launch.sh)"
        "  # or jac start --client desktop",
        style="muted"
    );
    return binary;
}

impl NativeDesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    binary = self.build(entry_file, project_dir, None);
    env = desktop_app_runtime_env();
    console.print(f"\n🚀 Launching {binary.name}", style="bold green");
    try {
        subprocess.run([str(binary)], cwd=str(binary.parent), env=env);
    } except KeyboardInterrupt {
        console.print("\n  Closing desktop app...", style="muted");
    }
}

impl NativeDesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    import from jaclang.runtimelib.watcher { JacFileWatcher }
    import from jaclang.runtimelib.client.targets.client_dev_common {
        _ClientHmrHandler,
        prepare_vite_dev_compilation,
        resolve_port_or_next_available,
        ensure_watchdog_common,
        stop_dev_watcher,
        terminate_dev_processes,
        install_dev_signal_handlers
    }

    console.print("\n🖥️  Desktop dev (native webview + Vite HMR)", style="bold");
    ensure_dev_build_env();

    broker_port = resolve_port_or_next_available(
        api_port if api_port > 0 else port, "broker"
    );
    vite_port = resolve_port_or_next_available(5173, "Vite", reserved=[broker_port]);

    (bundler, compiler) = prepare_vite_dev_compilation(project_dir, entry_file);

    bundler.create_vite_config(
        entry_file,
        is_dev=True,
        api_port=broker_port,
        for_desktop_dev=True,
        desktop_broker_port=broker_port
    );
    console.print(f"  Starting Vite dev server (port {vite_port})…", style="muted");
    vite_process = bundler.start_dev_server(port=vite_port, host="127.0.0.1");
    if not vite_process {
        raise RuntimeError("Failed to start Vite dev server");
    }

    binary_proc = None;
    hot_watcher = None;
    def cleanup_dev {
        console.print("\n  Stopping desktop app and Vite…", style="muted");
        stop_dev_watcher(hot_watcher);
        terminate_dev_processes([binary_proc, vite_process]);
        console.print("  ✔ Stopped", style="success");
    }

    try {
        console.print("  Building native host (once for dev session)…", style="muted");

        binary = _assemble_native_host(
            entry_file, project_dir, project_dir / self.output_dir, None
        );

        env = desktop_app_runtime_env();
        env["JAC_DESKTOP_DEV_PORT"] = str(vite_port);
        env["JAC_DESKTOP_BROKER_PORT"] = str(broker_port);

        console.print(
            f"\n🚀 Launching {binary.name} (Vite HMR on :{vite_port})",
            style="bold green"
        );
        binary_proc = subprocess.Popen([str(binary)], cwd=str(binary.parent), env=env);

        if ensure_watchdog_common("the webview") {
            hmr_handler = _ClientHmrHandler(
                compiler=compiler, entry_file=entry_file, project_dir=project_dir
            );
            hot_watcher = JacFileWatcher(watch_paths=[str(project_dir.resolve())]);
            hot_watcher.add_callback(hmr_handler.on_event);
            hot_watcher.start();
        }

        console.print("\n  Press Ctrl+C to stop\n", style="muted");
        install_dev_signal_handlers();
    } except Exception {
        terminate_dev_processes([vite_process, binary_proc]);
        stop_dev_watcher(hot_watcher);
        raise;
    }

    try {
        if binary_proc is not None {
            binary_proc.wait();
        }
    } except KeyboardInterrupt {
        console.print("\n  Interrupted.", style="muted");
    } finally {
        cleanup_dev();
    }
}
