import subprocess;
import hashlib;
import json;
import from pathlib { Path }

def resolve_node_tool_entry(project_dir: Path, tool: str) -> (Path | None);

def resolve_node_tool(project_dir: Path, tool: str) -> list[str];

def run_manifest_install(project_dir: Path);

def _deps_current(project_dir: Path, stamp: Path, signature: str) -> bool;

def manifest_signature(project_dir: Path) -> str;

impl resolve_node_tool_entry(project_dir: Path, tool: str) -> (Path | None) {
    shim = project_dir / "node_modules" / ".bin" / tool;
    if not shim.exists() {
        return None;
    }
    return shim.resolve();
}

impl resolve_node_tool(project_dir: Path, tool: str) -> list[str] {
    bun = js_runtime_path();
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

impl run_manifest_install(project_dir: Path) {
    with FileLock(project_dir / ".jac-dependencies.lock") {
        stamp = project_dir / ".jac-dependencies.sha256";
        current = _deps_current(project_dir, stamp, manifest_signature(project_dir));
        if offline() {
            if not current {
                raise RuntimeError(
                    "JavaScript dependencies are not ready for offline use. "
                    "Run `jac setup <app>` online first."
                );
            }
            console.print(
                "Using verified offline JavaScript dependency installation",
                style="muted"
            );
            return;
        }
        if current {
            return;
        }
        console.print(f"Synchronizing dependencies in {project_dir.name}...");
        (returncode, _) = run_pm(["install"], str(project_dir));
        if returncode != 0 {
            raise subprocess.CalledProcessError(returncode, ["install"]);
        }
        stamp.write_text(manifest_signature(project_dir));
    }
}

impl _deps_current(project_dir: Path, stamp: Path, signature: str) -> bool {
    if not stamp.is_file() or stamp.read_text() != signature {
        return False;
    }
    manifest_path = project_dir / "package.json";
    if not manifest_path.is_file() {
        return False;
    }
    manifest = json.loads(manifest_path.read_text());
    names = list(manifest.get("dependencies", {}).keys())
        + list(manifest.get("devDependencies", {}).keys());
    return all((project_dir / "node_modules" / str(name)).exists() for name in names);
}

impl manifest_signature(project_dir: Path) -> str {
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
