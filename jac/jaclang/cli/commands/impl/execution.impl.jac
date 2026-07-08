import marshal;
import os;
import sys;
import types;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.cli.commands.cli_helpers { proc_file as _proc_file }
import from jaclang.jac0core.ext_registry { is_native_module }

def _discover_config_from_file(filename: str) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig, get_config, set_config }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    file_path = Path(filename).resolve();

    Jac.set_full_target_path(str(file_path));
    file_dir = file_path.parent;

    existing_config = get_config();
    active_profile = existing_config.active_profile if existing_config else None;

    try {
        config = get_config(start_path=file_dir, force_discover=True);
    } except (OSError, KeyError, ValueError) as e {
        console.print(
            f"Warning: Failed to discover config from {file_dir}: {e}", style="warning"
        );
        return;
    }
    if config is not None {
        if active_profile {
            config.apply_profile_overlay(active_profile);
        }
        add_venv_to_path(config);
    }
}

def _populate_native_argv(engine: object, argv: list[str]) -> None {
    import ctypes;

    argc_addr = engine.get_global_value_address("__jac_argc");
    argv_addr = engine.get_global_value_address("__jac_argv");
    if argc_addr == 0 or argv_addr == 0 {
        return;
    }

    argc = len(argv);
    c_strings = [ctypes.c_char_p(arg.encode("utf-8")) for arg in argv];
    c_argv = (ctypes.c_char_p * argc)(*c_strings);

    argc_ptr = ctypes.cast(argc_addr, ctypes.POINTER(ctypes.c_int32));
    argc_ptr[0] = argc;
    argv_ptr = ctypes.cast(argv_addr, ctypes.POINTER(ctypes.c_void_p));
    argv_ptr[0] = ctypes.cast(c_argv, ctypes.c_void_p).value;

    engine._jac_argv_refs = (c_strings, c_argv);
}

def _print_plan(plan: object) {
    console.print(f"project kind : {plan.kind}");
    console.print(f"action       : {plan.action}");
    console.print(f"summary      : {plan.summary}");
    if plan.entry_path {
        console.print(f"entry-point  : {plan.entry_path}");
    }
    console.print(f"equivalent   : {plan.command_line()}");
    if plan.requires_plugin {
        console.print(f"requires     : {plan.requires_plugin} plugin");
    }
}

def _plugin_available(pkg: str) -> bool {
    import importlib.util;
    try {
        return importlib.util.find_spec(pkg.replace("-", "_")) is not None;
    } except (ImportError, ValueError) {
        return False;
    }
}

def _execute_plan(
    plan: object,
    main: bool,
    cache: bool,
    autonative: bool,
    diagnostics: str,
    args: list
) -> int {
    if plan.requires_plugin and not _plugin_available(plan.requires_plugin) {
        console.error(
            f"Project kind '{plan.kind}' requires the {plan.requires_plugin} plugin, "
            f"which is not installed. Install it, then: {plan.command_line()}"
        );
        return 1;
    }
    if plan.action == "execute" {
        return run(
            filename=plan.entry_path,
            main=main,
            cache=cache,
            autonative=autonative,
            diagnostics=diagnostics,
            args=args
        );
    }
    if plan.action == "serve" {
        if "client" in plan.flags {
            console.error(
                f"Project kind '{plan.kind}' is run via the {plan.requires_plugin} "
                f"plugin command: {plan.command_line()}"
            );
            return 1;
        }

        return start(
            filename=plan.entry_path,
            port=plan.flags.get("port", 8000),
            no_client=plan.flags.get("no_client", False),
            dev=plan.flags.get("dev", False)
        );
    }
    if plan.action == "build" {
        if plan.verb == "nacompile" {
            import from jaclang.cli.commands.nacompile { nacompile }
            out = plan.flags.get("output", "");
            if out {
                out_dir = os.path.dirname(out);
                if out_dir {
                    os.makedirs(out_dir, exist_ok=True);
                }
            }
            return nacompile(
                filename=plan.entry_path,
                output=out,
                shared=plan.flags.get("shared", False)
            );
        }
        if plan.verb == "build" {
            import from jaclang.cli.commands.build { build }
            return build(projection=plan.flags.get("as", "jab"));
        }

        console.error(
            f"Project kind '{plan.kind}' builds via the {plan.requires_plugin} "
            f"plugin command: {plan.command_line()}"
        );
        return 1;
    }
    console.error(f"Unsupported run action '{plan.action}' for kind '{plan.kind}'.");
    return 1;
}

