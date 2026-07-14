import io;
import os;
import tempfile;
import unittest.mock;
import from contextlib { redirect_stderr, redirect_stdout }
import from pathlib { Path }
import from jaclang.scale.config.config_loader { JacScaleConfig }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.runtime.discovery.route_policy { format_route_origin_lines }
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import jaclang.scale.runtime.realizer.kubernetes_realizer as realizer_mod;


def _write_sv_app(tmpdir: str) -> str {
    # Two sv-import targets so discovery derives cart_app and orders_app;
    # the tests then declare an explicit route for cart_app only.
    path = os.path.join(tmpdir, "main.jac");
    with open(path, "w") as f {
        f.write(
            "sv import from cart_app { view_cart }\n"
            "sv import from orders_app { create_order }\n"
        );
    }
    return path;
}


def _fake_scale_config(raw_scale_doc: dict) -> any {
    cfg = unittest.mock.MagicMock();
    cfg.get_kubernetes_config.return_value = {
        "app_name": "test-app",
        "namespace": "default",
        "container_port": 8000
    };
    cfg.get_secrets_config.return_value = {};
    cfg.load.return_value = raw_scale_doc;
    cfg.microservices_declared.return_value = bool(raw_scale_doc.get("microservices"));
    return cfg;
}


def _realize_capturing(ms_config: dict, raw_scale_doc: dict, app: str) -> tuple {
    out = io.StringIO();
    err = io.StringIO();
    fake_target = unittest.mock.MagicMock();
    with unittest.mock.patch.object(
        realizer_mod, "get_scale_config", return_value=_fake_scale_config(raw_scale_doc)
    ), unittest.mock.patch(
        "jaclang.scale.runtime.cli.plan.print_plan", return_value=({}, [])
    ), unittest.mock.patch.object(
        DeploymentTargetFactory, "create", return_value=fake_target
    ), redirect_stdout(out), redirect_stderr(err) {
        rc = KubernetesRealizer(ms_config=dict(ms_config)).realize(app, dry_run=True);
    }
    return (rc, out.getvalue(), err.getvalue());
}


test "configured [scale.microservices] is never told to go set it (issue 7434)" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_sv_app(tmpdir);
        ms = {"enabled": True, "routes": {"cart_app": "/api/cart"}};
        (rc, out, err) = _realize_capturing(
            ms,
            {"microservices": {"enabled": True, "routes": {"cart_app": "/api/cart"}}},
            app
        );
        assert rc == 0;
        combined = out + err;
        assert "default routes" not in combined , (
            f"banner must not claim default routes when [scale.microservices] "
            f"is set and honored:\n{combined}"
        );
        assert "set [scale.microservices]" not in combined.lower() , (
            f"must not tell the user to set [scale.microservices] when it is "
            f"already set:\n{combined}"
        );
        assert "routes /<name>" not in combined , (
            f"banner must report the routes actually applied, not the literal "
            f"placeholder:\n{combined}"
        );
    }
}


test "banner reports applied routes, split configured vs auto-derived" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_sv_app(tmpdir);
        ms = {"enabled": True, "routes": {"cart_app": "/api/cart"}};
        (rc, out, err) = _realize_capturing(
            ms,
            {"microservices": {"enabled": True, "routes": {"cart_app": "/api/cart"}}},
            app
        );
        assert rc == 0;
        assert "cart_app -> /api/cart" in out , (
            f"explicitly configured route must be reported as applied:\n{out}"
        );
        assert "orders_app -> /orders" in out , (
            f"auto-derived route must be reported as applied:\n{out}"
        );
        assert "configured:" in out and "auto-derived:" in out , (
            f"banner must distinguish configured services from auto-derived "
            f"ones:\n{out}"
        );
    }
}


test "absent [scale.microservices] still gets the customize hint and warning" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_sv_app(tmpdir);
        ms = {"enabled": None, "routes": {}};
        (rc, out, err) = _realize_capturing(ms, {}, app);
        assert rc == 0;
        assert "auto-detected" in out , (
            f"a config-less project must be reported as auto-detected:\n{out}"
        );
        assert "set [scale.microservices]" in out.lower() , (
            f"a config-less project must be pointed at [scale.microservices]:\n{out}"
        );
        assert "Set [scale.microservices]" in err , (
            f"the production-readiness warning must fire when the section is "
            f"genuinely absent:\n{err}"
        );
        assert "cart_app -> /cart" in out and "orders_app -> /orders" in out , (
            f"auto-derived routes must be reported as applied:\n{out}"
        );
    }
}


test "format_route_origin_lines splits configured from auto-derived routes" {
    lines = format_route_origin_lines(
        {"cart_app": "/api/cart", "orders_app": "/orders"}, {"cart_app": "/api/cart"}
    );
    assert lines == [
        "configured:   cart_app -> /api/cart",
        "auto-derived: orders_app -> /orders"
    ] , f"unexpected lines: {lines}";

    assert format_route_origin_lines({}, {}) == [];
    assert format_route_origin_lines({"a": "/a"}, {}) == ["auto-derived: a -> /a"];
    assert format_route_origin_lines({"a": "/x"}, {"a": "/x"}) == [
        "configured:   a -> /x"
    ];
}


test "microservices_declared reads the raw jac.toml section, not merged defaults" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml = Path(tmpdir) / "jac.toml";
        toml.write_text("[project]\nname = \"app\"\n");
        assert JacScaleConfig(Path(tmpdir)).microservices_declared() == False , (
            "no [scale.microservices] section must read as not declared, even "
            "though the merged config always carries microservices defaults"
        );
        toml.write_text(
            "[project]\nname = \"app\"\n\n"
            "[scale.microservices]\nenabled = true\n\n"
            "[scale.microservices.routes]\ncart_app = \"/api/cart\"\n"
        );
        assert JacScaleConfig(Path(tmpdir)).microservices_declared() == True;
        toml.write_text(
            "[project]\nname = \"app\"\n\n"
            "[scale.microservices.routes]\ncart_app = \"/api/cart\"\n"
        );
        assert JacScaleConfig(Path(tmpdir)).microservices_declared() == True , (
            "routes declared without an explicit enabled key still count as "
            "a configured section"
        );
    }
}
