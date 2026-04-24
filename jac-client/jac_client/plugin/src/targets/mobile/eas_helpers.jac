"""EAS (Expo Application Services) build helpers for MobileTarget.

Handles generating eas.json, checking EAS CLI readiness, and submitting
cloud builds via `eas build`.
"""
import from pathlib { Path }
import from jaclang.cli.console { console }
import subprocess;
import json;

"""Generate eas.json from the [mobile.eas] section of jac.toml."""
def _generate_eas_json(mobile_dir: Path, project_dir: Path) {
    console.print("  Generating eas.json from jac.toml...", style="muted");
    try {
        import from jac_client.plugin.src.mobile_config { MobileConfig }
        mobile_config = MobileConfig(project_dir=project_dir);
        eas_config = mobile_config.get_eas_config();

        eas_json_path = mobile_dir / "eas.json";
        with open(eas_json_path, "w") as f {
            json.dump(eas_config, f, indent=2);
        }
        console.print(f"  ✔ Generated eas.json", style="success");
    } except Exception as e {
        console.warning(f"  Failed to generate eas.json: {e}");
        raise;
    }
}

"""Check if EAS CLI is installed and the user is logged in.

Returns dict: {is_ready: bool, error_code: str, error_message: str}
Error codes: CLI_NOT_FOUND | NOT_LOGGED_IN | CLI_CHECK_FAILED | LOGIN_CHECK_FAILED
"""
def _check_eas_ready(mobile_dir: Path) -> dict {
    try {
        result = subprocess.run(
            ["eas", "--version"], capture_output=True, text=True, timeout=5
        );
        if result.returncode != 0 {
            return {
                'is_ready': False,
                'error_code': 'CLI_NOT_FOUND',
                'error_message': "EAS CLI not found. Install with: npm install -g eas-cli"
            };
        }
    } except FileNotFoundError {
        return {
            'is_ready': False,
            'error_code': 'CLI_NOT_FOUND',
            'error_message': "EAS CLI not found. Install with: npm install -g eas-cli"
        };
    } except Exception as e {
        return {
            'is_ready': False,
            'error_code': 'CLI_CHECK_FAILED',
            'error_message': f"Failed to check EAS CLI: {e}"
        };
    }

    try {
        result = subprocess.run(
            ["eas", "whoami"], capture_output=True, text=True, timeout=5
        );
        if result.returncode != 0 or not result.stdout.strip() {
            return {
                'is_ready': False,
                'error_code': 'NOT_LOGGED_IN',
                'error_message': "Not logged into EAS. Run: eas login"
            };
        }
    } except Exception as e {
        return {
            'is_ready': False,
            'error_code': 'LOGIN_CHECK_FAILED',
            'error_message': f"Failed to check EAS login status: {e}"
        };
    }

    return {'is_ready': True, 'error_code': '', 'error_message': ""};
}

