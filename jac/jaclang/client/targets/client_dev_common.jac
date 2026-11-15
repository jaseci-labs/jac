import os;
import shutil;
import socket;
import subprocess;
import from pathlib { Path }
import from typing { Optional, cast }

def port_bind_error(port: int) -> Optional[str];

def assert_port_available(port: int, role: str, failure_hint: str) -> None;

def resolve_port_or_next_available(
    start_port: int,
    role: str,
    reserved: Optional[list[int]] = None,
    max_scan: int = 200
) -> int;

def setup_android_port_reverse_common(ports: list[int], timeout: int = 5) -> None;

def ensure_watchdog_common(target_name: str) -> bool;

def start_backend_server_common(entry_file: Path, project_dir: Path, port: int) -> any;

def prepare_vite_dev_compilation(
    project_dir: Path, entry_file: Path
) -> tuple[ViteBundler, ViteCompiler];

obj _ClientHmrHandler {
    has compiler: any,
        entry_file: Path,
        project_dir: Path;

    def on_event(evt: FileChangeEvent) -> None;
}

def dev_proxy_paths(
    project_dir: Path, entry_file: Path
) -> tuple[list[str], list[str]];


def invalidate_runtime_module_cache(paths: list[str]) -> None;

def stop_dev_watcher(watcher: any);

def terminate_dev_processes(
    processes: list[subprocess.Popen[bytes] | None],
    timeout: int = SUBPROCESS_TIMEOUT_SHORT
);

def install_dev_signal_handlers;
