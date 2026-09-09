import subprocess;
import hashlib;
import json;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.client { get_bun }

def resolve_node_tool_entry(project_dir: Path, tool: str) -> (Path | None) {
    shim = project_dir / "node_modules" / ".bin" / tool;
    if not shim.exists() {
        return None;
    }
    return shim.resolve();
}

def resolve_node_tool(project_dir: Path, tool: str) -> list[str] {
    bun = _require_bundled_bun();
    `entry = resolve_node_tool_entry(project_dir, tool);
    if `entry is None {
        raise RuntimeError(
            f"The npm tool '{tool}' is not installed under "
            f"{project_dir / 'node_modules'}. Install the project's "
            "dependencies first; project tools must resolve from the local node_modules."
        );
    }
    return [bun, str(`entry)];
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
    import from jaclang.toolchains.store { offline, InstallLock }
    with InstallLock(project_dir / ".jac-dependencies.lock") {
        stamp = project_dir / ".jac-dependencies.sha256";
        signature = manifest_signature(project_dir);
        if offline() {
            manifest = json.loads((project_dir / "package.json").read_text());
            names = list(manifest.get("dependencies", {}).keys())
                + list(manifest.get("devDependencies", {}).keys());
            complete = all(
                (project_dir / "node_modules" / str(name)).exists() for name in names
            );
            if not stamp.is_file() or stamp.read_text() != signature or not complete {
                raise RuntimeError(
                    "JavaScript dependencies are not ready for offline use. Run jac setup online first."
                );
            }
            console.print(
                "Using verified offline JavaScript dependency installation",
                style="muted"
            );
            return;
        }
        cmd = [resolve_package_manager(), "install"];
        console.print(f"Synchronizing dependencies in {project_dir.name}...");
        subprocess.run(cmd, cwd=project_dir, check=True, capture_output=False);
        stamp.write_text(manifest_signature(project_dir));
    }
}

def manifest_signature(project_dir: Path) -> str {
    digest = hashlib.sha256();
    for name in ["package.json", "bun.lock", "bun.lockb"] {
        path = project_dir / name;
        if path.is_file() {
            digest.update(name.encode());
            digest.update(path.read_bytes());
        }
    }
    return digest.hexdigest();
}
