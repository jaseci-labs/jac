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
import os
import signal
import socket
import sys
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pluggy import PluginManager
from types import FrameType


def _signal_handler(signum: int, frame: FrameType | None) -> None:
    """Handle signals and log them to stderr."""
    sig_name = (
        signal.Signals(signum).name if hasattr(signal, "Signals") else str(signum)
    )
    sys.stderr.write(f"[sidecar] Received signal: {sig_name} ({signum})\n")
    sys.stderr.flush()
    sys.exit(128 + signum)


# Register signal handlers early
# Note: SIGHUP doesn't exist on Windows, so we check for availability
_signals_to_handle = [signal.SIGTERM, signal.SIGINT]
if hasattr(signal, "SIGHUP"):
    _signals_to_handle.append(signal.SIGHUP)

for sig in _signals_to_handle:
    with contextlib.suppress(OSError, ValueError):
        signal.signal(sig, _signal_handler)


# Set JAC_USE_STDERR before any jaclang imports.
# This redirects console output to stderr since Tauri closes stdout after reading the port.
os.environ["JAC_USE_STDERR"] = "1"


def _find_free_port(host: str = "127.0.0.1") -> int:
    """Find and return a free port on the given host."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return s.getsockname()[1]


def _register_frozen_plugins(plugin_manager: PluginManager) -> None:
    """Register all Jac plugins manually for PyInstaller frozen apps.

    Entry point discovery fails in frozen apps, so we register each plugin
    explicitly. jac_client, jac_scale, and byllm all have __init__.py at
    every directory level (like standard Python packages), so
    importlib.import_module works normally with JacMetaImporter handling
    individual .jac files.
    """
    plugins = [
        ("jac_scale.plugin", "JacCmd", "scale"),
        ("jac_client.plugin.client", "JacClient", "client"),
        ("byllm.plugin", "JacRuntime", "byllm"),
    ]
    for module_path, class_name, name in plugins:
        try:
            import importlib

            mod = importlib.import_module(module_path)
            cls = getattr(mod, class_name)
            if not plugin_manager.is_registered(cls):
                plugin_manager.register(cls, name=name)
                sys.stderr.write(f"[sidecar] Registered {name} plugin\n")
        except ImportError as e:
            import traceback

            sys.stderr.write(f"[sidecar] {name} not bundled: {e}\n")
            traceback.print_exc(file=sys.stderr)
        except Exception as e:
            import traceback

            sys.stderr.write(f"[sidecar] {name} registration error: {e}\n")
            traceback.print_exc(file=sys.stderr)


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

            _register_frozen_plugins(plugin_manager)
        except Exception:
            pass

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

    port = args.port
    if port == 0:
        port = _find_free_port(args.host)

    # Determine base path
    if args.base_path:
        base_path = Path(args.base_path).resolve()
    else:
        # Try to find project root (look for jac.toml)
        base_path = Path.cwd()
        for parent in [base_path] + list(base_path.parents):
            if (parent / "jac.toml").exists():
                base_path = parent
                break

    # Resolve module path
    module_path = Path(args.module_path)
    if not module_path.is_absolute():
        module_path = base_path / module_path

    if not module_path.exists():
        # Console not yet available (jaclang not imported)
        sys.stderr.write(f"Error: Module file not found: {module_path}\n")
        sys.stderr.write(f"  Base path: {base_path}\n")
        sys.exit(1)

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
        sys.exit(1)

    # Register plugins manually for PyInstaller bundles.
    # Entry point discovery fails in frozen apps, so we register explicitly.
    if getattr(sys, "frozen", False):
        _register_frozen_plugins(plugin_manager)

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
        sys.exit(1)

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
            sys.exit(1)
    except Exception as e:
        console.error(f"Failed to load module '{module_name}': {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)

    # Create and start the API server
    try:
        # Get server class (allows plugins like jac-scale to provide enhanced server)
        server_class = Jac.get_api_server_class()
        server = server_class(
            module_name=module_name, port=port, base_path=str(base_path)
        )

        # MUST be raw stdout — Tauri host reads this line to discover the port.
        # Cannot use console here; Tauri parses this exact format.
        sys.stdout.write(f"JAC_SIDECAR_PORT={port}\n")
        sys.stdout.flush()

        # Check if server was created properly
        if server.server is None:
            console.error("Server socket not created")
            sys.exit(1)

        # Start the server (blocks until interrupted)
        # no_client=True: client bundle is already embedded in the Tauri webview
        server.start(dev=False, no_client=True)

    except KeyboardInterrupt:
        console.print("\nShutting down sidecar...", style="muted")
        sys.exit(0)
    except Exception as e:
        console.error(f"Server failed to start: {e}")
        import traceback

        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
