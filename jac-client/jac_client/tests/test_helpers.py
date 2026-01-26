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


def get_env_with_bun() -> dict[str, str]:
    """Get environment dict with bun in PATH."""
    env = os.environ.copy()
    bun_path = shutil.which("bun")
    if bun_path:
        bun_dir = str(Path(bun_path).parent)
        current_path = env.get("PATH", "")
        if bun_dir not in current_path:
            env["PATH"] = f"{bun_dir}:{current_path}"
    return env


# Backward compatibility alias
get_env_with_npm = get_env_with_bun


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
