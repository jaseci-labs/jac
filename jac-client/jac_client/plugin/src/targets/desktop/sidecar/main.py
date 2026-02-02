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
    --host HOST          Host to bind to (default: 127.0.0.1)
    --help               Show this help message
"""

from __future__ import annotations

import argparse
import socket
import sys
from pathlib import Path


def _find_free_port(host: str = "127.0.0.1") -> int:
    """Find and return a free port on the given host."""
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind((host, 0))
        return s.getsockname()[1]


def main():
    """Main entry point for the sidecar."""
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
        from jaclang.pycore.runtime import JacRuntime as Jac
    except ImportError as e:
        # Console not available (jaclang import failed)
        sys.stderr.write(f"Error: Failed to import Jac runtime: {e}\n")
        sys.stderr.write("  Make sure jaclang is installed: pip install jaclang\n")
        sys.exit(1)

    # Get the console now that jaclang is available
    from jaclang.cli.console import console

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

        # stderr: Tauri drops the stdout pipe after reading the port marker,
        # so any further stdout writes raise BrokenPipeError.
        console.print("Jac Sidecar starting...", style="bold")
        console.print(f"  Module: {module_name}", style="muted")
        console.print(f"  Base path: {base_path}", style="muted")
        console.print(f"  Server: http://{args.host}:{port}", style="muted")
        console.print("")

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
