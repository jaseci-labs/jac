import io;
import os;
import tempfile;
import unittest.mock;
import from contextlib { redirect_stderr, redirect_stdout }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import jaclang.scale.runtime.realizer.kubernetes_realizer as realizer_mod;


def _write_app(tmpdir: str) -> str {
    path = os.path.join(tmpdir, "main.jac");
    with open(path, "w") as f {
        f.write("with entry { print(1); }\n");
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
        app = _write_app(tmpdir);
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
        assert "auto-detected" not in combined , (
            f"nothing is auto-detected anymore; the routes table is "
            f"authoritative:\n{combined}"
        );
    }
}


test "banner reports the applied routes from the config cut" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        ms = {"enabled": True, "routes": {"cart_app": "/api/cart", "orders_app": ""}};
        (rc, out, err) = _realize_capturing(ms, {"microservices": dict(ms)}, app);
        assert rc == 0;
        assert "cart_app -> /api/cart" in out , (
            f"explicitly configured route must be reported as applied:\n{out}"
        );
        assert "orders_app -> /orders" in out , (
            f"empty-prefix route must derive and be reported:\n{out}"
        );
    }
}
