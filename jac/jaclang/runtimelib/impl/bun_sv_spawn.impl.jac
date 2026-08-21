import os;
import subprocess;
import from pathlib { Path }
import from jaclang.runtimelib.bun_service_builder { build_bun_service_artifact }
import from jaclang.runtimelib.client { get_bun }
import from jaclang.runtimelib.bun_sv_spawn { SpawnedBunService }


impl spawn_bun_sv_service(
    module_name: str,
    base_path: str,
    port: int,
    *,
    scale_mode: bool = False,
    health_timeout: (float | None) = None,
    progress: any = None
) -> SpawnedBunService {
    bun = get_bun();
    if not bun {
        raise RuntimeError(
            "Bundled bun runtime is required for Bun-hosted sv services"
        );
    }
    artifact = build_bun_service_artifact(module_name, base_path);
    base_url = f"http://127.0.0.1:{port}";
    child_env = dict(os.environ);
    child_env['PORT'] = str(port);
    child_env['JAC_PORT'] = str(port);
    if scale_mode {
        child_env['JAC_SV_SIBLING'] = '1';
        log_dir = Path(base_path) / '.jac' / 'logs';
        log_dir.mkdir(parents=True, exist_ok=True);
        log_path = log_dir / f"{module_name}.log";
        log_file = open(log_path, 'ab');
        try {
            proc = subprocess.Popen(
                [bun, str(artifact)],
                stdout=log_file,
                stderr=subprocess.STDOUT,
                env=child_env,
                cwd=base_path
            );
        } finally {
            log_file.close();
        }
    } else {
        proc = subprocess.Popen(
            [bun, str(artifact)],
            cwd=base_path,
            env=child_env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        );
    }
    import from jaclang.scale.runtime.context.util {
        boot_health_timeout,
        wait_for_health
    }
    budget = health_timeout if health_timeout is not None else (
        boot_health_timeout() if scale_mode else 10.0
    );
    healthy = wait_for_health(
        base_url, lambda { proc.poll() is None; }, timeout=budget, progress=progress
    );
    if not healthy {
        proc.terminate();
        raise RuntimeError(
            f"Bun sv service '{module_name}' did not become healthy at {base_url}"
        );
    }
    return SpawnedBunService(base_url=base_url, proc=proc);
}
