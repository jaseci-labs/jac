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
# Defaults mirror the documented React Native target decisions in the jac-client
# reference (docs/docs/reference/plugins/jac-client.md). Pinned
# versions guard against silent upstream drift breaking the scaffold; bump
# explicitly with a smoke test, not implicitly via "@latest".
glob DEFAULT_PROJECT_DIR_NAME = "mobile-rn",
     DEFAULT_APP_NAME = "main",
     DEFAULT_APP_SLUG = "jac-app",
     DEFAULT_APP_ID = "com.jac.app",
     EXPO_SDK_VERSION = "54",
     REACT_NATIVE_VERSION = "0.81.4",
     # EAS CLI is versioned independently of the Expo SDK (it ships via
     # `npx eas-cli`, not the expo package). Pin its major separately so
     # eas.json's `cli.version` guardrail targets the right product.
     EAS_CLI_VERSION = "20",
     SUBPROCESS_TIMEOUT_BUILD: int = SUBPROCESS_TIMEOUT_BUILD_NATIVE;

def resolve_npx -> str {
    return _node_resolve_npx_or_bunx();
}

def run_manifest_install(project_dir: Path) {
    _node_run_manifest_install(project_dir);
}

def resolve_rn_project_dir(project_dir: Path) -> Path {
    cfg = _load_react_native_config(project_dir);
    custom = str(cfg.get("project_dir", "") or "").strip();
    if custom {
        p = Path(custom);
        if not p.is_absolute() {
            p = project_dir / p;
        }
        return p;
    }
    return project_dir / DEFAULT_PROJECT_DIR_NAME;
}

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
