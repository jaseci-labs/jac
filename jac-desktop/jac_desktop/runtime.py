"""PyTauri desktop shell runtime for Jac projects.

Invoked by the stable ``src-pytauri/app.py`` stub (or ``python -m jac_desktop.runtime``).
Reads project config from ``jac.toml`` at startup; dev mode may override the API base URL
via ``JAC_PYTAURI_API_BASE_URL``.
"""

from __future__ import annotations

import importlib
import json
import os
import subprocess
import sys
import threading
from pathlib import Path
from typing import Any

from anyio.from_thread import start_blocking_portal
from jac_desktop.config_loader import get_desktop_config
from jac_desktop.helpers.desktop_helpers import (
    SIDECAR_BOOT_TIMEOUT,
    _get_toml_api_base_url,
)
from pytauri import Commands, WebviewUrl
from pytauri.webview import WebviewWindowBuilder
from pytauri_wheel.lib import builder_factory, context_factory

import jaclang  # noqa: F401 — bootstrap .jac meta path before jac_desktop imports

API_BASE_URL_ENV = "JAC_PYTAURI_API_BASE_URL"

_sidecar_proc: subprocess.Popen[str] | None = None
_api_base_url: str | None = None
_sidecar_error: str | None = None
commands = Commands()


def _resolve_configured_base_url(project_dir: Path) -> str:
    """API base URL from env override (dev) or jac.toml; empty means use sidecar."""
    env_override = os.environ.get(API_BASE_URL_ENV, "").strip()
    if env_override:
        return env_override
    return _get_toml_api_base_url(project_dir)


def _load_tauri_plugins(project_dir: Path) -> list[Any]:
    """Import and init pytauri_plugins requested in [plugins.desktop].tauri_plugins."""
    try:
        plugin_ids = get_desktop_config(project_dir).get_tauri_plugins_config()
    except Exception as exc:
        sys.stderr.write(f"[pytauri-shell] failed to read tauri plugin config: {exc}\n")
        return []

    plugins: list[Any] = []
    for name in sorted(set(plugin_ids)):
        try:
            mod = importlib.import_module(f"pytauri_plugins.{name}")
            plugins.append(mod.init())
        except Exception as exc:
            sys.stderr.write(
                f"[pytauri-shell] failed to load tauri plugin '{name}': {exc}\n"
            )
    return plugins


def _find_sidecar(shell_dir: Path) -> Path | None:
    """Locate the bundled sidecar binary."""
    if os.name == "nt":
        candidates = [
            "binaries/jac-sidecar/jac-sidecar.exe",
            "binaries/jac-sidecar.exe",
            "binaries/jac-sidecar.bat",
        ]
    else:
        candidates = [
            "binaries/jac-sidecar/jac-sidecar",
            "binaries/jac-sidecar",
            "binaries/jac-sidecar.sh",
        ]
    for rel in candidates:
        path = shell_dir / rel
        if path.exists():
            return path
    return None


def _find_module_path(shell_dir: Path, project_dir: Path) -> Path | None:
    """Find main.jac next to or above the project."""
    bundled = shell_dir / "jac" / "main.jac"
    if bundled.exists():
        return bundled
    current = project_dir
    for _ in range(10):
        module_path = current / "main.jac"
        if module_path.exists():
            return module_path
        if current.parent == current:
            break
        current = current.parent
    return None


def _data_path() -> Path:
    """Writable runtime data dir."""
    if os.name == "nt":
        base = os.environ.get("LOCALAPPDATA") or os.path.join(
            os.environ.get("USERPROFILE", "."), "AppData", "Local"
        )
        return Path(base) / "jac-app"
    return Path(os.environ.get("HOME", ".")) / ".local" / "share" / "jac-app"


def _start_sidecar(
    shell_dir: Path, project_dir: Path, configured_base_url: str
) -> None:
    """Launch the sidecar and discover its port from stdout."""
    global _sidecar_proc, _api_base_url, _sidecar_error

    if configured_base_url:
        _api_base_url = configured_base_url
        sys.stderr.write(
            f"[pytauri-shell] using configured API base URL: {_api_base_url}\n"
        )
        return

    if os.environ.get("JAC_PYTAURI_NO_SIDECAR") == "1":
        sys.stderr.write(
            "[pytauri-shell] sidecar disabled via JAC_PYTAURI_NO_SIDECAR\n"
        )
        return

    sidecar = _find_sidecar(shell_dir)
    if sidecar is None:
        sys.stderr.write(
            "[pytauri-shell] sidecar binary not found; skipping autostart\n"
        )
        return

    cmd = [str(sidecar)]
    module_path = _find_module_path(shell_dir, project_dir)
    if module_path is not None:
        cmd += [
            "--module-path",
            str(module_path),
            "--base-path",
            str(module_path.parent),
        ]
    else:
        cmd += ["--module-path", "main.jac"]
    cmd += ["--port", "0", "--host", "127.0.0.1"]
    cmd += ["--data-path", str(_data_path())]

    env = os.environ.copy()
    for key in ("PYTHONHOME", "PYTHONPATH", "PYTHONDONTWRITEBYTECODE"):
        env.pop(key, None)

    sys.stderr.write(f"[pytauri-shell] spawning sidecar: {sidecar}\n")
    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=sys.stderr,
        env=env,
        text=True,
    )
    _sidecar_proc = proc

    discovered_port: list[str | None] = [None]
    discovered_failure: list[str | None] = [None]

    def _read_sidecar_stdout() -> None:
        assert proc.stdout is not None
        for line in proc.stdout:
            sys.stderr.write(f"[sidecar] {line}")
            sys.stderr.flush()
            if line.startswith("JAC_SIDECAR_FAILED="):
                discovered_failure[0] = line.split("=", 1)[1].strip()
            elif line.startswith("JAC_SIDECAR_PORT="):
                try:
                    port = int(line.split("=", 1)[1].strip())
                    discovered_port[0] = f"http://127.0.0.1:{port}"
                except ValueError:
                    pass

    thread = threading.Thread(target=_read_sidecar_stdout, daemon=True)
    thread.start()
    thread.join(timeout=SIDECAR_BOOT_TIMEOUT)

    if discovered_failure[0]:
        _sidecar_error = discovered_failure[0]
        _api_base_url = None
        sys.stderr.write(f"[pytauri-shell] sidecar failed: {_sidecar_error}\n")
        _stop_sidecar()
        return

    if discovered_port[0] is None:
        sys.stderr.write(
            f"[pytauri-shell] sidecar did not report JAC_SIDECAR_PORT "
            f"within {SIDECAR_BOOT_TIMEOUT}s\n"
        )
        _sidecar_error = f"sidecar did not report port within {SIDECAR_BOOT_TIMEOUT}s"
        _stop_sidecar()
        return

    _api_base_url = discovered_port[0]
    sys.stderr.write(f"[pytauri-shell] sidecar ready on {_api_base_url}\n")


