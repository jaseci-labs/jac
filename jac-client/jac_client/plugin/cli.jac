"""Command line interface tool for the Jac Client.

This module extends core CLI commands for client-side development:
- `jac add --npm`: Add npm dependencies
- `jac remove --npm`: Remove npm dependencies
- `jac add --expo`: Add Expo-compatible packages
- `jac remove --expo`: Remove Expo packages
- `jac expo <cmd>`: Run Expo CLI commands in mobile project context

For creating client projects, use: `jac create --use client`
"""

import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, HookContext }
import from jaclang.pycore.runtime { hookimpl }
import os;

glob registry = get_registry();

# Register targets when module loads
# Import base target classes - this should trigger annex pass to auto-discover .impl.jac files
import from jac_client.plugin.src.targets.desktop_target {
    DesktopTarget
}
import from jac_client.plugin.src.targets.web_target { WebTarget }
import from jac_client.plugin.src.targets.mobile_target { MobileTarget }
import from jac_client.plugin.src.targets.register { register_targets }

with entry {
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
            "client",
            typ=str,
            default="web",
            help="Build client (web, desktop, mobile)",
            choices=["web", "desktop", "mobile"],
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
        Arg.create(
            "target",
            typ=str,
            default=None,
            help="Target platform for mobile builds (ios, android, all)",
            choices=["ios", "android", "all"],
            short=""
        ),
        Arg.create(
            "profile",
            typ=str,
            default="preview",
            help="Build profile for mobile builds (development, preview, production)",
            choices=["development", "preview", "production"],
            short=""
        ),
        Arg.create(
            "local",
            typ=bool,
            default=False,
            help="Force local build for mobile (no EAS cloud)"
        ),

    ],
    examples=[
        ("jac build", "Build web target (default)"),
        ("jac build main.jac", "Build specific file"),
        ("jac build --client desktop", "Build desktop app"),
        ("jac build --client desktop --platform windows", "Build for Windows"),
        ("jac build --client mobile --target ios --profile production", "Build iOS app"),
        ("jac build --client mobile --target android --profile preview", "Build Android preview"),

    ],
    group="build",
    source="jac-client"
)
def build(
    filename: str = "main.jac", target: str = "web", platform: str | None = None
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
            "target", kind=ArgKind.POSITIONAL, help="Target to setup (e.g., desktop)"
        ),

    ],
    examples=[
        ("jac setup desktop", "Setup desktop target (Tauri)"),
        ("jac setup mobile", "Setup mobile target (Expo + WebView)"),
    ],
    group="project",
    source="jac-client"
)
def setup(target: str) -> int {
    # This will be handled by the pre_hook
    return 0;
}

