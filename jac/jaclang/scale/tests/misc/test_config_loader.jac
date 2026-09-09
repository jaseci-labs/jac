import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.comptime { fields }
import from jaclang.scale.config.config_loader {
    JacScaleConfig,
    get_scale_config,
    reset_scale_config
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "get_gateway_config returns ingress block" {
    cfg = JacScaleConfig();
    cfg._config = {
        "gateway": {
            "ingress": {
                "enabled": True,
                "host": "jac-shop.local",
                "ingress_class_name": "nginx",
                "annotations": {"nginx.ingress.kubernetes.io/proxy-body-size": "10m"}
            }
        }
    };
    out = cfg.get_gateway_config();
    assert "ingress" in out;
    ing = out["ingress"];
    assert ing["enabled"] is True;
    assert ing["host"] == "jac-shop.local";
    assert ing["ingress_class_name"] == "nginx";
    assert ing["annotations"]["nginx.ingress.kubernetes.io/proxy-body-size"] == "10m";
}


test "get_gateway_config ingress defaults to {} when section absent" {
    cfg = JacScaleConfig();
    cfg._config = {"gateway": {"colocate": False}};
    out = cfg.get_gateway_config();
    assert out["ingress"] == {};
}


test "get_gateway_config preserves all sections (regression guard)" {
    cfg = JacScaleConfig();
    cfg._config = {
        "gateway": {
            "colocate": False,
            "gateway_port": 9000,
            "http_forward_timeout": 60,
            "replicas": 2,
            "ingress": {"enabled": False}
        }
    };
    out = cfg.get_gateway_config();
    expected_keys: set[str] = {
        "colocate",
        "gateway_port",
        "gateway_host",
        "http_forward_timeout",
        "replicas",
        "rate_limit",
        "cors",
        "identity",
        "ingress",
        "logs",
        "tracing",
        "shared_volumes"
    };
    missing = expected_keys - set(out.keys());
    assert not missing , f"missing keys: {missing}";
    assert out["gateway_port"] == 9000;
    assert out["replicas"] == 2;
}


test "get_gateway_config logs block defaults to {} when absent" {
    cfg = JacScaleConfig();
    cfg._config = {"gateway": {}};
    out = cfg.get_gateway_config();
    assert out["logs"] == {};
}


test "get_gateway_config logs block round-trips enabled flag" {
    cfg = JacScaleConfig();
    cfg._config = {"gateway": {"logs": {"enabled": True}}};
    out = cfg.get_gateway_config();
    assert out["logs"] == {"enabled": True};
}


test "get_gateway_config colocates by default" {
    cfg = JacScaleConfig();
    cfg._config = {"gateway": {"gateway_port": 8000}};
    assert cfg.get_gateway_config()["colocate"] is True;
    cfg._config = {};
    assert cfg.get_gateway_config()["colocate"] is True;
}


test "get_gateway_config preserves an explicit colocate = false" {
    cfg = JacScaleConfig();
    cfg._config = {"gateway": {"colocate": False}};
    assert cfg.get_gateway_config()["colocate"] is False;
}


test "get_gateway_config never reads the fleet from the environment" {
    cfg = JacScaleConfig();
    cfg._config = {"gateway": {}};
    os.environ["JAC_SV_FLEET"] = '{"root": "web", "members": []}';
    try {
        out = cfg.get_gateway_config();
        assert "routes" not in out;
        assert "members" not in out;
    } finally {
        del os.environ["JAC_SV_FLEET"];
    }
}


test "every get_websocket_config key has a schema entry (#8000 1.2)" {
    # The websocket guide documented a backplane value that raised at boot and
    # none of the seven [scale.websocket] keys were schema-declared, so nothing
    # validated or surfaced them. Keep the runtime reader and the schema in
    # lockstep.
    import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
    schema = JacScalePluginConfig.get_config_schema();
    ws_schema = schema["options"].get("websocket");
    assert ws_schema is not None , "[scale.websocket] missing from plugin_config schema";
    declared = set(ws_schema["nested"].keys());
    cfg = JacScaleConfig();
    cfg._config = {"websocket": {}};
    read_keys = set(cfg.get_websocket_config().keys());
    assert read_keys == declared , f"schema/read drift: schema-only={declared
        - read_keys}, read-only={read_keys - declared}";
}


