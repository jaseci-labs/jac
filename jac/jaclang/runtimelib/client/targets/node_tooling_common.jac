import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }

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
