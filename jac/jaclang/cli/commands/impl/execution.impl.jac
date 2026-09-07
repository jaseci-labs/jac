import marshal;
import os;
import sys;
import types;
import from pathlib { Path }
import from jaclang.cli.console { console, use_line_buffered_output }
import from jaclang.cli.commands.cli_helpers { proc_file as _proc_file }
import from jaclang.server.assembly {
    assemble_served_program,
    colocate_services as _colocate_services,
    gateway_colocates as _gateway_colocates,
    service_apps as _service_apps
}
import from jaclang.project.kinds { RunPlan }
import type from importlib.metadata { EntryPoint }
import type from jaclang.compiler.backends.native.llvm.binding.executionengine {
    ExecutionEngine
}

def _discover_config_from_file(filename: str) -> None {
    import from pathlib { Path }
    import from jaclang.project.config {
        JacConfig,
        get_config,
        project_scope_is_pinned,
        set_config
    }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.runtime.runtime { JacRuntime as Jac }

    file_path = Path(filename).resolve();

    Jac.set_full_target_path(str(file_path));
    file_dir = file_path.parent;

    if project_scope_is_pinned() {
        return;
    }

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


def _project_label(config: any) -> str {
    name = config.project.name if config?.project else "";
    proj_root = str(config.project_root) if config?.project_root else "?";
    return f"'{name}' at {proj_root}" if name else proj_root;
}


def _app_serves(config: any, app: any) -> bool {
    import from jaclang.project.kinds { kind_spec }
    try {
        spec = kind_spec(config.resolved_kind(app));
    } except Exception {
        return False;
    }
    return spec is not None and spec.action == "serve";
}


def _project_serves(config: any) -> bool {
    if config is None {
        return False;
    }
    for app in config.apps.values() {
        if _app_serves(config, app) {
            return True;
        }
    }
    return False;
}


def _takes_over_app(config: any, file_path: str) -> bool {
    if config is None {
        return False;
    }
    app = config.app_for_path(file_path);
    if app is None or not _app_serves(config, app) {
        return False;
    }
    project_root = str(config.project_root) if config.project_root else "";
    if not project_root {
        return True;
    }
    try {
        entry_file = app.entry_path(project_root);
    } except Exception {
        return True;
    }
    return os.path.abspath(file_path) != os.path.abspath(entry_file);
}


def _scope_notice(message: str) {
    console.print(f"jac run: {message}", file=sys.stderr, style="muted");
}


def _pin_run_scope(filename: str, takeover: (bool | None)) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig, get_config, pin_project_scope }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.runtime.runtime { JacRuntime as Jac }

    file_path = Path(filename).resolve();
    Jac.set_full_target_path(str(file_path));

    existing_config = get_config();
    active_profile = existing_config.active_profile if existing_config else None;

    try {
        owner = JacConfig.discover(start_path=file_path.parent);
        ambient = JacConfig.discover(start_path=Path.cwd());
    } except (OSError, KeyError, ValueError) as e {
        console.warning(f"Failed to discover config from {file_path.parent}: {e}");
        return;
    }

    chosen = owner;
    notice = "";
    if takeover is False {
        chosen = None;
        context = owner or ambient;
        if context is not None {
            notice = (
                f"{file_path.name} runs standalone (--no-takeover); it will not "
                f"touch the project {_project_label(context)}"
            );
        }
    } elif owner is None {
        if ambient is not None {
            if takeover {
                chosen = ambient;
                notice = (
                    f"takeover: {file_path.name} runs as the project "
                    f"{_project_label(ambient)}, rewriting its client build"
                );
            } elif _project_serves(ambient) {
                notice = (
                    f"{file_path.name} is outside the project "
                    f"{_project_label(ambient)}; running it standalone "
                    "(--takeover runs it as this project)"
                );
            }
        }
    } elif takeover or _takes_over_app(owner, str(file_path)) {
        notice = (
            f"takeover: {file_path.name} runs as the project "
            f"{_project_label(owner)}, rewriting its client build "
            "(--no-takeover runs it standalone)"
        );
    }
    if notice {
        _scope_notice(notice);
    }

    if chosen is not None and active_profile {
        chosen.apply_profile_overlay(active_profile);
    }
    pin_project_scope(chosen);
    if chosen is not None {
        add_venv_to_path(chosen);
    }
}

def _default_codespace_is_native -> bool {
    import from jaclang.project.config { get_config, PlacementConfig }
    cfg = get_config();
    effective = cfg.placement.default_codespace
        if cfg is not None
        else PlacementConfig().default_codespace;
    return effective == 'native';
}

def _populate_native_argv(engine: ExecutionEngine, argv: list[str]) -> None {
    import ctypes;

    argc_addr = int(engine.get_global_value_address("__jac_argc"));
    argv_addr = int(engine.get_global_value_address("__jac_argv"));
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

    setattr(engine, "_jac_argv_refs", (c_strings, c_argv));
}

def _plan_ui(plan: RunPlan) -> str {
    return plan.spec.ui;
}

def _plan_route(plan: RunPlan, app: any) -> str {
    if app is None {
        return "";
    }
    return app.effective_route() if plan.spec.has_server else "";
}

