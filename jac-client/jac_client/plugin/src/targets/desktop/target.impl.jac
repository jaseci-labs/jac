"""Implementation of DesktopTarget methods using new BuildContext/BuildResult interface.

This implementation wraps the existing desktop target logic while providing
the standardized BuildContext → BuildResult interface.
"""
import json;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from ..types { BuildContext, BuildResult }
import from ...desktop_config { DesktopConfig }

# Import helper functions
import from .helpers {
    _generate_tauri_config,
    _generate_cargo_toml,
    _generate_build_rs,
    _generate_default_icons,
    _generate_main_rs,
    _add_desktop_config,
    _check_and_install_dependencies,
    _populate_icon_array,
    _make_localhost_url
}

"""Setup desktop target - scaffold Tauri project structure."""
impl DesktopTarget.setup(self: DesktopTarget, ctx: BuildContext) -> BuildResult {
    tauri_dir = ctx.project_dir / "src-tauri";

    try {
        console.print("\n🖥️  Setting up desktop target (Tauri)", style="bold");
        console.print(f"  Project directory: {ctx.project_dir}", style="muted");

        # Check if already set up
        if tauri_dir.exists() {
            console.warning("Desktop target already set up. Skipping...");
            return BuildResult.ok();
        }

        # Create src-tauri directory structure
        console.print("  Creating src-tauri/ directory structure...", style="muted");
        tauri_dir.mkdir(parents=True, exist_ok=True);
        (tauri_dir / "src").mkdir(exist_ok=True);
        (tauri_dir / "binaries").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {tauri_dir}", style="success");

        # Load desktop config
        try {
            desktop_config = DesktopConfig(project_dir=ctx.project_dir);
            config_data = desktop_config.load();
            project_name = config_data.get('name', 'my-jac-app');
            project_version = config_data.get('version', '1.0.0');
            identifier = config_data.get('identifier', 'com.myapp');
        } except Exception as e {
            console.warning(f"  Failed to load desktop config: {e}, using defaults");
            project_name = 'my-jac-app';
            project_version = '1.0.0';
            identifier = 'com.myapp';
        }

        # Generate config files (continue on failures)
        try { _generate_tauri_config(tauri_dir, project_name, identifier, project_version); }
        except Exception as e { console.warning(f"  Failed to generate tauri.conf.json: {e}"); }

        try { _generate_cargo_toml(tauri_dir, project_name, identifier); }
        except Exception as e { console.warning(f"  Failed to generate Cargo.toml: {e}"); }

        try { _generate_build_rs(tauri_dir); }
        except Exception as e { console.warning(f"  Failed to generate build.rs: {e}"); }

        try { _generate_default_icons(tauri_dir); }
        except Exception as e { console.warning(f"  Failed to generate icons: {e}"); }

        try { _generate_main_rs(tauri_dir); }
        except Exception as e { console.warning(f"  Failed to generate main.rs: {e}"); }

        try { _add_desktop_config(ctx.project_dir, project_name, identifier, project_version); }
        except Exception as e { console.warning(f"  Failed to add [desktop] section: {e}"); }

        # Update icons in config
        try {
            config_path = tauri_dir / "tauri.conf.json";
            if config_path.exists() {
                with open(config_path, "r") as f {
                    config = json.load(f);
                }
                _populate_icon_array(tauri_dir, config);
                with open(config_path, "w") as f {
                    json.dump(config, f, indent=2);
                }
            }
        } except Exception as e {
            console.warning(f"  Failed to update icon array: {e}");
        }

        # Check dependencies
        console.print("\n📦 Checking required dependencies...", style="bold");
        try { _check_and_install_dependencies(); }
        except Exception as e { console.warning(f"  Dependency check issue: {e}"); }

        console.success("Desktop target setup complete!");
        console.print("\nNext steps:", style="bold");
        console.print("  1. Build: jac build main.jac --client desktop");
        console.print("  2. Dev:   jac start --client desktop --dev");

        return BuildResult.ok();
    } except Exception as e {
        # Ensure tauri_dir exists even on failure
        if not tauri_dir.exists() {
            try {
                tauri_dir.mkdir(parents=True, exist_ok=True);
                (tauri_dir / "src").mkdir(exist_ok=True);
            } except Exception as mkdir_err {
                console.warning(f"  Could not create src-tauri directory: {mkdir_err}");
            }
        }
        return BuildResult.fail(str(e));
    }
}

