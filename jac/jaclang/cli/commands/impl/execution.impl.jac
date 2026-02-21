"""Implementation of execution commands.

Direct implementations - no delegation to cli.jac.
"""

import marshal;
import os;
import sys;
import types;
import from typing { Any }
import from jaclang.cli.console { console }

glob _runtime_initialized = False;

"""Initialize Jac runtime once on first use."""
def _ensure_jac_runtime -> None {
    global _runtime_initialized;
    if not _runtime_initialized {
        import from jaclang.jac0core.runtime { JacRuntime as Jac }
        Jac.setup();
        _runtime_initialized = True;
    }
}

"""Discover jac.toml from the file's directory when an absolute/relative path is given.

This ensures that when running `jac start /path/to/project/main.jac` from any directory,
the jac.toml in /path/to/project/ is found and used for plugin configuration.
The active profile is forwarded to discover() so the multi-file config
layering is applied atomically during discovery.
"""
def _discover_config_from_file(filename: str) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig, get_config, set_config }
    import from jaclang.project.dependencies { add_venv_to_path }

    file_path = Path(filename).resolve();
    file_dir = file_path.parent;

    # Preserve the active profile from any previously loaded config so that
    # re-discovery does not lose the --profile overlay applied by _apply_profile.
    existing_config = get_config();
    active_profile = existing_config.active_profile if existing_config else None;

    # Use get_config with start_path to discover from the file's directory.
    # This ensures we don't accidentally discover config from cwd first.
    # If a config was already loaded, force_discover ensures we re-discover
    # from the correct location.
    try {
        config = get_config(start_path=file_dir, force_discover=True);
    } except (OSError, KeyError, ValueError) as e {
        console.print(
            f"Warning: Failed to discover config from {file_dir}: {e}", style="warning"
        );
        return;
    }
    if config is not None {
        # Re-apply the profile overlay that was set before re-discovery.
        if active_profile {
            config.apply_profile_overlay(active_profile);
        }
        add_venv_to_path(config);
    }
}

