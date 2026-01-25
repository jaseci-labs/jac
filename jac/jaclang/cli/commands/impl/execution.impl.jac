"""Implementation of execution commands.

Direct implementations - no delegation to cli.jac.
"""

import marshal;
import os;
import sys;
import types;
import from typing { Any }

glob _runtime_initialized = False;

"""Initialize Jac runtime once on first use."""
def _ensure_jac_runtime -> None {
    global _runtime_initialized;
    if not _runtime_initialized {
        import from jaclang.pycore.runtime { JacRuntime as Jac }
        Jac.setup();
        _runtime_initialized = True;
    }
}

"""Re-discover jac.toml from the file's directory when an absolute/relative path is given.

This ensures that when running `jac start /path/to/project/main.jac` from any directory,
the jac.toml in /path/to/project/ is found and used for plugin configuration.
"""
def _discover_config_from_file(filename: str) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig, set_config }
    import from jaclang.project.dependencies { add_packages_to_path }

    file_path = Path(filename).resolve();
    file_dir = file_path.parent;

    # Re-discover config starting from the file's directory
    config = JacConfig.discover(start_path=file_dir);
    if config is not None {
        set_config(config);
        add_packages_to_path(config);
    }
}

"""Create JacRuntime and return the base path, module name, and runtime state.

This is the canonical function for setting up CLI execution context.
It handles base_path setup, closing any existing context, and creating a new one.
"""
def _proc_file(filename: str) -> tuple {
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    (base, mod) = os.path.split(filename);
    base = base or './';
    if filename.endswith('.jac') {
        mod = mod[:-4];
    } elif filename.endswith('.py') {
        mod = mod[:-3];
    } else {
        print('Not a valid file!\nOnly supports `.jac` and `.py`', file=sys.stderr);
        <>exit(1);
    }
    # Only set base path if not already set (allows tests to override)
    if not Jac.base_path_dir {
        Jac.set_base_path(base);
    }
    # CLI contexts use system_root (no user authentication)
    mach = Jac.create_j_context(user_root=None);
    Jac.set_context(mach);
    return (base, mod, mach);
}

"""Run the specified .jac file."""
impl run(filename: str, main: bool = True, cache: bool = True) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    # Re-discover config from the file's directory (handles absolute paths)
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];
    try {
        Jac.jac_import(
            target=mod,
            base_path=base,
            override_name='__main__' if main else None,
            lng=lng
        );
    } except Exception as e {
        import from jaclang.pycore.helpers { dump_traceback }
        print(dump_traceback(e), file=sys.stderr);
        mach.close();
        return 1;
    }
    mach.close();
    return 0;
}

"""Run the specified entrypoint function in the given .jac file."""
impl enter(
    filename: str,
    entrypoint: str,
    args: list = [],
    main: bool = True,
    <>root: str = '',
    <>node: str = ''
) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from jaclang.pycore.constructs { WalkerArchetype }
    # Re-discover config from the file's directory (handles absolute paths)
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    # Set user root if provided (for permission boundary)
    if <>root {
        mach.set_user_root(<>root);
    }
    if filename.endswith('.jac') {
        ret_module = Jac.jac_import(
            target=mod, base_path=base, override_name='__main__' if main else None
        );
    } else {
        mach.close();
        print('Not a valid file!\nOnly supports `.jac`', file=sys.stderr);
        return 1;
    }
    if ret_module {
        (loaded_mod, ) = ret_module;
        if not loaded_mod {
            print('Errors occurred while importing the module.', file=sys.stderr);
            mach.close();
            return 1;
        } else {
            archetype = getattr(loaded_mod, entrypoint)(*args);
            mach.set_entry_node(<>node);
            if (
                isinstance(archetype, WalkerArchetype)
                and Jac.check_read_access(mach.entry_node)
            ) {
                Jac.spawn(mach.entry_node.archetype, archetype);
            }
        }
    }
    mach.close();
    return 0;
}

