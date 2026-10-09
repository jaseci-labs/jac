import os;
import from pathlib { Path }
import from jaclang.server.sv_client { sv_host_env_key }
import from jaclang.jac0core.host {
    HOST_BUN,
    HOST_CPYTHON,
    SV_SERVICE_HOST_KINDS,
    resolve_registry_name
}

glob _DEFAULT_SV_HOST: str = HOST_CPYTHON,
     _BUN_ARTIFACT_EXCLUDED_DIRS: tuple = (
         '.jac',
         '.git',
         'node_modules',
         '__pycache__'
     );


def _resolve_sv_host_override(raw: str) -> (str | None) {
    if not raw.strip() {
        return None;
    }
    key = resolve_registry_name(raw, SV_SERVICE_HOST_KINDS);
    if key is not None {
        return key;
    }
    try {
        import from jaclang.client.targets.registry { get_host_factory }
        names = get_host_factory().get_available_host_names();
        alt = resolve_registry_name(raw, names);
        if alt is not None {
            return alt;
        }
        valid = ', '.join(sorted(set(list(SV_SERVICE_HOST_KINDS) + list(names))));
        raise ValueError(f"Unknown sv host '{raw}'; valid hosts: {valid}");
    } except ImportError {
        ;
    }
    return None;
}


def resolve_sv_service_host(module_name: str, base_path: str = '.') -> str {
    env_raw = os.environ.get(sv_host_env_key(module_name), '');

    env_host = _resolve_sv_host_override(env_raw);
    if env_host is not None {
        return env_host;
    }
    if env_raw.strip() {
        raise ValueError(
            f"{sv_host_env_key(module_name)}='{env_raw}' is not a known sv host"
        );
    }
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        svc_cfg = get_scale_config().get_app_scale_config(module_name);
        if isinstance(svc_cfg, dict) {
            raw_cfg = str(svc_cfg.get('host', '') or '');
            configured = _resolve_sv_host_override(raw_cfg);
            if configured is not None {
                return configured;
            }
            if raw_cfg.strip() {
                raise ValueError(
                    f'[apps.{module_name}.scale] '
                        + f"host='{raw_cfg}' is not a known sv host"
                );
            }
        }
    } except (ImportError, AttributeError, KeyError, TypeError) {
        ;
    }
    return _sv_host_from_artifact(module_name, base_path);
}


def _sv_host_from_artifact(module_name: str, base_path: str) -> str {
    if bun_artifact_is_fresh(module_name, base_path) {
        return HOST_BUN;
    }
    return _DEFAULT_SV_HOST;
}


def bun_service_artifact_path(module_name: str, base_path: str = '.') -> Path {
    return Path(base_path) / '.jac' / 'server' / f"{module_name}.mjs";
}


def bun_artifact_stamp_path(module_name: str, base_path: str = '.') -> Path {
    return Path(base_path) / '.jac' / 'server' / f"{module_name}.mjs.stamp";
}


def bun_service_input_paths(base_path: str) -> list[Path] {
    base = Path(base_path);
    paths: list[Path] = [];
    toml = base / 'jac.toml';
    if toml.is_file() {
        paths.append(toml);
    }
    if not base.is_dir() {
        return paths;
    }
    for p in sorted(base.rglob('*.jac')) {
        rel = p.relative_to(base);
        if rel.parts and rel.parts[0] in _BUN_ARTIFACT_EXCLUDED_DIRS {
            continue;
        }
        paths.append(p);
    }
    return paths;
}


def bun_service_inputs_digest(module_name: str, base_path: str = '.') -> str {
    import hashlib;
    h = hashlib.sha256();
    entry_path = Path(base_path) / f"{module_name}.jac";
    h.update(str(entry_path).encode('utf-8'));
    h.update(b'\x00');
    for p in bun_service_input_paths(base_path) {
        h.update(str(p).encode('utf-8'));
        h.update(b'\x00');
        try {
            h.update(p.read_bytes());
        } except OSError {
            h.update(b'<unreadable>');
        }
        h.update(b'\x00');
    }
    return h.hexdigest();
}


def bun_artifact_is_fresh(module_name: str, base_path: str = '.') -> bool {
    artifact = bun_service_artifact_path(module_name, base_path);
    stamp = bun_artifact_stamp_path(module_name, base_path);
    if not artifact.is_file() or not stamp.is_file() {
        return False;
    }
    try {
        recorded = stamp.read_text(encoding='utf-8').strip();
    } except OSError {
        return False;
    }
    if not recorded {
        return False;
    }
    return recorded == bun_service_inputs_digest(module_name, base_path);
}


def is_bun_sv_service(module_name: str, base_path: str = '.') -> bool {
    return resolve_sv_service_host(module_name, base_path) == HOST_BUN;
}
