"""Mobile target: Capacitor install, config, and android/ios platform scaffolds."""
import json;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jac_client.plugin.src.targets.mobile.common {
    _run_cap_cmd,
    _run_install_cmd
}
import from jac_client.plugin.src.targets.mobile.config { _write_capacitor_config }

"""Ensure Capacitor dependencies are installed."""
def _ensure_capacitor_deps(project_dir: Path) -> None {
    node_modules = project_dir / "node_modules" / "@capacitor" / "cli";
    if node_modules.exists() {
        console.print("  ✔ Capacitor dependencies already installed", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/core"]);
    _run_install_cmd(project_dir, ["@capacitor/cli"], dev=True);
}

"""Ensure Capacitor config exists."""
def _ensure_capacitor_config(project_dir: Path, web_dist_dir: Path) -> None {
    config_path = project_dir / "capacitor.config.json";
    if config_path.exists() {
        try {
            existing = json.loads(config_path.read_text(encoding="utf-8"));
            web_dir_rel = str(web_dist_dir.relative_to(project_dir));
            if existing.get("webDir") != web_dir_rel {
                existing["webDir"] = web_dir_rel;
                config_path.write_text(
                    json.dumps(existing, indent=2), encoding="utf-8"
                );
                console.print(
                    "  ✔ Updated capacitor.config.json webDir", style="muted"
                );
            } else {
                console.print(
                    "  ✔ capacitor.config.json already exists", style="muted"
                );
            }
        } except Exception {
            console.print("  ✔ capacitor.config.json already exists", style="muted");
        }
        return;
    }
    _write_capacitor_config(project_dir, web_dist_dir);
}

"""Ensure web dist directory has at least a placeholder index.html.

Capacitor's 'add' and 'sync' commands require an index.html in webDir.
"""
def _ensure_placeholder_index(web_dist_dir: Path) -> None {
    index_html = web_dist_dir / "index.html";
    if index_html.exists() {
        return;
    }
    web_dist_dir.mkdir(parents=True, exist_ok=True);
    index_html.write_text(
        '<!DOCTYPE html><html><head></head><body></body></html>', encoding="utf-8"
    );
}

"""Ensure Android platform is added."""
def _ensure_android_platform(project_dir: Path, web_dist_dir: Path) -> None {
    android_dir = project_dir / "android";
    if android_dir.exists() {
        console.print("  ✔ Android platform already added", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/android"]);
    _ensure_placeholder_index(web_dist_dir);
    _run_cap_cmd(project_dir, ["add", "android"], "cap add android");
    console.print("  ✔ Android platform added", style="success");
}

"""Ensure iOS platform is added."""
def _ensure_ios_platform(project_dir: Path, web_dist_dir: Path) -> None {
    ios_dir = project_dir / "ios";
    if ios_dir.exists() {
        console.print("  ✔ iOS platform already added", style="muted");
        return;
    }
    _run_install_cmd(project_dir, ["@capacitor/ios"]);
    _ensure_placeholder_index(web_dist_dir);
    _run_cap_cmd(project_dir, ["add", "ios"], "cap add ios");
    console.print("  ✔ iOS platform added", style="success");
}
