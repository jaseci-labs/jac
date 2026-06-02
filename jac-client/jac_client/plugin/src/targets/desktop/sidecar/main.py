#!/usr/bin/env python3
"""
Jac Sidecar Entry Point

This is the entry point for the Jac backend sidecar.
It launches the Jac runtime and starts an HTTP API server.

Usage:
    python -m jac_client.plugin.src.targets.desktop.sidecar.main [OPTIONS]
    # Or via wrapper script: ./jac-sidecar.sh [OPTIONS]

Options:
    --module-path PATH    Path to the .jac module file (default: main.jac)
    --port PORT          Port to bind the API server (default: 8000, 0 = auto)
    --base-path PATH     Base path for the project (default: current directory)
    --data-path PATH     Writable path for runtime data (default: ~/.local/share/jac-app/.jac)
    --host HOST          Host to bind to (default: 127.0.0.1)
    --help               Show this help message
"""

from __future__ import annotations

import argparse
import contextlib
import importlib
import os
import signal
import socket
import sys
from pathlib import Path
from types import FrameType
from typing import TYPE_CHECKING, Any, NamedTuple, Protocol

_SIDECAR_DIR = Path(__file__).resolve().parent

if TYPE_CHECKING:
    from pluggy import PluginManager


class FrozenPluginSpec(NamedTuple):
    """How to register one Jac plugin in a PyInstaller-frozen sidecar."""

    module_path: str
    class_name: str
    entry_name: str
    config_key: str | None = None


_PRIMARY_ENTRY_BY_CONFIG_KEY: dict[str, str] = {
    "jac_scale": "scale",
    "byllm": "byllm",
    "jac_mcp": "mcp",
    "jac_coder": "coder",
}
_FALLBACK_REGISTRY: dict[str, FrozenPluginSpec] = {
    "jac_scale": FrozenPluginSpec("jac_scale.plugin", "JacCmd", "scale", "jac_scale"),
    "byllm": FrozenPluginSpec("byllm.plugin", "JacRuntime", "byllm", "byllm"),
    "jac_mcp": FrozenPluginSpec("jac_mcp.plugin", "JacCmd", "mcp", "jac_mcp"),
    "jac_coder": FrozenPluginSpec("jac_coder.plugin", "JacCmd", "coder", "jac_coder"),
}
_CORE_PLUGINS: tuple[FrozenPluginSpec, ...] = (
    FrozenPluginSpec("jac_client.plugin.client", "JacClient", "serve"),
)


def _normalize_config_key(name: str) -> str:
    return name.replace("-", "_").lower()


def _default_plugins_config() -> dict[str, bool]:
    return {
        "jac_scale": True,
        "byllm": True,
        "jac_coder": True,
        "jac_mcp": True,
    }


def _is_enabled(value: object) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() not in ("false", "0", "no", "off", "")
    return bool(value)


def _jac_toml_candidates(base_path: Path | None) -> list[Path]:
    candidates: list[Path] = []
    if base_path is not None:
        candidates.append(base_path / "jac.toml")
    meipass = getattr(sys, "_MEIPASS", None)
    if meipass:
        candidates.append(Path(meipass) / "jac.toml")
    return candidates


def load_sidecar_plugins_config(base_path: Path | None = None) -> dict[str, bool]:
    merged: dict[str, object] = dict(_default_plugins_config())
    for path in _jac_toml_candidates(base_path):
        if not path.is_file():
            continue
        try:
            import tomllib

            with open(path, "rb") as handle:
                data = tomllib.load(handle)
        except Exception as exc:
            sys.stderr.write(
                f"[sidecar] failed to load plugin config from {path}: {exc}\n"
            )
            continue
        desktop = data.get("plugins", {}).get("desktop", {})
        if not isinstance(desktop, dict):
            continue
        raw = desktop.get("plugins", {})
        if isinstance(raw, dict):
            merged.update(raw)
        break
    return {str(key): _is_enabled(value) for key, value in merged.items()}


