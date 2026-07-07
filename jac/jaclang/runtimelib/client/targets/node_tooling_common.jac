import json;
import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }
import from jaclang.runtimelib.client.targets.build_common { SUBPROCESS_TIMEOUT_SHORT }

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

def resolve_node_runner -> list[str] {
    return [_require_bundled_bun(), "x"];
}

def resolve_package_manager -> str {
    return _require_bundled_bun();
}

def _require_bundled_bun -> str {
    bun_path = get_bun();
    if bun_path is None {
        raise RuntimeError(
            "Bundled bun is missing. Shipped jac binaries include it (a "
            "missing copy indicates a broken build); for a source checkout "
            "run `zig build fetch-bun`, or set JAC_BUN to a bun binary."
        );
    }
    return bun_path;
}

def run_manifest_install(project_dir: Path) {
    cmd = [resolve_package_manager(), "install"];
    console.print(f"  Installing dependencies in {project_dir.name}...", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}

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
    cmd = [resolve_package_manager(), "add"];
    if dev {
        cmd.append("--dev");
    }
    cmd.extend(packages);
    console.print(f"  Installing: {' '.join(packages)}", style="muted");
    subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
}
