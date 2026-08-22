import from jaclang.project.config_schema {
    report_schema_findings,
    validate_against_schema
}
import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }

impl known_deploy_targets -> list[str] {
    return DeploymentTargetFactory.known_targets();
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
    }
    return findings;
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
