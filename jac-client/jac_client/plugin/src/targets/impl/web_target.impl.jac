"""Implementation of WebTarget methods."""
import types;
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.vite_bundler { ViteBundler }

"""Setup web target (no-op - web works out of the box)."""
impl WebTarget.setup(self: WebTarget, project_dir: Path) -> None {
    # Web target requires no setup - it works out of the box
    # This is a no-op implementation
    pass;
}

"""Start web dev server with HMR.

For web target, this delegates to the core jac start --dev behavior.
The actual HMR implementation is in jaclang/cli/commands/impl/execution.impl.jac.
This method is called when using non-default targets that inherit from WebTarget.
"""
impl WebTarget.dev(self: WebTarget, entry_file: Path, project_dir: Path) -> None {
    import from jaclang.cli.console { console }
    # Web dev mode is handled by core jac start --dev
    # When called directly (e.g., from PWATarget.dev() -> super().dev()),
    # we start the Vite dev server
    bundler = ViteBundler(project_dir=project_dir);

    # Create dev config
    client_dir = bundler._get_client_dir();
    bundler.create_vite_config(entry_file, is_dev=True, api_port=8000);

    # Ensure package.json exists
    if not (client_dir / 'configs' / 'package.json').exists() {
        bundler.create_package_json();
    }

    console.print("\n🌐 Starting web dev server (Vite + HMR)", style="bold");
    console.print("  Press Ctrl+C to stop\n", style="muted");

    # Start Vite dev server (blocking)
    process = bundler.start_dev_server(port=5173, suppress_initial_output=False);
    if process {
        try {
            process.wait();
        } except KeyboardInterrupt {
            console.print("\n  Stopping dev server...", style="muted");
            process.terminate();
            process.wait(timeout=5);
        }
    }
}

"""Start web target in production preview mode.

For web target, this builds the bundle and serves it.
This method is called when using non-default targets that inherit from WebTarget.
"""
impl WebTarget.start(self: WebTarget, entry_file: Path, project_dir: Path) -> None {
    import from jaclang.cli.console { console }
    import http.server;
    import socketserver;

    # Build the bundle first
    console.print("\n🌐 Building web bundle for production preview...", style="bold");
    bundle_path = self.build(entry_file, project_dir, None);

    # Serve the dist directory
    dist_dir = project_dir / ".jac" / "client" / "dist";
    if not dist_dir.exists() {
        raise RuntimeError(f"Build output not found: {dist_dir}");
    }

    import os;
    os.chdir(dist_dir);

    port = 8080;
    handler = http.server.SimpleHTTPRequestHandler;

    console.print(f"\n🚀 Serving at http://localhost:{port}/", style="bold green");
    console.print("  Press Ctrl+C to stop\n", style="muted");

    with socketserver.TCPServer(("", port), handler) as httpd {
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
    # Load the module (same as jac start does via _proc_file + jac_import)
    (base, mod) = os.path.split(str(entry_file));
    base = base or "./";
    if entry_file.name.endswith('.jac') {
        mod = mod[:-4];
    }
    # Import the module (Jac.jac_import handles context creation internally)
    Jac.jac_import(target=mod, base_path=base, lng='jac');
    if Jac.program.errors_had {
        errors = '\n'.join(str(e) for e in Jac.program.errors_had);
        raise RuntimeError(f"Failed to compile {entry_file}:\n{errors}") ;
    }
    # Get the loaded module
    loaded_mod = Jac.loaded_modules.get(mod);
    if not loaded_mod {
        raise RuntimeError(f"Module '{mod}' not found after import") ;
    }
    # Type assertion: loaded_mod is guaranteed to be not None here
    if not isinstance(loaded_mod, types.ModuleType) {
        raise RuntimeError(f"Module '{mod}' is not a valid module type") ;
    }
    # Build bundle using ViteClientBundleBuilder (same as jac start's introspector.ensure_bundle)
    builder = JacClient.get_client_bundle_builder();
    bundle = builder.build(loaded_mod, force=True);
    # Find the bundle file
    bundle_path = bundler.find_bundle();
    if not bundle_path {
        raise RuntimeError("Web build failed: bundle not found") ;
    }
    # Always generate static index.html for static serving
    _generate_index_html(
        bundle_path=bundle_path,
        bundler=bundler,
        loaded_mod=loaded_mod,
        project_dir=project_dir
    );
    return bundle_path;
}

"""Generate static index.html file for the built bundle."""
def _generate_index_html(
    bundle_path: Path,
    bundler: ViteBundler,
    loaded_mod: types.ModuleType,
    project_dir: Path
) -> None {
    import html;
    import hashlib;
    import from jaclang.project.config { get_config }
    import from jac_client.plugin.client { HeaderBuilder }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    # Get the first client export function (or default to 'app')
    mod_path = getattr(loaded_mod, '__file__', None);
    if mod_path {
        mod = Jac.program.mod.hub.get(mod_path);
        if mod and mod.gen.client_manifest {
            client_exports = mod.gen.client_manifest.exports;
            # client_exports is a list[str], not a dict
            if client_exports and len(client_exports) > 0 {
                function_name = client_exports[0];
            } else {
                function_name = 'app';
            }
        } else {
            function_name = 'app';
        }
    } else {
        function_name = 'app';
    }

    # Get module name
    module_name = loaded_mod.__name__;

    # Get dist directory (output_dir is already a Path)
    dist_dir = Path(bundler.output_dir);

    # Check for CSS file
    css_link = '';
    css_file = bundler.find_css();
    if css_file {
        css_hash = hashlib.sha256(css_file.read_bytes()).hexdigest()[:8];
        css_filename = css_file.name;
        css_link = f'<link rel="stylesheet" href="{css_filename}?hash={css_hash}"/>';
    }

    # Get meta data from config
    config = get_config();
    meta_data = {};
    if config {
        client_cfg = config.get_plugin_config("client");
        if client_cfg {
            meta_data = client_cfg.get("app_meta_data", {});
        }
    }

    # Build HTML head using HeaderBuilder (same as render_page)
    head_builder = HeaderBuilder(meta_data, function_name);
    head_content = head_builder.build_head();
    if css_link {
        head_content += f"\n            {css_link}";
    }

    # Get bundle filename (relative to dist_dir)
    bundle_filename = bundle_path.name;

    # Generate HTML with __jac_init__ script tag for client runtime
    init_payload = {
        "module": module_name,
        "function": function_name,
        "args": {},
        "argOrder": [],
        "globals": {}
    };
    import json;
    init_json = json.dumps(init_payload);

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

    # Write index.html to dist directory
    index_html = dist_dir / 'index.html';
    index_html.write_text(html_content, encoding='utf-8');
}
