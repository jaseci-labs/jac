"""Command line interface tool for the Jac Client.

This module extends core CLI commands to add the --npm flag for
client-side (frontend) package management:
- `jac add --npm`: Add npm dependencies
- `jac remove --npm`: Remove npm dependencies

For creating client projects, use: `jac create --use client`
"""

import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }
import from jaclang.pycore.runtime { hookimpl }
import os;

"""Jac CLI extensions for client-side development."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Extend core commands to add --npm flag for npm package management.""";
        registry = get_registry();

        # Extend the core 'create' command with --skip flag for client template
        registry.extend_command(
            command_name="create",
            args=[
                Arg.create(
                    "skip",
                    typ=bool,
                    default=False,
                    help="Skip npm package installation (for --use client)"
                ),

            ],
            pre_hook=_handle_create_skip,
            source="jac-client"
        );

        # Extend the core 'add' command with --npm flag
        registry.extend_command(
            command_name="add",
            args=[
                Arg.create(
                    "npm",
                    typ=bool,
                    default=False,
                    help="Add as npm (client-side) dependency"
                ),

            ],
            pre_hook=_handle_npm_add,
            source="jac-client"
        );

        # Extend the core 'remove' command with --npm flag
        registry.extend_command(
            command_name="remove",
            args=[
                Arg.create(
                    "npm",
                    typ=bool,
                    default=False,
                    help="Remove npm (client-side) dependency"
                ),

            ],
            pre_hook=_handle_npm_remove,
            source="jac-client"
        );
    }
}

"""Pre-hook to handle --skip flag for create command."""
def _handle_create_skip(ctx: HookContext) -> None {
    # Check if --skip flag is set
    skip_flag = ctx.get_arg("skip", False);
    if skip_flag {
        # Set environment variable to skip npm installation
        os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    }
    # Let core create command run normally
}

"""Pre-hook to handle --npm flag for adding npm dependencies."""
def _handle_npm_add(ctx: HookContext) -> None {
    # Check if --npm flag is set
    npm_flag = ctx.get_arg("npm", False);
    if not npm_flag {
        # Let core add command run normally
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.project.dep_registry { get_dependency_registry }
    import from jaclang.project.dependencies { DependencyResolver }
    import from jaclang.cli.console { console }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    registry = get_dependency_registry();
    dep_type = registry.get_by_flag("--npm");
    if dep_type is None {
        console.error(
            "--npm flag requires jac-client plugin",
            hint="Install with: pip install jac-client"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    dev = ctx.get_arg("dev", False);

    # If no packages specified, install all npm packages from jac.toml
    if not packages {
        if dep_type.install_all_handler is None {
            console.error(f"No install_all handler registered for {dep_type.name}");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        try {
            console.print(
                f"\n📦 Installing all {dep_type.name} packages from jac.toml",
                style="bold"
            );
            with console.status(
                f"[cyan]Installing {dep_type.name} packages...[/cyan]", spinner="dots"
            ) as status {
                dep_type.install_all_handler(config);
            }
            console.success(f"Installed all {dep_type.name} packages");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 0);
        } except Exception as e {
            console.error(f"Failed to install packages: {e}");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
        }
        return;
    }

    # Install specific packages
    try {
        resolver = DependencyResolver(config=config);
        console.print(
            f"\n📦 Adding {len(packages)} {dep_type.name} package(s)", style="bold"
        );
        for pkg_spec in packages {
            (name, version) = resolver.parse_spec(pkg_spec);
            with console.status(f"[cyan]Installing {name}...[/cyan]", spinner="dots") as status {
                dep_type.install_handler(config, name, version, dev);
            }
            console.print(f"  ✔ {name}", style="success");
        }
        section = f"dependencies.{dep_type.dev_name if dev else dep_type.name}";
        console.print(f"\n  ✔ Updated jac.toml [{section}]", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except Exception as e {
        console.error(f"Failed to install packages: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

"""Pre-hook to handle --npm flag for removing npm dependencies."""
def _handle_npm_remove(ctx: HookContext) -> None {
    # Check if --npm flag is set
    npm_flag = ctx.get_arg("npm", False);
    if not npm_flag {
        # Let core remove command run normally
        return;
    }

    import from jaclang.project.config { get_config }
    import from jaclang.project.dep_registry { get_dependency_registry }
    import from jaclang.cli.console { console }

    config = get_config();
    if config is None {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error("No packages specified.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    registry = get_dependency_registry();
    dep_type = registry.get_by_flag("--npm");
    if dep_type is None {
        console.error("--npm flag requires jac-client plugin to be installed.");
        console.print("Install with: pip install jac-client", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    dev = ctx.get_arg("dev", False);

    try {
        for name in packages {
            console.info(f"Removing {name} ({dep_type.name})...");
            dep_type.remove_handler(config, name, dev);
        }
        console.success(f"Removed {len(packages)} package(s)");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except Exception as e {
        console.error(f"Error removing packages: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}