def _run_jab(filename: str, port: (int | None), args: list, serve_only: bool) -> int {
    import from jaclang.runtimelib.jab { materialize_jab }

    try {
        img_root = materialize_jab(filename);
    } except Exception as e {
        console.error(f"Cannot load {filename}: {e}");
        return 1;
    }
    return run_jab_image(img_root, port, args, serve_only, filename);
}

impl run_jab_image(
    img_root: Path, port: (int | None), args: list, serve_only: bool, label: str
) -> int {
    import from jaclang.runtimelib.jab { jab_app_meta }

    meta = jab_app_meta(img_root);
    kind = str(meta.get("kind") or "cli");
    entry_meta: dict = meta.get("entry") or {};
    caps: list = meta.get("capabilities") or [];
    entry_rel = str(entry_meta.get("path") or "");
    if not entry_rel {
        attach_note = ", attachable package" if "attachable" in caps else "";
        console.error(
            f"{label} has no entry (kind '{kind}'{attach_note}); "
            "it cannot be run directly."
        );
        return 1;
    }
    entry_abs = str(img_root / entry_rel);
    if not os.path.isfile(entry_abs) {
        console.error(f"{label}: sealed entry '{entry_rel}' missing from image.");
        return 1;
    }
    servable = kind in ["service", "service-mesh", "web-app", "web-static"];
    if serve_only or servable {
        serve_port = port;
        if serve_port is None {
            import from jaclang.project.config { get_config_for_path }
            img_cfg = get_config_for_path(img_root);
            serve_port = img_cfg.serve.port if img_cfg else 8000;
        }
        return start(
            filename=entry_abs,
            port=serve_port,
            no_client=(kind == "service"),
            dev=False
        );
    }
    if kind in ["cli", "cli-native", "native-binary"] {
        if kind != "cli" {
            native_bin = _jab_native_bin(img_root, entry_rel);
            if native_bin {
                os.execv(native_bin, [native_bin] + [str(a) for a in args]);
            }
        }
        return run(filename=entry_abs, args=args);
    }
    console.error(
        f"{label}: kind '{kind}' is not directly runnable from a jab "
        "(build its platform projection instead)."
    );
    return 1;
}

def _jab_native_bin(img_root: object, entry_rel: str) -> (str | None) {
    import from jaclang.jac0core.ext_registry { base_stem }
    import from jaclang.runtimelib.sealed_serve { NATIVE_DIR_REL }
    try {
        import jaclang.compiler.passes.native.llvm.binding as llvm;
        triple = llvm.get_default_triple();
    } except Exception {
        return None;
    }
    stem = base_stem(os.path.basename(entry_rel));
    cand = os.path.join(str(img_root), NATIVE_DIR_REL, triple, stem);
    if os.path.isfile(cand) and os.access(cand, os.X_OK) {
        return cand;
    }
    return None;
}

def _run_project(
    show: bool, main: bool, cache: bool, autonative: bool, diagnostics: str, args: list
) -> int {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.kinds { plan_project_run, is_valid_kind, VALID_KINDS }

    existing_config = get_config();
    active_profile = existing_config.active_profile if existing_config else None;
    cfg = get_config(start_path=Path.cwd(), force_discover=True);
    if cfg is None {
        console.error(
            "No file given and no jac.toml found.\n"
            "  Usage: jac run <file.jac>, or run inside a Jac project directory."
        );
        return 1;
    }
    if active_profile {
        cfg.apply_profile_overlay(active_profile);
    }
    if cfg.project.kind and not is_valid_kind(cfg.project.kind) {
        console.error(
            f"Unknown [project] kind '{cfg.project.kind}'.\n"
            f"  Valid kinds: {', '.join(VALID_KINDS)}"
        );
        return 1;
    }
    project_root = str(cfg.project_root) if cfg.project_root else os.getcwd();
    plan = plan_project_run(cfg, project_root);
    if plan is None {
        console.error(
            "Could not resolve an entry-point for this project.\n"
            f"  Set [project] entry-point in jac.toml (project root: {project_root})."
        );
        return 1;
    }
    if show {
        _print_plan(plan);
        return 0;
    }
    return _execute_plan(
        plan,
        main=main,
        cache=cache,
        autonative=autonative,
        diagnostics=diagnostics,
        args=args
    );
}