def _parse_entry_point_value(value: str) -> tuple[str, str] | None:
    module_path, sep, class_name = value.partition(":")
    if not sep or not module_path or not class_name:
        return None
    return module_path, class_name


def _build_registry_from_entry_points() -> dict[str, FrozenPluginSpec]:
    registry: dict[str, FrozenPluginSpec] = {}
    try:
        from importlib.metadata import entry_points

        eps = entry_points(group="jac")
    except Exception as exc:
        sys.stderr.write(f"[sidecar] failed to discover jac entry points: {exc}\n")
        return registry

    for ep in eps:
        dist = getattr(ep, "dist", None)
        dist_name = getattr(dist, "name", "") if dist else ""
        if not dist_name:
            continue
        config_key = _normalize_config_key(dist_name)
        primary = _PRIMARY_ENTRY_BY_CONFIG_KEY.get(config_key)
        if primary is not None and ep.name != primary:
            continue
        if primary is None and (
            ep.name.endswith("_plugin_config") or ep.name.endswith("_plugin")
        ):
            continue
        parsed = _parse_entry_point_value(ep.value)
        if parsed is None:
            continue
        module_path, class_name = parsed
        registry[config_key] = FrozenPluginSpec(
            module_path=module_path,
            class_name=class_name,
            entry_name=ep.name,
            config_key=config_key,
        )
    return registry


def _resolve_registry() -> dict[str, FrozenPluginSpec]:
    dynamic = _build_registry_from_entry_points()
    resolved = dict(_FALLBACK_REGISTRY)
    resolved.update(dynamic)
    return resolved


def resolve_frozen_plugin_specs(
    plugins_config: dict[str, bool] | None = None,
    base_path: Path | None = None,
) -> list[FrozenPluginSpec]:
    if plugins_config is None:
        plugins_config = load_sidecar_plugins_config(base_path)

    registry = _resolve_registry()
    specs: list[FrozenPluginSpec] = list(_CORE_PLUGINS)
    for config_key, enabled in plugins_config.items():
        if not enabled:
            continue
        spec = registry.get(config_key)
        if spec is None:
            continue
        specs.append(spec)

    seen: set[tuple[str, str, str]] = set()
    unique: list[FrozenPluginSpec] = []
    for spec in specs:
        key = (spec.module_path, spec.class_name, spec.entry_name)
        if key in seen:
            continue
        seen.add(key)
        unique.append(spec)
    return unique


def _register_spec(plugin_manager: PluginManager, spec: FrozenPluginSpec) -> None:
    label = spec.config_key or spec.entry_name
    try:
        mod = importlib.import_module(spec.module_path)
        cls = getattr(mod, spec.class_name)
        if plugin_manager.is_registered(cls):
            return
        plugin_manager.register(cls, name=spec.entry_name)
        sys.stderr.write(f"[sidecar] Registered {label} plugin\n")
    except ImportError as exc:
        import traceback

        sys.stderr.write(f"[sidecar] {label} not bundled: {exc}\n")
        traceback.print_exc(file=sys.stderr)
    except Exception as exc:
        import traceback

        sys.stderr.write(f"[sidecar] {label} registration error: {exc}\n")
        traceback.print_exc(file=sys.stderr)


def register_frozen_plugins(
    plugin_manager: PluginManager,
    *,
    plugins_config: dict[str, bool] | None = None,
    base_path: Path | None = None,
) -> None:
    for spec in resolve_frozen_plugin_specs(plugins_config, base_path):
        _register_spec(plugin_manager, spec)


def _emit_sidecar_failure(reason: str) -> None:
    """Write failure marker to stdout for Tauri runtime (pipe may still be open)."""
    safe = reason.replace("\n", " ").replace("\r", " ")[:500]
    try:
        sys.stdout.write(f"JAC_SIDECAR_FAILED={safe}\n")
        sys.stdout.flush()
    except OSError:
        pass


