"""Bundle creation helpers for MobileTarget.

Handles copying the web bundle into the mobile build directory,
running the Node.js create-bundle.js script, and managing the
.jac/mobile/ build directory.
"""
import from pathlib { Path }
import from jaclang.cli.console { console }
import subprocess;
import shutil;
import json;

"""Ensure icons and yarn deps are present in the .jac/mobile/ build directory.

Called before every build/dev/start — no file copy needed since setup() now
scaffolds directly into .jac/mobile/.
"""
def _ensure_mobile_deps(mobile_build_dir: Path) {
    import from jac_client.plugin.src.targets.mobile.setup_helpers {
        _install_yarn_dependencies,
        _generate_placeholder_icons
    }
    _icon_names = ["icon.png", "splash.png", "adaptive-icon.png", "favicon.png"];
    _assets_dir = mobile_build_dir / "assets";
    if any(not (_assets_dir / _n).exists() for _n in _icon_names) {
        _generate_placeholder_icons(mobile_build_dir);
    }

    if not (mobile_build_dir / "node_modules").exists() {
        console.print("  Installing dependencies in .jac/mobile/...", style="muted");
        try {
            _install_yarn_dependencies(mobile_build_dir);
        } except Exception as e {
            console.warning(f"  Failed to install dependencies: {e}");
            raise;
        }
    } else {
        console.print("  ✔ Dependencies already installed", style="success");
    }
}

"""Copy the Vite-built web bundle files into the mobile assets directory."""
def _copy_web_bundle_to_mobile(web_bundle_path: Path, mobile_dir: Path) {
    assets_dir = mobile_dir / "assets" / "jac-app";
    dist_dir = web_bundle_path if web_bundle_path.is_dir() else web_bundle_path.parent;

    html_file = dist_dir / "index.html";
    if html_file.exists() {
        shutil.copy2(html_file, assets_dir / "index.html");
        console.print(f"    ✔ Copied index.html", style="success");
    } else {
        raise RuntimeError(f"index.html not found in {dist_dir}");
    }

    css_files = list(dist_dir.glob("*.css"));
    if css_files {
        shutil.copy2(css_files[0], assets_dir / "styles.css");
        console.print(
            f"    ✔ Copied {css_files[0].name} as styles.css", style="success"
        );
    } else {
        console.warning("    No CSS file found, creating empty styles.css");
        (assets_dir / "styles.css").write_text("");
    }

    js_files = list(dist_dir.glob("*.js"));
    if js_files {
        main_js = max(js_files, key=lambda f : f.stat().st_size);
        shutil.copy2(main_js, assets_dir / "client.js");
        console.print(f"    ✔ Copied {main_js.name} as client.js", style="success");
    } else {
        raise RuntimeError(f"No JavaScript files found in {dist_dir}");
    }
}

"""Run create-bundle.js to produce bundle.html + bundle.ts from web assets."""
def _create_mobile_bundle(mobile_dir: Path) {
    script_path = mobile_dir / "assets" / "jac-app" / "create-bundle.js";
    if not script_path.exists() {
        raise RuntimeError(f"Bundle script not found: {script_path}");
    }
    try {
        result = subprocess.run(
            ["node", str(script_path)],
            cwd=str(script_path.parent),
            capture_output=True,
            text=True,
            timeout=30
        );
        if result.returncode != 0 {
            console.error(f"  Bundle creation failed: {result.stderr}");
            raise RuntimeError(f"Bundle creation failed: {result.stderr}");
        }
        console.print(f"  {result.stdout.strip()}", style="success");
    } except subprocess.TimeoutExpired {
        raise RuntimeError("Bundle creation timed out");
    } except Exception as e {
        raise RuntimeError(f"Failed to create bundle: {e}");
    }
}
