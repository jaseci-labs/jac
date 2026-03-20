import os;
import re;
import from typing { Any }
import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
import from jac_scale.abstractions.models.sandbox_result { SandboxResult }
import from jac_scale.abstractions.models.sandbox_status { SandboxStatus, SandboxInfo }
import from jac_scale.abstractions.logger { Logger }

glob _UNSAFE_PATH_RE = re.compile(r"(\.\.[\\/]|[;|&`$'\"\\\n\r])");

def validate_sandbox_path(path: str) -> str {
    if not path or not path.strip() {
        raise ValueError("Path cannot be empty");
    }
    path = path.strip();
    if os.path.isabs(path) {
        raise ValueError("Absolute paths are not allowed");
    }
    normalized = str(os.path.normpath(path));
    if normalized.startswith("..") or "/../" in normalized or normalized == ".." {
        raise ValueError("Path traversal is not allowed");
    }
    if _UNSAFE_PATH_RE.search(path) {
        raise ValueError("Path contains unsafe characters");
    }
    return normalized;
}

obj SandboxEnvironment {
    has config: SandboxConfig,
        logger: (Logger | None) = None;

    def create(user_id: str, project_id: str, code_path: str) -> SandboxResult;
    def stop(sandbox_id: str) -> None;
    def status(sandbox_id: str) -> SandboxStatus;
    def destroy(sandbox_id: str) -> None;
    def list_sandboxes(user_id: str) -> list[SandboxInfo];
    def cleanup_expired -> int;
    def logs(sandbox_id: str, offset: int = 0) -> dict;
    def write_file(sandbox_id: str, path: str, content: str) -> dict;
    def read_file(sandbox_id: str, path: str) -> dict;
    def delete_file(sandbox_id: str, path: str) -> dict;
    def list_files(sandbox_id: str, path: str = ".") -> dict;
    def exec_command(sandbox_id: str, command: str, timeout: int = 30) -> dict;
}
