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


glob _GATEWAY_KEYS: set[str] = {
         "colocate",
         "gateway_port",
         "gateway_host",
         "http_forward_timeout",
         "rate_limit",
         "cors",
         "identity",
         "ingress",
         "logs",
         "tracing",
         "shared_volumes"
     };


test "get_gateway_config fills every section and never reads the fleet from the environment" {
    ingress = {
        "enabled": True,
        "host": "jac-shop.local",
        "ingress_class_name": "nginx",
        "annotations": {"nginx.ingress.kubernetes.io/proxy-body-size": "10m"}
    };
    # (raw config, values the normalized gateway block must carry)
    cases = [
        ({}, {"colocate": True, "ingress": {}, "logs": {}}),
        ({"gateway": {"gateway_port": 8000}}, {"colocate": True, "gateway_port": 8000}),
        ({"gateway": {"colocate": False}}, {"colocate": False, "ingress": {}}),
        ({"gateway": {"logs": {"enabled": True}}}, {"logs": {"enabled": True}}),
        ({"gateway": {"ingress": ingress}}, {"ingress": ingress}),
        (
            {
                "gateway": {
                    "colocate": False,
                    "gateway_port": 9000,
                    "http_forward_timeout": 60,
                    "replicas": 2,
                    "ingress": {"enabled": False}
                }
            },
            {"gateway_port": 9000, "replicas": 2, "ingress": {"enabled": False}}
        )
    ];
    os.environ["JAC_SV_FLEET"] = '{"root": "web", "members": []}';
    try {
        for row in cases {
            (raw, expected) = row;
            cfg = JacScaleConfig();
            cfg._config = raw;
            out = cfg.get_gateway_config();
            missing = _GATEWAY_KEYS - set(out.keys());
            assert not missing , f"{raw!r}: missing keys {missing}";
            for (key, want) in expected.items() {
                assert out[key] == want , f"{raw!r}: {key} = {out[key]!r}, expected {want!r}";
            }
            assert "routes" not in out and "members" not in out , (
                f"{raw!r}: the fleet leaked in from the environment"
            );
        }
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


test "get_kubernetes_config derives its keys without writing them back, so repeated calls agree" {
    # load() returns the cached dict by reference; deriving kubernetes keys
    # must not write them back, or later readers of the raw config see
    # derived values as if the user had configured them.
    cfg = JacScaleConfig();
    cfg._config = {
        "kubernetes": {"namespace": "demo"},
        "monitoring": {"namespace": "demo_metrics"}
    };
    first = cfg.get_kubernetes_config();
    assert cfg.get_kubernetes_config() == first;
    leaked = cfg._config["kubernetes"];
    assert leaked == {"namespace": "demo"} , f"derived keys leaked into the cached config: {leaked}";
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
# default lives, so this drives a real jac.toml through the real loader rather
# than asserting against a second copy of the defaults.

test "every [scale.kubernetes] key reaches the resolved config, written, declared, or derived" {
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
    # Left out of the toml, so they must resolve to the declaration itself;
    # app_name is left out so it derives from [project].name instead.
    unwritten: set[str] = {
        "app_name",
        "min_replicas",
        "max_replicas",
        "cpu_utilization_target",
        "memory_utilization_target",
        "readiness_initial_delay",
        "liveness_failure_threshold",
        "container_port"
    };
    written: dict[str, any] = {};
    lines: list[str] = [];
    for f in fields(KubernetesConfig) {
        if f.name in not_written or f.name in unwritten {
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
    assert len(written) > 25 , (
        f"only {len(written)} keys were probed; the sweep stopped covering the section"
    );
    with tempfile.TemporaryDirectory() as project {
        (Path(project) / "jac.toml").write_text(
            '[project]\nname = "sweep-app"\nversion = "0.0.1"\n\n'
            '[scale.admin]\nusername = "metrics-admin"\n\n'
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
        for name in sorted(unwritten - {"app_name"}) {
            got = resolved[name];
            want = getattr(declared, name);
            assert got == want , f"{name} resolved to {got!r}, not the declared {want!r}";
        }
        assert resolved["app_name"] == "sweep-app";
        # admin_username comes from [scale.admin], the hand-off the sweep skips.
        assert resolved["admin_username"] == "metrics-admin";
    }
}