"""Submit a cloud build via EAS.

Returns dict: {build_id, build_url, artifact_type, platform}
"""
def _build_with_eas(
    mobile_dir: Path,
    project_dir: Path,
    build_type: str = "production",
    platform: str = "android"
) -> dict {
    console.print(f"\n🚀 Starting EAS build...", style="bold");
    console.print(f"  Build type: {build_type}", style="muted");
    console.print(f"  Platform: {platform}", style="muted");

    eas_status = _check_eas_ready(mobile_dir);
    if not eas_status['is_ready'] {
        error_code = eas_status.get('error_code', '');
        error_msg = eas_status['error_message'];

        if error_code == 'CLI_NOT_FOUND' {
            console.error(f"  {error_msg}");
            raise RuntimeError(error_msg);
        } elif error_code == 'NOT_LOGGED_IN' {
            console.warning("  Not logged into EAS");
            console.print("\n💡 EAS login required for building:", style="bold");
            console.print("  - If you have an Expo account: Login now", style="muted");
            console.print(
                "  - If you don't: Sign up at https://expo.dev/signup first",
                style="muted"
            );
            console.print(
                "\n🔐 Login to EAS? (You'll be prompted for credentials)", style="bold"
            );
            user_input = str(input("  Continue with login? [Y/n]: ")).strip().lower();
            if user_input in ['', 'y', 'yes'] {
                console.print("\n  Running: eas login", style="muted");
                console.print("  (Follow the prompts to login)\n", style="muted");
                try {
                    result = subprocess.run(
                        ["eas", "login"],
                        cwd=str(mobile_dir),
                        timeout=300
                    );
                    if result.returncode != 0 {
                        console.error("  Login failed");
                        raise RuntimeError("EAS login failed");
                    }
                    console.success("  ✔ Login successful!");
                } except subprocess.TimeoutExpired {
                    console.error("  Login timed out");
                    raise RuntimeError("EAS login timed out");
                } except Exception as e {
                    console.error(f"  Login failed: {e}");
                    raise RuntimeError(f"EAS login failed: {e}");
                }
            } else {
                console.print("\n💡 To build later, run: eas login", style="bold");
                console.print(
                    "💡 For local dev testing: jac start main.jac --client mobile",
                    style="muted"
                );
                raise RuntimeError("User declined EAS login");
            }
        } else {
            console.error(f"  {error_msg}");
            raise RuntimeError(error_msg);
        }
    }

    eas_json_path = mobile_dir / "eas.json";
    if not eas_json_path.exists() {
        console.print("  Generating EAS configuration...", style="muted");
        try {
            _generate_eas_json(mobile_dir, project_dir);
            console.success("  ✔ EAS configured");
        } except Exception as e {
            console.warning(f"  Failed to generate eas.json: {e}");
            raise RuntimeError(f"EAS configuration failed: {e}");
        }
    } else {
        console.print("  ✔ EAS configuration found", style="success");
    }

    cmd = ["eas", "build", "--profile", build_type, "--platform", platform];
    console.print(f"\n  Running: {' '.join(cmd)}", style="muted");
    console.print(f"  (This will upload your project to EAS cloud)", style="muted");
    console.print(
        f"  (Note: First-time setup may ask to configure project)", style="muted"
    );
    console.print(f"  (Select the platform you chose: {platform})\n", style="muted");

    try {
        result = subprocess.run(
            cmd, cwd=str(mobile_dir), timeout=600
        );
        if result.returncode != 0 {
            console.error(f"\n  EAS build submission failed");
            raise RuntimeError(f"EAS build failed with exit code {result.returncode}");
        }
        console.success(f"\n✔ Build submitted successfully!");
        console.print(f"\n💡 Your build is now processing on EAS cloud", style="bold");
        console.print(f"   Monitor progress at: https://expo.dev", style="muted");
        return {
            'build_id': 'submitted',
            'build_url': 'https://expo.dev (check your account)',
            'artifact_type': _get_artifact_type(build_type, platform),
            'platform': platform
        };
    } except subprocess.TimeoutExpired {
        console.error("  EAS build submission timed out");
        raise RuntimeError("EAS build submission timed out");
    } except Exception as e {
        console.error(f"  EAS build failed: {e}");
        raise RuntimeError(f"EAS build failed: {e}");
    }
}

"""Parse EAS CLI stdout for build ID and URL."""
def _parse_eas_output(output: str, build_type: str, platform: str) -> dict {
    import re;
    build_id = "";
    build_url = "";

    for line in output.split('\n') {
        if 'Build ID' in line or 'build ID' in line {
            parts = line.split(':');
            if len(parts) > 1 {
                build_id = parts[1].strip();
            }
        }
        if 'expo.dev' in line {
            m = re.search(r'https://expo\.dev/[^\s]+', line);
            if m {
                build_url = m.group(0);
            }
        }
    }

    if not build_id or not build_url {
        for url in re.findall(r'https://[^\s]+', output) {
            if 'expo.dev' in url and 'builds' in url {
                build_url = url;
                m = re.search(r'/builds/([a-f0-9\-]+)', url);
                if m {
                    build_id = m.group(1);
                }
                break;
            }
        }
    }

    return {
        'build_id': build_id or 'unknown',
        'build_url': build_url or 'Check expo.dev for build status',
        'artifact_type': _get_artifact_type(build_type, platform),
        'platform': platform
    };
}

"""Map build_type + platform to the expected output artifact type."""
def _get_artifact_type(build_type: str, platform: str) -> str {
    if platform == "android" {
        return "AAB (Android App Bundle)" if build_type == "production" else "APK";
    } elif platform == "ios" {
        return "APP (Simulator)" if build_type == "development" else "IPA";
    } elif platform == "all" {
        return "AAB + IPA" if build_type == "production" else "APK + IPA";
    }
    return "Unknown";
}
