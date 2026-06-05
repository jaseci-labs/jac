"""Implementation of Bun installer utility.

Auto-manages a project-local bun binary inside .jac/bin/ so users
never need to install bun globally.  The resolution order is:

  1. System PATH (if the user already has bun installed, use it)
  2. .jac/bin/bun (project-local, managed by jac)
  3. Auto-download to .jac/bin/ (silent, no prompt)
"""

import os;
import platform;
import shutil;
import subprocess;
import sys;
import zipfile;

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }

# Map (system, machine) to bun release asset name.
# (BUN_VERSION is defined in the bun_installer.jac interface — the single
#  source of truth shared with deployment targets.)
glob _PLATFORM_MAP: dict[str, dict[str, str]] = {
         "Darwin": {
             "arm64": "bun-darwin-aarch64",
             "aarch64": "bun-darwin-aarch64",
             "x86_64": "bun-darwin-x64"
         },
         "Linux": {
             "x86_64": "bun-linux-x64",
             "aarch64": "bun-linux-aarch64",
             "arm64": "bun-linux-aarch64"
         },
         "Windows": {
             "AMD64": "bun-windows-x64",
             "x86_64": "bun-windows-x64",
             "aarch64": "bun-windows-aarch64"
         }
     };


"""Return the resolved asset name for the current platform, or None."""
def _get_platform_asset -> str | None {
    system = platform.system();
    machine = platform.machine();
    system_map = _PLATFORM_MAP.get(system, {});
    return system_map.get(machine, None);
}


"""Return the .jac/bin directory for the current project, creating it if needed."""
def _get_jac_bin_dir -> Path {
    config = get_config();
    if config and config.project_root {
        base = config.get_build_dir();
    } else {
        base = Path.cwd() / ".jac";
    }
    bin_dir = base / "bin";
    bin_dir.mkdir(parents=True, exist_ok=True);
    return bin_dir;
}


"""Download and extract bun to .jac/bin/.

Returns the path to the bun binary, or None on failure.
"""
def _download_bun(bin_dir: Path) -> Path | None {
    import tempfile;
    import urllib.request;
    import urllib.error;

    asset_name = _get_platform_asset();
    if not asset_name {
        console.error(
            f"Unsupported platform: {platform.system()} {platform.machine()}",
            emoji=False
        );
        return None;
    }

    url = f"https://github.com/oven-sh/bun/releases/download/bun-v{BUN_VERSION}/{asset_name}.zip";
    is_windows = platform.system() == "Windows";
    bun_name = "bun.exe" if is_windows else "bun";
    bun_path = bin_dir / bun_name;

    console.print(f"\n  ⏳ Installing Bun v{BUN_VERSION} to .jac/bin/ ...");

    try {
        with tempfile.TemporaryDirectory() as tmp {
            zip_path = os.path.join(tmp, "bun.zip");
            # Download
            urllib.request.urlretrieve(url, zip_path);
            # Extract - bun zips contain a single directory with the binary
            with zipfile.ZipFile(zip_path, "r") as zf {
                # Find the bun binary inside the archive
                members = zf.namelist();
                bun_member = None;
                for m in members {
                    if m.endswith(f"/{bun_name}") or m == bun_name {
                        bun_member = m;
                        break;
                    }
                }
                if not bun_member {
                    console.error("Could not find bun binary in archive", emoji=False);
                    return None;
                }
                # Extract just the binary
                extracted = zf.extract(bun_member, tmp);
                shutil.move(extracted, str(bun_path));
            }
            # Make executable
            if not is_windows {
                os.chmod(str(bun_path), 0o755);
            }
        }

        # Write version marker so we know when to upgrade
        version_file = bin_dir / ".bun-version";
        version_file.write_text(BUN_VERSION);

        # Verify
        result = subprocess.run(
            [str(bun_path), "--version"], capture_output=True, text=True, timeout=10
        );
        if result.returncode == 0 {
            console.success(
                f"Bun {result.stdout.strip()} installed to .jac/bin/", emoji=False
            );
            return bun_path;
        } else {
            console.error("Downloaded bun binary failed verification", emoji=False);
            bun_path.unlink(missing_ok=True);
            return None;
        }
    } except urllib.error.URLError as e {
        console.error(f"Download failed: {e}", emoji=False);
        return None;
    } except zipfile.BadZipFile {
        console.error("Downloaded file is not a valid zip", emoji=False);
        return None;
    } except subprocess.TimeoutExpired {
        console.error("Bun verification timed out", emoji=False);
        return None;
    } except Exception as e {
        console.error(f"Installation failed: {e}", emoji=False);
        return None;
    }
}


"""Resolve the path to the bun binary, auto-installing if needed.

Resolution order:
  1. System PATH
  2. .jac/bin/bun (project-local, check version)
  3. Auto-download to .jac/bin/

On success the resolved directory is prepended to PATH so subprocesses
that resolve via PATH (e.g. shell=True) can find bun too.
Returns the absolute path to bun, or None if unavailable.
"""
impl get_bun -> str | None {
    is_windows = platform.system() == "Windows";
    bun_name = "bun.exe" if is_windows else "bun";

    bun_path: str | None = None;

    # 1. System PATH
    system_bun = shutil.which("bun");
    if system_bun {
        bun_path = system_bun;
    } else {
        bin_dir = _get_jac_bin_dir();
        local_bun = bin_dir / bun_name;
        # 2. .jac/bin/bun (may already be downloaded)
        if local_bun.exists() {
            # Check if version matches (upgrade if stale)
            version_file = bin_dir / ".bun-version";
            if version_file.exists()
            and version_file.read_text().strip() == BUN_VERSION {
                bun_path = str(local_bun);
            } else {
                # Version mismatch - re-download
                console.warning(f"Upgrading Bun to v{BUN_VERSION}...", emoji=False);
                local_bun.unlink(missing_ok=True);
            }
        }
        # 3. Auto-download
        if bun_path is None {
            result = _download_bun(bin_dir);
            if result {
                bun_path = str(result);
            }
        }
    }

    if bun_path is None {
        return None;
    }

    # Ensure bun's directory is on PATH for subprocesses that resolve via PATH.
    bun_dir = str(Path(bun_path).parent);
    current_path = os.environ.get("PATH", "");
    if bun_dir not in current_path.split(os.pathsep) {
        os.environ["PATH"] = f"{bun_dir}{os.pathsep}{current_path}";
    }
    return bun_path;
}
