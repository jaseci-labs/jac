impl k8s_safe_slug(name: str, fallback: str = 'jaseci') -> str {
    import re;
    lowered = (name or '').strip().lower();
    slug = re.sub(r'[^a-z0-9-]+', '-', lowered);
    slug = re.sub(r'-+', '-', slug).strip('-');
    slug = slug[:63].strip('-');
    return slug or fallback;
}

impl normalize_database_mode(raw: any) -> str {
    mode = str(raw or '').strip().lower() or 'auto';
    if mode not in DATABASE_MODES {
        raise ValueError(
            "[scale.kubernetes] database_mode must be one of "
            f"{', '.join(DATABASE_MODES)}, got {raw!r}."
        );
    }
    return mode;
}

impl resolve_database_mode(config: dict[str, any]) -> str {
    mode = normalize_database_mode(config.get('database_mode'));
    if mode == 'auto' and config.get('postgres_enabled') is False {
        return 'none';
    }
    return mode;
}

impl KubernetesConfig.postinit {
    self.database_mode = normalize_database_mode(self.database_mode);
}

impl KubernetesConfig.database_enabled -> bool {
    return self.database_mode != 'none';
}

impl KubernetesConfig.database_deploy_intent(app_name: str) -> dict[str, any] {
    return {
        'app_name': app_name,
        'namespace': self.namespace,
        'database_mode': self.database_mode,
        'database_url': self.database_url,
        'database_namespace': self.database_namespace
    };
}

impl KubernetesConfig.to_dict -> dict[str, any] {
    out: dict[str, any] = {};
    comptime for f in fields(KubernetesConfig) {
        out[f.name] = get_field(self, f.name);
    }
    return out;
}

impl KubernetesConfig.from_dict(cls: type, config: dict[str, any]) -> KubernetesConfig {
    """A key absent from config is not passed, so the has-declaration above
        is the only place a default for it exists. The three assignments after
        the loop are the only fields whose value is not the config's verbatim.""";
    kw: dict[str, any] = {};
    comptime for f in fields(KubernetesConfig) {
        if f.name in config {
            kw[f.name] = config[f.name];
        }
    }
    kw['database_mode'] = resolve_database_mode(config);
    kw['database_url'] = str(config.get('database_url') or '');
    kw['database_namespace'] = str(config.get('database_namespace') or '');
    return cls(**kw);
}
