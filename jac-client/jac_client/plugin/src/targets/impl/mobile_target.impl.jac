"""Implementation of MobileTarget methods.

Helper functions are split into focused submodules under targets/mobile/:
  setup_helpers  — scaffolding generators (_generate_*, _add_mobile_config, …)
  bundle_helpers — web→mobile bundle pipeline (_prepare_build_dir, _create_mobile_bundle, …)
  dev_helpers    — dev-server utilities (_get_local_ip, _start_backend_server, …)
"""
import from pathlib { Path }
import from typing { Optional, Any }
import from jaclang.cli.console { console }
import subprocess;

import from jac_client.plugin.src.targets.mobile.setup_helpers {
    _generate_app_json_from_toml,
    _generate_package_json,
    _generate_tsconfig,
    _generate_webview_screen,
    _generate_bundle_script,
    _generate_layout_file,
    _add_mobile_config,
    _check_mobile_dependencies,
    _install_yarn_dependencies,
    _generate_placeholder_icons,
    _generate_gitignore
}
import from jac_client.plugin.src.targets.mobile.bundle_helpers {
    _prepare_build_dir,
    _copy_web_bundle_to_mobile,
    _create_mobile_bundle
}
import from jac_client.plugin.src.targets.mobile.dev_helpers {
    _get_local_ip,
    _write_dev_config,
    _write_build_config,
    _start_vite_dev_server,
    _start_backend_server
}

# ============================================================================
# MobileTarget.setup — scaffold the mobile/ source directory
# ============================================================================
"""Setup mobile target — scaffold React Native/Expo project structure."""
impl MobileTarget.setup(project_dir: Path) -> None {
    mobile_dir = project_dir / "mobile";

    console.print("\n📱 Setting up mobile target (React Native/Expo)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");
    console.print(
        f"  Source directory: {mobile_dir.relative_to(project_dir)}", style="muted"
    );
    console.print(
        f"  Build artifacts: .jac/mobile/ (not tracked in git)", style="muted"
    );

    if mobile_dir.exists() {
        console.warning("Mobile target already set up. Skipping...");
        return;
    }

    if not project_dir.exists() {
        try {
            project_dir.mkdir(parents=True, exist_ok=True);
        } except Exception as e {
            raise RuntimeError(f"Failed to create project directory: {e}");
        }
    }

    console.print("  Creating mobile/ directory structure...", style="muted");
    try {
        mobile_dir.mkdir(parents=True, exist_ok=True);
        (mobile_dir / "app").mkdir(exist_ok=True);
        (mobile_dir / "assets").mkdir(exist_ok=True);
        (mobile_dir / "assets" / "jac-app").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {mobile_dir}", style="success");
    } except Exception as e {
        raise RuntimeError(f"Failed to create mobile directory: {e}");
    }

    try {
        import from jac_client.plugin.src.mobile_config { MobileConfig }
        try {
            mobile_config = MobileConfig(project_dir=project_dir);
            config_data = mobile_config.load();
            project_name = config_data.get('name', 'my-jac-app');
            project_version = config_data.get('version', '1.0.0');
            bundle_id = config_data.get('bundle_id', 'com.example.myjacapp');
        } except Exception as e {
            console.warning(f"  Failed to load mobile config: {e}, using defaults");
            project_name = 'my-jac-app';
            project_version = '1.0.0';
            bundle_id = 'com.example.myjacapp';
        }

        console.print(
            f"  Project: {project_name} v{project_version}, bundle: {bundle_id}",
            style="muted"
        );

        for (fn, label) in [
            (
                lambda : _generate_app_json_from_toml(mobile_dir, project_dir),
                "app.json"
            ),
            (lambda : _generate_package_json(mobile_dir, project_name), "package.json"),
            (lambda : _generate_tsconfig(mobile_dir), "tsconfig.json"),
            (lambda : _generate_webview_screen(mobile_dir), "app/index.tsx"),
            (lambda : _generate_bundle_script(mobile_dir), "create-bundle.js"),
            (lambda : _generate_layout_file(mobile_dir), "app/_layout.tsx"),
            (
                lambda :
                    _add_mobile_config(
                        project_dir, project_name, bundle_id, project_version
                    ),
                "[mobile] in jac.toml"
            ),
            (lambda : _generate_placeholder_icons(mobile_dir), "placeholder icons"),
            (lambda : _generate_gitignore(mobile_dir), ".gitignore"),

        ] {
            try {
                fn();
            } except Exception as e {
                console.warning(f"  Failed to generate {label}: {e}");
            }
        }

        console.print("\n📦 Checking required dependencies...", style="bold");
        try {
            _check_mobile_dependencies();
        } except Exception as e {
            console.warning(f"  Dependency check issue: {e}");
        }

        console.success("Mobile target setup complete!");
        console.print("\n💡 Source files created in mobile/ directory", style="bold");
        console.print(
            "   Dependencies & bundles will be in .jac/mobile/ during build/dev",
            style="muted"
        );
        console.print("\nNext steps:", style="bold");
        console.print(
            "  jac build main.jac --client mobile -p android -b development",
            style="muted"
        );
        console.print("  jac start main.jac --client mobile --dev", style="muted");
    } finally {
        if not mobile_dir.exists() {
            try {
                mobile_dir.mkdir(parents=True, exist_ok=True);
            } except Exception as e {
                console.error(f"  CRITICAL: Could not create mobile directory: {e}");
            }
        }
    }
}

