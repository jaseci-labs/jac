"""React Native target config helpers.

Loads ``[plugins.client.react_native]`` from jac.toml and normalizes the
Config knobs:
  - ``release`` (debug vs release builds)
  - ``android_builder`` / ``ios_builder`` (gradle|xcodebuild|eas)
  - ``eas_profile`` (local EAS build profile)
  - ``eas_update`` + ``eas_update_branch`` (opt-in OTA publish)
"""
import from pathlib { Path }
import from jaclang.runtimelib.client.config_loader { JacClientConfig }

glob _RN_BUILDERS_ANDROID = {"gradle", "eas"},
     _RN_BUILDERS_IOS = {"xcodebuild", "eas"};

"""Load ``[plugins.client.react_native]`` from jac.toml."""
def _load_react_native_config(project_dir: Path) -> dict {
    return JacClientConfig(project_dir).get_react_native_config();
}

"""Parse truthy/falsy values from bool/string/int config entries."""
def _to_bool(value: any, fallback: bool = False) -> bool {
    if value is None {
        return fallback;
    }
    if isinstance(value, bool) {
        return value;
    }
    if isinstance(value, int) {
        return value != 0;
    }
    txt = str(value).strip().lower();
    if txt in {"1", "true", "yes", "y", "on"} {
        return True;
    }
    if txt in {"0", "false", "no", "n", "off"} {
        return False;
    }
    return fallback;
}

"""Resolve release mode from config."""
def _resolve_rn_release(rn_cfg: dict) -> bool {
    return _to_bool(rn_cfg.get("release", False), False);
}

"""Resolve Android build backend (gradle or eas)."""
def _resolve_rn_android_builder(rn_cfg: dict) -> str {
    raw = str(rn_cfg.get("android_builder", "") or "").strip().lower();
    if raw == "" {
        if _to_bool(rn_cfg.get("use_eas_build", False), False) {
            return "eas";
        }
        return "gradle";
    }
    if raw in _RN_BUILDERS_ANDROID {
        return raw;
    }
    raise ValueError(
        f"Unsupported react-native android_builder '{raw}'. Supported: gradle, eas."
    );
}

"""Resolve iOS build backend (xcodebuild or eas)."""
def _resolve_rn_ios_builder(rn_cfg: dict) -> str {
    raw = str(rn_cfg.get("ios_builder", "") or "").strip().lower();
    if raw == "" {
        if _to_bool(rn_cfg.get("use_eas_build", False), False) {
            return "eas";
        }
        return "xcodebuild";
    }
    if raw in _RN_BUILDERS_IOS {
        return raw;
    }
    raise ValueError(
        f"Unsupported react-native ios_builder '{raw}'. Supported: xcodebuild, eas."
    );
}

"""Resolve EAS build profile name."""
def _resolve_rn_eas_profile(rn_cfg: dict, release: bool) -> str {
    raw = str(rn_cfg.get("eas_profile", "") or "").strip();
    if raw != "" {
        return raw;
    }
    return "production" if release else "preview";
}

"""Return True when OTA publish is explicitly enabled."""
def _resolve_rn_eas_update_enabled(rn_cfg: dict) -> bool {
    return _to_bool(rn_cfg.get("eas_update", rn_cfg.get("ota_update", False)), False);
}

"""Resolve EAS update branch name."""
def _resolve_rn_eas_update_branch(rn_cfg: dict, release: bool) -> str {
    raw = str(
        rn_cfg.get("eas_update_branch", rn_cfg.get("ota_update_branch", "")) or ""
    ).strip();
    if raw != "" {
        return raw;
    }
    return "production" if release else "preview";
}

"""Resolve optional EAS update message."""
def _resolve_rn_eas_update_message(rn_cfg: dict) -> str {
    return str(rn_cfg.get("eas_update_message", "") or "").strip();
}
