"""Implementation of jac-shadcn CLI hooks."""

import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }
import from typing { Any }
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
}

impl _handle_shadcn_add(ctx: HookContext) -> None {
    if not ctx.get_arg("shadcn", False) {
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }
    import from jac_shadcn.shadcn_handler { add_shadcn_components }

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
    import from jac_shadcn.shadcn_handler { remove_shadcn_components }

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

impl JacShadcnPlugin.register_project_template -> dict[str, Any] | None {
    import from jaclang.project.template_loader { load_template_from_directory }
    import from jaclang.cli.console { console }

    # Find template directory relative to this module
    # plugin.impl.jac is in jac_shadcn/impl/, so .parent.parent = jac_shadcn/
    module_dir = Path(__file__).parent.parent;  # jac_shadcn directory
    template_dir = module_dir / "templates" / "jac-shadcn";

    if not template_dir.exists() {
        # Fallback: look in installed package location
        import from importlib.resources { files }
        try {
            package_root = str(files("jac_shadcn"));
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
        return template.to_dict();
    } except Exception as e {
        console.warning(f"Could not load jac-shadcn template: {e}");
        return None;
    }
}
