import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind, HookContext }
import from jaclang.project.config { JacConfig }
import from jaclang.jac0core.runtime { hookimpl }
import from jaclang.runtimelib.client.mobile_setup_env {
    mobile_setup_platform_env_restore,
    mobile_setup_platform_env_swap
}
import os;

glob registry = get_registry();

import from jaclang.runtimelib.client.targets.register {
    register_targets,
    sync_client_target_choices
}
import from jaclang.runtimelib.client.targets.registry { ClientTarget }
import from pathlib { Path }

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
            help=(
                "Build client target (web, pwa, mobile, desktop). "
                "Choices reflect installed targets (desktop builds a native webview app)."
            ),
            choices=["web", "pwa", "mobile"],
            short=""
        ),
        Arg.create(
            "platform",
            typ=str,
            default=None,
            help="Platform for desktop/mobile builds (windows, macos, linux, all, android, ios)",
            choices=["windows", "macos", "linux", "all", "android", "ios"],
            short="p"
        ),

    ],
    examples=[
        ("jac build", "Build web target (default)"),
        ("jac build main.jac", "Build specific file"),
        ("jac build --client pwa", "Build PWA (Progressive Web App)"),
        ("jac build --client desktop", "Build desktop app (native webview, no Rust)"),
        ("jac build --client mobile --platform android", "Build Android mobile app"),
        ("jac build --client mobile --platform ios", "Build iOS mobile app"),

    ],
    group="build",
    source="jac-client"
)
def build(
    filename: str = "main.jac", target: str = "web", platform: str | None = None
) -> int {
    return 0;
}

@registry.command(
    name="setup",
    help="Setup a build target (one-time initialization)",
    args=[
        Arg.create(
            "target", kind=ArgKind.POSITIONAL, help="Target to setup (e.g., desktop)"
        ),

    ],
    examples=[
        ("jac setup mobile", "Setup mobile target (default platform)"),
        ("jac setup mobile --platform ios", "Setup iOS scaffold only"),
        ("jac setup mobile --platform all", "Setup both Android and iOS (macOS)")
    ],
    group="project",
    source="jac-client"
)
def setup(target: str, platform: str | None = None) -> int {
    return 0;
}

class JacClientCmd {
    @hookimpl
    static def create_cmd {
        register_targets();
        registry = get_registry();

        registry.extend_command(
            command_name="create",
            args=[
                Arg.create(
                    "skip",
                    typ=bool,
                    default=False,
                    help="Skip npm package installation (when creating client kinds: web-app/web-static/mobile)"
                ),

            ],
            pre_hook=_handle_create_skip,
            source="jac-client"
        );

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

        registry.extend_command(
            command_name="build", pre_hook=_handle_build_target, source="jac-client"
        );

        registry.extend_command(
            command_name="setup",
            args=[
                Arg.create(
                    "platform",
                    typ=str,
                    default=None,
                    help="Platform for mobile setup (android, ios, all)",
                    choices=["android", "ios", "all"],
                    short="p"
                ),

            ],
            pre_hook=_handle_setup_target,
            source="jac-client"
        );

        if registry.has_command("start") {
            registry.extend_command(
                command_name="start",
                args=[
                    Arg.create(
                        "client",
                        typ=str,
                        default="web",
                        help=(
                            "Client build target for dev server (web, pwa, mobile, desktop). "
                            "Choices reflect installed targets (desktop builds a native webview app)."
                        ),
                        choices=["web", "pwa", "mobile"],
                        short=""
                    ),
                    Arg.create(
                        "host",
                        typ=str,
                        default="",
                        help=(
                            "Mobile dev (--client mobile --dev): optional host/IP override for "
                            "Capacitor live-reload. When omitted, jac auto-selects a host."
                        ),
                        short=""
                    ),
                    Arg.create(
                        "platform",
                        typ=str,
                        default="auto",
                        help=(
                            "Mobile start/dev: android or ios (auto = use [plugins.client.mobile] "
                            "default_platform or android)"
                        ),
                        choices=["auto", "android", "ios"],
                        short=""
                    ),

                ],
                pre_hook=_handle_start_target,
                source="jac-client"
            );
        }

        sync_client_target_choices();
    }
}

