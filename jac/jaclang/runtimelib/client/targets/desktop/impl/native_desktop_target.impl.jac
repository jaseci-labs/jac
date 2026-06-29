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

impl NativeDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jaclang.runtimelib.client.desktop_config { get_desktop_config }

    ensure_dev_build_env();

    console.print("\n🖥️  Building desktop app (Jac-native webview)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    dist_dir = web_bundle.parent;

    cfg = get_desktop_config(project_dir);
    cfg.validate();
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    dispatch = cfg.get_dispatch_config();
    plugin_configs = cfg.get_plugin_configs();
    app_name = ident.name or "app";

    out_dir = project_dir / self.output_dir;
    if out_dir.exists() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);

    shutil.copytree(dist_dir, out_dir / "dist");
    webview_dir = _find_webview_dir();
    lib = _ensure_libwebview(webview_dir);
    out_lib_name = libwebview_name();
    shutil.copy2(lib, out_dir / out_lib_name);
    shutil.copy2(webview_dir / "webview.na.jac", out_dir / "webview.na.jac");

    sv_root = entry_file.parent;
    sv_stage = out_dir / "sv";
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

    _stage_pyembed_shim(out_dir);
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
    (out_dir / "host.na.jac").write_text(host_src);

    console.print("  Compiling native host (jac nacompile)...", style="muted");
    binary = out_dir / app_name;
    res = subprocess.run(
        [_jac_bin(), "nacompile", str(out_dir / "host.na.jac"), "-o", str(binary)],
        cwd=str(out_dir),
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
    launcher = out_dir / f"{app_name}-launch.sh";
    launcher.write_text(
        "#!/bin/sh\n"
        "cd \"$(dirname \"$0\")\" || exit 1\n"
        "export GDK_BACKEND=\"${GDK_BACKEND:-x11}\"\n"
        "export WEBKIT_DISABLE_DMABUF_RENDERER=\"${WEBKIT_DISABLE_DMABUF_RENDERER:-1}\"\n"
        "export WEBKIT_DISABLE_COMPOSITING_MODE=\"${WEBKIT_DISABLE_COMPOSITING_MODE:-1}\"\n"
        f"exec ./{app_name} \"$@\"\n"
    );
    os.chmod(launcher, 0o755);
    console.print(f"\n✅ Desktop app built: {binary}", style="bold green");
    console.print(
        f"   run: (cd {out_dir} && ./{launcher.name})  # or jac start --client desktop",
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
    console.print(
        "  desktop --dev: building and launching (HMR not yet wired)", style="muted"
    );
    self.start(entry_file, project_dir, api_port);
}
