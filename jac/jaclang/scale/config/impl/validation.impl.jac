import from jaclang.project.config_schema {
    report_schema_findings,
    validate_against_schema
}
import from jaclang.scale.config.plugin_config {
    JacScalePluginConfig,
    app_scale_schema
}
import from jaclang.scale.deploy.target.registry { DeploymentTargetRegistry }
import math;

impl known_deploy_targets -> list[str] {
    return DeploymentTargetRegistry.known_targets();
}

impl scale_schema_options -> dict[str, any] {
    schema = JacScalePluginConfig.get_config_schema();
    declared = schema.get("options", {});
    options: dict[str, any] = dict(declared) if isinstance(declared, dict) else {};
    for name in known_deploy_targets() {
        if name not in options {
            options[name] = {
                "type": "dict",
                "default": {},
                "description": f"Deployment settings for the '{name}' target"
            };
        }
    }
    return options;
}

impl validate_scale_config(raw: dict[str, any] | None) -> list[str] {
    findings = validate_against_schema(raw, scale_schema_options(), "scale");
    if isinstance(raw, dict) {
        findings.extend(_declared_target_findings(raw));
        findings.extend(_scheduler_bound_findings(raw));
    }
    return findings;
}

impl validate_app_scale_config(raw: dict[str, any] | None, app_name: str) -> list[str] {
    return validate_against_schema(raw, app_scale_schema(), f"apps.{app_name}.scale");
}

impl _as_number(raw: any) -> float | None {
    if isinstance(raw, bool) or not isinstance(raw, (int, float, str)) {
        return None;
    }
    try {
        value = float(raw);
    } except Exception {
        return None;
    }
    return value if math.isfinite(value) else None;
}

impl scheduler_min_interval(raw: any) -> float | None {
    value = _as_number(raw);
    return value if value is not None and value > 0.0 else None;
}

impl scheduler_job_cap(raw: any) -> int | None {
    value = _as_number(raw);
    if value is None or value < 0.0 {
        return None;
    }
    wanted = int(value);
    return wanted if float(wanted) == value else None;
}

impl _scheduler_bound_findings(raw: dict[str, any]) -> list[str] {
    cfg = raw.get("scheduler");
    if not isinstance(cfg, dict) {
        return [];
    }
    out: list[str] = [];
    if "min_interval" in cfg
        and scheduler_min_interval(cfg.get("min_interval")) is None {
        out.append(
            f"jac.toml [scale.scheduler] min_interval {cfg.get('min_interval')!r}"
            " must be a finite number greater than 0; the 1.0 second default is"
            " used instead"
        );
    }
    if "max_jobs_per_user" in cfg
        and scheduler_job_cap(cfg.get("max_jobs_per_user")) is None {
        out.append(
            "jac.toml [scale.scheduler] max_jobs_per_user "
            f"{cfg.get('max_jobs_per_user')!r} must be a whole number 0 or more,"
            " where 0 means unlimited; the default of 25 is used instead"
        );
    }
    return out;
}

impl _declared_target_findings(raw: dict[str, any]) -> list[str] {
    deploy_cfg = raw.get("deploy");
    if not isinstance(deploy_cfg, dict) {
        return [];
    }
    target = deploy_cfg.get("target");
    if not isinstance(target, str) or not target {
        return [];
    }
    known = known_deploy_targets();
    if target in known {
        return [];
    }
    import from difflib { get_close_matches }
    matches = get_close_matches(target, known, n=1, cutoff=0.6);
    hint = f"; did you mean '{matches[0]}'?"
        if matches
        else f". Known targets: {', '.join(known)}.";
    return [
        f"jac.toml [scale.deploy] target '{target}' is not a known deployment "
        f"target{hint}"
    ];
}