"""Create JacRuntime and return the base path, module name, and runtime state.

This is the canonical function for setting up CLI execution context.
It handles base_path setup, closing any existing context, and creating a new one.
"""
def _proc_file(filename: str) -> tuple {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    (base, mod) = os.path.split(filename);
    base = base or './';
    if filename.endswith('.na.jac') {
        mod = mod[:-7];
    } elif filename.endswith('.jac') {
        mod = mod[:-4];
    } elif filename.endswith('.py') {
        mod = mod[:-3];
    } else {
        console.error('Not a valid file!\nOnly supports `.jac` and `.py`');
        `exit(1);
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
impl run(filename: str, main: bool = True, cache: bool = True, args: list = []) -> int {
    _ensure_jac_runtime();
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    # Re-discover config from the file's directory (handles absolute paths)
    _discover_config_from_file(filename);
    # Set sys.argv so the script can access arguments via sys.argv[1:]
    original_argv = sys.argv;
    sys.argv = [filename] + list(args);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];
    try {
        if filename.endswith('.na.jac') {
            # Native files: compile directly and call jac_entry.
            # Skip jac_import to avoid resolving a .jac file with the same name.
            import ctypes;
            full_path = os.path.abspath(filename);
            program = Jac.get_program();
            ir_mod = program.compile(file_path=full_path);
            if ir_mod and ir_mod.gen.native_engine {
                engine = ir_mod.gen.native_engine;
                if main {
                    addr = engine.get_function_address("jac_entry");
                    if addr != 0 {
                        ctypes.CFUNCTYPE(None)(addr)();
                    }
                }
            } else {
                console.error("Native compilation failed for " + filename);
                mach.close();
                return 1;
            }
        } else {
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name='__main__' if main else None,
                lng=lng
            );
        }
    } except Exception as e {
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                console.error(error.pretty_print(colors=True));
            }
        } else {
            import from jaclang.jac0core.helpers { dump_traceback }
            console.error(dump_traceback(e));
        }
        sys.argv = original_argv;
        mach.close();
        return 1;
    }
    sys.argv = original_argv;
    mach.close();
    return 0;
}

"""Run the specified entrypoint function in the given .jac file."""
impl enter(
    filename: str,
    entrypoint: str,
    args: list = [],
    main: bool = True,
    `root: str = '',
    nd: str = ''
) -> int {
    _ensure_jac_runtime();
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.constructs { WalkerArchetype }
    # Re-discover config from the file's directory (handles absolute paths)
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    # Set user root if provided (for permission boundary)
    if `root {
        mach.set_user_root(`root);
    }
    if filename.endswith('.jac') {
        ret_module = Jac.jac_import(
            target=mod, base_path=base, override_name='__main__' if main else None
        );
    } else {
        mach.close();
        console.error('Not a valid file!\nOnly supports `.jac`');
        return 1;
    }
    if ret_module {
        (loaded_mod, ) = ret_module;
        if not loaded_mod {
            console.error('Errors occurred while importing the module.');
            mach.close();
            return 1;
        } else {
            archetype = getattr(loaded_mod, entrypoint)(*args);
            mach.set_entry_node(nd);
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
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from pathlib { Path }
    if not Path(filename).exists() {
        if filename == "main.jac" {
            console.error(
                f"Error: File 'main.jac' not found in the current directory."
            );
            console.error(f"  Current directory: {os.getcwd()}");
            console.error(
                "  Please specify a file: jac start <filename.jac> or make sure main.jac exists in the current directory"
            );
        } else {
            console.error(f"Error: File '{filename}' not found.");
            console.error(f"  Current directory: {os.getcwd()}");
            console.error("  Please check the file path and try again.");
        }
        return 1;
    }
    # Re-discover config from the file's directory (handles absolute paths)
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];
    # Load the Jac module (actual compilation/bundling happens in server.start())
    try {
        Jac.jac_import(target=mod, base_path=base, lng=lng);
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                console.error(error.pretty_print(colors=True));
            }
            mach.close();
            return 1;
        }
    } except Exception as e {
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                console.error(error.pretty_print(colors=True));
            }
        } else {
            import from jaclang.jac0core.helpers { dump_traceback }
            console.error(f"Error loading {filename}: {e}");
            console.error(dump_traceback(e));
        }
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
            import from jaclang.jac0core.helpers { dump_traceback }
            console.error(f"Error generating endpoint documentation: {e}");
            console.error(dump_traceback(e));
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
        # Auto-install watchdog if not available
        if not _ensure_watchdog_installed() {
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
            console.error(f"Error: Could not initialize HMR: {e}");
            console.error(
                "\nMake sure 'watchdog' is installed by running: jac install --dev"
            );
            mach.close();
            return 1;
        } except Exception as e {
            console.error(f"Warning: HMR initialization failed: {e}");
        }
        # Start Vite dev server if client mode enabled
        if not no_client {
            # Do initial compilation for HMR
            try {
                compiler = server.introspector._bundle_builder._get_compiler();
                compiler.compile(server.introspector._module, Path(filename));
                console.print("  ✔ Initial client compilation completed");
            } except Exception as e {
                console.error(f"Warning: Initial client compilation failed: {e}");
            }
            vite_process = _start_vite_dev_server(base, vite_port, actual_api_port);
        }
    }
    # Pass startup banner callback so it's printed AFTER compilation/bundling completes
    try {
        server.start(
            dev=dev,
            no_client=no_client,
            on_ready=lambda :
                _print_startup_message(dev, no_client, port, actual_api_port, base)
        );
        return 0;
    } except KeyboardInterrupt {
        console.print('\nShutting down...');
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
        import from jaclang.jac0core.helpers { dump_traceback }
        console.error(f"Server error: {e}");
        console.error(dump_traceback(e));
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

"""Ensure watchdog is installed, auto-install if missing."""
def _ensure_watchdog_installed -> bool {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.dependencies {
        get_venv_site_packages,
        DependencyInstaller
    }

    config = get_config();
    if config is None {
        # No project, check global availability
        try {
            import watchdog;
            return True;
        } except ImportError {
            console.error("\n  Error: --dev requires 'watchdog' package.\n");
            console.error("  Install it with: pip install watchdog\n");
            return False;
        }
    }
    # Check if watchdog is installed in the project's venv
    site_packages = get_venv_site_packages(config.get_venv_dir());
    if site_packages.exists() {
        # Add site-packages to path temporarily to check
        import sys;
        original_path = sys.path.copy();
        sys.path.insert(0, str(site_packages));
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
        # Auto-install watchdog from dev dependencies
        console.print(
            "\n  📦 Installing watchdog (required for --dev mode)...\n", style="info"
        );
        installer = DependencyInstaller(config=config, verbose=False);
        specs = installer.get_pip_package_specs(include_dev=True);
        if installer.install_package(specs) {
            console.success("  ✔ watchdog installed\n");
            return True;
        } else {
            console.error("\n  Error: Failed to install watchdog\n");
            return False;
        }
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
        bundler.create_vite_config(entry_file, is_dev=True, api_port=api_port);

        # Ensure package.json exists
        if not (client_dir / 'configs' / 'package.json').exists() {
            bundler.create_package_json();
        }

        # Start the dev server (messages handled by bundler)
        return bundler.start_dev_server(vite_port, suppress_initial_output=True);
    } except ImportError as e {
        console.error(
            f"[Vite] Warning: jac-client not installed, skipping Vite dev server: {e}"
        );
        return None;
    } except Exception as e {
        console.error(f"[Vite] Warning: Could not start Vite dev server: {e}");
        return None;
    }
}

"""Debug the specified .jac file."""
impl debug(filename: str, main: bool = True, cache: bool = False) -> int {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.helpers { debugger as db }
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
                console.print('Debugging with Jac debugger.\n');
                db.runcall(func);
                console.print('Done debugging.');
            }
        } else {
            console.error(f"Error while generating bytecode in {filename}.");
            return 1;
        }
    } else {
        console.error('Not a .jac file.');
        return 1;
    }
    return 0;
}
