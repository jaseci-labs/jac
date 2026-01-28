"""Implementation of WebTarget methods."""
import types;
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.vite_bundler { ViteBundler }

"""Build web bundle using existing Vite pipeline."""
impl WebTarget.build(
    self: WebTarget,
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None
) -> Path {
    import os;
    import shutil;
    import from jaclang.pycore.runtime { JacRuntime as Jac }
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
        errors = '\n'.join(Jac.program.errors_had);
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
    import from jaclang.pycore.runtime { JacRuntime as Jac }

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
    <script src="{bundle_filename}" defer></script>
  </body>
</html>''';

    # Write index.html to dist directory
    index_html = dist_dir / 'index.html';
    index_html.write_text(html_content, encoding='utf-8');
}