# ============================================================================
# MobileTarget.build — web bundle → mobile bundle (native build runs elsewhere)
# ============================================================================
"""Build mobile bundle — produces .jac/mobile/ ready for `expo prebuild` + native build.

The native APK/IPA build (Gradle / Xcode) is intentionally not run here.
Drive it from CI or a local script; see .github/JAC_MOBILE.md.
"""
impl MobileTarget.build(
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None,
    build_type: str = "production"
) -> Path {
    console.print("\n📱 Building mobile app (React Native)", style="bold");

    mobile_src_dir = project_dir / "mobile";
    if not mobile_src_dir.exists() {
        raise RuntimeError("Mobile target not set up. Run 'jac setup mobile' first.");
    }
    mobile_build_dir = project_dir / ".jac" / "mobile";

    console.print("  Step 1: Preparing build directory...", style="muted");
    _prepare_build_dir(mobile_src_dir, mobile_build_dir);

    console.print("  Step 2: Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, platform);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    console.print("  Step 3: Copying web bundle to build directory...", style="muted");
    _copy_web_bundle_to_mobile(web_bundle_path, mobile_build_dir);

    console.print("  Step 4: Creating mobile bundle...", style="muted");
    _create_mobile_bundle(mobile_build_dir);

    console.print("  Step 5: Writing build config (backend URL)...", style="muted");
    _write_build_config(mobile_build_dir, project_dir);

    console.success("Mobile bundle created successfully!");
    console.print(f"  Build directory: {mobile_build_dir}", style="muted");
    console.print(
        f"\n💡 Next: run `expo prebuild` then your native build", style="bold"
    );
    console.print(
        f"     cd {mobile_build_dir} && npx expo prebuild --platform android",
        style="muted"
    );

    return mobile_build_dir;
}

# ============================================================================
# MobileTarget.dev — HMR dev mode (Vite + Expo dev client)
# ============================================================================
"""Start mobile dev server — Vite HMR + backend + Expo dev client."""
impl MobileTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import signal;
    import sys;
    console.print("\n📱 Starting mobile dev server (Expo + HMR)", style="bold");

    mobile_src_dir = project_dir / "mobile";
    if not mobile_src_dir.exists() {
        raise RuntimeError("Mobile target not set up. Run 'jac setup mobile' first.");
    }
    mobile_build_dir = project_dir / ".jac" / "mobile";

    _prepare_build_dir(mobile_src_dir, mobile_build_dir);

    local_ip = _get_local_ip();
    console.print(f"  Detected local IP: {local_ip}", style="muted");
    _write_dev_config(mobile_build_dir, project_dir, local_ip);

    console.print("  Step 1: Building web bundle for bundled mode...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built", style="success");

    console.print("  Step 2: Creating mobile bundle...", style="muted");
    _copy_web_bundle_to_mobile(web_bundle_path, mobile_build_dir);
    _create_mobile_bundle(mobile_build_dir);

    console.print("  Step 3: Starting Vite dev server on port 5173...", style="muted");
    vite_process = _start_vite_dev_server(entry_file, project_dir, api_port);
    console.print(f"  ✔ Vite dev server running", style="success");

    console.print(
        f"  Step 4: Starting backend server on port {api_port}...", style="muted"
    );
    server_process = _start_backend_server(entry_file, project_dir, api_port);
    console.print(f"  ✔ Backend server starting on port {api_port}", style="success");

    console.print("  Step 5: Starting Expo dev server...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");

    expo_process = None;

    def cleanup {
        console.print("\n  Stopping dev servers...", style="muted");
        for proc in [expo_process, vite_process, server_process] {
            if proc {
                try {
                    proc.terminate();
                    proc.wait(timeout=5);
                } except Exception {
                    try {
                        proc.kill();
                    } except Exception { }
                }
            }
        }
        console.print("  ✔ Dev servers stopped", style="success");
    }

    def signal_handler(signum: int, frame: Any) {
        cleanup();
        sys.exit(0);
    }

    signal.signal(signal.SIGINT, signal_handler);
    signal.signal(signal.SIGTERM, signal_handler);

    try {
        expo_process = subprocess.Popen(
            ["npx", "expo", "start"], cwd=str(mobile_build_dir)
        );
        console.success("Expo dev server started!");
        console.print(
            "  Scan QR code with Expo Go app to test on device", style="muted"
        );
        console.print(f"\n  🌐 Dev Server URLs (IP: {local_ip}):", style="bold");
        console.print(f"     Vite dev server: http://{local_ip}:5173", style="muted");
        console.print(f"     Backend API: http://{local_ip}:{api_port}", style="muted");
        console.print("\n  💡 Two rendering modes:", style="bold");
        console.print(
            "     Bundle mode (default): Loads pre-built HTML from assets",
            style="muted"
        );
        console.print(
            "     HMR mode: USE_DEV_SERVER=true in .jac/mobile/app/index.tsx",
            style="muted"
        );
        return_code = expo_process.wait();
        if return_code != 0 {
            console.warning(f"  Expo process exited with code {return_code}");
        }
    } except KeyboardInterrupt {
        console.print("\n  Keyboard interrupt detected. Stopping...", style="muted");
    } except Exception as e {
        console.error(f"  Error starting mobile dev: {e}");
    } finally {
        cleanup();
    }
}

