"""Shared test utilities for jac-client tests."""

from __future__ import annotations

import os
import shutil
import socket
import sys
from pathlib import Path


def get_free_port() -> int:
    """Get a free port by binding to port 0 and releasing it."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("", 0))
        s.listen(1)
        port = s.getsockname()[1]
    return port


def get_jac_command() -> list[str]:
    """Get the jac command with proper path handling."""
    jac_path = shutil.which("jac")
    if jac_path:
        return [jac_path]
    return [sys.executable, "-m", "jaclang"]


def get_env_with_npm() -> dict[str, str]:
    """Get environment dict with npm in PATH."""
    env = os.environ.copy()
    npm_path = shutil.which("npm")
    if npm_path:
        npm_dir = str(Path(npm_path).parent)
        current_path = env.get("PATH", "")
        if npm_dir not in current_path:
            env["PATH"] = f"{npm_dir}:{current_path}"
    # Also check common nvm locations
    nvm_dir = os.environ.get("NVM_DIR", os.path.expanduser("~/.nvm"))
    nvm_node_bin = Path(nvm_dir) / "versions" / "node"
    if nvm_node_bin.exists():
        for version_dir in nvm_node_bin.iterdir():
            bin_dir = version_dir / "bin"
            if bin_dir.exists() and (bin_dir / "npm").exists():
                current_path = env.get("PATH", "")
                if str(bin_dir) not in current_path:
                    env["PATH"] = f"{bin_dir}:{current_path}"
                break
    return env


def wait_for_port(host: str, port: int, timeout: float = 60.0) -> None:
    """Block until a TCP port is accepting connections or timeout."""
    import time

    deadline = time.time() + timeout
    while time.time() < deadline:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            sock.settimeout(0.5)
            try:
                sock.connect((host, port))
                return
            except OSError:
                time.sleep(0.5)
    raise TimeoutError(f"Timed out waiting for {host}:{port}")
