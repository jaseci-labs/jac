"""Per-app scale settings live under [apps.<name>.scale] and reach every reader
through one helper; the gateway's own settings live under [scale.gateway]."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.scale.config.config_loader {
    APP_SCALE_KEYS,
    JacScaleConfig,
    app_scale_overrides,
    get_scale_config,
    normalize_gateway_config,
    reset_scale_config
}
import from jaclang.scale.config.validation {
    STRICT_ENV,
    validate_app_scale_config,
    validate_scale_config
}
import from jaclang.scale.runtime.fleet { fleet_from_config }

glob _TOML: str = '[project]\n'
     'name = "shop"\n'
     'default-app = "web"\n'
     '\n'
     '[apps.web]\n'
     'kind = "web-app"\n'
     'entry-point = "main.jac"\n'
     '\n'
     '[apps.orders]\n'
     'kind = "service"\n'
     'entry-point = "orders.jac"\n'
     '\n'
     '[apps.orders.scale]\n'
     'rpc_timeout = 120.0\n'
     'replicas = 2\n'
     'cpu_limit = "2000m"\n'
     'env = { LOG_LEVEL = "DEBUG" }\n'
     '\n'
     '[apps.orders.scale.hpa]\n'
     'max = 20\n'
     '\n'
     '[apps.orders.scale.http_activation]\n'
     'enabled = true\n'
     'target_port = 8000\n'
     'concurrency_target = 5\n'
     '\n'
     '[scale.gateway]\n'
     'gateway_port = 9100\n'
     'colocate = false\n'
     'boot_health_timeout = 120\n'
     '\n'
     '[scale.gateway.rate_limit]\n'
     'enabled = true\n'
     'per_ip_rpm = 120\n';


def _project -> str {
    d = tempfile.mkdtemp(prefix="jac-app-scale-");
    (Path(d) / "jac.toml").write_text(_TOML, encoding="utf-8");
    (Path(d) / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "orders.jac").write_text("with entry {}\n", encoding="utf-8");
    return d;
}


test "app_scale_overrides reads [apps.<name>.scale] and nothing else" {
    d = _project();
    try {
        cfg = JacConfig.load(Path(d) / "jac.toml");
        orders = app_scale_overrides(cfg, "orders");
        assert orders["rpc_timeout"] == 120.0 , orders;
        assert orders["replicas"] == 2 , orders;
        assert orders["cpu_limit"] == "2000m" , orders;
        assert orders["env"] == {"LOG_LEVEL": "DEBUG"} , orders;
        assert orders["hpa"] == {"max": 20} , orders;
        assert orders["http_activation"]["enabled"] is True , orders;
        assert "gateway" not in orders , "base [scale] sections never leak in";
        assert set(orders.keys()) <= set(APP_SCALE_KEYS) , orders.keys();
        assert app_scale_overrides(cfg, "web") == {};
        assert app_scale_overrides(cfg, "ghost") == {};
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "the fleet carries each member's overrides" {
    d = _project();
    try {
        cfg = JacConfig.load(Path(d) / "jac.toml");
        fleet = fleet_from_config(cfg, project_root=d);
        assert fleet.app_config("orders")["replicas"] == 2;
        assert fleet.app_config("web") == {};
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "JacScaleConfig answers per-app settings and the gateway block" {
    d = _project();
    reset_scale_config();
    try {
        scale_cfg = get_scale_config(project_dir=Path(d));
        assert scale_cfg.get_app_scale_config("orders")["rpc_timeout"] == 120.0;
        assert scale_cfg.get_app_scale_config("web") == {};
        gw = scale_cfg.get_gateway_config();
        assert gw["gateway_port"] == 9100 , gw;
        assert gw["colocate"] is False , gw;
        assert gw["boot_health_timeout"] == 120 , gw;
        assert gw["rate_limit"]["per_ip_rpm"] == 120 , gw;
        assert gw["identity"]["gateway_owned"] is True , gw;
    } finally {
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "timeouts resolve per app, then the gateway, then the default" {
    import from jaclang.scale.runtime.context.util {
        boot_health_timeout,
        http_forward_timeout
    }
    import from jaclang.scale.runtime.rpc.rpc { _sv_rpc_timeout }
    d = _project();
    reset_scale_config();
    try {
        get_scale_config(project_dir=Path(d));
        assert _sv_rpc_timeout("orders") == 120.0;
        assert _sv_rpc_timeout("web") == 10.0;
        assert http_forward_timeout("orders") == 30.0;
        assert boot_health_timeout() == 120.0;
    } finally {
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "normalize_gateway_config fills every section with defaults" {
    gw = normalize_gateway_config({});
    for key in [
        "colocate",
        "gateway_port",
        "gateway_host",
        "http_forward_timeout",
        "rate_limit",
        "cors",
        "identity",
        "ingress",
        "shared_volumes",
        "logs",
        "tracing"
    ] {
        assert key in gw , f"missing {key}";
    }
    assert gw["colocate"] is True;
    assert "boot_health_timeout" not in gw;
    assert normalize_gateway_config({"identity": {"gateway_owned": False}})["identity"][
        "gateway_owned"
    ]
        is False;
    assert normalize_gateway_config({"replicas": 3})["replicas"] == 3;
}


test "an unknown per-app key is flagged with a suggestion" {
    msgs = validate_app_scale_config({"cpu_limits": "2000m"}, "orders");
    assert len(msgs) == 1 , msgs;
    assert "apps.orders.scale" in msgs[0] , msgs[0];
    assert "did you mean 'cpu_limit'" in msgs[0] , msgs[0];
}


test "the old [scale.microservices] table is unknown to the schema" {
    msgs = validate_scale_config({"microservices": {"routes": {}}});
    assert len(msgs) == 1 , msgs;
    assert "microservices" in msgs[0] , msgs[0];
    assert "gateway" in JacScaleConfig().get_config_schema()["options"];
}


test "strict mode refuses a misspelled per-app key from the on-disk toml" {
    d = _project();
    (Path(d) / "jac.toml").write_text(
        _TOML.replace('cpu_limit = "2000m"', 'cpu_limits = "2000m"'), encoding="utf-8"
    );
    os.environ[STRICT_ENV] = "1";
    try {
        cfg = JacConfig.load(Path(d) / "jac.toml");
        raised = "";
        try {
            app_scale_overrides(cfg, "orders");
        } except ValueError as e {
            raised = str(e);
        }
        assert "cpu_limits" in raised , raised;
    } finally {
        os.environ.pop(STRICT_ENV, None);
        shutil.rmtree(d, ignore_errors=True);
    }
}


glob _PROFILE_TOML: str = '[apps.orders.scale]\n'
     'replicas = 1\n'
     'cpu_limit = "500m"\n'
     '\n'
     '[apps.orders.scale.hpa]\n'
     'enabled = false\n'
     '\n'
     '[scale.gateway]\n'
     'gateway_port = 9200\n';


def _project_with_profile -> str {
    d = _project();
    (Path(d) / "jac.e2e.toml").write_text(_PROFILE_TOML, encoding="utf-8");
    return d;
}


test "a profile retunes [apps.<name>.scale], not only [scale.gateway]" {
    d = _project_with_profile();
    old = os.environ.get("JAC_PROFILE");
    os.environ["JAC_PROFILE"] = "e2e";
    reset_scale_config();
    try {
        scale_cfg = get_scale_config(project_dir=Path(d));
        gw = scale_cfg.get_gateway_config();
        orders = scale_cfg.get_app_scale_config("orders");
        assert gw["gateway_port"] == 9200 , gw;
        assert orders["replicas"] == 1 , orders;
        assert orders["cpu_limit"] == "500m" , orders;
        assert orders["hpa"]["enabled"] is False , orders;
        assert orders["rpc_timeout"] == 120.0 , orders;
        assert orders["hpa"]["max"] == 20 , orders;
    } finally {
        reset_scale_config();
        if old is None {
            os.environ.pop("JAC_PROFILE", None);
        } else {
            os.environ["JAC_PROFILE"] = old;
        }
        shutil.rmtree(d, ignore_errors=True);
    }
}


glob _INTERP_TOML: str = '[project]\n'
     'name = "shop"\n'
     'default-app = "web"\n'
     '\n'
     '[apps.web]\n'
     'kind = "web-app"\n'
     'entry-point = "main.jac"\n'
     '\n'
     '[apps.orders]\n'
     'kind = "service"\n'
     'entry-point = "orders.jac"\n'
     'route = "/${ORDERS_ROUTE_SEG}"\n';


test "a base app's interpolated value survives a profile that retunes it" {
    d = tempfile.mkdtemp(prefix="jac-apps-interp-");
    (Path(d) / "jac.toml").write_text(_INTERP_TOML, encoding="utf-8");
    (Path(d) / "jac.e2e.toml").write_text(
        '[apps.orders.scale]\nreplicas = 1\n', encoding="utf-8"
    );
    old_seg = os.environ.get("ORDERS_ROUTE_SEG");
    os.environ["ORDERS_ROUTE_SEG"] = "orders";
    try {
        cfg = JacConfig.load(Path(d) / "jac.toml");
        assert cfg.apps["orders"].route == "/orders" , cfg.apps["orders"].route;
        cfg.merge_from_toml_file(Path(d) / "jac.e2e.toml");
        assert cfg.apps["orders"].route == "/orders" , cfg.apps["orders"].route;
        assert cfg.apps["orders"].overlays["scale"]["replicas"] == 1 , (
            cfg.apps["orders"].overlays
        );
    } finally {
        if old_seg is None {
            os.environ.pop("ORDERS_ROUTE_SEG", None);
        } else {
            os.environ["ORDERS_ROUTE_SEG"] = old_seg;
        }
        shutil.rmtree(d, ignore_errors=True);
    }
}


test "profile and local app overlays preserve nested pod settings" {
    d = _project();
    try {
        cfg = JacConfig.load(Path(d) / "jac.toml");
        cfg.environments["preview"] = {
            "apps": {
                "orders": {
                    "scale": {
                        "replicas": 1,
                        "deployment_overlay": {
                            "spec": {
                                "template": {
                                    "spec": {
                                        "initContainers": [
                                            {
                                                "name": "install-kubectl",
                                                "image": "tools"
                                            }
                                        ],
                                        "volumes": [
                                            {
                                                "name": "key",
                                                "secret": {
                                                    "secretName": "github-app-key"
                                                }
                                            }
                                        ]
                                    }
                                }
                            }
                        }
                    }
                }
            }
        };
        cfg.apply_profile("preview");
        Path(d, "jac.local.toml").write_text(
            '[apps.orders.scale]\ncpu_limit = "250m"\n'
        );
        cfg.merge_from_toml_file(Path(d, "jac.local.toml"));
        scale = cfg.apps["orders"].overlays["scale"];
        assert scale["replicas"] == 1;
        assert scale["cpu_limit"] == "250m";
        pod = scale["deployment_overlay"]["spec"]["template"]["spec"];
        assert pod["initContainers"][0]["name"] == "install-kubectl";
        assert pod["volumes"][0]["secret"]["secretName"] == "github-app-key";
        effective = cfg.effective_for_app("orders");
        assert effective.plugins["scale"]["deployment_overlay"]["spec"]["template"][
            "spec"
        ]
            == pod;
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}