def _print_plan(plan: RunPlan, app: any) {
    if app is not None and not app.implicit {
        console.print(f"app          : {app.name}");
    }
    console.print(f"kind         : {plan.kind}");
    console.print(f"action       : {plan.action}");
    console.print(f"summary      : {plan.summary}");
    if plan.entry_path {
        console.print(f"entry-point  : {plan.entry_path}");
    }
    ui = _plan_ui(plan);
    if ui {
        console.print(f"ui           : {ui}");
    }
    platform = str(plan.flags.get("platform", "") or "");
    if platform {
        console.print(f"platform     : {platform}");
    }
    route = _plan_route(plan, app);
    if route {
        console.print(f"route        : {route}");
    }
    console.print(f"equivalent   : {plan.command_line()}");
}

def _workspace_plans(cfg: any, project_root: str) -> list {
    import from jaclang.project.kinds { plan_app_run, plan_workspace }
    try {
        return plan_workspace(cfg, project_root);
    } except ValueError {}
    plans: list = [];
    for app in cfg.apps.values() {
        try {
            plans.append(plan_app_run(cfg, project_root, app));
        } except ValueError {}
    }
    return plans;
}

def _show_workspace(cfg: any, project_root: str) -> int {
    header = ["app", "kind", "entry_rel", "action", "ui", "route"];
    rows: list[list[str]] = [];
    planned: set[str] = set();
    for plan in _workspace_plans(cfg, project_root) {
        app = cfg.app(plan.app);
        planned.add(plan.app);
        entry_rel = (
            os.path.relpath(plan.entry_path, project_root) if plan.entry_path else "-"
        );
        rows.append(
            [
                plan.app,
                plan.kind,
                entry_rel,
                plan.action,
                _plan_ui(plan) or "-",
                _plan_route(plan, app) or "-"
            ]
        );
    }
    for (name, unplanned) in cfg.apps.items() {
        if name not in planned {
            app_cfg: any = unplanned;
            rows.append(
                [
                    name,
                    str(app_cfg.kind or "-"),
                    "(no entry)",
                    "-",
                    str(app_cfg.ui() or "-"),
                    "-"
                ]
            );
        }
    }
    widths = [max([len(r[i]) for r in ([header] + rows)]) for i in range(len(header))];
    console.print("  ".join([header[i].ljust(widths[i]) for i in range(len(header))]));
    console.print("  ".join(["-" * w for w in widths]));
    for row in rows {
        console.print("  ".join([row[i].ljust(widths[i]) for i in range(len(header))]));
    }
    if cfg.default_app {
        console.print(f"\ndefault-app  : {cfg.default_app}");
    }
    return 0;
}

def _serve_flag_spelling -> dict {
    return {
        "port": "--port",
        "dev": "--dev",
        "api_port": "--api-port",
        "no_client": "--no-client",
        "faux": "--faux",
        "host": "--host",
        "platform": "--platform",
        "fleet": "--fleet",
        "workers": "--workers"
    };
}

def _flag_list(names: list) -> str {
    return ", ".join(sorted(names));
}

def _port_is_explicit(port: (int | None), cfg: any) -> bool {
    if port is None {
        return False;
    }
    if cfg is None {
        return True;
    }
    raw = getattr(cfg, "_raw_data", {}).get("serve", {});
    return not (isinstance(raw, dict) and raw.get("port") == port);
}

def _serve_overrides(
    port: (int | None),
    dev: (bool | None),
    api_port: (int | None),
    no_client: (bool | None),
    faux: (bool | None),
    host: (str | None),
    platform: (str | None),
    fleet: bool,
    cfg: any,
    workers: (str | None) = None
) -> dict {
    over: dict = {};
    if _port_is_explicit(port, cfg) {
        over["port"] = port;
    }
    if dev is not None {
        over["dev"] = dev;
    }
    if api_port is not None {
        over["api_port"] = api_port;
    }
    if no_client is not None {
        over["no_client"] = no_client;
    }
    if faux is not None {
        over["faux"] = faux;
    }
    if host is not None {
        over["host"] = host;
    }
    if platform is not None {
        over["platform"] = platform;
    }
    if fleet {
        over["fleet"] = True;
    }
    if workers is not None {
        over["workers"] = workers;
    }
    return over;
}

def _entry_flags_used(
    entry_name: str, nd: str, root_id: str, debug_mode: bool
) -> list {
    used: list = [];
    if entry_name {
        used.append("--entry");
    }
    if nd {
        used.append("--node");
    }
    if root_id {
        used.append("--root");
    }
    if debug_mode {
        used.append("--debug");
    }
    return used;
}

def _kind_serve_flags(
    plan: (RunPlan | None), kind_serves: bool, serve_mode: (bool | None)
) -> dict {
    if not kind_serves or plan is None {
        return {};
    }
    if serve_mode is not True {
        return dict(plan.flags);
    }
    return {
        k: v
        for (k, v) in plan.flags.items()
        if k != "dev"
    };
}

def _serve_with(
    entry_path: str,
    plan_flags: dict,
    over: dict,
    main: bool,
    app_name: str,
    takeover: bool = False
) -> int {
    import from jaclang.project.providers { initialize_provider_registry }

    if not entry_path {
        console.error(
            "Nothing to serve: no entry-point resolved.\n"
            "  Name a file or an app, or set the app's entry-point in jac.toml."
        );
        return 1;
    }
    initialize_provider_registry();

    kw: dict = {
        "port": 0,
        "dev": False,
        "api_port": 0,
        "no_client": False,
        "faux": False,
        "host": "",
        "platform": "",
        "takeover": False,
        "fleet": False,
        "workers": ""
    };
    for (k, v) in plan_flags.items() {
        if k in kw {
            kw[k] = v;
        }
    }
    for (k, v) in over.items() {
        if k not in kw {
            raise ValueError(f"serve override {k!r} is not a serve argument");
        }
        kw[k] = v;
    }
    kw["takeover"] = takeover;
    return serve(filename=entry_path, main=main, app=app_name, **kw);
}

