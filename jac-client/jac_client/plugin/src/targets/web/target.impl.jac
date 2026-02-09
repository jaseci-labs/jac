"""Implementation of WebTarget methods using new BuildContext/BuildResult interface."""
import os;
import shutil;
import types;
import from pathlib { Path }
import from jaclang.pycore.runtime { JacRuntime as Jac }
import from jac_client.plugin.client { JacClient }
import from ..types { BuildContext, BuildResult }
import from ...vite_bundler { ViteBundler }

"""Build web bundle using existing Vite pipeline."""
impl WebTarget.build(self: WebTarget, ctx: BuildContext) -> BuildResult {
    try {
        bundler = ViteBundler(project_dir=ctx.project_dir);

        # Clean dist directory for fresh build
        dist_dir = bundler.output_dir;
        if dist_dir.exists() {
            shutil.rmtree(dist_dir);
        }
        dist_dir.mkdir(parents=True, exist_ok=True);

        # Load the module
        (base, mod) = os.path.split(str(ctx.entry_file));
        base = base or "./";
        if ctx.entry_file.name.endswith('.jac') {
            mod = mod[:-4];
        }

        # Import the module
        Jac.jac_import(target=mod, base_path=base, lng='jac');
        if Jac.program.errors_had {
            errors = '\n'.join(str(e) for e in Jac.program.errors_had);
            return BuildResult.fail(f"Failed to compile {ctx.entry_file}:\n{errors}");
        }

        # Get the loaded module
        loaded_mod = Jac.loaded_modules.get(mod);
        if not loaded_mod {
            return BuildResult.fail(f"Module '{mod}' not found after import");
        }

        if not isinstance(loaded_mod, types.ModuleType) {
            return BuildResult.fail(f"Module '{mod}' is not a valid module type");
        }

        # Build bundle
        builder = JacClient.get_client_bundle_builder();
        bundle = builder.build(loaded_mod, force=True);

        # Find the bundle file
        bundle_path = bundler.find_bundle();
        if not bundle_path {
            return BuildResult.fail("Web build failed: bundle not found");
        }

        # Generate static index.html
        _generate_index_html(
            bundle_path=bundle_path,
            bundler=bundler,
            loaded_mod=loaded_mod,
            project_dir=ctx.project_dir
        );

        return BuildResult.ok(output_path=bundle_path);
    } except Exception as e {
        return BuildResult.fail(str(e));
    }
}

"""Start web dev server."""
impl WebTarget.dev(self: WebTarget, ctx: BuildContext) -> BuildResult {
    try {
        bundler = ViteBundler(project_dir=ctx.project_dir);
        bundler.start_dev_server(port=ctx.port);
        return BuildResult.ok();
    } except Exception as e {
        return BuildResult.fail(str(e));
    }
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
    import json;
    import from jaclang.project.config { get_config }
    import from jac_client.plugin.client { HeaderBuilder }
    import from jaclang.pycore.runtime { JacRuntime as Jac }

    # Get the first client export function (or default to 'app')
    mod_path = getattr(loaded_mod, '__file__', None);
    function_name = 'app';

    if mod_path {
        mod = Jac.program.mod.hub.get(mod_path);
        if mod and mod.gen.client_manifest {
            client_exports = mod.gen.client_manifest.exports;
            if client_exports and len(client_exports) > 0 {
                function_name = client_exports[0];
            }
        }
    }

    # Get module name
    module_name = loaded_mod.__name__;

    # Get dist directory
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

    # Build HTML head using HeaderBuilder
    head_builder = HeaderBuilder(meta_data, function_name);
    head_content = head_builder.build_head();
    if css_link {
        head_content += f"\n            {css_link}";
    }

    # Get bundle filename
    bundle_filename = bundle_path.name;

    # Generate HTML with __jac_init__ script tag
    init_payload = {
        "module": module_name,
        "function": function_name,
        "args": {},
        "argOrder": [],
        "globals": {}
    };
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