def _exit_after_port(reason: str, code: int = 1) -> None:
    """Exit after port discovery, notifying the parent via JAC_SIDECAR_FAILED."""
    _emit_sidecar_failure(reason)
    raise SystemExit(code)


def _signal_handler(signum: int, frame: FrameType | None) -> None:
    """Handle signals and log them to stderr."""
    sig_name = (
        signal.Signals(signum).name if hasattr(signal, "Signals") else str(signum)
    )
    sys.stderr.write(f"[sidecar] Received signal: {sig_name} ({signum})\n")
    sys.stderr.flush()
    _emit_sidecar_failure(f"terminated by {sig_name}")
    raise SystemExit(128 + signum)


def _register_signal_handlers() -> None:
    """Register signal handlers after port discovery line is written."""
    signals_to_handle = [signal.SIGTERM, signal.SIGINT]
    if hasattr(signal, "SIGHUP"):
        signals_to_handle.append(signal.SIGHUP)

    for sig in signals_to_handle:
        with contextlib.suppress(OSError, ValueError):
            signal.signal(sig, _signal_handler)


# Set JAC_USE_STDERR before any jaclang imports.
# This redirects console output to stderr since Tauri closes stdout after reading the port.
os.environ["JAC_USE_STDERR"] = "1"


def _bind_listen_socket(host: str, port: int) -> tuple[socket.socket, int]:
    """Bind and listen on host/port (port=0 picks a free port). Returns (socket, port)."""
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.bind((host, 0) if port == 0 else (host, port))
    sock.listen()
    return sock, sock.getsockname()[1]


class _PreboundSocketServer(Protocol):
    server: Any

    def create_handler(self) -> type: ...


def _attach_prebound_socket(
    server: _PreboundSocketServer, listen_sock: socket.socket
) -> None:
    """Wire a pre-bound listen socket into the Jac API server backend."""
    from http.server import HTTPServer

    backend = server.server
    if backend is None:
        handler_class = server.create_handler()
        httpd = HTTPServer(
            server_address=("", 0),
            RequestHandlerClass=handler_class,
            bind_and_activate=False,
        )
        httpd.socket = listen_sock
        httpd.server_address = listen_sock.getsockname()
        server.server = httpd
        return

    if hasattr(backend, "run_server"):
        backend._prebound_listen_socket = listen_sock
        return

    if isinstance(backend, HTTPServer):
        if backend.socket is not None:
            backend.server_close()
        backend.socket = listen_sock
        backend.server_address = listen_sock.getsockname()


def _run_jac_cli():
    """Run jaclang CLI commands in-process (multi-mode sidecar support).

    When the sidecar is invoked with --jac-cli, it acts as a jac CLI proxy,
    routing commands to jaclang directly. This avoids needing a separate jac.exe.

    Usage: sidecar.exe --jac-cli create myproject --use template.jacpack --force
           sidecar.exe --jac-cli install
           sidecar.exe --jac-cli lsp
    """
    os.environ["NO_COLOR"] = "1"
    os.environ["PYTHONUTF8"] = "1"
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")

    # Register plugins manually for frozen apps (entry point discovery fails)
    if getattr(sys, "frozen", False):
        try:
            from jaclang.jac0core.runtime import plugin_manager

            register_frozen_plugins(plugin_manager)
        except Exception as exc:
            sys.stderr.write(f"[sidecar] frozen plugin registration failed: {exc}\n")

    from jaclang.jac0core.cli_boot import start_cli

    # Remove --jac-cli from argv so jaclang sees clean args
    sys.argv = ["jac"] + sys.argv[2:]  # skip [sidecar.exe, --jac-cli, ...]
    start_cli()


