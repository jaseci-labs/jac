impl _jaclang_src_roots -> list[Path] {
    roots: list[Path] = [];
    jac_src = os.environ.get("JAC_DESKTOP_JAC_SRC");
    if jac_src {
        roots.append(Path(jac_src));
    }
    try {
        import jaclang;
        jl = jaclang?.__file__;
        if jl {
            roots.append(Path(str(jl)).resolve().parent.parent);
        }
    } except Exception {}
    return roots;
}

impl _find_desktop_native_dir -> Path {
    for src in _jaclang_src_roots() {
        native = src / "jaclang" / "client" / "targets" / "desktop" / "native";
        if (
            (native / "oauth_broker.jac").is_file()
            and (native / "host_boot.jac").is_file()
            and (native / "webview" / "webview.jac").is_file()
        ) {
            return native;
        }
    }
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native", here / "native"];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native");
        p = p.parent;
    }
    for cand in candidates {
        if (
            (cand / "oauth_broker.jac").is_file()
            and (cand / "host_boot.jac").is_file()
            and (cand / "webview" / "webview.jac").is_file()
        ) {
            return cand;
        }
    }
    raise RuntimeError(
        "jac-desktop: desktop/native assets incomplete -- need "
        "oauth_broker.jac, host_boot.jac, and webview/webview.jac. "
        "Rebuild the jac binary (zig build) or set JAC_DESKTOP_JAC_SRC."
    );
}

impl _find_native_asset_dir(subdir: str, marker: str) -> Path {
    if subdir == "webview" and marker == "webview.jac" {
        import from jaclang.toolchains.desktop { source_workspace }
        return source_workspace(_find_desktop_native_dir() / "webview", "webview");
    }
    for src in _jaclang_src_roots() {
        dev = src / "jaclang" / "client" / "targets" / "desktop" / "native" / subdir;
        if (dev / marker).exists() {
            return dev;
        }
    }
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native" / subdir, here / "native" / subdir];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native" / subdir);
        p = p.parent;
    }
    for cand in candidates {
        if (cand / marker).exists() {
            return cand;
        }
    }
    raise RuntimeError(
        f"jac-desktop: native/{subdir} assets not found in the package."
    );
}

impl _find_webview_dir -> Path {
    return source_workspace(_find_desktop_native_dir() / "webview", "webview");
}

impl _find_cef_dir -> Path {
    return source_workspace(_find_native_asset_dir("cef", "cef.jac"), "cef");
}

impl _jac_subprocess_env -> dict[str, str] {
    return desktop_launch_env();
}

impl _patchelf_rpath(binary: Path, rpath: str) -> bool {
    patchelf = ensure_patchelf();
    res = subprocess.run([patchelf, "--set-rpath", rpath, str(binary)]);
    if res.returncode != 0 {
        console.print(
            f"  [yellow]patchelf rpath patch failed for {binary.name}; rebuild on this machine if it won't start[/yellow]"
        );
        return False;
    }
    return True;
}

impl _patch_host_rpath(binary: Path) {
    _patchelf_rpath(binary, "$ORIGIN");
}

impl _fused_runtime_dir -> Path {
    import jaclang;
    return Path(jaclang.__file__).parent / "dist" / "fused";
}

