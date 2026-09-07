import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.config_schema { report_schema_findings }
import from jaclang.scale.config.validation {
    STRICT_ENV,
    known_deploy_targets,
    validate_scale_config
}
import from jaclang.comptime { fields }
import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.config_loader {
    JacScaleConfig,
    get_scale_config,
    reset_scale_config
}

def _collect_default_mismatches(
    options: dict[str, any], defaults: dict[str, any], path: str, bad: list[str]
) {
    for (key, dval) in defaults.items() {
        spec = options.get(key);
        if not isinstance(spec, dict) {
            continue;
        }
        if isinstance(dval, dict) {
            nested = spec.get("nested");
            if isinstance(nested, dict) {
                _collect_default_mismatches(nested, dval, f"{path}.{key}", bad);
            }
            continue;
        }
        if "default" in spec and spec.get("default") != dval {
            bad.append(
                f"{path}.{key}: schema={spec.get('default')!r} runtime={dval!r}"
            );
        }
    }
}

test "an unknown key is reported once, at its path, with a suggestion" {
    # (config, text the single finding must carry)
    cases = [
        ({"gatway": {"colocate": True}}, ["gatway", "did you mean 'gateway'"]),
        (
            {"kubernetes": {"cpu_limits": "1000m"}},
            ["scale.kubernetes", "did you mean 'cpu_limit'"]
        ),
        (
            {"gateway": {"gateway_prot": 8001}},
            ["scale.gateway", "did you mean 'gateway_port'"]
        ),
        (
            {"deploy": {"target": "kuberntes"}},
            ["kuberntes", "did you mean 'kubernetes'"]
        ),
        ({"microservices": {"routes": {}}}, ["microservices"]),
        ({"sso": "not-a-table", "bogus": 1}, ["bogus"])
    ];
    for row in cases {
        (cfg, fragments) = row;
        msgs = validate_scale_config(cfg);
        assert len(msgs) == 1 , f"{cfg!r}: expected 1 finding, got {msgs}";
        for fragment in fragments {
            assert fragment in msgs[0] , f"{cfg!r}: {msgs[0]}";
        }
    }
}

test "declared, open-dict, and platform-injected keys produce no findings" {
    for cfg in [
        {},
        None,
        {
            "sso": {"host": "http://localhost:8000"},
            "server": {"structured_logs": False},
            "kubernetes": {"namespace": "prod", "cpu_limit": "1000m"},
            "fat_bundle": True,
            "seal_timeout": 120
        },
        {
            "secrets": {"MY_API_KEY": "${MY_API_KEY}"},
            "kubernetes": {"labels": {"team": "core"}},
            "gateway": {
                "env": {"LOG_LEVEL": "DEBUG"},
                "deployment_overlay": {"spec": {"replicas": 2}},
                "hpa": {"behavior": {"scaleDown": {"stabilizationWindowSeconds": 600}}}
            }
        },
        {
            "storage": {"backend": "postgres", "type": "sv"},
            "deploy": {"target": "kubernetes"},
            "tracing": {"enabled": True},
            "scheduler": {"enabled": True}
        },
        {
            "gateway": {
                "colocate": False,
                "boot_health_timeout": 60.0,
                "boot_max_wait": 120,
                "health_monitor_interval": 10.0,
                "route_refresh_seconds": 5.0
            }
        }
    ] {
        msgs = validate_scale_config(cfg);
        assert msgs == [] , f"{cfg!r}: expected no findings, got {msgs}";
    }
}

test "every default config key is declared in the schema" {
    defaults = JacScaleConfig().get_default_config();
    msgs = validate_scale_config(defaults);
    assert msgs == [] , f"defaults drifted from schema: {msgs}";
}

test "schema defaults agree with runtime defaults" {
    bad: list[str] = [];
    _collect_default_mismatches(
        JacScalePluginConfig.get_config_schema().get("options", {}),
        JacScaleConfig().get_default_config(),
        "scale",
        bad
    );
    assert bad == [] , f"schema/defaults disagree: {bad}";
}