test "config sections read by config_loader are schema-declared (#8000 1.2)" {
    import from jaclang.scale.config.plugin_config { JacScalePluginConfig }
    schema_sections = set(JacScalePluginConfig.get_config_schema()["options"].keys());
    cfg = JacScaleConfig();
    cfg._config = {};
    for section in [
        "websocket",
        "database",
        "kubernetes",
        "events",
        "monitoring",
        "server"
    ] {
        assert section in schema_sections , f"[scale.{section}] is read by config_loader but has no schema entry";
    }
}


test "get_kubernetes_config leaves the cached config dict unmutated" {
    # load() returns the cached dict by reference; deriving kubernetes keys
    # must not write them back, or later readers of the raw config see
    # derived values as if the user had configured them.
    cfg = JacScaleConfig();
    cfg._config = {
        "kubernetes": {"namespace": "demo"},
        "monitoring": {"namespace": "demo_metrics"}
    };
    cfg.get_kubernetes_config();
    leaked = cfg._config["kubernetes"];
    assert leaked == {"namespace": "demo"} , f"derived keys leaked into the cached config: {leaked}";
}


test "repeated get_kubernetes_config calls return equal results" {
    # Pre-copy, every call stacked derived keys onto the cached dict, so the
    # result depended on how many times it had been called before.
    cfg = JacScaleConfig();
    cfg._config = {
        "kubernetes": {"namespace": "demo"},
        "monitoring": {"namespace": "demo_metrics"}
    };
    first = cfg.get_kubernetes_config();
    second = cfg.get_kubernetes_config();
    assert first == second;
}


test "get_scale_config raises on a different project_dir instead of silently reusing" {
    reset_scale_config();
    dir_a = tempfile.mkdtemp(prefix="jac-cfg-a-");
    dir_b = tempfile.mkdtemp(prefix="jac-cfg-b-");
    try {
        first = get_scale_config(project_dir=Path(dir_a));
        assert get_scale_config() is first;
        assert get_scale_config(project_dir=Path(dir_a)) is first;
        raised = False;
        try {
            get_scale_config(project_dir=Path(dir_b));
        } except RuntimeError {
            raised = True;
        }
        assert raised , "a second project_dir was silently ignored and the first project's config returned";
    } finally {
        reset_scale_config();
        shutil.rmtree(dir_a, ignore_errors=True);
        shutil.rmtree(dir_b, ignore_errors=True);
    }
}


"""Load a jac.toml with the given [scale] body; return the monitoring namespace and what was logged."""
def _load_monitoring_namespace(scale_body: str) -> tuple[str, str] {
    import io;
    import logging;
    reset_scale_config();
    stream = io.StringIO();
    handler = logging.StreamHandler(stream);
    root_logger = logging.getLogger();
    previous_level = root_logger.level;
    root_logger.addHandler(handler);
    root_logger.setLevel(logging.WARNING);
    project_dir = tempfile.mkdtemp(prefix="jac-cfg-ns-");
    try {
        (Path(project_dir) / "jac.toml").write_text(
            f'[project]\nname = "repro"\n\n{scale_body}'
        );
        namespace = get_scale_config(
            project_dir=Path(project_dir)
        ).get_monitoring_config()["namespace"];
    } finally {
        root_logger.removeHandler(handler);
        root_logger.setLevel(previous_level);
        reset_scale_config();
        shutil.rmtree(project_dir, ignore_errors=True);
    }
    return (namespace, stream.getvalue());
}


