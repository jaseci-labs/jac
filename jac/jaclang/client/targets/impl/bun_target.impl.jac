import os;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.jac0core.sv_service_host { bun_artifact_is_fresh }
import from jaclang.client { get_bun }
import from jaclang.client.bun_installer { bun_unavailable_message }
import from jaclang.bun_service_builder { build_bun_service_artifact }

glob JAC_FILE_EXTENSION = ".jac";


def _module_stem(entry_file: Path) -> str {
    mod = entry_file.name;
    if mod.endswith(JAC_FILE_EXTENSION) {
        mod = mod[:-len(JAC_FILE_EXTENSION)];
    }
    return mod;
}


def _resolve_bun_artifact_for_start(
    target: BunTarget, entry_file: Path, project_dir: Path
) -> Path {
    mod = _module_stem(entry_file);
    if bun_artifact_is_fresh(mod, str(project_dir)) {
        if target.last_built_artifact is not None {
            return target.last_built_artifact;
        }
        cached = project_dir / '.jac' / 'server' / f"{mod}.mjs";
        target.last_built_artifact = cached;
        return cached;
    }
    artifact = build_bun_service_artifact(mod, str(project_dir));
    target.last_built_artifact = artifact;
    return artifact;
}


impl BunTarget.setup(project_dir: Path) -> None {
    server_root = project_dir / '.jac' / 'server';
    server_root.mkdir(parents=True, exist_ok=True);
}


impl BunTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    mod = _module_stem(entry_file);
    artifact = build_bun_service_artifact(mod, str(project_dir));
    self.last_built_artifact = artifact;
    return artifact;
}


impl BunTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    self.start(entry_file, project_dir, api_port=port);
}


impl BunTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    bun = get_bun();
    if not bun {
        raise RuntimeError(bun_unavailable_message()) from None;
    }
    artifact = _resolve_bun_artifact_for_start(self, entry_file, project_dir);
    env = dict(os.environ);
    env['PORT'] = str(api_port);
    env['JAC_PORT'] = str(api_port);
    console.print(
        f"\n🚀 Starting Bun sv service at http://127.0.0.1:{api_port}/",
        style="bold green"
    );
    subprocess.run([bun, str(artifact)], cwd=str(project_dir), env=env, check=True);
}
