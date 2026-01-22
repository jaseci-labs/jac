"""Command line interface tool for the Jac Client.

This module extends core CLI commands to add the --npm flag for
client-side (frontend) package management:
- `jac add --npm`: Add npm dependencies
- `jac remove --npm`: Remove npm dependencies

For creating client projects, use: `jac create --use client`
"""

import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, HookContext }
import from jaclang.pycore.runtime { hookimpl }
import os;

glob registry = get_registry();

with entry {
    # Register targets when module loads
    import from jac_client.plugin.src.targets.register { register_targets }
    register_targets();
}

"""Register 'build' command at module level."""
@registry.command(
    name="build",
    help="Build a Jac application for a specific target",
    args=[
        Arg.create(
            "filename",
            kind=ArgKind.POSITIONAL,
            default="main.jac",
            help="Path to .jac file (default: main.jac)"
        ),
        Arg.create(
            "target",
            typ=str,
            default="web",
            help="Build target (web, desktop)",
            choices=["web", "desktop"],
            short=""  # Disable auto-generated -t (may conflict with other plugins)
        ),
        Arg.create(
            "platform",
            typ=str,
            default=None,
            help="Platform for desktop builds (windows, macos, linux, all)",
            choices=["windows", "macos", "linux", "all"],
            short="p"  # Use -p for platform
        ),
    ],
    examples=[
        ("jac build", "Build web target (default)"),
        ("jac build main.jac", "Build specific file"),
        ("jac build --target desktop", "Build desktop app"),
        ("jac build --target desktop --platform windows", "Build for Windows"),
    ],
    group="build",
    source="jac-client"
)
def build(
    filename: str = "main.jac",
    target: str = "web",
    platform: str | None = None
) -> int {
    # This will be handled by the pre_hook
    return 0;
}

"""Register 'setup' command at module level."""
@registry.command(
    name="setup",
    help="Setup a build target (one-time initialization)",
    args=[
        Arg.create(
            "target",
            kind=ArgKind.POSITIONAL,
            help="Target to setup (e.g., desktop)"
        ),
    ],
    examples=[
        ("jac setup desktop", "Setup desktop target (Tauri)"),
    ],
    group="project",
    source="jac-client"
)
def setup(target: str) -> int {
    # This will be handled by the pre_hook
    return 0;
}

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

        # Add pre-hook to build command (command is registered at module level)
        registry.extend_command(
            command_name="build",
            pre_hook=_handle_build_target,
            source="jac-client"
        );

        # Add pre-hook to setup command (command is registered at module level)
        registry.extend_command(
            command_name="setup",
            pre_hook=_handle_setup_target,
            source="jac-client"
        );

        # Extend 'start' command with --target flag
        # Note: jac-scale also uses --target, but for deployment targets
        # We use it for build targets, so we need to handle both cases
        registry.extend_command(
            command_name="start",
            args=[
                Arg.create(
                    "build_target",  # Use different name to avoid conflict with jac-scale's --target
                    typ=str,
                    default="web",
                    help="Build target for dev server (web, desktop)",
                    choices=["web", "desktop"],
                    short=""  # Disable auto-generated short flag
                ),
            ],
            pre_hook=_handle_start_target,
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

"""Pre-hook to handle --target flag for build command."""
def _handle_build_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jac_client.plugin.src.targets.registry { get_target_registry }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    
    target_name = ctx.get_arg("target", "web");
    platform = ctx.get_arg("platform", None);
    
    registry = get_target_registry();
    target = registry.get(target_name);
    
    if not target {
        console.error(f"Unknown target: {target_name}");
        console.print(f"Available targets: {', '.join([t.name for t in registry.get_all()])}", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    
    # Store target info in context for use by build handler
    ctx.set_data("build_target", target);
    ctx.set_data("build_platform", platform);
    
    # If target requires setup, warn user
    if target.requires_setup {
        console.warning(f"Target '{target_name}' requires setup. Run 'jac setup {target_name}' first.");
    }
    
    # Build using target's build method
    try {
        config = get_config();
        if not config {
            console.error("No jac.toml found. Run 'jac create' to create a project.");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        
        entry_file = ctx.get_arg("filename", None);
        if not entry_file {
            entry_file = config.entry_point;
        }
        if not entry_file {
            console.error("No entry file specified. Use: jac build <file>");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        
        entry_path = Path(entry_file);
        project_dir = config.project_root or Path.cwd();
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }
        bundle_path = target.build(entry_path, project_dir, platform);
        
        console.success(f"Build complete: {bundle_path}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except NotImplementedError as e {
        console.error(f"Target '{target_name}' is not yet implemented. Coming in Phase 2!");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    } except Exception as e {
        console.error(f"Build failed: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

"""Pre-hook to handle --build-target flag for start command."""
def _handle_start_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jac_client.plugin.src.targets.registry { get_target_registry }
    
    target_name = ctx.get_arg("build_target", "web");
    
    registry = get_target_registry();
    target = registry.get(target_name);
    
    if not target {
        console.error(f"Unknown target: {target_name}");
        console.print(f"Available targets: {', '.join([t.name for t in registry.get_all()])}", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    
    # Store target info in context
    ctx.set_data("start_target", target);
    
    # For now, only web target is fully implemented
    if target_name == "desktop" {
        console.error("Desktop target is not yet implemented. Coming in Phase 2!");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    
    # Web target: let existing start command handle it
    # (no cancellation, let it run normally)
}

"""Pre-hook to handle setup command."""
def _handle_setup_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jac_client.plugin.src.targets.registry { get_target_registry }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    
    target_name = ctx.get_arg("target", None);
    if not target_name {
        console.error("No target specified. Use: jac setup <target>");
        console.print("Available targets: desktop", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    
    registry = get_target_registry();
    target = registry.get(target_name);
    
    if not target {
        console.error(f"Unknown target: {target_name}");
        console.print(f"Available targets: {', '.join([t.name for t in registry.get_all()])}", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    
    # Setup using target's setup method
    try {
        config = get_config();
        if not config {
            console.error("No jac.toml found. Run 'jac create' to create a project.");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        
        project_dir = config.project_root or Path.cwd();
        console.print(f"Setting up target '{target_name}' in: {project_dir}", style="muted");
        target.setup(project_dir);
        
        # Verify setup completed successfully
        tauri_dir = project_dir / "src-tauri";
        if not tauri_dir.exists() {
            console.error(f"Setup completed but src-tauri directory not found at: {tauri_dir}");
            console.print("This may indicate the setup function failed silently.", style="muted");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        
        console.success(f"Target '{target_name}' setup complete!");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except NotImplementedError as e {
        console.error(f"Target '{target_name}' setup is not yet implemented.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    } except Exception as e {
        import traceback;
        console.error(f"Setup failed: {e}");
        console.print(traceback.format_exc(), style="muted");
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