def _build_plan(plan: RunPlan) -> int {
    if plan.verb == "native" {
        import from jaclang.cli.commands.native_build { native_build }
        out = plan.flags.get("output", "");
        if out {
            out_dir = os.path.dirname(out);
            if out_dir {
                os.makedirs(out_dir, exist_ok=True);
            }
        }
        return native_build(
            filename=plan.entry_path, output=out, lib=plan.flags.get("lib", False)
        );
    }
    if plan.verb == "build" {
        import from jaclang.cli.commands.build { build }
        return build(
            target=plan.app,
            projection=plan.flags.get("as", "jab"),
            platform=plan.flags.get("platform", None)
        );
    }

    console.error(f"Project kind '{plan.kind}' has no build verb '{plan.verb}'.");
    return 1;
}

def _show_run(
    plan: (RunPlan | None), app: any, target: str, file: str, want_serve: bool
) -> int {
    if plan is None {
        act = "serve" if want_serve else "execute";
        console.print(f"jac run {target}  ->  {act} (explicit file; no app claims it)");
        return 0;
    }
    _print_plan(plan, app);
    if want_serve and plan.action != "serve" {
        console.print("override     : --serve forces serving");
    }
    if (not want_serve) and plan.action == "serve" {
        console.print("override     : --no-serve forces execution");
    }
    if (not want_serve) and plan.action == "build" and file {
        console.print("override     : a named file executes; a bare run builds");
    }
    return 0;
}

def _run_jab(
    filename: str, port: (int | None), args: list[str], serve_only: bool
) -> int {
    import from jaclang.dist.jab { materialize_jab }

    try {
        img_root = materialize_jab(filename);
    } except Exception as e {
        console.error(f"Cannot load {filename}: {e}");
        return 1;
    }
    return run_jab_image(img_root, port, args, serve_only, filename);
}

impl run_jab_image(
    img_root: Path, port: (int | None), args: list[str], serve_only: bool, label: str
) -> int {
    import from jaclang.dist.jab { jab_app_meta }

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

            serve_port = (
                img_cfg.serve.port if img_cfg and img_cfg.serve.port != 8000 else 0
            );
        }
        return serve(
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
        return run(target=entry_abs, args=args);
    }
    console.error(
        f"{label}: kind '{kind}' is not directly runnable from a jab "
        "(build its platform projection instead)."
    );
    return 1;
}