"""Build desktop app - web bundle + Tauri."""
impl DesktopTarget.build(self: DesktopTarget, ctx: BuildContext) -> BuildResult {
    try {
        import from ..factory { get_target }
        import subprocess;

        console.print("\n🖥️  Building desktop app", style="bold");

        # Validate setup
        validation = self.validate(ctx);
        if not validation.success {
            return validation;
        }

        # Build web bundle first (use factory for consistency)
        web_target = get_target("web");
        web_result = web_target.build(ctx);
        if not web_result.success {
            return web_result;
        }

        tauri_dir = ctx.project_dir / "src-tauri";

        # Build Tauri app
        console.print("\n  Building Tauri app...", style="muted");
        build_cmd = ["cargo", "tauri", "build"];

        if ctx.platform {
            # Add platform-specific flags
            if ctx.platform == "windows" {
                build_cmd.extend(["--target", "x86_64-pc-windows-msvc"]);
            } elif ctx.platform == "macos" {
                build_cmd.extend(["--target", "x86_64-apple-darwin"]);
            } elif ctx.platform == "linux" {
                build_cmd.extend(["--target", "x86_64-unknown-linux-gnu"]);
            }
        }

        result = subprocess.run(
            build_cmd,
            cwd=str(tauri_dir),
            capture_output=True,
            text=True
        );

        if result.returncode != 0 {
            return BuildResult.fail(f"Tauri build failed:\n{result.stderr}");
        }

        bundle_dir = tauri_dir / "target" / "release" / "bundle";
        console.success(f"Desktop build complete: {bundle_dir}");

        return BuildResult.ok(output_path=bundle_dir);
    } except Exception as e {
        return BuildResult.fail(str(e));
    }
}

"""Start desktop dev server - Vite + Tauri hot reload."""
impl DesktopTarget.dev(self: DesktopTarget, ctx: BuildContext) -> BuildResult {
    try {
        import subprocess;
        import os;
        import from ...vite_bundler { API_BASE_URL_ENV_VAR }

        console.print("\n🖥️  Starting desktop dev mode", style="bold");

        # Validate setup
        validation = self.validate(ctx);
        if not validation.success {
            return validation;
        }

        tauri_dir = ctx.project_dir / "src-tauri";

        # Set API URL for dev mode
        api_url = _make_localhost_url(ctx.port);
        env = os.environ.copy();
        env[API_BASE_URL_ENV_VAR] = api_url;

        console.print(f"  API URL: {api_url}", style="muted");
        console.print("  Starting Tauri dev server...", style="muted");

        # Start tauri dev (this will start vite dev server automatically)
        result = subprocess.run(
            ["cargo", "tauri", "dev"],
            cwd=str(tauri_dir),
            env=env
        );

        return BuildResult.ok();
    } except Exception as e {
        return BuildResult.fail(str(e));
    }
}

"""Start desktop app - build and launch."""
impl DesktopTarget.start(self: DesktopTarget, ctx: BuildContext) -> BuildResult {
    try {
        import subprocess;
        import os;
        import from ...vite_bundler { API_BASE_URL_ENV_VAR }
        import from ..factory { get_target }

        console.print("\n🖥️  Starting desktop app", style="bold");

        # Validate setup
        validation = self.validate(ctx);
        if not validation.success {
            return validation;
        }

        # Build web bundle first (use factory for consistency)
        web_target = get_target("web");
        web_result = web_target.build(ctx);
        if not web_result.success {
            return web_result;
        }

        tauri_dir = ctx.project_dir / "src-tauri";

        # Set API URL
        api_url = _make_localhost_url(ctx.port);
        env = os.environ.copy();
        env[API_BASE_URL_ENV_VAR] = api_url;

        console.print(f"  API URL: {api_url}", style="muted");
        console.print("  Launching app...", style="muted");

        # Run in production mode (uses built bundle)
        result = subprocess.run(
            ["cargo", "run", "--release"],
            cwd=str(tauri_dir),
            env=env
        );

        return BuildResult.ok();
    } except Exception as e {
        return BuildResult.fail(str(e));
    }
}
