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
    _make_localhost_url,
    _update_tauri_config_for_dev,
    _run_tauri_dev,
    _start_backend_server,
    _resolve_server_port,
    _get_toml_api_base_url,
    _update_tauri_config_for_build,
    _bundle_sidecar
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
        import signal;
        import sys;
        import from ...vite_bundler { ViteBundler, API_BASE_URL_ENV_VAR }
        import from jac_client.plugin.client { JacClient }

        console.print("\n🖥️  Starting desktop dev server (Tauri)", style="bold");

        # Validate setup
        validation = self.validate(ctx);
        if not validation.success {
            return validation;
        }

        tauri_dir = ctx.project_dir / "src-tauri";

        # Step 1: Update tauri.conf.json for dev mode
        console.print("  Configuring Tauri for dev mode...", style="muted");
        _update_tauri_config_for_dev(tauri_dir);

        # Step 2: Prepare package.json and compile module
        console.print("  Preparing compilation setup...", style="muted");
        vite_port = 5173;
        bundler = ViteBundler(
            project_dir=ctx.project_dir, output_dir=None, minify=False, config_path=None
        );

        # Ensure package.json exists
        package_json_path = bundler._get_client_dir() / 'configs' / 'package.json';
        if not package_json_path.exists() {
            bundler.create_package_json();
        }

        # Get the compiler and compile the module
        builder = JacClient.get_client_bundle_builder();
        if not builder.vite_package_json or not builder.vite_package_json.exists() {
            builder.vite_package_json = package_json_path;
        }
        compiler = builder._get_compiler();
        compiler.compiled_dir.mkdir(parents=True, exist_ok=True);
        compiler.compile_runtime_utils();

        # Compile the module
        (module_js, mod, module_manifest) = compiler.jac_compiler.compile_module(
            ctx.entry_file
        );
        module_name = ctx.entry_file.stem;
        compiled_module_path = compiler.compiled_dir / f"{module_name}.js";
        compiled_module_path.write_text(module_js, encoding='utf-8');
        compiler.create_entry_file(ctx.entry_file);
        console.print("  ✔ Module compiled for dev mode", style="success");

        # Step 3: Start Vite dev server
        console.print("  Starting web dev server...", style="muted");
        dev_config_path = bundler.create_vite_config(
            ctx.entry_file,
            api_base_url_override=_make_localhost_url(ctx.port),
            is_dev=True,
            api_port=ctx.port
        );
        vite_process = bundler.start_dev_server(port=vite_port);
        if not vite_process {
            return BuildResult.fail("Failed to start Vite dev server");
        }
        console.print(
            f"  ✔ Web dev server running on http://localhost:{vite_port}", style="success"
        );

        # Step 4: Start backend API server
        toml_base_url = _get_toml_api_base_url(ctx.project_dir);
        server_port = _resolve_server_port(toml_base_url, ctx.port);
        _generate_main_rs(
            tauri_dir, api_base_url=toml_base_url or _make_localhost_url(server_port)
        );
        console.print(
            f"  Starting backend server on port {server_port}...", style="muted"
        );
        server_process = _start_backend_server(ctx.entry_file, ctx.project_dir, server_port);
        console.print(
            f"  ✔ Backend server starting on port {server_port}", style="success"
        );

        # Step 5: Launch Tauri dev
        console.print("  Launching Tauri dev window...", style="muted");
        console.print("  (Press Ctrl+C to stop)", style="muted");

        # Setup cleanup function
        def cleanup -> None {
            console.print("\n  Stopping dev servers...", style="muted");
            if vite_process {
                try {
                    vite_process.terminate();
                    vite_process.wait(timeout=5);
                } except Exception {
                    vite_process.kill();
                }
            }
            if server_process {
                try {
                    server_process.terminate();
                    server_process.wait(timeout=5);
                } except Exception {
                    server_process.kill();
                }
            }
            console.print("  ✔ Dev servers stopped", style="success");
        }

        def signal_handler(signum: int, frame: any) -> None {
            cleanup();
            sys.exit(0);
        }

        signal.signal(signal.SIGINT, signal_handler);
        signal.signal(signal.SIGTERM, signal_handler);

        try {
            # Run tauri dev
            tauri_process = _run_tauri_dev(tauri_dir);
            tauri_process.wait();
        } except KeyboardInterrupt {
            console.print(
                "\n  Keyboard interrupt detected. Stopping...", style="muted"
            );
        } finally {
            cleanup();
        }

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
        import signal;
        import sys;
        import from ...vite_bundler { API_BASE_URL_ENV_VAR }
        import from ..factory { get_target }

        console.print("\n🖥️  Starting desktop app", style="bold");

        # Validate setup
        validation = self.validate(ctx);
        if not validation.success {
            return validation;
        }

        tauri_dir = ctx.project_dir / "src-tauri";

        # Step 1: Build web bundle with explicit backend URL for desktop webview
        toml_base_url = _get_toml_api_base_url(ctx.project_dir);
        server_port = _resolve_server_port(toml_base_url, ctx.port);

        if not toml_base_url {
            os.environ[API_BASE_URL_ENV_VAR] = _make_localhost_url(server_port);
        }

        console.print("  Building web bundle...", style="muted");
        web_target = get_target("web");
        try {
            web_result = web_target.build(ctx);
        } finally {
            os.environ.pop(API_BASE_URL_ENV_VAR, None);
        }

        if not web_result.success {
            return web_result;
        }
        console.print("  ✔ Web bundle built", style="success");

        # Step 2: Update tauri.conf.json to point to web bundle
        console.print("  Updating Tauri configuration...", style="muted");
        dist_path = ctx.project_dir / ".jac" / "client" / "dist" / "index.html";
        _update_tauri_config_for_build(tauri_dir, ctx.project_dir, dist_path);

        # Step 3: Regenerate main.rs with the actual backend URL so sidecar is skipped
        _generate_main_rs(
            tauri_dir, api_base_url=toml_base_url or _make_localhost_url(server_port)
        );

        # Step 4: Start backend API server
        console.print(
            f"  Starting backend server on port {server_port}...", style="muted"
        );
        server_process = _start_backend_server(ctx.entry_file, ctx.project_dir, server_port);
        console.print(
            f"  ✔ Backend server starting on port {server_port}", style="success"
        );

        # Step 5: Launch Tauri app
        console.print("  Launching Tauri app...", style="muted");
        console.print("  (Press Ctrl+C to stop)", style="muted");

        # Setup cleanup function
        tauri_process = None;

        def cleanup -> None {
            console.print("\n  Stopping app...", style="muted");
            if tauri_process {
                try {
                    tauri_process.terminate();
                    tauri_process.wait(timeout=5);
                } except Exception {
                    tauri_process.kill();
                }
            }
            if server_process {
                try {
                    server_process.terminate();
                    server_process.wait(timeout=5);
                } except Exception {
                    server_process.kill();
                }
            }
            console.print("  ✔ App stopped", style="success");
        }

        def signal_handler(signum: int, frame: any) -> None {
            cleanup();
            sys.exit(0);
        }

        signal.signal(signal.SIGINT, signal_handler);
        signal.signal(signal.SIGTERM, signal_handler);

        try {
            # Run tauri dev (it will use the built bundle from distDir)
            tauri_process = _run_tauri_dev(tauri_dir);

            if not tauri_process {
                console.error("  Failed to start Tauri process");
                cleanup();
                return BuildResult.fail("Failed to start Tauri process");
            }

            # Wait for tauri process to finish
            return_code = tauri_process.wait();
            if return_code != 0 {
                console.warning(f"  Tauri process exited with code {return_code}");
            }
        } except KeyboardInterrupt {
            console.print(
                "\n  Keyboard interrupt detected. Stopping app...", style="muted"
            );
        } finally {
            cleanup();
        }

        return BuildResult.ok();
    } except Exception as e {
        return BuildResult.fail(str(e));
    }
}