# ============================================================================
# MobileTarget.start — bundle mode (no HMR, simulates production locally)
# ============================================================================
"""Start mobile app with pre-built bundle (no HMR Vite server).

Use this to verify the bundled app behaviour on a device without
triggering a full native build.  Unlike dev(), no Vite server is
started — Expo loads the pre-built assets only.
"""
impl MobileTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import signal;
    import sys;
    console.print("\n📱 Starting mobile app (bundle mode, no HMR)", style="bold");

    mobile_src_dir = project_dir / "mobile";
    if not mobile_src_dir.exists() {
        raise RuntimeError("Mobile target not set up. Run 'jac setup mobile' first.");
    }
    mobile_build_dir = project_dir / ".jac" / "mobile";

    _prepare_build_dir(mobile_src_dir, mobile_build_dir);

    local_ip = _get_local_ip();
    console.print(f"  Detected local IP: {local_ip}", style="muted");
    _write_dev_config(mobile_build_dir, project_dir, local_ip);

    console.print("  Building web bundle...", style="muted");
    web_bundle_path = super.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built", style="success");

    console.print("  Creating mobile bundle...", style="muted");
    _copy_web_bundle_to_mobile(web_bundle_path, mobile_build_dir);
    _create_mobile_bundle(mobile_build_dir);

    console.print(f"  Starting backend server on port {api_port}...", style="muted");
    server_process = _start_backend_server(entry_file, project_dir, api_port);
    console.print(f"  ✔ Backend server starting on port {api_port}", style="success");

    expo_process = None;

    def cleanup {
        console.print("\n  Stopping servers...", style="muted");
        for proc in [expo_process, server_process] {
            if proc {
                try {
                    proc.terminate();
                    proc.wait(timeout=5);
                } except Exception {
                    try {
                        proc.kill();
                    } except Exception { }
                }
            }
        }
        console.print("  ✔ Servers stopped", style="success");
    }

    def signal_handler(signum: int, frame: Any) {
        cleanup();
        sys.exit(0);
    }

    signal.signal(signal.SIGINT, signal_handler);
    signal.signal(signal.SIGTERM, signal_handler);

    console.print("  Starting Expo (bundle mode)...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");

    try {
        expo_process = subprocess.Popen(
            ["npx", "expo", "start", "--no-dev", "--minify"], cwd=str(mobile_build_dir)
        );
        console.success("Expo started in bundle mode!");
        console.print(f"  Backend API: http://{local_ip}:{api_port}", style="muted");
        console.print(
            "  Scan QR code with Expo Go app to test on device", style="muted"
        );
        return_code = expo_process.wait();
        if return_code != 0 {
            console.warning(f"  Expo process exited with code {return_code}");
        }
    } except KeyboardInterrupt {
        console.print("\n  Keyboard interrupt detected. Stopping...", style="muted");
    } except Exception as e {
        console.error(f"  Error starting mobile app: {e}");
    } finally {
        cleanup();
    }
}