impl _stage_fused_runtime(out_dir: Path) {
    src = _fused_runtime_dir();
    if not (src / "bringup.jac").is_file() {
        raise RuntimeError(
            f"jac-desktop: the fused runtime library is missing from this jaclang ({src})."
        );
    }
    dst = out_dir / "fused";
    dst.mkdir(parents=True, exist_ok=True);
    for f in sorted(src.`glob("*.jac")) {
        if f.is_file() {
            stage_module(f, dst);
        }
    }
}

impl stage_postgres(resources: Path, backend: str, vendor: bool = True) -> str {
    if backend != "embedded" {
        return "";
    }
    import from jaclang.data.pg_dist { bundled_dist_dir, cached_dist_dir }
    if not vendor {
        return cached_dist_dir();
    }
    src = Path(bundled_dist_dir());
    dst = resources / "pgdist";
    console.print("  Bundling the embedded postgres distribution…", style="muted");
    shutil.copytree(src, dst, dirs_exist_ok=True);
    return "pgdist";
}


impl _bundle_runtime(host_binary: Path) {
    jac_bin = os.path.realpath(os.sys.executable);

    if not graft_runtime(jac_bin, str(host_binary)) {
        raise RuntimeError(
            "jac-desktop: the running jac binary carries no fused-runtime "
            f"({jac_bin}); a desktop app needs a fused `jac` built via `zig build`. "
            "(A bare pip/source jaclang install has no embeddable runtime.)"
        );
    }
}

impl _jac_bin -> str {
    exe = jac_binary();
    if exe {
        return exe;
    }
    found = shutil.which("jac");
    if found {
        return found;
    }
    raise RuntimeError("jac CLI not found on PATH.");
}

impl _native_build_cef(
    cef_dir: Path, source_name: str, output: Path, shared: bool
) -> Path {
    headers = cef_dir / "cef_headers";
    runtime = cef_dir / "cef_dist";
    if not (headers / "include").is_dir() or not (runtime / "libcef.so").is_file() {
        raise RuntimeError(
            f"jac-desktop: building {output.name} needs the CEF distribution that ensure_cef stages in {cef_dir}."
        );
    }
    with FileLock(cef_dir / ".native-build.lock") {
        build_dir = cef_dir / ".build";
        build_dir.mkdir(parents=True, exist_ok=True);
        script = (cef_dir / "bootstrap.js").read_text().strip();
        (build_dir / "bootstrap_js.h").write_text(
            f"static const char JAC_BOOTSTRAP_JS[] = {json.dumps(script)};\n"
        );
        cmd = ["cc", "-std=gnu11", "-O2", "-Wall"];
        if shared {
            cmd += ["-shared", "-fPIC", "-fvisibility=hidden"];
        }
        cmd += [
            f"-I{headers}",
            f"-I{build_dir}",
            str(cef_dir / source_name),
            "-o",
            str(output),
            f"-L{runtime}",
            f"-Wl,-rpath-link,{runtime}",
            "-Wl,-rpath,$ORIGIN"
        ];
        cmd += ["-Wl,--no-as-needed", "-lcef"];
        cmd += ["-ldl"] if shared else [f"-L{cef_dir}", "-lcef_dispatch"];
        res = subprocess.run(cmd);
        if res.returncode != 0 or not output.exists() {
            raise RuntimeError(f"cc failed for {output.name} (source {source_name}).");
        }
        return output;
    }
}

impl build_cef_dispatch(cef_dir: Path) -> Path {
    cef_dir = source_workspace(cef_dir, "cef");
    return _native_build_cef(
        cef_dir, "cef_dispatch.c", cef_dir / "libcef_dispatch.so", True
    );
}

impl build_cef_subprocess(cef_dir: Path) -> Path {
    cef_dir = source_workspace(cef_dir, "cef");
    return _native_build_cef(
        cef_dir, "cef_subprocess.c", cef_dir / "cef-subprocess", False
    );
}

impl serving_app_for(config: any, entry_file: Path, backend: str) -> str {
    if config is None or not config.is_workspace or not config.apps {
        return "";
    }
    selected_app = config.app_for_path(str(entry_file.resolve()));
    if selected_app is not None {
        return selected_app.name;
    }
    if backend != "embedded" {
        return "";
    }
    try {
        chosen = config.resolve_app("");
    } except ValueError {
        chosen = None;
    }
    serving = config.serving_apps();
    if chosen is not None and any(app.name == chosen.name for app in serving) {
        return chosen.name;
    }
    for app in serving {
        if app.kind == "web-app" {
            return app.name;
        }
    }
    return "";
}

impl stage_program(
    entry_file: Path,
    project_dir: Path,
    image_dir: Path,
    backend: str,
    dist_dir: (Path | None),
    serves_remote: bool = False
) -> dict[str, str] {
    if (backend != "embedded" or serves_remote) and dist_dir is not None {
        import from jaclang.project.client_paths { client_assets_dir }
        import from jaclang.project.config { get_config_for_dir }
        config = get_config_for_dir(str(project_dir));
        assets = client_assets_dir(config, project_dir, str(entry_file));
        if assets.is_dir() {
            shutil.copytree(assets, image_dir / "dist" / "assets", dirs_exist_ok=True);
        }
    }
    if backend != "embedded" {
        return {};
    }
    if dist_dir is None {
        return {"entry": str(entry_file.resolve())};
    }

    import from jaclang.project.config { get_config_for_dir }
    config = get_config_for_dir(str(project_dir));
    if config is None {
        raise RuntimeError(f"jac-desktop: no jac.toml under {project_dir}");
    }
    app = serving_app_for(config, entry_file, backend);
    console.print(
        "  Sealing the app image" + (f" for '{app}'" if app else ""), style="muted"
    );
    build_jab(config, image_dir / "app.jab", app=app, bake_client=False);
    return {"jab": "app.jab"};
}

impl inject_backend_script(index_html: Path) {
    html = index_html.read_text(encoding="utf-8");
    if BACKEND_SCRIPT_TAG in html {
        return;
    }
    if "<head>" not in html {
        raise RuntimeError(
            f"jac-desktop: {index_html} has no <head>; the backend script cannot load before the bundle"
        );
    }
    index_html.write_text(
        html.replace("<head>", "<head>\n    " + BACKEND_SCRIPT_TAG, 1), encoding="utf-8"
    );
}

impl desktop_storage_identifier(
    identifier: str, project_dir: Path, entry_file: Path, backend: str
) -> str {
    if not identifier {
        return identifier;
    }
    import from jaclang.project.config { get_config_for_dir }
    config = get_config_for_dir(str(project_dir));
    serving = storage_app_for(config, entry_file, backend);
    return f"{identifier}.{serving}" if serving else identifier;
}

impl storage_app_for(config: any, entry_file: Path, backend: str) -> str {
    if config is None or not config.is_workspace or not config.apps {
        return "";
    }
    selected_app = config.app_for_path(str(entry_file.resolve()));
    if backend != "embedded" {
        return selected_app.name if selected_app is not None else "";
    }
    try {
        chosen = config.resolve_app("");
    } except ValueError {
        chosen = None;
    }
    serving = config.serving_apps();
    if chosen is not None and any(app.name == chosen.name for app in serving) {
        return chosen.name;
    }
    for app in serving {
        if app.kind == "web-app" {
            return app.name;
        }
    }
    return selected_app.name if selected_app is not None else "";
}
