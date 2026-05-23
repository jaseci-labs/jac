"""Implementation of jac-shadcn CLI hooks."""

import os;
import from pathlib { Path }
import from jaclang.cli.command { Arg, HookContext }
import from jaclang.cli.registry { get_registry }

impl JacShadcnPlugin.create_cmd -> None {
    # Importing this module triggers the @registry.command(name="shadcn")
    # decorator at the top of shadcn_cli.jac, registering `jac shadcn` as
    # a top-level command group.
    import jac_shadcn.shadcn_cli;

    # Extend `jac create` so `jac create myapp --use shadcn --style nova
    # --theme rose` scaffolds AND themes in one go. The post-hook fires only
    # when both conditions hold: --use shadcn AND at least one theme flag.
    registry = get_registry();
    registry.extend_command(
        command_name="create",
        args=[
            # Explicit shorts everywhere to avoid auto-gen collisions with
            # `jac create`'s existing flags (--force=-f, --use=-u, --list_jacpacks=-l).
            Arg.create(
                "style", typ=str, default="", help="jac-shadcn: visual style", short=""
            ),
            Arg.create(
                "base-color",
                typ=str,
                default="",
                help="jac-shadcn: base color",
                short=""
            ),
            Arg.create(
                "theme", typ=str, default="", help="jac-shadcn: accent theme", short=""
            ),
            Arg.create(
                "font", typ=str, default="", help="jac-shadcn: font family", short=""
            ),
            Arg.create(
                "radius",
                typ=str,
                default="",
                help="jac-shadcn: border radius",
                short=""
            ),
            Arg.create(
                "menu-accent",
                typ=str,
                default="",
                help="jac-shadcn: menu accent",
                short=""
            ),
            Arg.create(
                "all",
                typ=bool,
                default=False,
                help="jac-shadcn: install every component the registry ships (default: 10 essentials)",
                short=""
            ),
            Arg.create(
                "bare",
                typ=bool,
                default=False,
                help="jac-shadcn: skip component install entirely (theme/css only)",
                short=""
            ),

        ],
        pre_hook=_validate_create_theme_args,
        post_hook=_handle_create_with_shadcn_theme,
        source="jac-shadcn"
    );
}


