import from jaclang.comptime { name as ct_name }
import from jaclang.cli.command { Arg, ArgKind, CommandSpec }
import from jaclang.project.config { JacConfig }
import type from jaclang.project.apps { AppConfig }
import os;

import from jaclang.client.targets.registry { ClientTarget, target_for_app }
import from pathlib { Path }

comptime SPEC_SETUP: CommandSpec = CommandSpec(
         name="setup",
         help="Set up an app's client (one-time initialization)",
         args=[
             Arg.create(
                 "target",
                 kind=ArgKind.POSITIONAL,
                 `default="",
                 help="App name from [apps]; omit to set up the default app"
             ),
             Arg.create(
                 "toolchain",
                 `default="",
                 help="Provision build tools without a project: android, ios, desktop, cef"
             ),
             Arg.create(
                 "platform",
                 `default="",
                 help="Also provision the app build platform: android or ios"
             )
         ],
         examples=[
             ("jac setup", "Set up the default app's client"),
             (
                 "jac setup mobile",
                 "Scaffold the Expo project for the app named 'mobile'"
             )
         ],
         group="project",
         handler_name=ct_name(setup)
     );

def setup(target: str = "", toolchain: str = "", platform: str = "") -> int {
    import from jaclang.cli.console { console }

    if toolchain {
        import from jaclang.toolchains.manager { setup_toolchain }
        return setup_toolchain(toolchain);
    }
    if platform {
        import from jaclang.toolchains.manager { setup_toolchain }
        if setup_toolchain(platform) != 0 {
            return 1;
        }
    }
    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }
    app: AppConfig | None = None;
    if target {
        app = config.app(target);
        if app is None {
            console.error(
                f"No app named '{target}' in {config.toml_path}.",
                hint=f"Apps: {', '.join(config.apps.keys())}"
            );
            return 1;
        }
    } else {
        try {
            app = config.resolve_app("");
        } except ValueError as e {
            console.error(str(e));
            return 1;
        }
    }
    import from jaclang.project.kinds { kind_has_client }
    kind = config.resolved_kind(app);
    if not kind_has_client(kind) {
        console.error(
            f"App '{app.name}' ({kind}) has no client to set up.",
            hint="Client kinds: web-app, web-static, desktop, mobile, js-package"
        );
        return 1;
    }
    return run_client_setup(app);
}

def run_client_setup(app: AppConfig) -> int {
    import from jaclang.cli.console { console }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }
    project_dir = config.project_root or Path.cwd();
    try {
        target_obj = target_for_app(app, project_dir);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }

    label = f"'{app.name}' ({target_obj.name})";
    if not app.implicit {
        import from jaclang.runtime.runtime { JacRuntime as Jac }
        Jac.set_full_target_path(app.entry_path(str(project_dir)));
    }
    try {
        console.print(f"Setting up {label} in: {project_dir}", style="muted");
        target_obj.setup(project_dir);
        console.success(f"Setup of {label} complete!");
        return 0;
    } except NotImplementedError as e {
        console.error(f"Setup for '{target_obj.name}' is not yet implemented.");
        return 1;
    } except Exception as e {
        import traceback;
        console.error(f"Setup failed: {e}");
        console.print(traceback.format_exc(), style="muted");
        return 1;
    }
}

def _place_bundle(bundle_path: Path, out_dir: Path) -> Path {
    import shutil;
    out_dir.mkdir(parents=True, exist_ok=True);
    if bundle_path.is_dir() {
        shutil.copytree(bundle_path, out_dir, dirs_exist_ok=True);
        return out_dir;
    }
    dest = out_dir / bundle_path.name;
    shutil.copy2(bundle_path, dest);
    return dest;
}

def run_client_build(
    app: AppConfig,
    platform: str | None,
    entry_override: str = "",
    output: str = "",
    kind: str = ""
) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.client.targets.registry { target_for_kind }

    config = get_config();
    if not config {
        console.error("No jac.toml found. Run 'jac create' to create a project.");
        return 1;
    }

    project_dir = config.project_root or Path.cwd();
    try {
        target = target_for_kind(kind or config.resolved_kind(app), project_dir);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }

    try {
        entry_path = (
            Path(entry_override)
                if entry_override
                else Path(app.entry_path(str(project_dir)))
        );
        if not entry_path.is_absolute() {
            entry_path = project_dir / entry_path;
        }
        if not entry_path.is_file() {
            console.error(
                f"No entry file for app '{app.name}' (expected {entry_path}).",
                hint="Set [apps.<name>] entry-point, or name a file: jac build <file>"
            );
            return 1;
        }

        import from jaclang.runtime.runtime { JacRuntime as Jac }
        Jac.set_full_target_path(str(entry_path));
        bundle_path = target.build(
            entry_path, project_dir, platform or app.platform or None
        );
        if output {
            bundle_path = _place_bundle(Path(bundle_path), Path(output));
        }

        console.success(f"Build complete: {bundle_path}");
        return 0;
    } except NotImplementedError as e {
        console.error(f"Client '{target.name}' is not yet implemented.");
        return 1;
    } except Exception as e {
        import traceback;
        console.error(f"Build failed: {e}\n{traceback.format_exc()}");
        return 1;
    }
}

def run_client_start(
    app: AppConfig,
    host: str,
    platform: str,
    port: int,
    api_port: int,
    dev: bool,
    no_client: bool
) -> int | None {
    import from jaclang.cli.console { console }
    import from jaclang.client.client_diagnostics { is_debug_mode }

    import from jaclang.project.kinds { kind_has_client }
    import from jaclang.client.targets.registry { target_for_kind }

    config = get_config();
    if not config {
        return None;
    }
    kind = config.resolved_kind(app);
    if not kind_has_client(kind) {
        return None;
    }

    project_dir = config.project_root or Path.cwd();
    try {
        target = target_for_kind(kind, project_dir);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }

    if target.name == "web" {
        return None;
    }
    app_platform = (platform or app.platform or "").strip().lower();
    if target.name == "mobile" and app_platform == "web" {
        return None;
    }

    entry_path = Path(app.entry_path(str(project_dir)));
    if not entry_path.is_file() {
        console.error(
            f"No entry file for app '{app.name}' (expected {entry_path}).",
            hint="Set [apps.<name>] entry-point in jac.toml."
        );
        return 1;
    }

    import from jaclang.runtime.runtime { JacRuntime as Jac }
    Jac.set_full_target_path(str(entry_path));

    if not dev and is_debug_mode(config) {
        console.warning(
            "Debug mode is enabled. For production, consider setting debug=false in [client] section of jac.toml"
        );
    }

    start_port = port or 8000;
    start_api = api_port or 0;
    if target.name == "mobile" {
        if app_platform and app_platform != "auto" {
            os.environ["JAC_MOBILE_PLATFORM"] = app_platform;
        }
        if host {
            import from jaclang.client.targets.react_native.dev { JAC_RN_DEV_HOST_ENV }
            os.environ[JAC_RN_DEV_HOST_ENV] = str(host);
        }
    }
    try {
        if dev {
            target.dev(entry_path, project_dir, port=start_port, api_port=start_api);
        } else {
            target.start(entry_path, project_dir, api_port=start_port);
        }
        return 0;
    } except Exception as e {
        import traceback;
        console.error(f"Client '{target.name}' failed: {e}");
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

def run_npm_add(packages: list, dev: bool, install_global: bool = False) -> int {
    import from jaclang.project.providers { InstallContext }
    import from jaclang.cli.console { console }

    if install_global {
        return run_npm_add_global(packages, dev);
    }

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

def run_npm_add_global(packages: list, dev: bool) -> int {
    import subprocess;
    import from jaclang.cli.console { console }
    import from jaclang.client.bun_installer { get_bun, bun_unavailable_message }
    import from jaclang.project.tool_paths { node_root }

    if not packages {
        console.error(
            "Provide at least one npm package to install globally.",
            hint="e.g. 'jac install --npm --global eslint'"
        );
        return 1;
    }
    bun = get_bun();
    if bun is None {
        console.error(bun_unavailable_message());
        return 1;
    }
    dest = node_root("global");
    assert dest is not None , "the global npm root is always resolvable";
    dest.mkdir(parents=True, exist_ok=True);
    pkg_json = dest / "package.json";
    if not pkg_json.exists() {
        pkg_json.write_text(
            '{\n  "name": "jac-global-tools",\n  "private": true\n}\n', encoding="utf-8"
        );
    }
    cmd: list = [bun, "add"];
    if dev {
        cmd.append("--dev");
    }
    cmd.extend(packages);
    console.print(
        f"\n📦 Installing {len(packages)} npm tool(s) globally into {dest}", style="bold"
    );
    result = subprocess.run(cmd, cwd=str(dest));
    if result.returncode != 0 {
        console.error("Global npm install failed.");
        return 1;
    }
    console.success(
        f"Installed {len(packages)} npm tool(s) globally — "
        "run with 'jac x --global <tool>'"
    );
    return 0;
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
