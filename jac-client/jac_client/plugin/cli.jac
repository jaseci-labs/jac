"""Command line interface tool for the Jac Client.

This module extends core CLI commands to add the --cl flag for
client-side (frontend) operations:
- `jac create --cl`: Create a client project (shorthand for --use client)
- `jac add --cl`: Add client-side npm dependencies
- `jac remove --cl`: Remove client-side npm dependencies
"""

import os;
import sys;
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, HookContext }
import from jaclang.pycore.runtime { hookimpl }

"""Jac CLI extensions for client-side development."""
class JacCmd {
    """Create Jac CLI cmds."""
    @hookimpl
    static def create_cmd -> None {
        """Extend core commands to add --cl flag for client-side operations.""";
        registry = get_registry();

        # Extend the core 'create' command with --cl and --skip flags
        registry.extend_command(
            command_name="create",
            args=[
                Arg.create(
                    "cl",
                    typ=bool,
                    default=False,
                    help="Use the client template (shorthand for --use client)",
                    short="c"
                ),
                Arg.create(
                    "skip",
                    typ=bool,
                    default=False,
                    help="Skip npm package installation after project creation",
                    short="s"
                ),

            ],
            pre_hook=_handle_client_create,
            source="jac-client"
        );

        # Extend the core 'add' command with --cl flag
        registry.extend_command(
            command_name="add",
            args=[
                Arg.create(
                    "cl",
                    typ=bool,
                    default=False,
                    help="Add as client-side (npm) dependency"
                ),

            ],
            pre_hook=_handle_client_add,
            source="jac-client"
        );

        # Extend the core 'remove' command with --cl flag
        registry.extend_command(
            command_name="remove",
            args=[
                Arg.create(
                    "cl",
                    typ=bool,
                    default=False,
                    help="Remove client-side (npm) dependency"
                ),

            ],
            pre_hook=_handle_client_remove,
            source="jac-client"
        );
    }
}

"""Pre-hook to handle --cl flag for client-side project creation."""
def _handle_client_create(ctx: HookContext) -> None {
    # Check if --cl flag is set
    cl_flag = ctx.get_arg("cl", False);
    if not cl_flag {
        # Let core create command run normally
        return;
    }

    # Check if use is already set to something other than default
    use = ctx.get_arg("use", "default");
    if use != "default" {
        # User explicitly set --use, respect that over --cl
        return;
    }

    # --cl is set, delegate to core create with use="client"
    # Use Python's importlib to import the compiled Jac module
    import importlib;
    project_module = importlib.import_module("jaclang.cli.commands.project");
    create_fn = getattr(project_module, "create");

    name = ctx.get_arg("name", "");
    force = ctx.get_arg("force", False);
    list_jacpacks = ctx.get_arg("list_jacpacks", False);
    skip_install = ctx.get_arg("skip", False);

    # Set environment variable to signal post_create hook to skip npm install
    if skip_install {
        os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    }

    try {
        result = create_fn(
            name=name, force=force, use="client", list_jacpacks=list_jacpacks
        );
        # Cancel core handler since we called create ourselves
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", result if result is not None else 0);
    } except SystemExit as e {
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", e.code if e.code is not None else 1);
    } except Exception as e {
        print(f"Error creating client project: {e}", file=sys.stderr);
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    } finally {
        # Clean up environment variable
        if "JAC_CLIENT_SKIP_NPM_INSTALL" in os.environ {
            del os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] ;
        }
    }
}

"""Pre-hook to handle --cl flag for adding client-side dependencies."""
def _handle_client_add(ctx: HookContext) -> None {
    # Check if --cl flag is set
    cl_flag = ctx.get_arg("cl", False);
    if not cl_flag {
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
    dep_type = registry.get_by_flag("--cl");
    if dep_type is None {
        console.error(
            "--cl flag requires jac-client plugin",
            hint="Install with: pip install jac-client"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    packages = ctx.get_arg("packages", []);
    dev = ctx.get_arg("dev", False);

    # If no packages specified, install all client packages from jac.toml
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

"""Pre-hook to handle --cl flag for removing client-side dependencies."""
def _handle_client_remove(ctx: HookContext) -> None {
    # Check if --cl flag is set
    cl_flag = ctx.get_arg("cl", False);
    if not cl_flag {
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
    dep_type = registry.get_by_flag("--cl");
    if dep_type is None {
        console.error("--cl flag requires jac-client plugin to be installed.");
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
