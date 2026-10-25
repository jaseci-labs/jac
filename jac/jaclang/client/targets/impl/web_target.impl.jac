import os;

import types;

import from pathlib { Path }

import from typing { Optional, cast }

glob DEFAULT_FUNCTION_NAME = "app",
     JAC_FILE_EXTENSION = ".jac",
     JAC_LANG_ID = "jac";

def _parse_entry_file(entry_file: Path) -> tuple[str, str];

def _pwa_enabled(project_dir: Path) -> bool;

impl WebTarget.setup(project_dir: Path) -> None {
    if _pwa_enabled(project_dir) {
        import from jaclang.client.targets.pwa_build { ensure_pwa_icons }
        ensure_pwa_icons(project_dir);
    }
}

impl WebTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    api_p = api_port if api_port > 0 else port + 1;

    hot_watcher: any = None;
    (prepared, compiler) = prepare_vite_dev_compilation(project_dir, entry_file);
    bundler = cast(ViteBundler, prepared);
    (dev_api_paths, dev_client_paths) = dev_proxy_paths(project_dir, entry_file);
    bundler.create_vite_config(
        entry_file,
        is_dev=True,
        api_port=api_p,
        api_paths=dev_api_paths,
        client_paths=dev_client_paths
    );

    try {
        if ensure_watchdog_common("the browser") {
            import from jaclang.server.watcher { JacFileWatcher }

            hmr_handler = _ClientHmrHandler(
                compiler=compiler, entry_file=entry_file, project_dir=project_dir
            );
            hot_watcher = JacFileWatcher(watch_paths=[str(project_dir.resolve())]);
            hot_watcher.add_callback(hmr_handler.on_event);
            hot_watcher.start();
        }

        console.print("\n🌐 Starting web dev server (Vite + HMR)", style="bold");
        console.print("  Press Ctrl+C to stop\n", style="muted");
        process = bundler.start_dev_server(port=port, suppress_initial_output=False);
        if process {
            try {
                process.`wait();
            } except KeyboardInterrupt {
                console.print("\n  Stopping dev server...", style="muted");
                terminate_dev_processes([process]);
            }
        }
    } finally {
        stop_dev_watcher(hot_watcher);
    }
}

impl WebTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    if serve(filename=str(entry_file.resolve()), port=api_port, dev=False) {
        raise RuntimeError(f'Could not start web application: {entry_file}');
    }
}

impl WebTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    bundler = ViteBundler(project_dir=project_dir);

    dist_dir = bundler.output_dir;
    if dist_dir {
        dist_dir.mkdir(parents=True, exist_ok=True);
    }

    program = Jac.get_program();
    loaded_mod = types.ModuleType(entry_file.stem);
    loaded_mod.__file__ = str(entry_file.resolve());
    builder = make_client_bundle_builder(project_dir);
    try {
        before = len(program.errors_had);
        artifact = program._get_compiler().get_client_artifact(
            str(entry_file.resolve()), program
        );
        if len(program.errors_had) > before {
            errors = '\n'.join(str(e) for e in program.errors_had[before:]);
            raise RuntimeError(f"Failed to compile {entry_file}:\n{errors}");
        }
        inputs = builder.prepare(loaded_mod);
        exports = list(artifact.manifest.exports or []) if artifact is not None else [];
        function_name = exports[0] if exports else DEFAULT_FUNCTION_NAME;
    } finally {
        program._get_compiler().release_compile_state(program);
    }
    builder.bundle(inputs);
    bundle_path = bundler.find_bundle();
    if not bundle_path {
        raise RuntimeError("Web build failed: bundle not found");
    }
    _generate_index_html(
        bundle_path=bundle_path,
        bundler=bundler,
        loaded_mod=loaded_mod,
        function_name=function_name,
        project_dir=project_dir
    );
    if _pwa_enabled(project_dir) {
        import from jaclang.client.targets.pwa_build { apply_pwa }
        apply_pwa(dist_dir, project_dir);
    }
    return bundle_path;
}

def _build_css_link(bundler: ViteBundler) -> str;

def _get_app_meta_data -> dict[str, any];

def _generate_index_html(
    bundle_path: Path,
    bundler: ViteBundler,
    loaded_mod: types.ModuleType,
    function_name: str,
    project_dir: Path
);

impl _parse_entry_file(entry_file: Path) -> tuple[str, str] {
    (base, mod) = os.path.split(str(entry_file));
    base = base or "./";
    if mod.endswith(JAC_FILE_EXTENSION) {
        mod = mod[:-len(JAC_FILE_EXTENSION)];
    }
    return (base, mod);
}

impl _pwa_enabled(project_dir: Path) -> bool {
    return JacClientConfig(project_dir).is_pwa_enabled();
}

impl _build_css_link(bundler: ViteBundler) -> str {
    import hashlib;

    css_file = bundler.find_css();
    if not css_file {
        return '';
    }
    if css_file.exists() {
        css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8];
        base_path = bundler.config_loader.get_base_path();
        return f'<link rel="stylesheet" href="{base_path}styles.css?hash={css_hash}"/>';
    }
    return '';
}

impl _get_app_meta_data -> dict[str, any] {
    config = get_config();
    if not config {
        return {};
    }
    client_cfg = config.get_plugin_config("client");
    if not client_cfg {
        return {};
    }
    return client_cfg.get("app_meta_data", {});
}