# get_default_config no longer restates the [scale.kubernetes] block, because
# KubernetesConfig's own has-declaration is the single source of those
# defaults. The test above therefore no longer reaches that section; these two
# hold the same contract against the declaration instead. _LOADER_DERIVED are
# the fields get_kubernetes_config assigns after loading, from
# [scale.monitoring], [scale.admin] and the system plugin deps: declaring them
# under [scale.kubernetes] would validate a value that is then overwritten.
# app_name is exempt from the default comparison alone: the schema's None means
# "derive a slug from [project].name", the declaration's 'jaseci' is the
# fallback when no project name is usable.
glob _LOADER_DERIVED: set[str] = {
         "admin_username",
         "monitoring_enabled",
         "k8s_metrics_enabled",
         "prometheus_admin_password",
         "service_dependencies"
     },
     _DERIVED_DEFAULT: set[str] = {"app_name"};


def _k8s_schema_options -> dict[str, any] {
    return JacScalePluginConfig.get_config_schema()["options"]["kubernetes"]["nested"];
}


test "every [scale.kubernetes] field the loader reads is declared in the schema" {
    opts = _k8s_schema_options();
    undeclared: list[str] = [];
    for f in fields(KubernetesConfig) {
        if f.name in _LOADER_DERIVED {
            continue;
        }
        if f.name not in opts {
            undeclared.append(f.name);
        }
    }
    assert sorted(undeclared) == [] , (
        f"KubernetesConfig declares {sorted(undeclared)}, which [scale.kubernetes] "
        "never names, so a user setting one is warned it is unknown while the "
        "loader uses it"
    );
}


test "the [scale.kubernetes] schema agrees with the declaration it documents" {
    opts = _k8s_schema_options();
    declared = KubernetesConfig();
    drift: list[str] = [];
    for f in fields(KubernetesConfig) {
        if f.name in _LOADER_DERIVED or f.name in _DERIVED_DEFAULT {
            continue;
        }
        spec = opts.get(f.name);
        if not isinstance(spec, dict) {
            continue;
        }
        if spec.get("default") != getattr(declared, f.name) {
            drift.append(
                f"{f.name}: schema={spec.get('default')!r} "
                f"declaration={getattr(declared, f.name)!r}"
            );
        }
    }
    disagreed = sorted(drift);
    assert disagreed == [] , (
        f"the schema documents a default the declaration does not apply: {disagreed}"
    );
}


test "strict mode raises on findings only while its env name is set and non-empty" {
    import from jaclang.project.config_schema { schema_strict_enabled }
    findings = validate_scale_config({"gatway": {}});
    os.environ.pop(STRICT_ENV, None);
    report_schema_findings(findings, "scale", STRICT_ENV);
    os.environ[STRICT_ENV] = "1";
    try {
        raised = "";
        try {
            report_schema_findings(findings, "scale", STRICT_ENV);
        } except ValueError as e {
            raised = str(e);
        }
        assert "gatway" in raised , f"strict mode did not raise on an unknown key: {raised!r}";
        report_schema_findings(
            validate_scale_config({"server": {"structured_logs": False}}),
            "scale",
            STRICT_ENV
        );
        assert not schema_strict_enabled("");
        report_schema_findings(["some finding"], "byllm", "");
    } finally {
        os.environ.pop(STRICT_ENV, None);
    }
}