"""Start REST API server for the specified .jac file."""
impl start(
    filename: str,
    port: int = 8000,
    main: bool = True,
    faux: bool = False,
    dev: bool = False,
    api_port: int = 0,
    no_client: bool = False
) -> int {
    _ensure_jac_runtime();
    import from jaclang.pycore.runtime { JacRuntime as Jac }
    import from pathlib { Path }
    if not Path(filename).exists() {
        if filename == "main.jac" {
            print(
                f"Error: File 'main.jac' not found in the current directory.",
                file=sys.stderr
            );
            print(f"  Current directory: {os.getcwd()}", file=sys.stderr);
            print(
                "  Please specify a file: jac start <filename.jac> or make sure main.jac exists in the current directory",
                file=sys.stderr
            );
        } else {
            print(f"Error: File '{filename}' not found.", file=sys.stderr);
            print(f"  Current directory: {os.getcwd()}", file=sys.stderr);
            print("  Please check the file path and try again.", file=sys.stderr);
        }
        return 1;
    }
    # Re-discover config from the file's directory (handles absolute paths)
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];
    try {
        Jac.jac_import(target=mod, base_path=base, lng=lng);
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                print(f"Error: {error}", file=sys.stderr);
            }
            mach.close();
            return 1;
        }
    } except Exception as e {
        import from jaclang.pycore.helpers { dump_traceback }
        print(f"Error loading {filename}: {e}", file=sys.stderr);
        print(dump_traceback(e), file=sys.stderr);
        mach.close();
        return 1;
    }
    # Determine actual port (for dev mode with client, Vite takes --port, API takes --api-port)
    if dev and not no_client {
        # Vite dev server gets the main port, API server gets api_port or port+1
        vite_port = port;
        actual_api_port = api_port if api_port > 0 else port + 1;
    } else {
        actual_api_port = port;
        vite_port = 0;
    }
    # Get server class from plugin hook (allows jac-scale to provide enhanced server)
    ServerClass = Jac.get_api_server_class();
    server = ServerClass(module_name=mod, port=actual_api_port, base_path=base);
    if faux {
        try {
            server.print_endpoint_docs();
        } except Exception as e {
            import from jaclang.pycore.helpers { dump_traceback }
            print(f"Error generating endpoint documentation: {e}", file=sys.stderr);
            print(dump_traceback(e), file=sys.stderr);
            mach.close();
            return 1;
        } finally {
            # Properly close the HTTP server socket (always executed)
            if server?.server and server.server {
                server.server.server_close();
            }
        }
        mach.close();
        return 0;
    }
    # Initialize HMR if dev mode enabled
    hot_reloader = None;
    vite_process = None;
    if dev {
        # Check if watchdog is available in the project environment
        if not _check_watchdog_available() {
            print(
                "\n  Error: --dev requires 'watchdog' package to be installed.\n",
                file=sys.stderr
            );
            print(
                "  The 'watchdog' package is listed in [dev-dependencies] of jac.toml.",
                file=sys.stderr
            );
            print("  Install it by running:\n", file=sys.stderr);
            print("    jac install --dev\n", file=sys.stderr);
            mach.close();
            return 1;
        }
        try {
            import from jaclang.runtimelib.hmr { HotReloader }
            import from jaclang.runtimelib.watcher { JacFileWatcher }

            watcher = JacFileWatcher(watch_paths=[base]);
            hot_reloader = HotReloader(
                base_path=base, module_name=mod, watcher=watcher
            );
            hot_reloader.start();
            # Connect the hot reloader to the server for HMR support
            if server?.enable_hmr {
                server.enable_hmr(hot_reloader);
            }
        } except ImportError as e {
            print(f"Error: Could not initialize HMR: {e}", file=sys.stderr, flush=True);
            print(
                "\nMake sure 'watchdog' is installed by running: jac install --dev",
                file=sys.stderr,
                flush=True
            );
            mach.close();
            return 1;
        } except Exception as e {
            print(
                f"Warning: HMR initialization failed: {e}", file=sys.stderr, flush=True
            );
        }
        # Start Vite dev server if client mode enabled
        if not no_client {
            vite_process = _start_vite_dev_server(base, vite_port, actual_api_port);
        }
    }
    # Print startup message
    _print_startup_message(dev, no_client, port, actual_api_port, base);
    try {
        server.start(dev=dev);
        return 0;
    } except KeyboardInterrupt {
        print('\nShutting down...');
        if hot_reloader {
            hot_reloader.stop();
        }
        if vite_process {
            vite_process.terminate();
            vite_process.wait(timeout=5);
        }
        mach.close();
        return 0;
    } except Exception as e {
        import from jaclang.pycore.helpers { dump_traceback }
        print(f"Server error: {e}", file=sys.stderr);
        print(dump_traceback(e), file=sys.stderr);
        if hot_reloader {
            hot_reloader.stop();
        }
        if vite_process {
            vite_process.terminate();
        }
        mach.close();
        return 1;
    }
}

"""Check if watchdog is available in the project's .jac environment."""
def _check_watchdog_available -> bool {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }

    config = get_config();
    if config is None {
        # No project, check global availability
        try {
            import watchdog;
            return True;
        } except ImportError {
            return False;
        }
    }
    # Check if watchdog is installed in the project's packages directory
    packages_dir = config.get_packages_dir();
    if packages_dir.exists() {
        # Add packages dir to path temporarily to check
        import sys;
        original_path = sys.path.copy();
        sys.path.insert(0, str(packages_dir));
        try {
            import watchdog;
            return True;
        } except ImportError { } finally {
            sys.path = original_path;
        }
    }
    # Fallback: check if globally available
    try {
        import watchdog;
        return True;
    } except ImportError {
        return False;
    }
}

