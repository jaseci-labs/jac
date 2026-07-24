import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }

def resolve_node_tool_entry(project_dir: Path, tool: str) -> (Path | None) {
    shim = project_dir / "node_modules" / ".bin" / tool;
    if not shim.exists() {
        return None;
    }
    return shim.resolve();
}

def resolve_node_tool(project_dir: Path, tool: str) -> list[str] {
    bun = _require_bundled_bun();
    entry = resolve_node_tool_entry(project_dir, tool);
    if entry is None {
        raise RuntimeError(
            f"The npm tool '{tool}' is not installed under "
            f"{project_dir / 'node_modules'}. Install the project's "
            "dependencies first; jac provisions bun and never provisions "
            "node, so npm tools must resolve from the local node_modules."
        );
    }
    return [bun, str(entry)];
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