test "the shared loader validates the on-disk jac.toml" {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(
        "[project]\nname = \"demo\"\n\n[scale.gatway]\ncolocate = true\n"
    );
    os.environ[STRICT_ENV] = "1";
    reset_scale_config();
    try {
        raised = False;
        try {
            get_scale_config(Path(d)).load();
        } except ValueError as e {
            raised = True;
            assert "gatway" in str(e) , str(e);
        }
        assert raised , "expected strict validation to fire from PluginConfigBase.load";
    } finally {
        os.environ.pop(STRICT_ENV, None);
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "a clean on-disk jac.toml loads without complaint under strict mode" {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(
        "[project]\nname = \"demo\"\n\n[scale.server]\nstructured_logs = false\n"
    );
    os.environ[STRICT_ENV] = "1";
    reset_scale_config();
    try {
        cfg = get_scale_config(Path(d)).load();
        assert cfg["server"]["structured_logs"] is False , cfg["server"];
    } finally {
        os.environ.pop(STRICT_ENV, None);
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}

# A leftover [scale.microservices] table must stop every command at config
# parse, not degrade into an "unknown key" warning and a single-pod deploy.
# This guards what test_ms_config_failloud guarded before the table dissolved.
test "a leftover [scale.microservices] table is a hard config error" {
    import from jaclang.project.config { JacConfig }
    for toml in [
        "[project]\nname = \"demo\"\n\n[scale.microservices]\nenabled = true\n",
        "[project]\nname = \"demo\"\n\n[scale.microservices.routes]\nadmin = \"\"\n",
        "[project]\nname = \"demo\"\n\n[scale.microservices.logs]\nenabled = true\n",
        "[project]\nname = \"demo\"\n\n[scale.microservices.services.billing]\n"
        "replicas = 2\n"
    ] {
        caught = "";
        try {
            JacConfig.from_toml_str(toml);
        } except ValueError as e {
            caught = str(e);
        }
        assert caught , f"expected a ValueError for:\n{toml}";
        assert "[scale.microservices]" in caught , caught;
        assert "[apps.<name>]" in caught , caught;
        assert "[scale.gateway]" in caught , caught;
        assert "breaking-changes" in caught , caught;
    }
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(
        "[project]\nname = \"demo\"\nentry-point = \"main.jac\"\n\n"
        "[scale.microservices.routes]\nadmin = \"\"\n"
    );
    (Path(d) / "main.jac").write_text("with entry {}\n");
    reset_scale_config();
    try {
        raised = "";
        try {
            get_scale_config(Path(d)).load();
        } except ValueError as e {
            raised = str(e);
        }
        assert "[scale.microservices]" in raised , (
            f"the scale loader must refuse the on-disk table: {raised!r}"
        );
        clean = JacConfig.from_toml_str(
            "[project]\nname = \"demo\"\n\n[scale.gateway]\ncolocate = false\n"
        );
        assert clean.plugins["scale"]["gateway"]["colocate"] is False;
    } finally {
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "plugins without a declared schema opt out of validation" {
    cfg = JacScaleConfig();
    assert cfg.get_config_strict_env() == STRICT_ENV;
    schema = cfg.get_config_schema();
    assert schema.get("section") == "scale" , schema.get("section");
    assert "gateway" in schema.get("options", {}) , "schema options missing";
}

test "shipped jac.toml files validate clean" {
    import tomllib;
    repo = Path(__file__).parents[5];
    checked = 0;
    for p in sorted(repo.rglob("jac*.toml")) {
        sp = str(p);
        if ".jac/cache" in sp or "node_modules" in sp {
            continue;
        }
        try {
            data = tomllib.loads(p.read_text());
        } except Exception {
            continue;
        }
        scale = data.get("scale");
        if not isinstance(scale, dict) or not scale {
            continue;
        }
        checked += 1;
        assert validate_scale_config(scale) == [] , (
            f"{p} does not validate: {validate_scale_config(scale)}"
        );
    }
    assert checked > 0 , f"sweep found no [scale] tables under {repo}";
}

test "a deploy target owns its config section exactly when the factory can build it" {
    import from jaclang.scale.deploy.target.factory {
        BUILTIN_TARGET_TYPES,
        DeploymentTargetFactory
    }
    for name in BUILTIN_TARGET_TYPES {
        assert name in known_deploy_targets() , name;
    }
    for name in known_deploy_targets() {
        msgs = validate_scale_config(
            {"deploy": {"target": name}, name: {"namespace": "prod"}}
        );
        assert msgs == [] , f"target '{name}' section flagged: {msgs}";
    }
    assert "fly" not in known_deploy_targets();
    before = validate_scale_config({"fly": {"app_name": "demo"}});
    assert len(before) == 1 , f"expected 1 finding, got {before}";

    def _factory(config: dict, logger: any = None) -> any {
        return None;
    }
    DeploymentTargetFactory.register("fly", _factory);
    try {
        assert "fly" in known_deploy_targets();
        after = validate_scale_config({"fly": {"app_name": "demo"}});
        assert after == [] , f"registered target section flagged: {after}";
    } finally {
        DeploymentTargetFactory._registry.pop("fly", None);
    }
}

test "normalizer passes documented boot keys through" {
    import from jaclang.scale.config.config_loader { normalize_gateway_config }
    normalized = normalize_gateway_config({"boot_max_wait": 120, "colocate": False});
    assert normalized.get("boot_max_wait") == 120 , normalized;
    assert normalized["colocate"] is False , normalized;
    assert "boot_health_timeout" not in normalized , normalized;
}