test "the monitoring namespace is sanitized on every path, and only a rewrite warns" {
    # (scale body, expected namespace, rewritten value the warning must name)
    cases = [
        ('[scale.monitoring]\nnamespace = "jac--shop"\n', "jac_shop", "jac--shop"),
        ('[scale.monitoring]\nnamespace = "myapp_prod"\n', "myapp_prod", ""),
        ('[scale.monitoring]\nnamespace = "---"\n', "jaclang_scale", "---"),
        ('[scale.monitoring]\nnamespace = 2024\n', "_2024", "2024"),
        (
            '[scale.kubernetes]\nnamespace = "jac-shop-prod"\n\n[scale.monitoring]\nnamespace = ""\n',
            "jac_shop_prod",
            ""
        )
    ];
    for row in cases {
        (body, expected, rewritten) = row;
        (namespace, logged) = _load_monitoring_namespace(body);
        assert namespace == expected , f"{body!r} -> {namespace!r}, expected {expected!r}";
        if not rewritten {
            assert logged == "" , f"a value that was not rewritten must not warn:\n{logged}";
            continue;
        }
        # Every project loads fresh, so each rewritten value must warn about itself.
        assert rewritten in logged and expected in logged and "dashboards" in logged , (
            f"no usable rewrite warning for {rewritten!r}:\n{logged}"
        );
    }
}


# KubernetesConfig's has-declaration is the only place a [scale.kubernetes]
# default lives, so these drive a real jac.toml through the real loader rather
# than asserting against a second copy of the defaults.

test "an unwritten [scale.kubernetes] key resolves to the declaration" {
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\nname = "decl-app"\nversion = "0.0.1"\n'
        );
        resolved = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        declared = KubernetesConfig();
        for name in [
            "min_replicas",
            "max_replicas",
            "cpu_utilization_target",
            "memory_utilization_target",
            "readiness_initial_delay",
            "liveness_failure_threshold",
            "container_port"
        ] {
            got = resolved[name];
            want = getattr(declared, name);
            assert got == want , f"{name} resolved to {got!r}, not the declared {want!r}";
        }
        assert resolved["app_name"] == "decl-app";
    }
}


test "every [scale.kubernetes] key a user writes reaches the resolved config" {
    # One sweep over every declared scalar field, so a key dropped between the
    # toml and the resolved config fails by name instead of waiting for someone
    # to notice their setting had no effect (#8401 was one such field).
    declared = KubernetesConfig();
    # Assigned by get_kubernetes_config after loading, from other sections, or
    # coerced on the way in; a written value is not what comes back.
    not_written: set[str] = {
        "database_mode",
        "database_url",
        "database_namespace",
        "admin_username",
        "monitoring_enabled",
        "k8s_metrics_enabled",
        "prometheus_admin_password",
        "service_dependencies"
    };
    written: dict[str, any] = {};
    lines: list[str] = [];
    for f in fields(KubernetesConfig) {
        if f.name in not_written {
            continue;
        }
        val = getattr(declared, f.name);
        new_val: any = None;
        if isinstance(val, bool) {
            new_val = not val;
            bool_txt = "true" if new_val else "false";
            lines.append(f.name + " = " + bool_txt);
        } elif isinstance(val, int) {
            new_val = val + 7;
            lines.append(f.name + " = " + str(new_val));
        } elif isinstance(val, str) {
            new_val = (val + "x") if val else "x";
            lines.append(f.name + ' = "' + new_val + '"');
        } else {
            continue;
        }
        written[f.name] = new_val;
    }
    assert len(written) > 30 , (
        f"only {len(written)} keys were probed; the sweep stopped covering the section"
    );
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\nname = "sweep-app"\nversion = "0.0.1"\n\n'
            '[scale.kubernetes]\n'
                + "\n".join(lines)
                + "\n"
        );
        resolved = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        dropped: list[str] = [];
        for (key, want) in written.items() {
            if resolved.get(key) != want {
                dropped.append(f"{key}: wrote {want!r}, got {resolved.get(key)!r}");
            }
        }
        missing = sorted(dropped);
        assert missing == [] , (
            f"a written [scale.kubernetes] key never reached the resolved config: {missing}"
        );
    }
}


test "a value from another section reaches the kubernetes config" {
    # admin_username is emitted by the loader from [scale.admin], not written
    # under [scale.kubernetes], so it exercises the hand-off the sweep skips.
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\nname = "admin-app"\nversion = "0.0.1"\n\n'
            '[scale.admin]\nusername = "metrics-admin"\n'
        );
        resolved = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        assert resolved["admin_username"] == "metrics-admin";
    }
}
