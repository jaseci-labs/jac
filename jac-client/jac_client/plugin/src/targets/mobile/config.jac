"""Mobile target: jac.toml and capacitor.config.json helpers."""
import json;
import os;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jac_client.plugin.src.mobile_setup_env { MOBILE_SETUP_PLATFORM_ENV }
import from jac_client.plugin.src.targets.mobile.common {
    DEFAULT_APP_ID,
    DEFAULT_APP_NAME,
    MOBILE_SETUP_MODES,
    SUPPORTED_PLATFORMS
}

"""Load mobile config from jac.toml."""
def _load_mobile_config(project_dir: Path) -> dict {
    try {
        import tomllib;
        toml_path = project_dir / "jac.toml";
        if toml_path.exists() {
            content = toml_path.read_text(encoding="utf-8");
            config = tomllib.loads(content);
            return config.get("plugins", {}).get("client", {}).get("mobile", {});
        }
    } except Exception {
        ;
    }
    return {};
}

"""Resolve mobile setup mode (android, ios, all).

Priority: explicit env override -> jac.toml default_platform -> host default.
"""
def _resolve_mobile_setup_mode(project_dir: Path, is_macos: bool) -> tuple[str, bool] {
    requested = os.environ.get(MOBILE_SETUP_PLATFORM_ENV, "").strip().lower();
    if requested in MOBILE_SETUP_MODES {
        return (requested, True);
    }
    mobile_cfg = _load_mobile_config(project_dir);
    default_platform = str(mobile_cfg.get("default_platform", "")).strip().lower();
    if default_platform in SUPPORTED_PLATFORMS {
        return (default_platform, False);
    }
    return ("ios", False) if is_macos else ("android", False);
}

"""Add [plugins.client.mobile] section to jac.toml if not present."""
def _add_mobile_config(project_dir: Path, app_name: str, app_id: str) -> None {
    toml_path = project_dir / "jac.toml";
    if not toml_path.exists() {
        return;
    }
    content = toml_path.read_text(encoding="utf-8");
    if "[plugins.client.mobile]" in content {
        console.print("  ✔ [plugins.client.mobile] already in jac.toml", style="muted");
        return;
    }

    mobile_section = (
        "\n[plugins.client.mobile]\n"
        f'app_name = "{app_name}"\n'
        f'app_id = "{app_id}"\n'
    );
    content += mobile_section;
    toml_path.write_text(content, encoding="utf-8");
    console.print("  ✔ Added [plugins.client.mobile] to jac.toml", style="success");
}

"""Write capacitor.config.json pointing webDir at the Vite output."""
def _write_capacitor_config(project_dir: Path, web_dist_dir: Path) {
    mobile_cfg = _load_mobile_config(project_dir);
    app_id = mobile_cfg.get("app_id", DEFAULT_APP_ID);
    app_name = mobile_cfg.get("app_name", DEFAULT_APP_NAME);

    try {
        web_dir_rel = str(web_dist_dir.relative_to(project_dir));
    } except ValueError {
        web_dir_rel = str(web_dist_dir);
    }

    config = {
        "appId": app_id,
        "appName": app_name,
        "webDir": web_dir_rel,
        "server": {"androidScheme": "https", "iosScheme": "capacitor"}
    };
    config_path = project_dir / "capacitor.config.json";
    config_path.write_text(json.dumps(config, indent=2), encoding="utf-8");
    console.print("  ✔ Wrote capacitor.config.json", style="success");
}