"""Pre-hook for `jac create --use shadcn --style X ...`: validate any
theme flags AND the --all/--bare mutex BEFORE create runs so an invalid
value doesn't leave a half-themed project behind. Cancels create on
validation failure."""
def _validate_create_theme_args(ctx: HookContext) -> None {
    if ctx.get_arg("use", "") != "shadcn" {
        return;
    }
    import from jaclang.cli.console { console }

    # --all and --bare are mutually exclusive.
    if ctx.get_arg("all", False) and ctx.get_arg("bare", False) {
        console.error(
            "--all and --bare are mutually exclusive",
            hint="Pick one: --all installs every component; --bare installs none."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    explicit: dict = {};
    s = ctx.get_arg("style", "");
    bc = ctx.get_arg("base_color", "") or ctx.get_arg("base-color", "");
    th = ctx.get_arg("theme", "");
    f = ctx.get_arg("font", "");
    r = ctx.get_arg("radius", "");
    ma = ctx.get_arg("menu_accent", "") or ctx.get_arg("menu-accent", "");
    if s { explicit["style"] = s; }
    if bc { explicit["baseColor"] = bc; }
    if th { explicit["theme"] = th; }
    if f { explicit["font"] = f; }
    if r { explicit["radius"] = r; }
    if ma { explicit["menuAccent"] = ma; }
    if not explicit {
        return;
    }
    import from jac_shadcn.validation { validate_theme_params }
    errors = validate_theme_params(explicit, "https://jac-shadcn.jaseci.org");
    if errors {
        for err in errors {
            console.error(err);
        }
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}


"""Post-hook for `jac create --use shadcn ...`: after create succeeds,
runs `jac shadcn init` in the new project dir. Always fires for
--use shadcn (a shadcn project that hasn't been init'd is a dead-end
state); the user controls component scope via --all / --bare / default
(10 essentials)."""
def _handle_create_with_shadcn_theme(ctx: HookContext, return_code: int) -> int {
    if return_code != 0 {
        return return_code;
    }
    if ctx.get_arg("use", "") != "shadcn" {
        return return_code;
    }
    # Read whichever underscored form the parser stored -- jaclang's CLI
    # also stores a hyphenated key whose value is unreliable when the
    # auto-short collides with another plugin's flag.
    style = ctx.get_arg("style", "");
    base_color = ctx.get_arg("base_color", "") or ctx.get_arg("base-color", "");
    theme = ctx.get_arg("theme", "");
    font = ctx.get_arg("font", "");
    radius = ctx.get_arg("radius", "");
    menu_accent = ctx.get_arg("menu_accent", "") or ctx.get_arg("menu-accent", "");
    install_set = "essential";
    if ctx.get_arg("all", False) {
        install_set = "all";
    } elif ctx.get_arg("bare", False) {
        install_set = "bare";
    }

    name = ctx.get_arg("name", "");
    if not name {
        # `jac create` picks a default name (e.g. jactastic) when not given.
        # Without the resolved name we can't find the new project dir,
        # so skip the auto-init.
        return return_code;
    }

    import from jaclang.cli.console { console }
    import from jaclang.project.config { get_config }
    import from jac_shadcn.shadcn_handler { init_shadcn_theme }

    project_dir = Path.cwd() / name;
    if not project_dir.exists() {
        return return_code;
    }

    # Validation already ran in the pre-hook, so any value here is known
    # good. We MUST pass force_discover=True here -- jaclang's get_config
    # is a process-lifetime singleton, and `jac create` itself populated
    # the cache BEFORE the new project's jac.toml existed. Without forcing
    # re-discovery from `project_dir`, init would write to whatever
    # ancestor jac.toml the cached config was anchored to. We also chdir
    # so any nested relative-path resolution inside init lands locally.
    saved_cwd = os.getcwd();
    try {
        os.chdir(str(project_dir));
        config = get_config(start_path=project_dir, force_discover=True);
        if config is None {
            return return_code;
        }
        console.print(
            "\n Applying jac-shadcn theme to new project...", style="bold cyan"
        );
        ok = init_shadcn_theme(
            config,
            style=style or "nova",
            base_color=base_color or "neutral",
            theme=theme or "neutral",
            font=font or "figtree",
            radius=radius or "default",
            menu_accent=menu_accent or "subtle",
            install_set=install_set
        );
        return 0 if ok else 1;
    } except Exception as e {
        console.error("Failed to apply jac-shadcn theme: " + str(e));
        return 1;
    } finally {
        os.chdir(saved_cwd);
    }
}


impl JacShadcnPlugin.register_project_template -> dict[str, any] | None {
    import from jaclang.project.template_loader { load_template_from_directory }
    import from jaclang.cli.console { console }

    # plugin.impl.jac is in jac_shadcn/impl/, so .parent.parent = jac_shadcn/
    module_dir = Path(__file__).parent.parent;
    template_dir = module_dir / "templates" / "shadcn";

    if not template_dir.exists() {
        # Fallback: look in installed package location
        import from importlib.resources { files }
        try {
            package_root = str(files("jac_shadcn"));
            template_dir = Path(package_root) / "templates" / "shadcn";
        } except (TypeError, ModuleNotFoundError) as e {
            console.warning(f"Failed to locate jac-shadcn template directory: {e}");
            return None;
        }
    }

    if not template_dir.exists() or not template_dir.is_dir() {
        return None;
    }

    try {
        template = load_template_from_directory(template_dir);
        return template.to_dict();
    } except Exception as e {
        console.warning(f"Could not load jac-shadcn template: {e}");
        return None;
    }
}
