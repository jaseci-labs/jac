"""
Jac Sidecar Entry Point

This is the entry point for the Jac backend sidecar.
It launches the Jac runtime and starts an HTTP API server.

Usage:
    python -m jac_client.plugin.src.targets.desktop.sidecar.main [OPTIONS]
    # Or via wrapper script: ./jac-sidecar.sh [OPTIONS]

Options:
    --module-path PATH    Path to the .jac module file (default: main.jac)
    --port PORT          Port to bind the API server (default: 8000)
    --base-path PATH     Base path for the project (default: current directory)
    --host HOST          Host to bind to (default: 127.0.0.1)
    --help               Show this help message
"""
import argparse;
import os;
import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
"""Main entry point for the sidecar."""
def main -> object {
    parser = argparse.ArgumentParser(
        description='Jac Backend Sidecar - Runs Jac API server in a bundled executable'
    );
    parser.add_argument(
        '--module-path',
        <>type=str,
        <>default='main.jac',
        help='Path to the .jac module file (default: main.jac)'
    );
    parser.add_argument(
        '--port',
        <>type=int,
        <>default=8000,
        help='Port to bind the API server (default: 8000)'
    );
    parser.add_argument(
        '--base-path',
        <>type=str,
        <>default=None,
        help='Base path for the project (default: current directory)'
    );
    parser.add_argument(
        '--host',
        <>type=str,
        <>default='127.0.0.1',
        help='Host to bind to (default: 127.0.0.1)'
    );
    args = parser.parse_args();
    if args.base_path {
        base_path = Path(args.base_path).resolve();
    } else {
        base_path = Path.cwd();
        for parent in ([base_path] + <>list(base_path.parents)) {
            if (parent / 'jac.toml').exists() {
                base_path = parent;
                break;
            }
        }
    }
    module_path = Path(args.module_path);
    if not module_path.is_absolute() {
        module_path = base_path / module_path;
    }
    if not module_path.exists() {
        console.print(f"Error: Module file not found: {module_path}", file=sys.stderr);
        console.print(f"  Base path: {base_path}", file=sys.stderr);
        sys.exit(1);
    }
    module_name = module_path.stem;
    module_base = module_path.parent;
    try {
        import from jaclang.pycore.runtime { JacRuntime as Jac }
        import from jaclang.runtimelib.server { JacAPIServer }
    } except ImportError as e {
        console.print(f"Error: Failed to import Jac runtime: {e}", file=sys.stderr);
        console.print('  Make sure jaclang is installed: pip install jaclang', file=sys.stderr);
        sys.exit(1);
    }
    try {
        Jac.jac_import(target=module_name, base_path=str(module_base), lng='jac');
        if Jac.program.errors_had {
            console.print('Error: Failed to compile module:', file=sys.stderr);
            for error in Jac.program.errors_had {
                console.print(f"  {error}", file=sys.stderr);
            }
            sys.exit(1);
        }
    } except Exception as e {
        console.print(f"Error: Failed to load module '{module_name}': {e}", file=sys.stderr);
        import traceback;
        traceback.print_exc();
        sys.exit(1);
    }
    try {
        ServerClass = Jac.get_api_server_class();
        server = ServerClass(
            module_name=module_name, port=args.port, base_path=str(base_path)
        );
        print(f"Jac Sidecar starting...");
        print(f"  Module: {module_name}");
        print(f"  Base path: {base_path}");
        print(f"  Server: http://{args.host}:{args.port}");
        print(f"Press Ctrl+C to stop the server");
        server.start(dev=False);
    } except KeyboardInterrupt {
        console.print('\nShutting down sidecar...');
        sys.exit(0);
    } except Exception as e {
        console.print(f"Error: Server failed to start: {e}", file=sys.stderr);
        import traceback;
        traceback.print_exc();
        sys.exit(1);
    }
}

with entry {
    if (__name__ == '__main__') {
        main();
    }
}

