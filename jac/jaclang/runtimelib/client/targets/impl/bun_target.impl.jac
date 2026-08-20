import os;
import subprocess;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client { get_bun }
import from jaclang.runtimelib.client.bun_installer { bun_unavailable_message }
import from jaclang.runtimelib.bun_service_builder { build_bun_service_artifact }

glob JAC_FILE_EXTENSION = ".jac";


def _module_stem(entry_file: Path) -> str {
    mod = entry_file.name;
    if mod.endswith(JAC_FILE_EXTENSION) {
        mod = mod[: -len(JAC_FILE_EXTENSION)];
    }
    return mod;
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
    mod = _module_stem(entry_file);
    artifact = build_bun_service_artifact(mod, str(project_dir));
    env = dict(os.environ);
    env['PORT'] = str(api_port);
    env['JAC_PORT'] = str(api_port);
    console.print(
        f"\n🚀 Starting Bun sv service at http://127.0.0.1:{api_port}/",
        style="bold green"
    );
    subprocess.run([bun, str(artifact)], cwd=str(project_dir), env=env, check=True);
}