def _jab_native_bin(img_root: Path, entry_rel: str) -> (str | None) {
    import from jaclang.jac0core.ext_registry { base_stem }
    import from jaclang.server.sealed_serve { NATIVE_DIR_REL }
    try {
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        triple = str(llvm.get_default_triple());
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


def _is_file_target(target: str) -> bool {
    if not target {
        return False;
    }
    if "/" in target or "\\" in target {
        return True;
    }
    return target.lower().endswith((".jac", ".py", ".jab"));
}

def _load_cwd_config -> any {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { initialize_provider_registry }

    initialize_provider_registry();
    existing_config = get_config();
    active_profile = existing_config.active_profile if existing_config else None;
    cfg = get_config(start_path=Path.cwd(), force_discover=True);
    if cfg is not None and active_profile {
        cfg.apply_profile_overlay(active_profile);
    }
    return cfg;
}

def _project_root_of(cfg: any) -> str {
    return str(cfg.project_root) if cfg.project_root else os.getcwd();
}

def _effective_config(cfg: any, app: any) -> any {
    if cfg is None or app is None or app.name not in cfg.apps {
        return cfg;
    }
    return cfg.effective_for_app(app.name);
}

def _file_app(cfg: any, target: str, takeover: (bool | None)) -> any {
    if cfg is None {
        return None;
    }
    app = cfg.app_for_path(os.path.abspath(target));
    if app is None and takeover is True {
        try {
            app = cfg.resolve_app("");
        } except ValueError {
            app = None;
        }
    }
    return app;
}

def _resolve_target(target: str, takeover: (bool | None) = None) -> tuple {
    import from jaclang.project.config { get_config }

    if _is_file_target(target) {
        _pin_run_scope(target, takeover);
        _discover_config_from_file(target);
        cfg = get_config();
        return (cfg, _file_app(cfg, target, takeover), target, 0);
    }
    cfg = _load_cwd_config();
    if cfg is None {
        if target {
            console.error(
                f"'{target}' is not a file, and no jac.toml defines an app by that "
                "name.\n"
                "  Usage: jac run <app> (inside a project), or jac run <file.jac>."
            );
        } else {
            console.error(
                "No target given and no jac.toml found.\n"
                "  Usage: jac run <file.jac>, or run inside a Jac project directory."
            );
        }
        return (None, None, "", 1);
    }
    if target {
        app = cfg.app(target);
        if app is not None {
            return (cfg, app, "", 0);
        }
        if os.path.isfile(target) {
            _pin_run_scope(target, takeover);
            _discover_config_from_file(target);
            file_cfg = get_config();
            return (file_cfg, _file_app(file_cfg, target, takeover), target, 0);
        }
        console.error(
            f"No app named '{target}' in {cfg.toml_path}, and no such file.",
            hint=f"Apps: {', '.join(cfg.apps.keys())}"
        );
        return (cfg, None, "", 2);
    }
    try {
        app = cfg.resolve_app("");
    } except ValueError as e {
        console.error(str(e));
        return (cfg, None, "", 2);
    }
    return (cfg, app, "", 0);
}

def _resolve_plan(target: str, takeover: (bool | None) = None) -> tuple {
    import from jaclang.project.kinds { plan_app_run }

    (cfg, app, file, rc) = _resolve_target(target, takeover);
    if rc {
        return (None, cfg, None, file, rc);
    }
    if cfg is None or app is None {
        return (None, cfg, None, file, 0);
    }
    project_root = _project_root_of(cfg);
    try {
        plan = plan_app_run(
            cfg,
            project_root,
            app,
            entry_override=(os.path.abspath(file) if file else "")
        );
    } except ValueError as e {
        if file {
            return (None, cfg, app, file, 0);
        }
        key = (
            "[project] entry-point"
                if app.implicit
                else f"[apps.{app.name}] entry-point"
        );
        console.error(f"{e}\n  Set {key} in jac.toml (project root: {project_root}).");
        return (None, cfg, app, file, 2);
    }
    return (plan, cfg, app, file, 0);
}

def _invoke_entrypoint(
    filename: str, entrypoint: str, args: list, main: bool, root_id: str, nd: str
) -> int {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.runtime.constructs { WalkerArchetype }

    if not filename.endswith('.jac') {
        console.error('Not a valid file!\nOnly supports `.jac`');
        return 1;
    }
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);

    if root_id {
        mach.set_user_root(root_id);
    }
    ret_module = Jac.jac_import(
        target=mod, base_path=base, override_name='__main__' if main else None
    );
    if not ret_module {
        mach.close();
        return 0;
    }
    (loaded_mod, ) = ret_module;
    if not loaded_mod {
        console.error('Errors occurred while importing the module.');
        mach.close();
        return 1;
    }
    archetype = getattr(loaded_mod, entrypoint)(*args);
    mach.set_entry_node(nd);
    if (
        isinstance(archetype, WalkerArchetype)
        and Jac.check_read_access(mach.entry_node)
    ) {
        Jac.`spawn(mach.entry_node.archetype, archetype);
    }
    mach.close();
    return 0;
}

impl run(
    target: str = "",
    show: bool = False,
    main: bool = True,
    cache: bool = True,
    diagnostics: str = "",
    entry_name: str = "",
    nd: str = "",
    root_id: str = "",
    debug_mode: bool = False,
    serve_mode: (bool | None) = None,
    port: (int | None) = None,
    dev: (bool | None) = None,
    api_port: (int | None) = None,
    no_client: (bool | None) = None,
    faux: (bool | None) = None,
    host: (str | None) = None,
    platform: (str | None) = None,
    takeover: (bool | None) = None,
    fleet: bool = False,
    workers: (str | None) = None,
    args: list = [],
    backend: str = ""
) -> int {
    use_line_buffered_output();
    if backend not in ("", "python", "native") {
        console.error("--backend must be python or native.");
        return 1;
    }
    if backend and (target.endswith(".jab") or debug_mode or entry_name) {
        console.error(
            "--backend requires ordinary Jac source execution; it cannot be combined with .jab, --debug or --entry."
        );
        return 1;
    }

    if target.endswith(".jab") {
        if dev {
            console.error(
                "A sealed .jab never serves in dev mode; run the project "
                "source with --dev instead."
            );
            return 1;
        }
        if show {
            console.print(
                f"jac run {target}  ->  kind-aware dispatch (sealed app bundle)"
            );
            return 0;
        }
        return _run_jab(target, port, args, serve_only=(serve_mode is True));
    }

    if show and not target {
        cfg0 = _load_cwd_config();
        if cfg0 is not None and cfg0.is_workspace {
            return _show_workspace(cfg0, _project_root_of(cfg0));
        }
    }

    (plan, cfg, app, file, rc) = _resolve_plan(target, takeover);
    if rc {
        return rc;
    }
    eff = _effective_config(cfg, app);

    over = _serve_overrides(
        port, dev, api_port, no_client, faux, host, platform, fleet, eff, workers
    );
    entry_flags = _entry_flags_used(entry_name, nd, root_id, debug_mode);
    kind_serves = plan is not None and plan.action == "serve";
    kind_can_serve = plan is None or kind_serves or bool(_plan_ui(plan));

    if serve_mode is False {
        want_serve = False;
    } elif serve_mode is True {
        want_serve = True;
    } elif kind_serves {
        want_serve = True;
    } else {
        want_serve = bool(over) and kind_can_serve;
    }

    if over and not want_serve {
        spelling = _serve_flag_spelling();
        shown = _flag_list([spelling[k] for k in over]);
        kind = plan.kind if plan is not None else "cli";
        console.error(
            f"{shown} applies only when serving, but app kind '{kind}' "
            "executes.\n"
            "  Add --serve to serve it anyway, or drop the flag."
        );
        return 1;
    }
    if entry_flags and want_serve {
        console.error(
            f"{_flag_list(entry_flags)} applies only when executing, but this "
            "runs as a server.\n"
            "  Add --no-serve to execute instead, or drop the flag."
        );
        return 1;
    }

    if backend
        and (
            want_serve or (plan is not None and plan.action == "build" and not file)
        ) {
        console.error(
            "--backend applies only when executing Jac source, not serving or building an app."
        );
        return 1;
    }
    if backend
        and not (file or (plan.entry_path if plan is not None else "")).endswith(
            ".jac"
        ) {
        console.error("--backend requires a .jac source file.");
        return 1;
    }
    if show {
        if backend {
            console.print(f"backend      : {backend}");
        }
        return _show_run(plan, app, target, file, want_serve);
    }

    if want_serve {
        return _serve_with(
            file or (plan.entry_path if plan is not None else ""),
            _kind_serve_flags(plan, kind_serves, serve_mode),
            over,
            main,
            app.name if app is not None else "",
            takeover=takeover is True
        );
    }
    if plan is not None and plan.action == "build" and not file {
        return _build_plan(plan);
    }

    exec_target = file or (plan.entry_path if plan is not None else "");
    if not exec_target {
        console.error(
            "Nothing to run: no entry-point resolved.\n"
            "  Usage: jac run <app> or jac run <file.jac>."
        );
        return 1;
    }
    if debug_mode {
        return debug(filename=exec_target, main=main, cache=cache);
    }
    if entry_name {
        return _invoke_entrypoint(exec_target, entry_name, args, main, root_id, nd);
    }
    return _exec_file(exec_target, main, cache, diagnostics, args, backend);
}

def _exec_file(
    filename: str,
    main: bool,
    cache: bool,
    diagnostics: str,
    args: list,
    backend: str = ""
) -> int {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.project.config { get_config }

    _discover_config_from_file(filename);

    if not cache {
        import from jaclang.compiler.driver.jir { scrub_cache_dirs }
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
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    previous_codespace = get_effective_default_codespace_override();
    try {
        if backend {
            set_effective_default_codespace(
                'server' if backend == 'python' else 'native'
            );
        }
        if filename.endswith('.jac') {
            native_executed = False;

            _cfg_kind = get_config();
            _kind_forced = False;
            if _cfg_kind is not None {
                import from jaclang.project.kinds { resolve_app_kind }
                _abs_file = os.path.abspath(filename);
                _app = _cfg_kind.app_for_path(_abs_file);
                _kind_forced = (
                    _app is not None
                    and resolve_app_kind(_cfg_kind, _app, _abs_file) == 'cli-native'
                );
            }
            import from jaclang.compiler.driver.boundary_classify {
                module_demoted_native as _na_demoted
            }
            if backend != "python"
                and (
                    backend == "native"
                    or _kind_forced
                    or (
                        _default_codespace_is_native()
                        and sys.stdout is sys.__stdout__
                        and not _na_demoted(filename)
                    )
                ) {
                import ctypes;
                import from jaclang.compiler.driver.compile_options {
                    CompileOptions as _RunOpts
                }
                full_path = os.path.abspath(filename);
                program = Jac.get_program();
                _run_options = (
                    _RunOpts(force_codespace='native', force_target_program=True)
                        if _kind_forced or backend == "native"
                        else None
                );
                ir_mod = program.compile(file_path=full_path, options=_run_options);
                if program.errors_had {
                    for _err in program.errors_had {
                        console.error(_err.pretty_print());
                    }
                    return 1;
                }
                if (
                    ir_mod
                    and ir_mod.decided_codespace == 'native'
                    and ir_mod.gen.native_engine
                ) {
                    engine = ir_mod.gen.native_engine;
                    _populate_native_argv(engine, sys.argv);
                    if main {
                        addr = engine.get_function_address("jac_entry");
                        if addr != 0 {
                            fn = ctypes.CFUNCTYPE(None)(addr);
                            fn();
                            native_executed = True;
                        }
                    }
                }
                if (_kind_forced or backend == "native") and not native_executed {
                    console.error(
                        "Native execution was requested but did not produce a runnable native "
                        "entry (no engine or no jac_entry)."
                    );
                    return 1;
                }
            }
            if not native_executed {
                if backend == "python" {
                    import from jaclang.compiler.driver.compile_options {
                        CompileOptions
                    }
                    program = Jac.get_program();
                    program.compile(
                        file_path=os.path.abspath(filename),
                        options=CompileOptions(
                            force_codespace="server",
                            default_codespace="server",
                            force_target_program=True
                        )
                    );
                    if program.errors_had {
                        for error in program.errors_had {
                            console.error(error.pretty_print());
                        }
                        return 1;
                    }
                }
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
        n_errors = len(Jac.get_program().errors_had);
        n_warnings = len(Jac.get_program().warnings_had);
        if diagnostics != "none" {
            if n_errors {
                for error in Jac.get_program().errors_had {
                    console.error(error.pretty_print());
                }
            }
            if diagnostics == "all" and n_warnings {
                for warning in Jac.get_program().warnings_had {
                    console.warning(f"{warning}");
                }
            }
        }
        return 1 if (n_errors and diagnostics != "none") else 0;
    } except Exception as e {
        if diagnostics != "none" {
            if Jac.get_program().errors_had {
                for error in Jac.get_program().errors_had {
                    console.error(error.pretty_print());
                }
            } else {
                import from jaclang.runtime.traceback_render { dump_traceback }
                console.error(dump_traceback(e));
            }
        }
        return 1 if diagnostics != "none" else 0;
    } finally {
        set_effective_default_codespace(previous_codespace);
        sys.argv = original_argv;
        mach.close();
    }
}

def _serve_app(cfg: any, app: str, filename: str) -> any {
    if cfg is None {
        return None;
    }
    if app {
        named = cfg.app(app);
        if named is not None {
            return named;
        }
    }
    return cfg.app_for_path(os.path.abspath(filename));
}


def _serve_fleet(
    cfg: any,
    served: any,
    filename: str,
    port: int,
    fleet: bool,
    dev: bool = False,
    no_client: bool = False
) -> (int | None) {
    if cfg is None or served is None {
        if fleet {
            console.error(
                "--fleet has nothing to run: no jac.toml app claims this file.\n"
                "  Declare [apps.<name>] kind = \"service\" entries and run an app."
            );
            return 1;
        }
        return None;
    }
    services = _service_apps(cfg, served);
    if not services {
        if fleet {
            console.error(
                "--fleet has nothing to run: no service apps are declared.\n"
                "  Declare them as [apps.<name>] kind = \"service\" in jac.toml."
            );
            return 1;
        }
        return None;
    }
    if not fleet and _gateway_colocates(cfg) {
        return None;
    }
    import from jaclang.project.kinds { plan_app_run }
    import from jaclang.scale.plugin { scale_local_serve }

    project_root = (
        str(cfg.project_root)
            if cfg.project_root
            else os.path.dirname(os.path.abspath(filename))
    );
    try {
        served_plan = plan_app_run(
            cfg, project_root, served, entry_override=os.path.abspath(filename)
        );
        members: list[RunPlan] = [
            plan_app_run(cfg, project_root, svc) for svc in services
        ];
    } except ValueError as e {
        console.error(f"Cannot assemble the service fleet: {e}");
        return 1;
    }
    return scale_local_serve(
        served_plan, members, port=port, dev=dev, no_client=no_client
    );
}


def _client_display_path(path: Path, base: str) -> str {
    import jaclang;
    resolved = path.resolve();
    roots = [Path(base).resolve(), Path(jaclang.__file__).resolve().parent.parent];
    for parent in roots {
        try {
            return str(resolved.relative_to(parent));
        } except ValueError {
            continue;
        }
    }
    return path.name;
}

impl serve(
    filename: str,
    port: int = 0,
    main: bool = True,
    faux: bool = False,
    dev: bool = False,
    api_port: int = 0,
    no_client: bool = False,
    host: str = "",
    platform: str = "",
    takeover: bool = False,
    fleet: bool = False,
    app: str = "",
    workers: str = ""
) -> int {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from pathlib { Path }
    import from jaclang.compiler.frontend.codeinfo { set_effective_default_codespace }
    import from jaclang.project.config { get_config }

    use_line_buffered_output();
    set_effective_default_codespace('server');

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
        console.error(f"couldn't read `{filename}`: No such file or directory");
        return 1;
    }

    _discover_config_from_file(filename);
    cfg = get_config();
    served = _serve_app(cfg, app, filename);
    if served is not None {
        import from jaclang.client.cli { run_client_start }
        client_rc = run_client_start(
            served, host, platform, port, api_port, dev, no_client
        );
        if client_rc is not None {
            return client_rc;
        }
    }

    import from jaclang.scale.plugin { mark_scale_runtime }
    mark_scale_runtime();
    fleet_rc = _serve_fleet(cfg, served, filename, port, fleet, dev, no_client);
    if fleet_rc is not None {
        return fleet_rc;
    }

    if takeover {
        import os;
        import from jaclang.server.session { takeover_project }
        tk_base = Jac.get_base_path_dir() or (os.path.split(filename)[0] or './');
        tk_target = Jac.get_full_target_path() or filename;
        evicted = takeover_project(tk_base, tk_target);
        if evicted {
            console.info(
                f"takeover: evicted {evicted} session(s) holding this"
                " project's database"
            );
        }
    }
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];

    try {
        Jac.jac_import(target=mod, base_path=base, lng=lng);
        if Jac.get_program().errors_had {
            for error in Jac.get_program().errors_had {
                console.error(error.pretty_print());
            }
            mach.close();
            return 1;
        }
        assemble_served_program(cfg, served, base);
    } except Exception as e {
        if Jac.get_program().errors_had {
            for error in Jac.get_program().errors_had {
                console.error(error.pretty_print());
            }
        } else {
            import from jaclang.runtime.traceback_render { dump_traceback }
            console.error(f"Error loading {filename}: {e}");
            console.error(dump_traceback(e));
        }
        mach.close();
        return 1;
    }

    try {
        mach.mem.unit_exit();
    } except Exception {}

    port_pinned = port > 0;
    port = port if port_pinned else 8000;
    if dev and not no_client {
        vite_port = port;
        actual_api_port = api_port if api_port > 0 else port + 1;
        api_port_pinned = api_port > 0;
    } else {
        actual_api_port = port;
        vite_port = 0;
        api_port_pinned = port_pinned;
    }

    import from jaclang.server.settings { ServeConfigError, ServeSettings }
    overrides: dict[str, any] = {
        'port': actual_api_port,
        'strict_port': api_port_pinned,
        'dev': dev,
        'no_client': no_client
    };
    if host {
        overrides['host'] = host;
    }
    if workers {
        overrides['workers'] = workers;
    }
    try {
        settings = ServeSettings.load(base, overrides);
    } except ServeConfigError as e {
        console.error(f"cannot start the server:\n{e}");
        mach.close();
        return 1;
    }
    ServerClass = Jac.get_api_server_class();
    server = ServerClass(module_name=mod, base_path=base, settings=settings);
    if faux {
        try {
            server.print_endpoint_docs();
        } except Exception as e {
            import from jaclang.runtime.traceback_render { dump_traceback }
            console.error(f"Error generating endpoint documentation: {e}");
            console.error(dump_traceback(e));
            mach.close();
            return 1;
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
            import from jaclang.server.hmr { HotReloader }
            import from jaclang.server.watcher { JacFileWatcher }

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
            console.warning(f"HMR initialization failed: {e}");
        }

        if not no_client {
            try {
                import time;
                import from jaclang.compiler.driver.pass_driver { compile_progress }
                compiler = server.introspector._bundle_builder._get_compiler();
                compiled: list[str] = [];
                active: list[str] = [];
                completed: list[int] = [0];
                started = time.perf_counter();
                with console.status("Compiling client...") as status {
                    def _on_module(file_path: str) {
                        compiled.append(file_path);
                        active.append(file_path);
                    }
                    def _on_finished(file_path: str) {
                        active.remove(file_path);
                        completed[0] += 1;
                    }
                    def _progress_text -> str {
                        current = list(active);
                        detail = (
                            f"Compiling client: {completed[0]} completed"
                            f" · {len(current)} active · {time.perf_counter()
                                - started:.1f}s"
                        );
                        if current {
                            detail += " · "
                                + _client_display_path(Path(current[-1]), base);
                        }
                        return detail;
                    }
                    status.update(_progress_text);
                    with compile_progress.listen(_on_module, _on_finished) {
                        compiler.compile(server.introspector._module, Path(filename));
                    }
                }
                elapsed = time.perf_counter() - started;
                detail = (
                    f"{len(compiled)} modules compiled"
                        if compiled
                        else "all modules served from cache"
                );
                console.print(
                    f"  ✔ Initial client compilation completed ({detail}, {elapsed:.1f}s)"
                );

                compiler._emit_na_wasm(Path(filename));
            } except Exception as e {
                console.warning(f"Initial client compilation failed: {e}");

                if hot_reloader is not None {
                    hot_reloader.record_error(str(filename), str(e));
                }
            }
        }
    }

    def _announce_ready(actual_port: int) {
        primary_port = actual_port;
        if dev and not no_client {
            free_vite_port = _find_free_port(
                vite_port, skip_port=actual_port, strict=port_pinned
            );
            declared_paths: list = [];
            claimed_paths: list = [];
            try {
                import from jaclang.client.vite_bundler { DEV_PROXY_PREFIXES }
                declared_paths = server.introspector.declared_api_paths();
                claimed_paths = server.introspector.client_claimed_paths(
                    DEV_PROXY_PREFIXES
                );
            } except Exception as e {
                console.warning(f"Could not read declared API paths: {e}");
            }
            (started_vite, bound_port) = _start_vite_dev_server(
                base, free_vite_port, actual_port, declared_paths, claimed_paths
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
        return int(
            server.start(dev=dev, no_client=no_client, on_ready=_announce_ready)
        );
    } except ServeConfigError as e {
        console.error(str(e));
        if hot_reloader is not None {
            hot_reloader.stop();
        }
        mach.close();
        return 1;
    } except KeyboardInterrupt {
        console.print('\nShutting down');
        return 0;
    } except Exception as e {
        import from jaclang.runtime.traceback_render { dump_traceback }
        import from jaclang.server.net { PortInUseError }
        if isinstance(e, PortInUseError) {
            raise;
        }
        console.error(f"Server error: {e}");
        console.error(dump_traceback(e));
        return 1;
    } finally {
        try {
            if hot_reloader is not None {
                hot_reloader.stop();
            }
        } finally {
            import subprocess;
            for started_vite in vite_holder {
                started_vite.terminate();
                try {
                    started_vite.`wait(timeout=5);
                } except subprocess.TimeoutExpired {
                    started_vite.kill();
                    started_vite.`wait();
                }
            }
            mach.close();
        }
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
        "\n  Installing watchdog (required for --dev mode)...\n", style="info"
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
    ips: list[str] = [];
    try {
        hostname = socket.gethostname();
        addrs = socket.getaddrinfo(hostname, None);
        for addr in addrs {
            ip = addr[4][0];
            if not isinstance(ip, str) {
                continue;
            }
            if not ip.startswith('127.') and ':' not in ip {
                if ip not in ips {
                    ips.append(ip);
                }
            }
        }
    } except Exception {}
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
        console.print(f"\n  jac dev server v{version}\n", style="bold cyan");
    } except Exception {
        console.print(f"\n  jac dev server\n", style="bold cyan");
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
        console.print("  Server ready", style="bold green");
        console.print();
        console.print("  Mode: Development (with HMR)", style="muted");
        console.print(f"    App:  http://localhost:{primary_port}/", style="muted");
        console.print(f"    API:  http://localhost:{api_port}/", style="muted");
        console.print();

        file_count = _count_jac_files(base_path);
        if file_count > 0 {
            console.print_watching("**/*.jac", file_count);
        } else {
            console.print("  Watching for changes", style="info");
        }
    } elif dev and no_client {
        console.print("  Server ready (API only)", style="bold green");
        console.print();
        file_count = _count_jac_files(base_path);
        if file_count > 0 {
            console.print_watching("**/*.jac", file_count);
        } else {
            console.print("  Watching for changes", style="info");
        }
    } elif no_client {
        console.print("  Server ready (no client)", style="bold green");
    } else {
        console.print("  Server ready", style="bold green");
    }

    console.print();
}

def _find_free_port(start: int, skip_port: int = 0, strict: bool = False) -> int {
    import from jaclang.server.net { find_available_port }
    try {
        return find_available_port(
            start, max_retries=50, skip_port=skip_port, strict=strict
        );
    } except OSError as e {
        if strict {
            raise;
        }
        console.warning(f"[Vite] {e}; falling back.");
        return start if start != skip_port else start + 50;
    }
}

def _start_vite_dev_server(
    base_path: str,
    vite_port: int,
    api_port: int,
    api_paths: (list[str] | None) = None,
    client_paths: (list[str] | None) = None
) -> any {
    import from pathlib { Path }

    try {
        import from jaclang.client.vite_bundler { ViteBundler }

        project_dir = Path(base_path);
        bundler = ViteBundler(project_dir);

        client_dir = bundler._get_client_dir();
        entry_file = client_dir / 'build' / 'main.js';

        bundler.create_vite_config(
            entry_file,
            is_dev=True,
            api_port=api_port,
            api_paths=api_paths,
            client_paths=client_paths
        );

        if not (client_dir / 'configs' / 'package.json').exists() {
            bundler.create_package_json();
        }

        try {
            import from jaclang.server.hmr { HotReloader }
            reloader = HotReloader._active;
            if reloader is not None {
                reloader.attach_client_bundler(bundler);
            }
        } except Exception as e {
            console.warning(f"Client error events will not reach the terminal: {e}");
        }

        process = bundler.start_dev_server(vite_port, suppress_initial_output=True);
        return (process, bundler.dev_server_port or vite_port);
    } except ImportError as e {
        console.warning(f"client bundler unavailable, skipping Vite dev server: {e}");
        return (None, vite_port);
    } except Exception as e {
        console.warning(f"Could not start Vite dev server: {e}");
        return (None, vite_port);
    }
}

impl debug(filename: str, main: bool = True, cache: bool = False) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.debugger { debugger as db }
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

def _tool_site_dirs(use_global: bool) -> list[tuple[str, Path]] {
    import from jaclang.project.tool_paths { python_project_site, python_global_site }

    sites: list[tuple[str, Path]] = [];
    if not use_global {
        proj_site = python_project_site();
        if proj_site is not None {
            sites.append(("project", proj_site));
        }
    }
    glob_site = python_global_site();
    if glob_site is not None {
        sites.append(("global", glob_site));
    }
    return sites;
}

def _console_scripts_in(site_dir: Path) -> list[tuple[str, str, EntryPoint]] {
    import from importlib.metadata { distributions }

    found: list[tuple[str, str, EntryPoint]] = [];
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

def _node_tools_in(bin_dir: Path | None) -> list[str] {
    names: set[str] = set();
    if bin_dir is None or not bin_dir.exists() {
        return [];
    }
    for `entry in bin_dir.iterdir() {
        if `entry.is_dir() {
            continue;
        }
        base = `entry.name;
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

def _find_node_tool(bin_dir: Path | None, name: str) -> Path | None {
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

def _run_entry_point(
    name: str, ep: EntryPoint, site_dir: Path, args: list[str]
) -> int {
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

def _run_node_tool(name: str, bin_path: Path, args: list[str]) -> int {
    import subprocess;
    import from jaclang.project.config { get_config }
    import from jaclang.client.bun_installer { get_bun }

    bun = get_bun();
    if bun is None {
        console.error(
            f"Cannot run npm tool '{name}': the bun runtime is unavailable.",
            hint="Install bun, or run the project once (e.g. 'jac run') to let jac provision it."
        );
        return 1;
    }
    config = get_config();
    cwd = str(config.project_root) if config and config.project_root else None;
    result = subprocess.run([bun, str(bin_path)] + list(args), cwd=cwd);
    return result.returncode;
}

def _tool_tiers(use_global: bool, use_node: bool) -> list[tuple[str, str, Path]] {
    import from jaclang.project.config { get_config }
    import from jaclang.project.tool_paths {
        python_project_site,
        python_global_site,
        node_bin_dir
    }

    config = get_config();

    universe: list[tuple[str, str, Path]] = [];
    proj_py = python_project_site(config);
    if proj_py is not None {
        universe.append(("project", "py", proj_py));
    }
    proj_node = node_bin_dir("project", config);
    if proj_node is not None {
        universe.append(("project", "node", proj_node));
    }
    glob_py = python_global_site();
    if glob_py is not None {
        universe.append(("global", "py", glob_py));
    }
    glob_node = node_bin_dir("global", config);
    if glob_node is not None {
        universe.append(("global", "node", glob_node));
    }

    tiers = universe;
    if use_global {
        tiers = [
            t
            for t in tiers
            if t[0] == "global"
        ];
    }
    if use_node {
        tiers = [
            t
            for t in tiers
            if t[1] == "node"
        ];
    }
    return tiers;
}

def _list_tools(tiers: list[tuple[str, str, Path]]) -> int {
    seen: set[str] = set();
    rows: list[tuple[str, str, str]] = [];
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
            "No CLI tools available. Install one with 'jac install <package>' "
            "(project Python), 'jac install --global <package>' (global Python), "
            "'jac install --npm <package>' (project npm), or "
            "'jac install --npm --global <package>' (global npm)."
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
    args: list[str] = []
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
        f"'jac install --global <package>' (global Python), "
        f"'jac install --npm <package>' (project npm), or "
        f"'jac install --npm --global <package>' (global npm) — "
        f"then 'jac x {name}'. Searched: {searched}."
    );
    return 1;
}
