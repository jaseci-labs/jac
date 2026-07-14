import from jaclang.cli.registry { get_registry }
import from jaclang.cli.command { Arg, ArgKind }
import from jaclang.project.config { JacConfig }
import from jaclang.runtimelib.client.mobile_setup_env {
    mobile_setup_platform_env_restore,
    mobile_setup_platform_env_swap
}
import os;

import from jaclang.runtimelib.client.targets.register {
    register_targets,
    sync_client_target_choices
}
import from jaclang.runtimelib.client.targets.registry { ClientTarget }
import from pathlib { Path }

glob registry = get_registry();

with entry {
    register_targets();
    sync_client_target_choices();
}

@registry.command(
    name="setup",
    help="Setup a build target (one-time initialization)",
    args=[
        Arg.create(
            "target", kind=ArgKind.POSITIONAL, help="Target to setup (e.g., desktop)"
        ),
        Arg.create(
            "platform",
            typ=str,
            default=None,
            help="Platform for mobile setup (android, ios, all)",
            choices=["android", "ios", "all"],
            short="p"
        ),

    ],
    examples=[
        ("jac setup mobile", "Setup mobile target (default platform)"),
        ("jac setup mobile --platform ios", "Setup iOS scaffold only"),
        ("jac setup mobile --platform all", "Setup both Android and iOS (macOS)")
    ],
    group="project"
)
def setup(target: str, platform: str | None = None) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    import from jaclang.project.config { get_config }

    factory = get_target_factory();
    available_targets = factory.get_available_target_names();
    if not target {
        console.error("No target specified. Use: jac setup <target>");
        console.print(
            f"Available targets: {', '.join(available_targets)}", style="muted"
        );
        return 1;
    }
    if target not in available_targets {
        console.error(f"Unknown setup target: '{target}'");
        console.print(
            f"Available targets: {', '.join(available_targets)}", style="muted"
        );
        return 1;
    }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }

    project_dir = config.project_root or Path.cwd();

    try {
        target_obj = factory.create(target, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        return 1;
    }

    setup_platform = platform;
    prev_setup_platform_env = None;
    if target == "mobile" and setup_platform {
        prev_setup_platform_env = mobile_setup_platform_env_swap(str(setup_platform));
    }
    try {
        console.print(f"Setting up target '{target}' in: {project_dir}", style="muted");
        target_obj.setup(project_dir);

        if target == "pwa" {
            pwa_icons_dir = project_dir / "pwa_icons";
            if not pwa_icons_dir.exists() {
                console.error(
                    f"Setup completed but pwa_icons directory not found at: {pwa_icons_dir}"
                );
                console.print(
                    "This may indicate the setup function failed silently.",
                    style="muted"
                );
                return 1;
            }
        }

        console.success(f"Target '{target}' setup complete!");
        return 0;
    } except NotImplementedError as e {
        console.error(f"Target '{target}' setup is not yet implemented.");
        return 1;
    } except Exception as e {
        import traceback;
        console.error(f"Setup failed: {e}");
        console.print(traceback.format_exc(), style="muted");
        return 1;
    } finally {
        if target == "mobile" and setup_platform {
            mobile_setup_platform_env_restore(prev_setup_platform_env);
        }
    }
}

def run_client_build(filename: str, client: str, platform: str | None) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    import from jaclang.project.config { get_config }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }

    project_dir = config.project_root or Path.cwd();
    target_name = _auto_client_target(config, client, project_dir);

    factory = get_target_factory();
    try {
        target = factory.create(target_name, project_dir);
    } except ValueError as e {
        console.error(str(e));
        console.print(
            f"Available targets: {', '.join(factory.get_available_target_names())}",
            style="muted"
        );
        return 1;
    }

    if _target_setup_missing(target_name, target, project_dir) {
        console.warning(
            f"Target '{target_name}' requires setup. Run 'jac setup {target_name}' first."
        );
    }

    try {
        entry_file = filename or config.project.entry_point;
        if not entry_file {
            console.error("No entry file specified. Use: jac build <file>");
            return 1;
        }

        entry_path = Path(entry_file);
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }

        bundle_path = target.build(entry_path, project_dir, platform);

        console.success(f"Build complete: {bundle_path}");
        return 0;
    } except NotImplementedError as e {
        console.error(f"Target '{target_name}' is not yet implemented.");
        return 1;
    } except Exception as e {
        import traceback;
        console.error(f"Build failed: {e}\n{traceback.format_exc()}");
        return 1;
    }
}

def run_client_start(
    filename: str,
    client: str,
    host: str,
    platform: str,
    port: int,
    api_port: int,
    dev: bool,
    no_client: bool
) -> int | None {
    import from jaclang.cli.console { console }
    import from jaclang.runtimelib.client.targets.registry { get_target_factory }
    import from jaclang.runtimelib.client.diagnostics { is_debug_mode }

    config = get_config();
    if not config {
        return None;
    }

    project_dir = config.project_root or Path.cwd();
    target_name = _auto_client_target(config, client, project_dir);

    if target_name == "web" {
        return None;
    }

    entry_file = filename or config.project.entry_point;
    if not entry_file {
        console.error("No entry file specified. Use: jac start <file>");
        return 1;
    }
    entry_path = Path(entry_file);
    if not entry_path.is_absolute() {
        entry_path = project_dir / entry_path;
    }

    if not dev and is_debug_mode(config) {
        console.warning(
            "Debug mode is enabled. For production, consider setting debug=false in [client] section of jac.toml"
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
        return 1;
    }

    start_port = port if port is not None else 8000;
    start_api = api_port if api_port is not None else 0;

    if _target_setup_missing(target_name, target, project_dir) {
        console.error(
            f"Target '{target_name}' not set up. Run 'jac setup {target_name}' first."
        );
        return 1;
    }
    try {
        if target_name == "mobile" {
            os.environ["JAC_MOBILE_PLATFORM"] = str(platform);
        }
        if dev {
            if target_name == "mobile" {
                os.environ["JAC_MOBILE_DEV_HOST"] = str(host);
            }

            target.dev(entry_path, project_dir, port=start_port, api_port=start_api);
        } else {
            target.start(entry_path, project_dir, api_port=start_port);
        }
        return 0;
    } except Exception as e {
        import traceback;
        console.error(f"Target '{target_name}' failed: {e}");
        console.print(traceback.format_exc(), style="muted");
        return 1;
    }
}

def get_config -> JacConfig | None {
    import from jaclang.project.config { get_config as _get_config }
    return _get_config();
}

def _npm_context -> tuple | None {
    import from jaclang.project.providers { get_provider_registry }
    import from jaclang.cli.console { console }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return None;
    }

    provider = get_provider_registry().get_by_flag("--npm");
    if provider is None {
        console.error(
            "--npm dependency support is unavailable",
            hint="The client framework ships with jaclang; reinstall jaclang if this persists."
        );
        return None;
    }
    return (config, provider);
}

def run_npm_add(packages: list, dev: bool) -> int {
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    npm_ctx = _npm_context();
    if npm_ctx is None {
        return 1;
    }
    (config, provider) = npm_ctx;
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
        return 0;
    } except Exception as e {
        console.error(f"Failed to install packages: {e}");
        return 1;
    }
}

def run_npm_remove(packages: list, dev: bool) -> int {
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    npm_ctx = _npm_context();
    if npm_ctx is None {
        return 1;
    }
    (config, provider) = npm_ctx;
    if not packages {
        console.error("No packages specified.");
        return 1;
    }
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
        return 0;
    } except Exception as e {
        console.error(f"Error removing packages: {e}");
        return 1;
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