def _stop_sidecar() -> None:
    global _sidecar_proc
    if _sidecar_proc is None:
        return
    try:
        _sidecar_proc.terminate()
        try:
            _sidecar_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            _sidecar_proc.kill()
    except Exception as exc:
        sys.stderr.write(f"[pytauri-shell] error stopping sidecar: {exc}\n")
    finally:
        _sidecar_proc = None


@commands.command()
async def get_api_url() -> bytes:
    """Frontend fallback when the init_script global is not enough."""
    return json.dumps(_api_base_url or "").encode("utf-8")


def _build_tauri_config(dev_server: str | None) -> dict[str, Any]:
    """Runtime tauri config overrides."""
    cfg: dict[str, Any] = {"app": {"windows": []}}
    if dev_server:
        cfg["build"] = {"frontendDist": dev_server}
    return cfg


def _read_window_config(shell_dir: Path) -> dict[str, Any]:
    """Read window block from tauri.conf.json."""
    conf = shell_dir / "tauri.conf.json"
    try:
        data = json.loads(conf.read_text(encoding="utf-8"))
        wins = data.get("app", {}).get("windows") or []
        if wins:
            return wins[0]
    except Exception as exc:
        sys.stderr.write(
            f"[pytauri-shell] failed to read window config from {conf}: {exc}\n"
        )
    return {}


def run_shell(shell_dir: Path | None = None) -> int:
    """Run the PyTauri desktop shell for a Jac project."""
    shell_dir = (shell_dir or Path.cwd()).resolve()
    project_dir = shell_dir.parent
    configured_base_url = _resolve_configured_base_url(project_dir)
    tauri_plugins = _load_tauri_plugins(project_dir)
    dev_server = os.environ.get("DEV_SERVER")

    _start_sidecar(shell_dir, project_dir, configured_base_url)
    try:
        with start_blocking_portal("asyncio") as portal:
            ctx = context_factory(
                shell_dir, tauri_config=_build_tauri_config(dev_server)
            )

            init_parts: list[str] = []
            if _sidecar_error:
                init_parts.append(
                    "globalThis.__JAC_SIDECAR_ERROR__ = " + json.dumps(_sidecar_error)
                )
            if _api_base_url:
                init_parts.append(
                    "globalThis.__JAC_API_BASE_URL__ = " + json.dumps(_api_base_url)
                )
            init_script = ";".join(init_parts) + (";" if init_parts else "")

            window = _read_window_config(shell_dir)

            def setup(handle: object) -> None:
                kwargs: dict[str, Any] = {}
                if init_script:
                    kwargs["initialization_script"] = init_script
                if "title" in window:
                    kwargs["title"] = window["title"]
                if "width" in window and "height" in window:
                    kwargs["inner_size"] = (
                        float(window["width"]),
                        float(window["height"]),
                    )
                if "minWidth" in window and "minHeight" in window:
                    kwargs["min_inner_size"] = (
                        float(window["minWidth"]),
                        float(window["minHeight"]),
                    )
                if "resizable" in window:
                    kwargs["resizable"] = bool(window["resizable"])
                WebviewWindowBuilder.build(
                    handle,
                    str(window.get("label", "main")),
                    WebviewUrl.App(Path("index.html")),
                    **kwargs,
                )

            builder_kwargs: dict[str, Any] = {
                "context": ctx,
                "invoke_handler": commands.generate_handler(portal),
                "setup": setup,
            }
            if tauri_plugins:
                builder_kwargs["plugins"] = tauri_plugins

            app = builder_factory().build(**builder_kwargs)
            return app.run_return()
    finally:
        _stop_sidecar()


def main() -> int:
    """CLI entry when run as ``python -m jac_desktop.runtime``."""
    return run_shell()


if __name__ == "__main__":
    sys.exit(main())
