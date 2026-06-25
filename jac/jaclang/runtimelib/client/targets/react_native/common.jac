"""Shared constants and helpers for the React Native (Expo) target."""

import from pathlib { Path }
import from jaclang.runtimelib.client.targets.build_common {
    SUBPROCESS_TIMEOUT_BUILD_NATIVE
}
import from jaclang.runtimelib.client.targets.node_tooling_common {
    resolve_npx_or_bunx as _node_resolve_npx_or_bunx,
    run_manifest_install as _node_run_manifest_install
}
import from jaclang.runtimelib.client.targets.react_native.config {
    _load_react_native_config
}

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
# Defaults mirror the documented React Native target decisions in docs/REACT_NATIVE_ARCHITECTURE.md. Pinned
# versions guard against silent upstream drift breaking the scaffold; bump
# explicitly with a smoke test, not implicitly via "@latest".
glob DEFAULT_PROJECT_DIR_NAME = "mobile-rn",
     DEFAULT_APP_NAME = "main",
     DEFAULT_APP_SLUG = "jac-app",
     DEFAULT_APP_ID = "com.jac.app",
     EXPO_SDK_VERSION = "54",
     REACT_NATIVE_VERSION = "0.81.4",
     SUBPROCESS_TIMEOUT_BUILD: int = SUBPROCESS_TIMEOUT_BUILD_NATIVE;

"""Resolve npx or bunx for one-off CLI invocations."""
def resolve_npx -> str {
    return _node_resolve_npx_or_bunx();
}

"""Install all dependencies from the Expo project's package.json."""
def run_manifest_install(project_dir: Path) {
    _node_run_manifest_install(project_dir);
}

"""Project directory for the Expo scaffold, honoring config overrides (D11).

Reads ``[plugins.client.react_native].project_dir`` from ``jac.toml``.
Falls back to ``mobile-rn/`` when not set.
"""
def resolve_rn_project_dir(project_dir: Path) -> Path {
    cfg = _load_react_native_config(project_dir);
    custom = str(cfg.get("project_dir", "") or "").strip();
    if custom {
        # Treat relative paths as project-root-relative; pass absolute
        # paths through unchanged.
        p = Path(custom);
        if not p.is_absolute() {
            p = project_dir / p;
        }
        return p;
    }
    return project_dir / DEFAULT_PROJECT_DIR_NAME;
}

"""Normalize and validate react-native platform string.

Defaults to ``'android'``. Accepts ``'android'`` or ``'ios'``.
"""
def normalize_rn_platform(platform: str | None = None) -> str {
    if platform is None or platform.strip() == "" {
        return "android";
    }
    value = platform.lower().strip();
    if value in ("android", "ios") {
        return value;
    }
    raise ValueError(
        f"Unsupported react-native platform '{platform}'. " "Supported: android, ios."
    );
}
