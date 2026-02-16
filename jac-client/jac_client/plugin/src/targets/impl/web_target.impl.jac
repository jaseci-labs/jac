"""Implementation of WebTarget methods."""
import types;
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.vite_bundler { ViteBundler }

glob VITE_DEV_SERVER_PORT = 5173,
     DEFAULT_FUNCTION_NAME = "app";

"""Setup web target (no-op - web works out of the box)."""
impl WebTarget.setup(self: WebTarget, project_dir: Path) -> None { }

"""Start web dev server with HMR.

For web target, this delegates to the core jac start --dev behavior.
The actual HMR implementation is in jaclang/cli/commands/impl/execution.impl.jac.
This method is called when using non-default targets that inherit from WebTarget.
"""
impl WebTarget.dev(
    self: WebTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jaclang.cli.console { console }
    # Web dev mode is handled by core jac start --dev
    # When called directly (e.g., from PWATarget.dev() -> super().dev()),
    # we start the Vite dev server
    bundler = ViteBundler(project_dir=project_dir);
    client_dir = bundler._get_client_dir();
    bundler.create_vite_config(entry_file, is_dev=True, api_port=api_port);
    if not (client_dir / 'configs' / 'package.json').exists() {
        bundler.create_package_json();
    }
    console.print("\n🌐 Starting web dev server (Vite + HMR)", style="bold");
    console.print("  Press Ctrl+C to stop\n", style="muted");
    process = bundler.start_dev_server(
        port=VITE_DEV_SERVER_PORT, suppress_initial_output=False
    );
    if process {
        try {
            process.wait();
        } except KeyboardInterrupt {
            console.print("\n  Stopping dev server...", style="muted");
            process.terminate();
            try {
                process.wait(timeout=5);
            } except Exception {
                # Force kill if graceful termination fails
                process.kill();
            }
        }
    }
}

"""Start web target in production preview mode.

For web target, this builds the bundle and serves it.
This method is called when using non-default targets that inherit from WebTarget.
"""
impl WebTarget.start(
    self: WebTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jaclang.cli.console { console }
    import http.server;
    import socketserver;
    bundler = ViteBundler(project_dir=project_dir);
    console.print("\n🌐 Building web bundle for production preview...", style="bold");
    self.build(entry_file, project_dir, None);
    # Serve the dist directory (use bundler.output_dir to avoid path duplication)
    dist_dir = bundler.output_dir;
    if not dist_dir.exists() {
        raise RuntimeError(f"Build output not found: {dist_dir}") ;
    }
    import os;
    os.chdir(dist_dir);
    handler = http.server.SimpleHTTPRequestHandler;
    console.print(f"\n🚀 Serving at http://localhost:{api_port}/", style="bold green");
    console.print("  Press Ctrl+C to stop\n", style="muted");
    with socketserver.TCPServer(("", api_port), handler) as httpd {
        try {
            httpd.serve_forever();
        } except KeyboardInterrupt {
            console.print("\n  Stopping server...", style="muted");
        }
    }
}

"""Build web bundle using existing Vite pipeline."""
impl WebTarget.build(
    self: WebTarget,
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None
) -> Path {
    import os;
    import shutil;
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jac_client.plugin.client { JacClient }
    bundler = ViteBundler(project_dir=project_dir);
    # Clean dist directory for fresh build
    dist_dir = bundler.output_dir;
    if dist_dir.exists() {
        shutil.rmtree(dist_dir);
    }
    dist_dir.mkdir(parents=True, exist_ok=True);
    (base, mod) = os.path.split(str(entry_file));
    base = base or "./";
    if entry_file.name.endswith('.jac') {
        mod = mod[:-4];
    }
    Jac.jac_import(target=mod, base_path=base, lng='jac');
    if Jac.program.errors_had {
        errors = '\n'.join(str(e) for e in Jac.program.errors_had);
        raise RuntimeError(f"Failed to compile {entry_file}:\n{errors}") ;
    }
    loaded_mod = Jac.loaded_modules.get(mod);
    if not loaded_mod {
        raise RuntimeError(f"Module '{mod}' not found after import") ;
    }
    if not isinstance(loaded_mod, types.ModuleType) {
        raise RuntimeError(f"Module '{mod}' is not a valid module type") ;
    }
    builder = JacClient.get_client_bundle_builder();
    builder.build(loaded_mod, force=True);
    bundle_path = bundler.find_bundle();
    if not bundle_path {
        raise RuntimeError("Web build failed: bundle not found") ;
    }
    _generate_index_html(
        bundle_path=bundle_path,
        bundler=bundler,
        loaded_mod=loaded_mod,
        project_dir=project_dir
    );
    return bundle_path;
}

"""Get the first client export function name from a loaded module."""
def _get_client_function_name(loaded_mod: types.ModuleType) -> str {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    mod_path = getattr(loaded_mod, '__file__', None);
    if not mod_path {
        return DEFAULT_FUNCTION_NAME;
    }

    mod = Jac.program.mod.hub.get(mod_path);
    if not mod {
        return DEFAULT_FUNCTION_NAME;
    }
    gen = getattr(mod, 'gen', None);
    if not gen {
        return DEFAULT_FUNCTION_NAME;
    }

    client_manifest = getattr(gen, 'client_manifest', None);
    if not client_manifest {
        return DEFAULT_FUNCTION_NAME;
    }

    client_exports = getattr(client_manifest, 'exports', None);
    if client_exports and len(client_exports) > 0 {
        return client_exports[0];
    }
    return DEFAULT_FUNCTION_NAME;
}

"""Build CSS link tag if CSS file exists."""
def _build_css_link(bundler: ViteBundler) -> str {
    import hashlib;

    css_file = bundler.find_css();
    if not css_file {
        return '';
    }
    css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8];
    return f'<link rel="stylesheet" href="{css_file.name}?hash={css_hash}"/>';
}

"""Get app meta data from project config."""
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

"""Generate static index.html file for the built bundle."""
def _generate_index_html(
    bundle_path: Path,
    bundler: ViteBundler,
    loaded_mod: types.ModuleType,
    project_dir: Path
) -> None {
    import html;
    import json;
    import from jac_client.plugin.client { HeaderBuilder }

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
    init_json = json.dumps(init_payload);
    bundle_filename = bundle_path.name;

    html_content = f'''<!DOCTYPE html>
<html lang="en">
  <head>
{head_content}
  </head>
  <body>
    <div id="root"></div>
    <script id="__jac_init__" type="application/json">{html.escape(init_json)}</script>
    <script type="module" src="{bundle_filename}"></script>
  </body>
</html>''';
    index_html = dist_dir / 'index.html';
    index_html.write_text(html_content, encoding='utf-8');
}
