import os;
import from pathlib { Path }
import from jaclang.jac0core.host { HOST_BUN, HOST_CPYTHON }

glob _DEFAULT_SV_HOST: str = HOST_CPYTHON;


def sv_host_env_key(module_name: str) -> str {
    return f"JAC_SV_{module_name.upper()}_HOST";
}


def resolve_sv_service_host(module_name: str, base_path: str = '.') -> str {
    env_host = os.environ.get(sv_host_env_key(module_name), '').strip().lower();
    if env_host {
        return env_host;
    }
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        svc_cfg = ms_cfg.get('services', {}).get(module_name, {});
        if isinstance(svc_cfg, dict) {
            configured = str(svc_cfg.get('host', '') or '').strip().lower();
            if configured {
                return configured;
            }
        }
    } except Exception {
        ;
    }
    artifact = bun_service_artifact_path(module_name, base_path);
    if artifact.exists() {
        return HOST_BUN;
    }
    return _DEFAULT_SV_HOST;
}


def bun_service_artifact_path(module_name: str, base_path: str = '.') -> Path {
    return Path(base_path) / '.jac' / 'server' / f"{module_name}.mjs";
}


def is_bun_sv_service(module_name: str, base_path: str = '.') -> bool {
    return resolve_sv_service_host(module_name, base_path) == HOST_BUN;
}