"""Register 'expo' passthrough command."""
@registry.command(
    name="expo",
    help="Run Expo CLI commands in the mobile project context",
    args=[
        Arg.create(
            "args",
            kind=ArgKind.MULTI,
            default=[],
            help="Arguments to pass to expo CLI"
        ),

    ],
    examples=[
        ("jac expo doctor", "Check Expo project health"),
        ("jac expo config", "View resolved Expo config"),
        ("jac expo prebuild", "Generate native projects"),
        ("jac expo install expo-camera", "Install an Expo package"),

    ],
    group="build",
    source="jac-client"
)
def expo(args: list[str] = []) -> int {
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

        # Extend the core 'add' command with --npm and --expo flags
        registry.extend_command(
            command_name="add",
            args=[
                Arg.create(
                    "npm",
                    typ=bool,
                    default=False,
                    help="Add as npm (client-side) dependency"
                ),
                Arg.create(
                    "expo",
                    typ=bool,
                    default=False,
                    help="Add as Expo dependency (SDK-compatible versions)"
                ),

            ],
            pre_hook=_handle_npm_add,
            source="jac-client"
        );

        # Extend the core 'remove' command with --npm and --expo flags
        registry.extend_command(
            command_name="remove",
            args=[
                Arg.create(
                    "npm",
                    typ=bool,
                    default=False,
                    help="Remove npm (client-side) dependency"
                ),
                Arg.create(
                    "expo",
                    typ=bool,
                    default=False,
                    help="Remove Expo dependency"
                ),

            ],
            pre_hook=_handle_npm_remove,
            source="jac-client"
        );

        # Add pre-hook to build command (command is registered at module level)
        registry.extend_command(
            command_name="build", pre_hook=_handle_build_target, source="jac-client"
        );

        # Add pre-hook to setup command (command is registered at module level)
        registry.extend_command(
            command_name="setup", pre_hook=_handle_setup_target, source="jac-client"
        );

        # Extend 'start' command with --client flag and mobile-specific flags
        # Note: jac-scale also uses --client, so we use --client to avoid conflict
        if registry.has_command("start") {
            registry.extend_command(
                command_name="start",
                args=[
                    Arg.create(
                        "client",  # Use client to avoid conflict with jac-scale's --client
                        typ=str,
                        default="web",
                        help="Client build target for dev server (web, desktop, mobile)",
                        choices=["web", "desktop", "mobile"],
                        short=""  # Disable auto-generated short flag
                    ),
                    Arg.create(
                        "ios",
                        typ=bool,
                        default=False,
                        help="Launch iOS simulator (mobile target)"
                    ),
                    Arg.create(
                        "android",
                        typ=bool,
                        default=False,
                        help="Launch Android emulator (mobile target)"
                    ),
                    Arg.create(
                        "tunnel",
                        typ=bool,
                        default=False,
                        help="Use Expo tunnel for remote physical devices (mobile target)"
                    ),

                ],
                pre_hook=_handle_start_target,
                source="jac-client"
            );
        }

        # Add pre-hook to expo command (command is registered at module level)
        registry.extend_command(
            command_name="expo", pre_hook=_handle_expo_passthrough, source="jac-client"
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

"""Pre-hook to handle --npm/--expo flag for adding dependencies."""
def _handle_npm_add(ctx: HookContext) -> None {
    # Check if --expo flag is set (handle before --npm)
    expo_flag = ctx.get_arg("expo", False);
    if expo_flag {
        _handle_expo_add(ctx);
        return;
    }

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

"""Pre-hook to handle --client flag for build command."""
def _handle_build_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jac_client.plugin.src.targets.registry { get_target_registry }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }

    target_name = ctx.get_arg("client", "web");
    platform = ctx.get_arg("platform", None);

    # For mobile builds, use --target flag as the platform
    if target_name == "mobile" {
        mobile_target_platform = ctx.get_arg("target", None);
        if mobile_target_platform {
            platform = mobile_target_platform;
        }
        # Pass profile and local flags via environment for mobile builds
        profile = ctx.get_arg("profile", "preview");
        os.environ["JAC_MOBILE_PROFILE"] = profile;
        if ctx.get_arg("local", False) {
            os.environ["JAC_MOBILE_LOCAL_BUILD"] = "1";
        }
    }

    try {
        registry = get_target_registry();
        target = registry.get(target_name);

        if not target {
            console.error(f"Unknown client target: {target_name}");
            console.print(
                f"Available client targets: {', '.join(
                    [t.name for t in registry.get_all()]
                )}",
                style="muted"
            );
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }

        # Store target info in context for use by build handler
        ctx.set_data("build_target", target);
        ctx.set_data("build_platform", platform);

        # Build using target's build method
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
        console.error(
            f"Target '{target_name}' is not yet implemented. Coming in Phase 2!"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    } except Exception as e {
        console.error(f"Build failed: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    } finally {
        # Clean up mobile-specific env vars
        for env_key in ["JAC_MOBILE_PROFILE", "JAC_MOBILE_LOCAL_BUILD"] {
            os.environ.pop(env_key, None);
        }
    }
}

"""Pre-hook to handle --client flag for start command."""
def _handle_start_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jac_client.plugin.src.targets.registry { get_target_registry }

    target_name = ctx.get_arg("client", "web");

    registry = get_target_registry();
    target = registry.get(target_name);

    if not target {
        console.error(f"Unknown client target: {target_name}");
        console.print(
            f"Available client targets: {', '.join(
                [t.name for t in registry.get_all()]
            )}",
            style="muted"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    # Store target info in context
    ctx.set_data("start_client_target", target);

    # Handle desktop target
    if target_name == "desktop" {
        import from pathlib { Path }
        import from jaclang.project.config { get_config }
        config = get_config();
        if not config {
            console.error("No jac.toml found. Run 'jac create' to create a project.");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        # Get entry file
        entry_file = ctx.get_arg("filename", None);
        if not entry_file {
            entry_file = config.entry_point;
        }
        if not entry_file {
            console.error("No entry file specified. Use: jac start <file>");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        entry_path = Path(entry_file);
        project_dir = config.project_root or Path.cwd();
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }
        # Check if setup has been run
        tauri_dir = project_dir / "src-tauri";
        if not tauri_dir.exists() {
            console.error("Desktop target not set up. Run 'jac setup desktop' first.");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        dev_mode = ctx.get_arg("dev", False);
        api_port = ctx.get_arg("port", 8000);
        try {
            if dev_mode {
                # Desktop target with --dev: launch Tauri dev mode (hot reload)
                target.dev(entry_path, project_dir, api_port=api_port);
            } else {
                # Desktop target without --dev: build web bundle and launch Tauri with built bundle
                target.start(entry_path, project_dir, api_port=api_port);
            }
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 0);
        } except Exception as e {
            import traceback;
            console.error(f"Desktop start failed: {e}");
            console.print(traceback.format_exc(), style="muted");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
        }
        return;
    }

    # Handle mobile target
    if target_name == "mobile" {
        import from pathlib { Path }
        import from jaclang.project.config { get_config }
        config = get_config();
        if not config {
            console.error("No jac.toml found. Run 'jac create' to create a project.");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        # Get entry file
        entry_file = ctx.get_arg("filename", None);
        if not entry_file {
            entry_file = config.entry_point;
        }
        if not entry_file {
            console.error("No entry file specified. Use: jac start <file>");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        entry_path = Path(entry_file);
        project_dir = config.project_root or Path.cwd();
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }
        # Check if setup has been run
        mobile_dir = project_dir / ".jac" / "mobile";
        if not (mobile_dir / "package.json").exists() {
            console.error("Mobile target not set up. Run 'jac setup mobile' first.");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        # Pass mobile-specific flags via environment
        if ctx.get_arg("ios", False) {
            os.environ["JAC_MOBILE_IOS"] = "1";
        }
        if ctx.get_arg("android", False) {
            os.environ["JAC_MOBILE_ANDROID"] = "1";
        }
        if ctx.get_arg("tunnel", False) {
            os.environ["JAC_MOBILE_TUNNEL"] = "1";
        }
        api_port = ctx.get_arg("port", 8000);
        try {
            target.dev(entry_path, project_dir, api_port=api_port);
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 0);
        } except Exception as e {
            import traceback;
            console.error(f"Mobile start failed: {e}");
            console.print(traceback.format_exc(), style="muted");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
        } finally {
            # Clean up mobile-specific env vars
            for env_key in ["JAC_MOBILE_IOS", "JAC_MOBILE_ANDROID", "JAC_MOBILE_TUNNEL"] {
                os.environ.pop(env_key, None);
            }
        }
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
        console.print("Available targets: desktop, mobile", style="muted");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    registry = get_target_registry();
    target = registry.get(target_name);

    if not target {
        console.error(f"Unknown client target: {target_name}");
        console.print(
            f"Available targets: {', '.join([t.name for t in registry.get_all()])}",
            style="muted"
        );
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
        console.print(
            f"Setting up target '{target_name}' in: {project_dir}", style="muted"
        );
        target.setup(project_dir);

        # Verify setup completed successfully (target-specific checks)
        if target_name == "desktop" {
            verify_dir = project_dir / "src-tauri";
            if not verify_dir.exists() {
                console.error(
                    f"Setup completed but src-tauri directory not found at: {verify_dir}"
                );
                console.print(
                    "This may indicate the setup function failed silently.", style="muted"
                );
                ctx.set_data("cancel_execution", True);
                ctx.set_data("cancel_return_code", 1);
                return;
            }
        } elif target_name == "mobile" {
            verify_dir = project_dir / ".jac" / "mobile";
            if not (verify_dir / "package.json").exists() {
                console.error(
                    f"Setup completed but .jac/mobile/package.json not found"
                );
                console.print(
                    "This may indicate the setup function failed silently.", style="muted"
                );
                ctx.set_data("cancel_execution", True);
                ctx.set_data("cancel_return_code", 1);
                return;
            }
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

"""Pre-hook to handle --npm/--expo flag for removing dependencies."""
def _handle_npm_remove(ctx: HookContext) -> None {
    # Check if --expo flag is set (handle before --npm)
    expo_flag = ctx.get_arg("expo", False);
    if expo_flag {
        _handle_expo_remove(ctx);
        return;
    }

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

# ===============================================================================
# Expo Handlers
# ===============================================================================

"""Validate mobile target setup and return mobile_dir, or cancel context on failure."""
def _get_mobile_dir_or_cancel(ctx: HookContext) -> object {
    import from jaclang.cli.console { console }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }

    project_dir = config.project_root or Path.cwd();
    mobile_dir = project_dir / ".jac" / "mobile";

    if not (mobile_dir / "package.json").exists() {
        console.error("Mobile target not set up. Run 'jac setup mobile' first.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }

    return mobile_dir;
}

"""Pre-hook to handle jac expo passthrough command."""
def _handle_expo_passthrough(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import subprocess;

    mobile_dir = _get_mobile_dir_or_cancel(ctx);
    if mobile_dir is None {
        return;
    }

    args = ctx.get_arg("args", []);
    if not args {
        console.error("No expo command specified. Usage: jac expo <command> [args...]");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    cmd = ["bunx", "expo"] + list(args);
    console.print(f"  Running: {' '.join(cmd)}", style="muted");
    console.print(f"  In: {mobile_dir}\n", style="muted");

    try {
        result = subprocess.run(cmd, cwd=str(mobile_dir));
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", result.returncode);
    } except Exception as e {
        console.error(f"Expo command failed: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

"""Handle --expo flag for adding packages."""
def _handle_expo_add(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import subprocess;

    mobile_dir = _get_mobile_dir_or_cancel(ctx);
    if mobile_dir is None {
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error("No packages specified. Usage: jac add --expo <package> [package...]");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    cmd = ["bunx", "expo", "install"] + list(packages);
    console.print(f"\n  Installing Expo packages: {', '.join(packages)}", style="bold");
    console.print(f"  Running: {' '.join(cmd)}\n", style="muted");

    try {
        result = subprocess.run(cmd, cwd=str(mobile_dir));
        if result.returncode == 0 {
            console.success(f"Installed {len(packages)} Expo package(s)");
        } else {
            console.error("Expo install failed (see output above)");
        }
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", result.returncode);
    } except Exception as e {
        console.error(f"Expo install failed: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

"""Handle --expo flag for removing packages."""
def _handle_expo_remove(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import subprocess;

    mobile_dir = _get_mobile_dir_or_cancel(ctx);
    if mobile_dir is None {
        return;
    }

    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error("No packages specified. Usage: jac remove --expo <package> [package...]");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    cmd = ["bunx", "expo", "uninstall"] + list(packages);
    console.print(f"\n  Removing Expo packages: {', '.join(packages)}", style="bold");
    console.print(f"  Running: {' '.join(cmd)}\n", style="muted");

    try {
        result = subprocess.run(cmd, cwd=str(mobile_dir));
        if result.returncode == 0 {
            console.success(f"Removed {len(packages)} Expo package(s)");
        } else {
            console.error("Expo uninstall failed (see output above)");
        }
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", result.returncode);
    } except Exception as e {
        console.error(f"Expo uninstall failed: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}