def _handle_create_skip(ctx: HookContext) {
    skip_flag = ctx.get_arg("skip", False);
    if skip_flag {
        os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    }
}

def _npm_hook_context(ctx: HookContext) -> tuple | None {
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { get_provider_registry }
    import from jaclang.cli.console { console }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }

    provider = get_provider_registry().get_by_flag("--npm");
    if provider is None {
        console.error(
            "--npm dependency support is unavailable",
            hint="The client framework ships with jaclang; reinstall jaclang if this persists."
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }
    return (config, provider);
}

def _handle_npm_add(ctx: HookContext) -> None {
    npm_flag = ctx.get_arg("npm", False);
    if not npm_flag {
        return;
    }
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    hook_ctx = _npm_hook_context(ctx);
    if hook_ctx is None {
        return;
    }
    (config, provider) = hook_ctx;
    packages = ctx.get_arg("packages", []);
    dev = ctx.get_arg("dev", False);
    install_ctx = InstallContext();

    try {
        if not packages {
            console.print(
                f"\n📦 Installing all {provider.name} packages from jac.toml",
                style="bold"
            );
            with console.status(
                f"Installing {provider.name} packages...", spinner="dots"
            ) as status {
                provider.install_all(config, provider.resolve(config), install_ctx);
            }
            console.success(f"Installed all {provider.name} packages");
        } else {
            console.print(
                f"\n📦 Adding {len(packages)} {provider.name} package(s)", style="bold"
            );
            for pkg_spec in packages {
                (name, version) = provider.parse_spec(pkg_spec);
                with console.status(
                    f"Installing {name}...", spinner="dots"
                ) as status {
                    provider.add_package(config, name, version, dev, install_ctx);
                }
                console.print(f"  ✔ {name}", style="success");
            }
            section = f"dependencies.{provider.name}" + (".dev" if dev else "");
            console.print(f"\n  ✔ Updated jac.toml [{section}]", style="muted");
        }
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except Exception as e {
        console.error(f"Failed to install packages: {e}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

def _auto_client_target(config: JacConfig, requested: str, project_dir: Path) -> str {
    if requested != "web" {
        return requested;
    }
    import from jaclang.project.kinds { resolve_entry, resolve_project_kind }
    try {
        entry = resolve_entry(config, str(project_dir));
        if resolve_project_kind(config, entry) == "web-static" {
            return "static";
        }
    } except Exception {
        return requested;
    }
    return requested;
}

def _target_setup_missing(
    target_name: str, target: ClientTarget, project_dir: Path
) -> bool {
    if not target.requires_setup {
        return False;
    }

    if target_name == "mobile" {
        android_dir = project_dir / "android";
        ios_dir = project_dir / "ios";
        return not android_dir.exists() and not ios_dir.exists();
    }

    return False;
}

def _handle_build_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }

    target_name = ctx.get_arg("client", "web");
    platform = ctx.get_arg("platform", None);

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    project_dir = config.project_root or Path.cwd();

    target_name = _auto_client_target(config, target_name, project_dir);

    factory = get_target_factory();
    try {
        target = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    ctx.set_data("build_target", target);
    ctx.set_data("build_platform", platform);

    if _target_setup_missing(target_name, target, project_dir) {
        console.warning(
            f"Target '{target_name}' requires setup. Run 'jac setup {target_name}' first."
        );
    }

    try {
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
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }

        bundle_path = target.build(entry_path, project_dir, platform);

        console.success(f"Build complete: {bundle_path}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 0);
    } except NotImplementedError as e {
        console.error(f"Target '{target_name}' is not yet implemented.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    } except Exception as e {
        import traceback;
        console.error(f"Build failed: {e}\n{traceback.format_exc()}");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
    }
}

def _get_start_context(ctx: HookContext) -> tuple | None {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.cli.console { console }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }

    entry_file = ctx.get_arg("filename", None);
    if not entry_file {
        entry_file = config.entry_point;
    }
    if not entry_file {
        console.error("No entry file specified. Use: jac start <file>");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return None;
    }

    entry_path = Path(entry_file);
    project_dir = config.project_root or Path.cwd();
    if not entry_path.is_absolute() {
        entry_path = project_dir / entry_path;
    }

    return (config, entry_path, project_dir);
}

def _handle_start_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    import from jaclang.runtimelib.client.diagnostics { is_debug_mode }
    import from pathlib { Path }

    target_name = ctx.get_arg("client", "web");

    start_ctx = _get_start_context(ctx);
    if not start_ctx {
        return;
    }
    (config, entry_path, project_dir) = start_ctx;

    target_name = _auto_client_target(config, target_name, project_dir);

    dev_mode = ctx.get_arg("dev", False);
    if not dev_mode and is_debug_mode(config) {
        console.warning(
            "Debug mode is enabled. For production, consider setting debug=false in [plugins.client] section of jac.toml"
        );
    }

    factory = get_target_factory();
    try {
        target = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    ctx.set_data("start_client_target", target);

    start_port = ctx.get_arg("port", 8000);
    if start_port is None {
        start_port = 8000;
    }
    start_api = ctx.get_arg("api_port", 0);
    if start_api is None {
        start_api = 0;
    }

    if target_name != "web" {
        if _target_setup_missing(target_name, target, project_dir) {
            console.error(
                f"Target '{target_name}' not set up. Run 'jac setup {target_name}' first."
            );
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
            return;
        }
        try {
            if target_name == "mobile" {
                os.environ["JAC_MOBILE_PLATFORM"] = str(
                    ctx.get_arg("platform", "auto")
                );
            }
            if dev_mode {
                if target_name == "mobile" {
                    os.environ["JAC_MOBILE_DEV_HOST"] = str(ctx.get_arg("host", ""));
                }

                target.dev(
                    entry_path, project_dir, port=start_port, api_port=start_api
                );
            } else {
                target.start(entry_path, project_dir, api_port=start_port);
            }
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 0);
        } except Exception as e {
            import traceback;
            console.error(f"Target '{target_name}' failed: {e}");
            console.print(traceback.format_exc(), style="muted");
            ctx.set_data("cancel_execution", True);
            ctx.set_data("cancel_return_code", 1);
        }
        return;
    }
}

def _handle_setup_target(ctx: HookContext) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }

    factory = get_target_factory();

    target_name = ctx.get_arg("target", None) or ctx.get_arg("subcommand", None);
    available_targets = factory.get_available_target_names();
    if target_name and target_name not in available_targets {
        return;
    }
    if not target_name {
        console.error("No target specified. Use: jac setup <target>");
        console.print(
            f"Available targets: {', '.join(available_targets)}", style="muted"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    project_dir = config.project_root or Path.cwd();

    try {
        target = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }

    setup_platform = ctx.get_arg("platform", None);
    prev_setup_platform_env = None;
    if target_name == "mobile" and setup_platform {
        prev_setup_platform_env = mobile_setup_platform_env_swap(str(setup_platform));
    }
    try {
        console.print(
            f"Setting up target '{target_name}' in: {project_dir}", style="muted"
        );
        target.setup(project_dir);

        if target_name == "pwa" {
            pwa_icons_dir = project_dir / "pwa_icons";
            if not pwa_icons_dir.exists() {
                console.error(
                    f"Setup completed but pwa_icons directory not found at: {pwa_icons_dir}"
                );
                console.print(
                    "This may indicate the setup function failed silently.",
                    style="muted"
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
    } finally {
        if target_name == "mobile" and setup_platform {
            mobile_setup_platform_env_restore(prev_setup_platform_env);
        }
    }
}

def _handle_npm_remove(ctx: HookContext) -> None {
    npm_flag = ctx.get_arg("npm", False);
    if not npm_flag {
        return;
    }
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    hook_ctx = _npm_hook_context(ctx);
    if hook_ctx is None {
        return;
    }
    (config, provider) = hook_ctx;
    packages = ctx.get_arg("packages", []);
    if not packages {
        console.error("No packages specified.");
        ctx.set_data("cancel_execution", True);
        ctx.set_data("cancel_return_code", 1);
        return;
    }
    dev = ctx.get_arg("dev", False);
    install_ctx = InstallContext();

    try {
        for name in packages {
            console.info(f"Removing {name} ({provider.name})...");
            if not provider.remove_package(config, name, dev, install_ctx) {
                deps_key = "dev-dependencies" if dev else "dependencies";
                raise RuntimeError(f'Package "{name}" not found in {deps_key}');
            }
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
