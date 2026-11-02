import socket;
import from pathlib { Path }

glob DEFAULT_PROJECT_DIR_NAME = "mobile-rn",
     DEFAULT_APP_NAME = "main",
     DEFAULT_APP_SLUG = "jac-app",
     DEFAULT_APP_ID = "com.jac.app",
     EXPO_SDK_VERSION = "57",
     REACT_NATIVE_VERSION = "0.86.3",
     EAS_CLI_VERSION = "20",
     SUBPROCESS_TIMEOUT_BUILD: int = SUBPROCESS_TIMEOUT_BUILD_NATIVE;

def resolve_node_tool(project_dir: Path, tool: str) -> list[str];

def run_manifest_install(project_dir: Path);

def resolve_rn_project_dir(
    project_dir: Path, client_cfg: (JacClientConfig | None) = None
) -> Path;

def normalize_rn_platform(platform: str | None = None) -> str;

def detect_lan_ipv4 -> str | None;