"""Get local network IP addresses."""
def _get_network_ips -> list[str] {
    import socket;
    ips = [];
    try {
        # Get hostname and all IP addresses
        hostname = socket.gethostname();
        addrs = socket.getaddrinfo(hostname, None);
        for addr in addrs {
            ip = addr[4][0];
            # Filter out localhost and IPv6
            if not ip.startswith('127.') and ':' not in ip {
                if ip not in ips {
                    ips.append(ip);
                }
            }
        }
    } except Exception {
    # Silently ignore network interface errors
    }
    return ips;
}

"""Count .jac files in directory and subdirectories."""
def _count_jac_files(directory: str) -> int {
    import from pathlib { Path }
    try {
        path = Path(directory);
        return len(list(path.rglob('*.jac')));
    } except Exception {
        return 0;
    }
}

"""Print startup message based on mode."""
def _print_startup_message(
    dev: bool, no_client: bool, port: int, api_port: int, base_path: str = '.'
) -> None {
    import from jaclang.cli.console { console }
    import from importlib.metadata { version as pkg_version }

    # Print header
    try {
        version = pkg_version('jaclang');
        console.print(f"\n  JAC DEV SERVER v{version}\n", style="bold cyan");
    } except Exception {
        console.print(f"\n  JAC DEV SERVER\n", style="bold cyan");
    }

    # Build URLs list as list of tuples to allow duplicate "Network" labels (like Vite)
    urls = [];
    urls.append(("Local", f"http://localhost:{api_port}/"));

    # Add network IPs (each as "Network" entry, just like Vite)
    network_ips = _get_network_ips();
    for ip in network_ips {
        urls.append(("Network", f"http://{ip}:{api_port}/"));
    }

    # Print URLs with arrows
    console.print_urls(urls);

    console.print();

    # Print mode information
    if dev and not no_client {
        console.print("  🚀 Server ready", style="bold green");
        console.print();
        console.print("  Mode: Development (with HMR)", style="muted");
        console.print(f"    Vite:  http://localhost:{port}/", style="muted");
        console.print(f"    API:   http://localhost:{api_port}/", style="muted");
        console.print();
        # Count and show watching files
        file_count = _count_jac_files(base_path);
        if file_count > 0 {
            console.print_watching("**/*.jac", file_count);
        } else {
            console.print("  👀 Watching for changes...", style="info");
        }
    } elif dev and no_client {
        console.print("  🚀 Server ready (API only)", style="bold green");
        console.print();
        file_count = _count_jac_files(base_path);
        if file_count > 0 {
            console.print_watching("**/*.jac", file_count);
        } else {
            console.print("  👀 Watching for changes...", style="info");
        }
    } elif no_client {
        console.print("  🚀 Server ready (no client)", style="bold green");
    } else {
        console.print("  🚀 Server ready", style="bold green");
    }

    console.print();
}

"""Start Vite dev server for HMR mode."""
def _start_vite_dev_server(base_path: str, vite_port: int, api_port: int) -> Any {
    import from pathlib { Path }

    try {
        import from jac_client.plugin.src.vite_bundler { ViteBundler }

        project_dir = Path(base_path);
        bundler = ViteBundler(project_dir);

        # Create dev config with API proxy
        client_dir = bundler._get_client_dir();
        entry_file = client_dir / 'build' / 'main.js';

        # Create the config even if entry doesn't exist yet
        bundler.create_dev_vite_config(entry_file, api_port);

        # Ensure package.json exists
        if not (client_dir / 'configs' / 'package.json').exists() {
            bundler.create_package_json();
        }

        # Start the dev server
        return bundler.start_dev_server(vite_port);
    } except ImportError as e {
        print(
            f"[Vite] Warning: jac-client not installed, skipping Vite dev server: {e}",
            file=sys.stderr
        );
        return None;
    } except Exception as e {
        print(f"[Vite] Warning: Could not start Vite dev server: {e}", file=sys.stderr);
        return None;
    }
}

"""Debug the specified .jac file."""
impl debug(filename: str, main: bool = True, cache: bool = False) -> int {
    import from jaclang.pycore.program { JacProgram }
    import from jaclang.pycore.helpers { debugger as db }
    (base, mod) = os.path.split(filename);
    base = base or './';
    mod = mod[:-4];
    if filename.endswith('.jac') {
        bytecode = JacProgram().compile(filename).gen.py_bytecode;
        if bytecode {
            code = marshal.loads(bytecode);
            if db.has_breakpoint(bytecode) {
                run(filename, main, cache);
            } else {
                func = types.FunctionType(code, globals());
                print('Debugging with Jac debugger.\n');
                db.runcall(func);
                print('Done debugging.');
            }
        } else {
            print(f"Error while generating bytecode in {filename}.", file=sys.stderr);
            return 1;
        }
    } else {
        print('Not a .jac file.', file=sys.stderr);
        return 1;
    }
    return 0;
}
