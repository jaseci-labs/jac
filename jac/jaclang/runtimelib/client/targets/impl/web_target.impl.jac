import os;
import types;
import from pathlib { Path }
import from typing { Optional, cast }
import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

glob DEFAULT_FUNCTION_NAME = "app",
     JAC_FILE_EXTENSION = ".jac",
     JAC_LANG_ID = "jac";

def _parse_entry_file(entry_file: Path) -> tuple[str, str] {
    (base, mod) = os.path.split(str(entry_file));
    base = base or "./";
    if mod.endswith(JAC_FILE_EXTENSION) {
        mod = mod[:-len(JAC_FILE_EXTENSION)];
    }
    return (base, mod);
}

impl WebTarget.setup(project_dir: Path) -> None { }

impl WebTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.client_dev_common {
        _ClientHmrHandler,
        ensure_watchdog_common,
        prepare_vite_dev_compilation,
        stop_dev_watcher,
        terminate_dev_processes
    }

    api_p = api_port if api_port > 0 else port + 1;

    hot_watcher: any = None;
    (prepared, compiler) = prepare_vite_dev_compilation(project_dir, entry_file);
    bundler = cast(ViteBundler, prepared);
    bundler.create_vite_config(entry_file, is_dev=True, api_port=api_p);

    try {
        if ensure_watchdog_common("the browser") {
            import from jaclang.runtimelib.watcher { JacFileWatcher }

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
                process.wait();
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
    import from jaclang.cli.console { console }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    bundler = ViteBundler(project_dir=project_dir);
    console.print("\n🌐 Building web bundle for production preview...", style="bold");
    self.build(entry_file, project_dir, None);

    dist_dir = bundler.output_dir;
    if not dist_dir or not dist_dir.exists() {
        raise RuntimeError(f"Build output not found: {dist_dir}");
    }

    (base, mod) = _parse_entry_file(entry_file);

    ServerClass = Jac.get_api_server_class();
    server = ServerClass(module_name=mod, port=api_port, base_path=base);

    console.print(
        f"\n🚀 Starting server at http://localhost:{api_port}/", style="bold green"
    );
    console.print("  Press Ctrl+C to stop\n", style="muted");

    try {
        server.start(dev=False, no_client=False);
    } except KeyboardInterrupt {
        console.print("\n  Stopping server...", style="muted");
    }
}

impl WebTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import shutil;
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.runtimelib.client.vite_client_bundle {
        make_client_bundle_builder
    }

    bundler = ViteBundler(project_dir=project_dir);

    dist_dir = bundler.output_dir;
    if dist_dir {
        if dist_dir.exists() {
            shutil.rmtree(dist_dir);
        }
        dist_dir.mkdir(parents=True, exist_ok=True);
    }

    (base, mod) = _parse_entry_file(entry_file);

    Jac.jac_import(target=mod, base_path=base, lng=JAC_LANG_ID);
    if Jac.program.errors_had {
        errors = '\n'.join(str(e) for e in Jac.program.errors_had);
        raise RuntimeError(f"Failed to compile {entry_file}:\n{errors}");
    }
    loaded_mod = Jac.loaded_modules.get(mod);
    if not loaded_mod {
        raise RuntimeError(f"Module '{mod}' not found after import");
    }
    if not isinstance(loaded_mod, types.ModuleType) {
        raise RuntimeError(f"Module '{mod}' is not a valid module type");
    }
    builder = make_client_bundle_builder(project_dir);
    builder.build(loaded_mod, force=True);
    bundle_path = bundler.find_bundle();
    if not bundle_path {
        raise RuntimeError("Web build failed: bundle not found");
    }
    _generate_index_html(
        bundle_path=bundle_path,
        bundler=bundler,
        loaded_mod=loaded_mod,
        project_dir=project_dir
    );
    return bundle_path;
}

def _get_client_function_name(loaded_mod: types.ModuleType) -> str {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    mod_path = loaded_mod?.__file__;
    if not mod_path {
        return DEFAULT_FUNCTION_NAME;
    }

    mod = Jac.program.find_module(mod_path);
    if not mod {
        return DEFAULT_FUNCTION_NAME;
    }
    gen = mod?.gen;
    if not gen {
        return DEFAULT_FUNCTION_NAME;
    }

    client_manifest = gen?.client_manifest;
    if not client_manifest {
        return DEFAULT_FUNCTION_NAME;
    }

    client_exports = client_manifest?.exports;
    if client_exports and len(client_exports) > 0 {
        return client_exports[0];
    }
    return DEFAULT_FUNCTION_NAME;
}

def _build_css_link(bundler: ViteBundler) -> str {
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

def _get_app_meta_data -> dict {
    import from jaclang.project.config { get_config }

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


def _generate_index_html(
    bundle_path: Path,
    bundler: ViteBundler,
    loaded_mod: types.ModuleType,
    project_dir: Path
) {
    import html;
    import json;
    import from jaclang.runtimelib.client.serving { HeaderBuilder }

    function_name = _get_client_function_name(loaded_mod);
    module_name = loaded_mod.__name__;
    dist_dir = Path(bundler.output_dir);
    css_link = _build_css_link(bundler);
    meta_data = _get_app_meta_data();
    head_builder = HeaderBuilder(meta_data, function_name);
    head_content = head_builder.build_head();
    if css_link {
        head_content += f"\n            {css_link}";
    }
    init_payload = {
        "module": module_name,
        "function": function_name,
        "args": {},
        "argOrder": [],
        "globals": {}
    };

    init_json = json.dumps(init_payload).replace('</', '<\\/');
    bundle_filename = bundle_path.name;
    base_path = bundler.config_loader.get_base_path();

    html_content = f'''<!DOCTYPE html>
<html lang="en">
  <head>
{head_content}
  </head>
  <body>
    <div id="root"></div>
    <script id="__jac_init__" type="application/json">{init_json}</script>
    <script type="module" src="{base_path}{bundle_filename}"></script>
  </body>
</html>''';
    index_html = dist_dir / 'index.html';
    index_html.write_text(html_content, encoding='utf-8');
}