impl run(
    filename: str = "",
    show: bool = False,
    main: bool = True,
    cache: bool = True,
    autonative: bool = False,
    diagnostics: str = "",
    entry_name: str = "",
    nd: str = "",
    root_id: str = "",
    debug_mode: bool = False,
    args: list = []
) -> int {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.project.config { get_config }

    if debug_mode {
        if not filename {
            console.error("jac run --debug needs a file.");
            return 1;
        }
        return debug(filename=filename, main=main, cache=cache);
    }
    if entry_name {
        if not filename {
            console.error("jac run --entry needs a file.");
            return 1;
        }
        return enter(filename, entry_name, args, main, root_id, nd);
    }
    if not filename {
        return _run_project(
            show=show,
            main=main,
            cache=cache,
            autonative=autonative,
            diagnostics=diagnostics,
            args=args
        );
    }
    if filename.endswith(".jab") {
        if show {
            console.print(
                f"jac run {filename}  ->  kind-aware dispatch (sealed app bundle)"
            );
            return 0;
        }
        return _run_jab(filename, None, args, serve_only=False);
    }
    if show {
        console.print(f"jac run {filename}  ->  execute (explicit file)");
        return 0;
    }

    _discover_config_from_file(filename);

    if not cache {
        import from jaclang.jac0core.jir { scrub_cache_dirs }
        scrub_cache_dirs(os.path.dirname(os.path.abspath(filename)) or ".");
    }

    if not diagnostics {
        cfg = get_config();
        diagnostics = cfg.run.diagnostics if cfg else "error";
    }

    original_argv = sys.argv;
    sys.argv = [filename] + list(args);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];
    try {
        if is_native_module(filename) {
            import ctypes;
            full_path = os.path.abspath(filename);
            program = Jac.get_program();
            ir_mod = program.compile(file_path=full_path);
            if program.errors_had {
                for _err in program.errors_had {
                    console.error(_err.pretty_print());
                }
                mach.close();
                return 1;
            }
            if ir_mod and ir_mod.gen.native_engine {
                engine = ir_mod.gen.native_engine;
                _populate_native_argv(engine, sys.argv);
                if main {
                    addr = engine.get_function_address("jac_entry");
                    if addr != 0 {
                        fn = ctypes.CFUNCTYPE(None)(addr);
                        fn();
                    }
                }
            } else {
                console.error("Native compilation failed for " + filename);
                mach.close();
                return 1;
            }
        } elif filename.endswith('.jac') {
            native_executed = False;
            if autonative {
                try {
                    import from jaclang.jac0core.program { JacProgram }
                    full_path = os.path.abspath(filename);
                    na_program = JacProgram();
                    na_program._auto_promote_native = True;
                    na_program._auto_promote_target = full_path;
                    ir_mod = na_program.compile(file_path=full_path);
                    if (
                        ir_mod and ir_mod.gen.native_compat and ir_mod.gen.native_engine
                    ) {
                        import ctypes;
                        engine = ir_mod.gen.native_engine;
                        _populate_native_argv(engine, sys.argv);
                        if main {
                            addr = engine.get_function_address("jac_entry");
                            if addr != 0 {
                                fn = ctypes.CFUNCTYPE(None)(addr);
                                fn();
                                native_executed = True;
                                console.print(
                                    f"[Module '{filename}' executed natively]",
                                    style="dim"
                                );
                            }
                        }
                    }
                } except Exception as _auto_err {
                    _ = _auto_err;
                }
            }
            if not native_executed {
                Jac.jac_import(
                    target=mod,
                    base_path=base,
                    override_name='__main__' if main else None,
                    lng=lng
                );
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
        if diagnostics != "none" {
            if Jac.program.errors_had {
                for error in Jac.program.errors_had {
                    console.error(error.pretty_print());
                }
            } else {
                import from jaclang.jac0core.helpers { dump_traceback }
                console.error(dump_traceback(e));
            }
        }
        sys.argv = original_argv;
        mach.close();
        return 1 if diagnostics != "none" else 0;
    }
    n_errors = len(Jac.program.errors_had);
    n_warnings = len(Jac.program.warnings_had);
    if diagnostics != "none" {
        if n_errors {
            for error in Jac.program.errors_had {
                console.error(error.pretty_print());
            }
        }
        if diagnostics == "all" and n_warnings {
            for warning in Jac.program.warnings_had {
                console.warning(f"{warning}");
            }
        }
    }
    sys.argv = original_argv;
    mach.close();
    return 1 if (n_errors and diagnostics != "none") else 0;
}

impl enter(
    filename: str,
    entrypoint: str,
    args: list = [],
    main: bool = True,
    `root: str = '',
    nd: str = ''
) -> int {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from jaclang.jac0core.constructs { WalkerArchetype }

    if len(sys.argv) > 1 and sys.argv[1] == "enter" {
        console.print(
            "note: 'jac enter' is deprecated; use jac run <file> --entry <name>",
            style="muted"
        );
    }
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);

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

impl dev(filename: str = "", port: int = 8000, api_port: int = 0) -> int {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.kinds { resolve_entry }

    target = filename;
    if not target {
        cfg = get_config(start_path=Path.cwd(), force_discover=True);
        if cfg is None or cfg.project_root is None {
            console.error(
                "No file given and no jac.toml found.\n"
                "  Usage: jac dev <file.jac>, or run inside a Jac project directory."
            );
            return 1;
        }
        target = resolve_entry(cfg, str(cfg.project_root));
        if not target {
            console.error(
                "Could not resolve an entry-point for this project.\n"
                "  Set [project] entry-point in jac.toml."
            );
            return 1;
        }
    }
    return start(filename=target, port=port, dev=True, api_port=api_port);
}

impl start(
    filename: str,
    port: int = 8000,
    main: bool = True,
    faux: bool = False,
    dev: bool = False,
    api_port: int = 0,
    no_client: bool = False,
    client: str = "web",
    host: str = "",
    platform: str = "auto",
    scale: bool = False,
    target: str = "kubernetes",
    enable_tls: bool = False,
    dry_run: bool = False,
    show_yaml: bool = False
) -> int {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }
    import from pathlib { Path }

    import from jaclang.runtimelib.client.cli { run_client_start }
    client_rc = run_client_start(
        filename, client, host, platform, port, api_port, dev, no_client
    );
    if client_rc is not None {
        return client_rc;
    }

    import from jaclang.scale.plugin { scale_start }
    scale_rc = scale_start(filename, scale, target, enable_tls, dry_run, show_yaml);
    if scale_rc is not None {
        return scale_rc;
    }

    if filename.endswith(".jab") {
        if dev {
            console.error(
                "A sealed .jab never serves in dev mode; run the project "
                "source with --dev instead."
            );
            return 1;
        }
        return _run_jab(filename, port, [], serve_only=True);
    }
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

    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];

    try {
        Jac.jac_import(target=mod, base_path=base, lng=lng);
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                console.error(error.pretty_print());
            }
            mach.close();
            return 1;
        }
    } except Exception as e {
        if Jac.program.errors_had {
            for error in Jac.program.errors_had {
                console.error(error.pretty_print());
            }
        } else {
            import from jaclang.jac0core.helpers { dump_traceback }
            console.error(f"Error loading {filename}: {e}");
            console.error(dump_traceback(e));
        }
        mach.close();
        return 1;
    }

    if dev and not no_client {
        vite_port = port;
        actual_api_port = api_port if api_port > 0 else port + 1;
    } else {
        actual_api_port = port;
        vite_port = 0;
    }

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
            if server?.server and server.server {
                server.server.server_close();
            }
        }
        mach.close();
        return 0;
    }

    hot_reloader = None;

    vite_holder: list = [];
    if dev {
        if not _ensure_watchdog_installed() {
            mach.close();
            return 1;
        }
        try {
            import from jaclang.runtimelib.hmr { HotReloader }
            import from jaclang.runtimelib.watcher { JacFileWatcher }

            watcher = JacFileWatcher(watch_paths=[base]);
            client_compiler = None;
            if not no_client {
                try {
                    client_compiler = server.introspector._bundle_builder._get_compiler();
                } except Exception as e {
                    console.warning(
                        f"Client compiler unavailable, HMR uses legacy mode: {e}"
                    );
                }
            }
            hot_reloader = HotReloader(
                base_path=base,
                module_name=mod,
                watcher=watcher,
                client_compiler=client_compiler
            );
            hot_reloader.start();

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

        if not no_client {
            try {
                compiler = server.introspector._bundle_builder._get_compiler();
                compiler.compile(server.introspector._module, Path(filename));
                console.print("  ✔ Initial client compilation completed");
            } except Exception as e {
                console.error(f"Warning: Initial client compilation failed: {e}");

                if hot_reloader {
                    hot_reloader.record_error(str(filename), str(e));
                }
            }
        }
    }

    def _announce_ready(actual_port: int) {
        primary_port = actual_port;
        if dev and not no_client {
            free_vite_port = _find_free_port(vite_port, skip_port=actual_port);
            (started_vite, bound_port) = _start_vite_dev_server(
                base, free_vite_port, actual_port
            );
            if started_vite {
                vite_holder.append(started_vite);
            }
            primary_port = bound_port;
        }
        _print_startup_message(
            dev=dev,
            no_client=no_client,
            primary_port=primary_port,
            api_port=actual_port,
            base_path=base
        );
    }
    try {
        server.start(dev=dev, no_client=no_client, on_ready=_announce_ready);
        return 0;
    } except KeyboardInterrupt {
        console.print('\nShutting down...');
        if hot_reloader {
            hot_reloader.stop();
        }
        for started_vite in vite_holder {
            started_vite.terminate();
            started_vite.wait(timeout=5);
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
        for started_vite in vite_holder {
            started_vite.terminate();
        }
        mach.close();
        return 1;
    }
}

def _watchdog_importable -> bool {
    import importlib;
    try {
        importlib.invalidate_caches();
        import watchdog;
        return True;
    } except ImportError {
        return False;
    }
}

def _ensure_watchdog_installed -> bool {
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.project.providers { InstallContext, get_python_provider }

    if _watchdog_importable() {
        return True;
    }

    config = get_config();
    if config is None {
        console.error("\n  Error: --dev requires 'watchdog' package.\n");
        console.error("  Install it with: pip install watchdog\n");
        return False;
    }

    console.print(
        "\n  📦 Installing watchdog (required for --dev mode)...\n", style="info"
    );
    python = get_python_provider();
    if python.install_specs(config, ["watchdog>=3.0.0"], InstallContext()) {
        add_venv_to_path(config);
        if _watchdog_importable() {
            console.success("watchdog installed");
            return True;
        }
        console.error(
            "\n  Error: watchdog was installed in the project venv but cannot be imported.\n"
        );
        console.error(
            "  Run 'jac install --dev' using a Jac install that matches the project venv Python version.\n"
        );
        return False;
    }
    console.error("\n  Error: Failed to install watchdog\n");
    return False;
}

def _get_network_ips -> list[str] {
    import socket;
    ips = [];
    try {
        hostname = socket.gethostname();
        addrs = socket.getaddrinfo(hostname, None);
        for addr in addrs {
            ip = addr[4][0];

            if not ip.startswith('127.') and ':' not in ip {
                if ip not in ips {
                    ips.append(ip);
                }
            }
        }
    } except Exception { }
    return ips;
}

def _count_jac_files(directory: str) -> int {
    import from pathlib { Path }
    try {
        path = Path(directory);
        return len(list(path.rglob('*.jac')));
    } except Exception {
        return 0;
    }
}

def _print_startup_message(
    dev: bool, no_client: bool, primary_port: int, api_port: int, base_path: str = '.'
) {
    import from importlib.metadata { version as pkg_version }

    try {
        version = pkg_version('jaclang');
        console.print(f"\n  JAC DEV SERVER v{version}\n", style="bold cyan");
    } except Exception {
        console.print(f"\n  JAC DEV SERVER\n", style="bold cyan");
    }

    urls = [];
    urls.append(("Local", f"http://localhost:{primary_port}/"));

    network_ips = _get_network_ips();
    for ip in network_ips {
        urls.append(("Network", f"http://{ip}:{primary_port}/"));
    }

    console.print_urls(urls);

    console.print();

    if dev and not no_client {
        console.print("  🚀 Server ready", style="bold green");
        console.print();
        console.print("  Mode: Development (with HMR)", style="muted");
        console.print(f"    App:  http://localhost:{primary_port}/", style="muted");
        console.print(f"    API:  http://localhost:{api_port}/", style="muted");
        console.print();

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

def _find_free_port(start: int, skip_port: int = 0) -> int {
    import socket;
    candidate = start;
    for _ in range(50) {
        if candidate != skip_port {
            try {
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as probe {
                    probe.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
                    probe.bind(('0.0.0.0', candidate));
                }
                return candidate;
            } except OSError {
                ;
            }
        }
        candidate += 1;
    }
    console.warning(
        f"[Vite] No free port found in {start}-{start + 49}; falling back."
    );

    return start if start != skip_port else start + 50;
}

def _start_vite_dev_server(base_path: str, vite_port: int, api_port: int) -> any {
    import from pathlib { Path }

    try {
        import from jaclang.runtimelib.client.vite_bundler { ViteBundler }

        project_dir = Path(base_path);
        bundler = ViteBundler(project_dir);

        client_dir = bundler._get_client_dir();
        entry_file = client_dir / 'build' / 'main.js';

        bundler.create_vite_config(entry_file, is_dev=True, api_port=api_port);

        if not (client_dir / 'configs' / 'package.json').exists() {
            bundler.create_package_json();
        }

        process = bundler.start_dev_server(vite_port, suppress_initial_output=True);
        return (process, bundler.dev_server_port or vite_port);
    } except ImportError as e {
        console.error(
            f"[Vite] Warning: client bundler unavailable, skipping Vite dev server: {e}"
        );
        return (None, vite_port);
    } except Exception as e {
        console.error(f"[Vite] Warning: Could not start Vite dev server: {e}");
        return (None, vite_port);
    }
}

impl debug(filename: str, main: bool = True, cache: bool = False) -> int {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.helpers { debugger as db }
    if len(sys.argv) > 1 and sys.argv[1] == "debug" {
        console.print(
            "note: 'jac debug' is deprecated; use jac run <file> --debug", style="muted"
        );
    }
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

def _tool_site_dirs(use_global: bool) -> list {
    import site;
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv { get_venv_site_packages }

    sites: list = [];
    if not use_global {
        config = get_config();
        if config is not None {
            sites.append(("project", get_venv_site_packages(config.get_venv_dir())));
        }
    }
    try {
        global_sites = site.getsitepackages();
    } except (AttributeError, IndexError, OSError) {
        global_sites = [];
    }
    if global_sites {
        sites.append(("global", Path(global_sites[0])));
    }
    return sites;
}

def _console_scripts_in(site_dir: object) -> list {
    import from importlib.metadata { distributions }

    found: list = [];
    if not site_dir.exists() {
        return found;
    }
    for dist in distributions(path=[str(site_dir)]) {
        dist_name = dist.metadata["Name"] if dist.metadata else None;
        dist_name = dist_name or "?";
        for ep in dist.entry_points {
            if ep.group == "console_scripts" {
                found.append((ep.name, dist_name, ep));
            }
        }
    }
    return found;
}

def _node_bin_dir -> object {
    import from jaclang.project.config { get_config }

    config = get_config();
    if config is None {
        return None;
    }
    return config.get_client_dir() / "node_modules" / ".bin";
}

def _node_tools_in(bin_dir: object) -> list {
    names: set = set();
    if bin_dir is None or not bin_dir.exists() {
        return [];
    }
    for entry in bin_dir.iterdir() {
        if entry.is_dir() {
            continue;
        }
        base = entry.name;
        for suffix in [".cmd", ".ps1", ".exe", ".bat"] {
            if base.endswith(suffix) {
                base = base[:-len(suffix)];
                break;
            }
        }
        if base and not base.startswith(".") {
            names.add(base);
        }
    }
    return sorted(names);
}

def _find_node_tool(bin_dir: object, name: str) -> object {
    if bin_dir is None or not bin_dir.exists() {
        return None;
    }
    for candidate in [
        name,
        name + ".cmd",
        name + ".exe",
        name + ".bat",
        name + ".ps1"
    ] {
        shim = bin_dir / candidate;
        if shim.exists() {
            return shim;
        }
    }
    return None;
}

def _run_entry_point(name: str, ep: object, site_dir: object, args: list) -> int {
    saved_path = list(sys.path);
    saved_argv = sys.argv;
    site_str = str(site_dir);
    if site_str in sys.path {
        sys.path.remove(site_str);
    }
    sys.path.insert(0, site_str);
    try {
        try {
            func = ep.load();
        } except Exception as e {
            console.error(f"Failed to load tool '{name}': {e}");
            return 1;
        }
        sys.argv = [name] + list(args);
        result = func();
        return result if isinstance(result, int) else 0;
    } except SystemExit as se {
        if se.code is None {
            return 0;
        }
        if isinstance(se.code, int) {
            return se.code;
        }
        console.error(str(se.code));
        return 1;
    } finally {
        sys.argv = saved_argv;
        sys.path.clear();
        sys.path.extend(saved_path);
    }
}

def _run_node_tool(name: str, bin_path: object, args: list) -> int {
    import subprocess;
    import from jaclang.runtimelib.client.bun_installer { get_bun }
    import from jaclang.project.config { get_config }

    bun = get_bun();
    if bun is None {
        console.error(
            f"Cannot run npm tool '{name}': the bun runtime is unavailable.",
            hint="Install bun, or run the project once (e.g. 'jac start') to let jac provision it."
        );
        return 1;
    }
    config = get_config();
    cwd = str(config.project_root) if config and config.project_root else None;
    result = subprocess.run([bun, str(bin_path)] + list(args), cwd=cwd);
    return result.returncode;
}

def _tool_tiers(use_global: bool, use_node: bool) -> list {
    if use_node {
        node_bin = _node_bin_dir();
        return [("node", "node", node_bin)] if node_bin is not None else [];
    }
    py_sites = _tool_site_dirs(use_global);
    if use_global {
        return [(label, "py", loc) for (label, loc) in py_sites];
    }
    tiers: list = [];
    node_bin = _node_bin_dir();
    node_inserted = False;
    for (label, loc) in py_sites {
        tiers.append((label, "py", loc));

        if label == "project" and node_bin is not None {
            tiers.append(("node", "node", node_bin));
            node_inserted = True;
        }
    }
    if node_bin is not None and not node_inserted {
        tiers.append(("node", "node", node_bin));
    }
    return tiers;
}

def _list_tools(tiers: list) -> int {
    seen: set = set();
    rows: list = [];
    for (label, kind, loc) in tiers {
        if kind == "py" {
            for (script_name, dist_name, _ep) in _console_scripts_in(loc) {
                if script_name in seen {
                    continue;
                }
                seen.add(script_name);
                rows.append((script_name, dist_name, label));
            }
        } else {
            for tool_name in _node_tools_in(loc) {
                if tool_name in seen {
                    continue;
                }
                seen.add(tool_name);
                rows.append((tool_name, "npm", label));
            }
        }
    }
    if not rows {
        console.info(
            "No CLI tools available. Install one with 'jac install <package>', "
            "'jac install --global <package>', or add an npm package for node tools."
        );
        return 0;
    }
    console.print("\nAvailable CLI tools (run with 'jac x <name>'):\n", style="info");
    width = max([len(r[0]) for r in rows]);
    for (tool_name, origin, label) in sorted(rows) {
        console.print(f"  {tool_name.ljust(width)}  {origin} [{label}]");
    }
    return 0;
}

impl x(
    name: str = "",
    use_global: bool = False,
    use_node: bool = False,
    list_tools: bool = False,
    args: list = []
) -> int {
    tiers = _tool_tiers(use_global, use_node);

    if list_tools or not name {
        return _list_tools(tiers);
    }

    import from jaclang.project.config { get_config }
    cfg_x = get_config();
    if cfg_x is not None and name in (cfg_x.scripts or {}) {
        import from jaclang.cli.commands.project { script }
        return script(name=name);
    }

    for (label, kind, loc) in tiers {
        if kind == "py" {
            for (script_name, _dist_name, ep) in _console_scripts_in(loc) {
                if script_name == name {
                    return _run_entry_point(name, ep, loc, args);
                }
            }
        } else {
            bin_path = _find_node_tool(loc, name);
            if bin_path is not None {
                return _run_node_tool(name, bin_path, args);
            }
        }
    }

    searched = ", ".join([f"{label} ({loc})" for (label, kind, loc) in tiers])
    or "no tiers";
    console.error(
        f"No CLI tool named '{name}' found.",
        hint=f"Install it — 'jac install <package>' (project Python), "
        f"'jac install --global <package>', or add an npm package (node) — "
        f"then 'jac x {name}'. Searched: {searched}."
    );
    return 1;
}
