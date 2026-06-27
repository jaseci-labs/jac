"""Shared Node/Bun tooling helpers for client targets."""

import json;
import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }
import from jaclang.runtimelib.client.targets.build_common { SUBPROCESS_TIMEOUT_SHORT }

"""Check if a command is available and optionally return its version."""
def check_command_available(
    cmd: list[str], timeout: int = SUBPROCESS_TIMEOUT_SHORT
) -> tuple[bool, str | None] {
    try {
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout);
        if result.returncode == 0 {
            return (True, result.stdout.strip());
        }
    } except Exception { }
    return (False, None);
}

"""Resolve npx command prefix (npx preferred, bunx fallback)."""
def resolve_npx_or_bunx -> str {
    (ok, _) = check_command_available(["npx", "--version"]);
    if ok {
        return "npx";
    }
    (ok, _) = check_command_available(["bunx", "--version"]);
    if ok {
        return "bunx";
    }
    raise RuntimeError(
        "npx or bunx not found. Install Node.js (https://nodejs.org) "
        "or Bun (https://bun.sh)."
    );
}

"""Resolve the package manager command, preferring npm and falling back to bun.

Returns the command to invoke as argv[0]: the literal "npm" (resolved via PATH,
the user's own Node toolchain) or, for bun, get_bun()'s ABSOLUTE path -- bun is
contained in the jac ecosystem and never placed on PATH, so it must be invoked
by its full path.
"""
def resolve_package_manager -> str {
    (npm_ok, _) = check_command_available(["npm", "--version"]);
    if npm_ok {
        return "npm";
    }
    bun_path = get_bun();
    if bun_path is not None {
        return bun_path;
    }
    raise RuntimeError(
        "npm or bun not found. Install Node.js (https://nodejs.org) "
        "or Bun (https://bun.sh)."
    );
}

"""Install all dependencies from an existing package.json manifest."""
def run_manifest_install(project_dir: Path) {
    cmd = [resolve_package_manager(), "install"];
    console.print(f"  Installing dependencies in {project_dir.name}...", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

"""Run an npm/bun install command."""
def run_install_cmd(
    project_dir: Path,
    packages: list[str],
    dev: bool = False,
    default_package_name: str = "jac-mobile-app"
) {
    pkg_json = project_dir / "package.json";
    if not pkg_json.exists() {
        pkg_data = {
            "name": default_package_name,
            "version": "1.0.0",
            "private": True,
            "type": "module"
        };
        pkg_json.write_text(json.dumps(pkg_data, indent=2), encoding="utf-8");
        console.print("  ✔ Created package.json", style="success");
    }
    if not packages {
        run_manifest_install(project_dir);
        return;
    }
    pkg_mgr = resolve_package_manager();
    cmd: list[str];
    if pkg_mgr == "npm" {
        cmd = ["npm", "install"];
        if dev {
            cmd.append("--save-dev");
        }
    } else {
        # pkg_mgr is bun's absolute path (never plain "bun" -- not on PATH).
        cmd = [pkg_mgr, "add"];
        if dev {
            cmd.append("--dev");
        }
    }
    cmd.extend(packages);
    console.print(f"  Installing: {' '.join(packages)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}
