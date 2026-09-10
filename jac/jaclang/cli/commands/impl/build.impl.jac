import os;

import from pathlib { Path }
import from jaclang.cli.console { console }

def _is_file_target(target: str) -> bool {
    if not target {
        return False;
    }
    if "/" in target or "\\" in target {
        return True;
    }
    return target.lower().endswith((".jac", ".py"));
}

def _build_target(cfg: any, target: str) -> tuple {
    if _is_file_target(target) {
        abs_file = os.path.abspath(target);
        return (cfg.app_for_path(abs_file), abs_file, 0);
    }
    if target {
        app = cfg.app(target);
        if app is not None {
            return (app, "", 0);
        }
        if os.path.isfile(target) {
            abs_file = os.path.abspath(target);
            return (cfg.app_for_path(abs_file), abs_file, 0);
        }
        console.error(
            f"No app named '{target}' in {cfg.toml_path}, and no such file.",
            hint=f"Apps: {', '.join(cfg.apps.keys())}"
        );
        return (None, "", 2);
    }
    try {
        return (cfg.resolve_app(""), "", 0);
    } except ValueError as e {
        console.error(str(e));
        return (None, "", 2);
    }
}

def _entry_stem(entry_path: str) -> str {
    return os.path.splitext(os.path.basename(entry_path))[0].split(".")[0];
}

def _build_app(
    cfg: any,
    project_root: str,
    app: any,
    projection: str,
    output: str,
    platform: str | None,
    fat: bool,
    entry_override: str,
    place: bool
) -> int {
    import from jaclang.project.kinds { plan_app_run }

    plan = None;
    if app is not None {
        try {
            plan = plan_app_run(cfg, project_root, app, entry_override=entry_override);
        } except ValueError as e {
            if not entry_override and projection not in ("wheel", "sdist", "npm") {
                console.error(str(e));
                return 2;
            }
        }
    }
    entry_path = entry_override or (plan.entry_path if plan is not None else "");
    kind_builds = plan is not None and plan.action == "build";
    plan_flags: dict = plan.flags if plan is not None else {};
    plan_verb = plan.verb if plan is not None else "";
    spec = plan.spec if plan is not None else None;
    client_artifact = projection == "client"
        or (
            spec is not None
            and bool(spec.ui)
            and not spec.has_server
            and "as" not in spec.flags
        );

    if client_artifact {
        import from jaclang.project.kinds { kind_has_client }
        if app is None {
            console.error(
                "A client build needs an app: no jac.toml app claims this file.",
                hint="Name the app instead: jac build <app>"
            );
            return 1;
        }
        resolved = cfg.resolved_kind(app);
        import from jaclang.client.cli { run_client_build }
        return run_client_build(
            app,
            platform,
            entry_override,
            output if place else "",
            kind=resolved if kind_has_client(resolved) else "web-app"
        );
    }

    if kind_builds and plan_verb == "native" {
        import from jaclang.cli.commands.native_build { native_build }
        if not entry_path or not os.path.isfile(entry_path) {
            console.error(
                f"No entry file for app '{app.name}'.",
                hint="Set the app's entry-point, or pass one: jac build main.jac --as native"
            );
            return 1;
        }
        plan_out = str(plan_flags.get("output", "") or "");
        out = (
            os.path.join(output, os.path.basename(plan_out or _entry_stem(entry_path)))
                if place or not plan_out
                else plan_out
        );
        out_dir = os.path.dirname(out);
        if out_dir {
            os.makedirs(out_dir, exist_ok=True);
        }
        return native_build(
            filename=entry_path, output=out, lib=bool(plan_flags.get("shared", False))
        );
    }

    if fat and projection not in ["jab", "binary"] {
        console.error(
            f"--fat is not supported for the '{projection}' projection.",
            hint="Vendoring applies to 'jab' and 'binary' bundles only."
        );
        return 1;
    }
    if (
        projection == "jab"
        and kind_builds
        and plan_verb == "build"
        and plan_flags.get("as") in ("wheel", "npm")
    ) {
        projection = str(plan_flags["as"]);
    }

    if projection in ["jab", "sealed", "binary", "wheel", "npm"] {
        import from jaclang.cli.commands.project { bundle }
        return bundle(
            output=output,
            target=projection,
            fat=fat,
            app=(app.name if app is not None else "")
        );
    }
    if projection == "source" {
        import from jaclang.cli.commands.eject { eject }
        return eject(
            source=project_root,
            output=(output if output != "dist" else ""),
            force=False
        );
    }
    console.error(f"Unknown projection: '{projection}'");
    return 1;
}

impl build(
    target: str = "",
    all_apps: bool = False,
    projection: str = "jab",
    output: str = "dist",
    check_only: bool = False,
    platform: str | None = None,
    fat: bool = False,
    native: bool = False,
    lib: bool = False,
    memory: str = "",
    native_target: str = "",
    debug: bool = False,
    native_link_mode: str = ""
) -> int {
    import from jaclang.project.config { get_config }
    if native or lib or memory or native_target or debug or native_link_mode {
        import from jaclang.cli.commands.native_build { native_build }
        if not native {
            console.error(
                "--lib, --memory, --target-triple, --link-mode and --debug describe a native build.",
                hint="Add --native: jac build main.jac --native --memory nogc"
            );
            return 1;
        }
        src = target;
        if not src or not os.path.isfile(src) {
            cfg_n = get_config(start_path=Path.cwd(), force_discover=True);
            (app_n, file_n, rc_n) = _build_target(cfg_n, target)
                if cfg_n is not None
                else (None, "", 1);
            if rc_n or not file_n {
                console.error(
                    "jac build --native needs a .jac file.",
                    hint="jac build main.jac --native"
                );
                return 1;
            }
            src = file_n;
        }
        out = "" if output == "dist" else output;
        return native_build(
            filename=src,
            output=out,
            lib=lib,
            target=native_target,
            debug=debug,
            memory=memory,
            link_mode=native_link_mode
        );
    }

    cfg = get_config(start_path=Path.cwd(), force_discover=True);
    if cfg is None or cfg.project_root is None {
        console.error(
            "jac build needs a project.",
            hint="Run inside a Jac project (jac.toml), or scaffold one with jac create."
        );
        return 1;
    }
    project_root = str(cfg.project_root);

    if check_only {
        import from jaclang.cli.commands.analysis { check }
        return check(
            paths=[project_root],
            ignore=[".jac", ".jachome", ".venv", "venv", "node_modules", ".git"]
        );
    }

    if all_apps {
        if target {
            console.error(
                "--all builds every app; drop the target.", hint="jac build --all"
            );
            return 1;
        }
        failed: list[str] = [];
        for app in (list(cfg.apps.values()) or [cfg.resolve_app("")]) {
            console.print(f"\nBuilding app '{app.name}' ({app.kind})", style="bold");
            rc = _build_app(
                cfg,
                project_root,
                app,
                projection,
                os.path.join(output, app.name),
                platform,
                fat,
                "",
                True
            );
            if rc != 0 {
                failed.append(app.name);
            }
        }
        if failed {
            console.error(f"Build failed for: {', '.join(failed)}");
            return 1;
        }
        return 0;
    }

    (app, file, rc) = _build_target(cfg, target);
    if rc {
        return rc;
    }
    return _build_app(
        cfg, project_root, app, projection, output, platform, fat, file, False
    );
}
