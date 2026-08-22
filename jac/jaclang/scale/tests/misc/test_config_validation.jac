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
import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
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

test "unknown section is flagged with a suggestion" {
    msgs = validate_scale_config({"microservice": {"routes": {}}});
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "microservice" in msgs[0] , msgs[0];
    assert "did you mean 'microservices'" in msgs[0] , msgs[0];
}

test "unknown nested key is flagged with a suggestion" {
    msgs = validate_scale_config({"kubernetes": {"cpu_limits": "1000m"}});
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "scale.kubernetes" in msgs[0] , msgs[0];
    assert "did you mean 'cpu_limit'" in msgs[0] , msgs[0];
}

test "per-service unknown key is flagged" {
    msgs = validate_scale_config(
        {"microservices": {"services": {"myapp": {"cpu_limits": "2000m"}}}}
    );
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "scale.microservices.services.myapp" in msgs[0] , msgs[0];
    assert "did you mean 'cpu_limit'" in msgs[0] , msgs[0];
}

test "open dict sections accept arbitrary keys" {
    cfg = {
        "secrets": {"MY_API_KEY": "${MY_API_KEY}"},
        "kubernetes": {"labels": {"team": "core"}},
        "microservices": {
            "routes": {"billing": "/billing"},
            "services": {
                "billing": {
                    "env": {"LOG_LEVEL": "DEBUG"},
                    "deployment_overlay": {"spec": {"replicas": 2}},
                    "hpa": {
                        "behavior": {"scaleDown": {"stabilizationWindowSeconds": 600}}
                    }
                }
            }
        }
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";
}

test "valid config produces no findings" {
    cfg = {
        "jwt": {"secret": "s", "algorithm": "HS256", "exp_delta_days": 7},
        "server": {"port": 8080, "docs_enabled": False},
        "kubernetes": {"namespace": "prod", "cpu_limit": "1000m"},
        "fat_bundle": True,
        "seal_timeout": 120
    };
    assert validate_scale_config(cfg) == [];
}

test "non-dict section values do not crash the validator" {
    msgs = validate_scale_config({"jwt": "not-a-table", "bogus": 1});
    assert len(msgs) == 1 , f"expected only the bogus finding, got {msgs}";
    assert "bogus" in msgs[0] , msgs[0];
}

test "empty or missing config is fine" {
    assert validate_scale_config({}) == [];
    assert validate_scale_config(None) == [];
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

test "reporting does not raise outside strict mode" {
    os.environ.pop(STRICT_ENV, None);
    report_schema_findings(
        validate_scale_config({"microservice": {}}), "scale", STRICT_ENV
    );
}

test "strict env raises on unknown keys" {
    os.environ[STRICT_ENV] = "1";
    try {
        raised = False;
        try {
            report_schema_findings(
                validate_scale_config({"microservice": {}}), "scale", STRICT_ENV
            );
        } except ValueError as e {
            raised = True;
            assert "microservice" in str(e) , str(e);
        }
        assert raised , "expected ValueError in strict mode";
    } finally {
        os.environ.pop(STRICT_ENV, None);
    }
}

test "strict env ignores a clean config" {
    os.environ[STRICT_ENV] = "1";
    try {
        report_schema_findings(
            validate_scale_config({"server": {"port": 9000}}), "scale", STRICT_ENV
        );
    } finally {
        os.environ.pop(STRICT_ENV, None);
    }
}

test "an empty strict-env name never escalates" {
    import from jaclang.project.config_schema { schema_strict_enabled }
    os.environ[STRICT_ENV] = "1";
    try {
        assert not schema_strict_enabled("");
        report_schema_findings(["some finding"], "byllm", "");
    } finally {
        os.environ.pop(STRICT_ENV, None);
    }
}

test "the shared loader validates the on-disk jac.toml" {
    d = tempfile.mkdtemp();
    (Path(d) / "jac.toml").write_text(
        "[project]\nname = \"demo\"\n\n[scale.microservice]\nroutes = {}\n"
    );
    os.environ[STRICT_ENV] = "1";
    reset_scale_config();
    try {
        raised = False;
        try {
            get_scale_config(Path(d)).load();
        } except ValueError as e {
            raised = True;
            assert "microservice" in str(e) , str(e);
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
        "[project]\nname = \"demo\"\n\n[scale.server]\nport = 9100\n"
    );
    os.environ[STRICT_ENV] = "1";
    reset_scale_config();
    try {
        cfg = get_scale_config(Path(d)).load();
        assert cfg["server"]["port"] == 9100 , cfg["server"];
    } finally {
        os.environ.pop(STRICT_ENV, None);
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "plugins without a declared schema opt out of validation" {
    cfg = JacScaleConfig();
    assert cfg.get_config_strict_env() == STRICT_ENV;
    schema = cfg.get_config_schema();
    assert schema.get("section") == "scale" , schema.get("section");
    assert "microservices" in schema.get("options", {}) , "schema options missing";
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

test "platform-injected and capability-intent keys are recognized" {
    cfg = {
        "storage": {"backend": "postgres", "type": "sv"},
        "deploy": {"target": "kubernetes"},
        "tracing": {"enabled": True},
        "scheduler": {"enabled": True}
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";
}

test "documented microservices boot and client keys are recognized" {
    cfg = {
        "microservices": {
            "boot_health_timeout": 60.0,
            "boot_max_wait": 120,
            "health_monitor_interval": 10.0,
            "client": {
                "entry": "client/main.jac",
                "static_mounts": [{"url_prefix": "/assets", "local_path": "public"}]
            }
        }
    };
    msgs = validate_scale_config(cfg);
    assert msgs == [] , f"expected no findings, got {msgs}";
}

test "every known deploy target owns a config section" {
    for name in known_deploy_targets() {
        msgs = validate_scale_config(
            {"deploy": {"target": name}, name: {"namespace": "prod"}}
        );
        assert msgs == [] , f"target '{name}' section flagged: {msgs}";
    }
}

test "a registered plugin target owns its section" {
    import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
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

test "a misspelled deploy target is reported instead of silencing its section" {
    msgs = validate_scale_config({"deploy": {"target": "kuberntes"}});
    assert len(msgs) == 1 , f"expected 1 finding, got {msgs}";
    assert "kuberntes" in msgs[0] , msgs[0];
    assert "did you mean 'kubernetes'" in msgs[0] , msgs[0];
}

test "known targets are exactly the ones the factory can build" {
    import from jaclang.scale.deploy.target.factory { BUILTIN_TARGET_TYPES }
    for name in BUILTIN_TARGET_TYPES {
        assert name in known_deploy_targets() , name;
    }
}

test "normalizer passes documented boot and static-mount keys through" {
    import from jaclang.scale.config.config_loader { normalize_microservices_config }
    normalized = normalize_microservices_config(
        {
            "boot_max_wait": 120,
            "client": {
                "entry": "client/main.jac",
                "static_mounts": [{"url_prefix": "/assets", "local_path": "public"}]
            }
        },
        env_routes_fallback=False
    );
    assert normalized.get("boot_max_wait") == 120 , normalized;
    assert "boot_health_timeout" not in normalized , normalized;
    mounts = normalized["client"]["static_mounts"];
    assert mounts == [{"url_prefix": "/assets", "local_path": "public"}] , mounts;
}


def _collect_schema_keys(schema: dict, out: set) -> None {
    if not isinstance(schema, dict) {
        return;
    }
    for (key, value) in schema.items() {
        if isinstance(value, dict) {
            out.add(str(key));
            _collect_schema_keys(value.get("nested", {}), out);
        }
    }
}


# The blocker this guards: a KubernetesConfig field that from_dict reads but
# the schema never declares. _walk_schema then warns "unknown key ... defaults
# apply instead" on every command, and hard-fails under
# JAC_SCALE_CONFIG_STRICT, for a key the loader does read. Walking the DEFAULT
# config dict cannot catch it, because the default dict is not what
# from_config consumes.
test "every [scale.kubernetes] key the constructor reads is declared in the schema" {
    import re;
    import from pathlib { Path }
    source = (
        Path(__file__).parents[2]
        / "deploy"
        / "target"
        / "kubernetes"
        / "kubernetes_config.jac"
    ).read_text();
    # Split on the constructor's real name. Splitting on a name the file does
    # not contain returns the WHOLE source, so the scrape silently widens to
    # every config.get in the module and the guard below can never fire.
    marker = "from_dict";
    assert marker in source , (
        f"'{marker}' is gone from kubernetes_config.jac, so this test is "
        "scraping the whole file instead of the constructor; update it"
    );
    body = source.split(marker, 1)[-1];
    consumed = set(re.findall(r"config\.get\(\s*'([a-z_]+)'", body));
    assert consumed , "could not read the constructor's keys; update this test";

    # Any section: a few keys the kubernetes block reads are owned by another
    # section and merged in, so "declared somewhere" is the honest bar. What
    # must never happen is a key the loader reads that the schema never names.
    declared: set = set();
    _collect_schema_keys(
        JacScalePluginConfig.get_config_schema().get("options", {}), declared
    );

    # Keys get_kubernetes_config assigns unconditionally after loading, from
    # [scale.monitoring] and from the system plugin deps. Declaring them under
    # [scale.kubernetes] would validate a value that is then thrown away, which
    # is the same lie this test exists to catch, pointing the other way.
    derived: set = {"monitoring_enabled", "service_dependencies"};

    missing = sorted(consumed - declared - derived);
    assert missing == [] , (
        f"the constructor reads {missing} but [scale.kubernetes] does not declare "
        "them, so a user setting one gets an 'unknown key' warning and the "
        "value is reported as ignored while the loader actually uses it"
    );
}
