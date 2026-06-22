"""Implementation of jac-shadcn CLI hooks."""

import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }
import from pathlib { Path }

impl JacShadcnPlugin.create_cmd -> None {
    registry = get_registry();

    registry.extend_command(
        command_name="add",
        args=[
            Arg.create(
                "shadcn",
                typ=bool,
                default=False,
                help="Add shadcn UI component(s) from registry"
            ),

        ],
        pre_hook=_handle_shadcn_add,
        source="jac-shadcn"
    );

    registry.extend_command(
        command_name="remove",
        args=[
            Arg.create(
                "shadcn", typ=bool, default=False, help="Remove shadcn UI component(s)"
            ),

        ],
        pre_hook=_handle_shadcn_remove,
        source="jac-shadcn"
    );

    # Theme options for `jac create --use jac-shadcn` (consumed in post_create).
    registry.extend_command(
        command_name="create",
        args=[
            Arg.create(
                "style",
                typ=str,
                default=None,
                help="shadcn style preset (nova|vega|maia|lyra|mira)",
                short=""
            ),
            Arg.create(
                "baseColor",
                typ=str,
                default=None,
                help="shadcn base palette (neutral|stone|zinc|gray)",
                short=""
            ),
            Arg.create(
                "theme",
                typ=str,
                default=None,
                help="shadcn accent theme (e.g. rose, emerald)",
                short=""
            ),
            Arg.create(
                "font",
                typ=str,
                default=None,
                help="shadcn font family (e.g. inter, outfit)",
                short=""
            ),
            Arg.create(
                "radius",
                typ=str,
                default=None,
                help="shadcn border radius (none|small|medium|large)",
                short=""
            ),
            Arg.create(
                "menuAccent",
                typ=str,
                default=None,
                help="shadcn menu accent (subtle|bold)",
                short=""
            ),
            Arg.create(
                "menuColor",
                typ=str,
                default=None,
                help="shadcn menu color scheme",
                short=""
            )
        ],
        pre_hook=_handle_create_theme,
        source="jac-shadcn"
    );
    # The jac-shadcn template is contributed via the aggregating
    # `register_project_template` hook (below) -- every plugin's templates are
    # collected, so no direct registry registration is needed here.
}

impl _handle_create_theme(ctx: HookContext) -> None {
    # Only act when scaffolding the jac-shadcn template.
    if ctx.get_arg("use", "default") != "jac-shadcn" {
        return;
    }
    overrides: dict = {};
    for key in [
        "style",
        "baseColor",
        "theme",
        "font",
        "radius",
        "menuAccent",
        "menuColor"
    ] {
        val = ctx.get_arg(key, None);
        if val is not None {
            overrides[key] = val;
        }
    }
    # Stash for _shadcn_post_create (same process). Mutate in place (glob is read-only to rebind).
    _PENDING_THEME.clear();
    _PENDING_THEME.update(overrides);
}

impl _shadcn_post_create(project_path: any, project_name: str) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.theme_handler {
        normalize_shadcn_config,
        materialize_themed_starter
    }

    try {
        shadcn_config = normalize_shadcn_config(dict(_PENDING_THEME));
        materialize_themed_starter(project_path, project_name, shadcn_config);
    } except Exception as e {
        console.warning("Could not apply shadcn theme: " + str(e));
    } finally {
        _PENDING_THEME.clear();
    }
}

impl _handle_shadcn_add(ctx: HookContext) -> None {
    if not ctx.get_arg("shadcn", False) {
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.shadcn_handler { add_shadcn_components }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create --use jac-shadcn' first."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error(
            "No components specified", hint="Usage: jac add --shadcn button card dialog"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    try {
        result = add_shadcn_components(config, packages);
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0 if result else 1);
    } except Exception as e {
        console.error("Failed to add components: " + str(e));
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

impl _handle_shadcn_remove(ctx: HookContext) -> None {
    if not ctx.get_arg("shadcn", False) {
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jaclang.cli.shadcn.shadcn_handler { remove_shadcn_components }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create --use jac-shadcn' first."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error(
            "No components specified", hint="Usage: jac remove --shadcn button"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    try {
        result = remove_shadcn_components(config, packages);
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0 if result else 1);
    } except Exception as e {
        console.error("Failed to remove components: " + str(e));
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

impl _build_shadcn_template_info -> dict[str, any] | None {
    import from jaclang.project.template_loader { load_template_from_directory }
    import from jaclang.cli.console { console }

    # Find template directory relative to this module
    # plugin.impl.jac is in jaclang/cli/shadcn/impl/, so .parent.parent = jaclang/cli/shadcn/
    module_dir = Path(__file__).parent.parent;  # jaclang/cli/shadcn directory
    template_dir = module_dir / "templates" / "jac-shadcn";

    if not template_dir.exists() {
        # Fallback: look in installed package location
        import from importlib.resources { files }
        try {
            package_root = str(files("jaclang.cli.shadcn"));
            template_dir = Path(package_root) / "templates" / "jac-shadcn";
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
        info = template.to_dict();
        # jac-shadcn is a non-default variant of the `fullstack` kind: `jac
        # create --use jac-shadcn` selects it, while `--kind fullstack` keeps
        # the plain jac-client fullstack template. (Also declared in the
        # template's jac.toml; set here too so it holds regardless of loader.)
        info["kind"] = "fullstack";
        info["is_default_for_kind"] = False;
        # Generate the themed starter (global.css, components, main.jac) after scaffold.
        info["post_create"] = _shadcn_post_create;
        return info;
    } except Exception as e {
        console.warning(f"Could not load jac-shadcn template: {e}");
        return None;
    }
}

# `register_project_template` is an aggregating hook: jac-shadcn's template is
# collected alongside every other plugin's, so this contributes the variant
# without competing with jac-client's kind templates.
impl JacShadcnPlugin.register_project_template -> dict[str, any] | None {
    return _build_shadcn_template_info();
}