def main():
    """Main entry point for the sidecar."""
    # Multi-mode: if --jac-cli is first arg, route to jaclang CLI
    if len(sys.argv) > 1 and sys.argv[1] == "--jac-cli":
        _run_jac_cli()
        return

    parser = argparse.ArgumentParser(
        description="Jac Backend Sidecar - Runs Jac API server in a bundled executable"
    )
    parser.add_argument(
        "--module-path",
        type=str,
        default="main.jac",
        help="Path to the .jac module file (default: main.jac)",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="Port to bind the API server (default: 8000, 0 = auto-assign free port)",
    )
    parser.add_argument(
        "--base-path",
        type=str,
        default=None,
        help="Base path for the project (default: current directory)",
    )
    parser.add_argument(
        "--host",
        type=str,
        default="127.0.0.1",
        help="Host to bind to (default: 127.0.0.1)",
    )
    parser.add_argument(
        "--data-path",
        type=str,
        default=None,
        help="Writable path for runtime data like database (default: ~/.local/share/jac-app/.jac)",
    )

    args = parser.parse_args()

    # Determine base path early so frozen plugin registration can read jac.toml.
    if args.base_path:
        base_path = Path(args.base_path).resolve()
    else:
        base_path = Path.cwd()
        for parent in [base_path] + list(base_path.parents):
            if (parent / "jac.toml").exists():
                base_path = parent
                break

    # Bind the listen socket before heavy boot so the port marker guarantees
    # the server is accepting connections when Tauri reads it.
    listen_sock, port = _bind_listen_socket(args.host, args.port)

    # MUST be raw stdout — Tauri host reads this line to discover the port.
    # Emit after bind+listen so the runtime invariant holds: when you see
    # JAC_SIDECAR_PORT=X, something is listening on that port.
    sys.stdout.write(f"JAC_SIDECAR_PORT={port}\n")
    sys.stdout.flush()
    _register_signal_handlers()

    # Resolve module path
    module_path = Path(args.module_path)
    if not module_path.is_absolute():
        module_path = base_path / module_path

    if not module_path.exists():
        # Console not yet available (jaclang not imported)
        sys.stderr.write(f"Error: Module file not found: {module_path}\n")
        sys.stderr.write(f"  Base path: {base_path}\n")
        _exit_after_port(f"module file not found: {module_path}")

    # Extract module name (without .jac extension)
    module_name = module_path.stem
    module_base = module_path.parent

    # Import Jac runtime and server
    try:
        # Import jaclang (must be installed via pip)
        from jaclang.jac0core.runtime import JacRuntime as Jac
        from jaclang.jac0core.runtime import plugin_manager
    except ImportError as e:
        # Console not available (jaclang import failed)
        sys.stderr.write(f"Error: Failed to import Jac runtime: {e}\n")
        sys.stderr.write("  Make sure jaclang is installed: pip install jaclang\n")
        _exit_after_port(f"failed to import Jac runtime: {e}")

    # Register plugins manually for PyInstaller bundles.
    # Entry point discovery fails in frozen apps, so we register explicitly.
    if getattr(sys, "frozen", False):
        register_frozen_plugins(plugin_manager, base_path=base_path)

    # Get the console now that jaclang is available
    from jaclang.cli.console import console

    # Determine data path (writable location for runtime data)
    # IMPORTANT: Must be set BEFORE Jac.jac_import so jac-scale config reads the correct path
    if args.data_path:
        data_path = Path(args.data_path).resolve()
    else:
        # Platform-specific default paths
        if sys.platform == "win32":
            # Windows: Use LOCALAPPDATA or fallback to USERPROFILE
            local_app_data = os.environ.get("LOCALAPPDATA")
            if local_app_data:
                data_path = Path(local_app_data) / "jac-app"
            else:
                data_path = Path.home() / "AppData" / "Local" / "jac-app"
        else:
            # Linux/macOS: ~/.local/share/jac-app
            data_path = Path.home() / ".local" / "share" / "jac-app"

    # Try to create data path with fallbacks
    fallback_paths = [
        data_path,
        Path.home() / ".jac-app",  # Fallback to home directory
    ]
    # Add platform-specific temp fallback
    if sys.platform == "win32":
        temp_dir = os.environ.get("TEMP") or os.environ.get("TMP")
        if temp_dir:
            fallback_paths.append(Path(temp_dir) / "jac-app")
    elif hasattr(os, "getuid"):
        fallback_paths.append(Path("/tmp") / f"jac-app-{os.getuid()}")

    data_path_created = False
    for candidate in fallback_paths:
        try:
            candidate.mkdir(parents=True, exist_ok=True)
            # Verify we can actually write to it
            test_file = candidate / ".write_test"
            test_file.touch()
            test_file.unlink()
            data_path = candidate
            data_path_created = True
            break
        except (OSError, PermissionError) as e:
            sys.stderr.write(f"[sidecar] Cannot use data path {candidate}: {e}\n")
            continue

    if not data_path_created:
        sys.stderr.write("Error: Could not create any writable data directory\n")
        sys.stderr.write(f"  Tried: {[str(p) for p in fallback_paths]}\n")
        _exit_after_port("could not create writable data directory")

    os.environ["JAC_DATA_PATH"] = str(data_path)

    # Load .env from bundled location (PyInstaller _MEIPASS) before changing CWD
    _meipass = getattr(sys, "_MEIPASS", None)
    if _meipass:
        bundled_env = Path(_meipass) / ".env"
        if bundled_env.is_file():
            try:
                from dotenv import load_dotenv

                load_dotenv(str(bundled_env), override=False)
                sys.stderr.write("[sidecar] Loaded .env from bundle\n")
            except ImportError:
                # dotenv not available, copy .env vars manually
                with open(bundled_env, encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            key, _, val = line.partition("=")
                            key = key.strip()
                            val = val.strip().strip('"').strip("'")
                            if key and key not in os.environ:
                                os.environ[key] = val

    # Change working directory to writable data path
    # This ensures relative paths like .jac/ work in read-only AppImage environments
    os.chdir(data_path)

    # Initialize Jac runtime
    try:
        # Import the module
        Jac.jac_import(target=module_name, base_path=str(module_base), lng="jac")
        if Jac.program.errors_had:
            console.error("Failed to compile module:")
            for error in Jac.program.errors_had:
                console.print(f"  {error}", style="error")
            _exit_after_port(f"failed to compile module '{module_name}'")
    except Exception as e:
        console.error(f"Failed to load module '{module_name}': {e}")
        import traceback

        traceback.print_exc()
        _exit_after_port(f"failed to load module '{module_name}': {e}")

    # Create and start the API server
    try:
        # Get server class (allows plugins like jac-scale to provide enhanced server)
        server_class = Jac.get_api_server_class()
        # port=0 skips postinit socket binding; we attach the pre-bound socket below.
        server = server_class(module_name=module_name, port=0, base_path=str(base_path))
        server.port = port
        _attach_prebound_socket(server, listen_sock)

        # Redirect stdout to stderr after port discovery.
        # Tauri drops the stdout pipe after reading JAC_SIDECAR_PORT, so any
        # subsequent stdout writes (e.g. console.print, sys.stdout.flush) would
        # crash with OSError: [Errno 22] Invalid argument. Redirecting to stderr
        # keeps all server logs visible in Tauri's stderr stream.
        sys.stdout = sys.stderr

        # Check if server was created properly
        if server.server is None:
            console.error("Server socket not created")
            _exit_after_port("server socket not created")

        # Start the server (blocks until interrupted)
        # no_client=True: client bundle is already embedded in the Tauri webview
        server.start(dev=False, no_client=True)

    except KeyboardInterrupt:
        console.print("\nShutting down sidecar...", style="muted")
        raise SystemExit(0) from None
    except SystemExit:
        raise
    except Exception as e:
        console.error(f"Server failed to start: {e}")
        import traceback

        traceback.print_exc()
        _exit_after_port(f"server failed to start: {e}")


if __name__ == "__main__":
    main()
