import os;
import subprocess;
import from pathlib { Path }
import from jaclang.bun_service_builder { build_bun_service_artifact }
import from jaclang.client { get_bun }


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
    }

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
    import from jaclang.scale.runtime.context.util {
        boot_health_timeout,
        wait_for_health
    }
    budget = health_timeout
        if health_timeout is not None
        else (boot_health_timeout() if scale_mode else 10.0);
    healthy = wait_for_health(
        base_url, lambda { proc.poll() is None; }, timeout=budget, progress=progress
    );
    if not healthy {
        exit_code = proc.poll();
        proc.terminate();
        if exit_code is None {
            detail = f'stopped making progress for {budget:.0f}s while starting up';
        } else {
            detail = f'exited with status {exit_code} before serving';
        }
        raise RuntimeError(
            f"Bun sv service '{module_name}' {detail}; expected it at {base_url}."
                + f' See {log_path} for its output'
        );
    }
    return SpawnedBunService(base_url=base_url, proc=proc);
}
