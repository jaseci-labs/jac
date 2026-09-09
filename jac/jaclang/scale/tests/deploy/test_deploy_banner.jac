import io;
import os;
import tempfile;
import unittest.mock;
import from contextlib { redirect_stderr, redirect_stdout }
import from jaclang.project.config { JacConfig }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.runtime.fleet { fleet_of }
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import jaclang.scale.runtime.realizer.kubernetes_realizer as realizer_mod;


def _write_app(tmpdir: str) -> str {
    path = os.path.join(tmpdir, "main.jac");
    with open(path, "w") as f {
        f.write("with entry { print(1); }\n");
    }
    return path;
}


def _fake_scale_config -> any {
    cfg = unittest.mock.MagicMock();
    cfg.get_kubernetes_config.return_value = {
        "app_name": "test-app",
        "namespace": "default",
        "container_port": 8000
    };
    cfg.get_secrets_config.return_value = {};
    cfg.get_gateway_config.return_value = {};
    cfg.get_jac_config.return_value = JacConfig();
    cfg.load.return_value = {};
    return cfg;
}


def _realize_capturing(fleet: any, app: str) -> tuple {
    out = io.StringIO();
    err = io.StringIO();
    fake_target = unittest.mock.MagicMock();
    with unittest.mock.patch.object(
        realizer_mod, "get_scale_config", return_value=_fake_scale_config()
    ), unittest.mock.patch(
        "jaclang.scale.runtime.cli.plan.print_plan", return_value=({}, [])
    ), unittest.mock.patch.object(
        DeploymentTargetFactory, "create", return_value=fake_target
    ), redirect_stdout(out), redirect_stderr(err) {
        rc = KubernetesRealizer(fleet=fleet).realize(app, dry_run=True);
    }
    return (rc, out.getvalue(), err.getvalue());
}


test "a configured fleet is never told to go declare one (issue 7434)" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        fleet = fleet_of({"cart_app": "/api/cart"}, root_app="main");
        (rc, out, err) = _realize_capturing(fleet, app);
        assert rc == 0;
        combined = out + err;
        assert "No service apps" not in combined , (
            f"banner must not claim there are no service apps when the fleet "
            f"has one:\n{combined}"
        );
        assert "auto-detected" not in combined , (
            f"nothing is auto-detected anymore; [apps] is authoritative:\n{combined}"
        );
    }
}


test "banner reports the applied routes from the fleet" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        fleet = fleet_of({"cart_app": "/api/cart", "orders_app": ""}, root_app="main");
        (rc, out, err) = _realize_capturing(fleet, app);
        assert rc == 0;
        assert "cart_app -> /api/cart" in out , (
            f"explicitly configured route must be reported as applied:\n{out}"
        );
        assert "orders_app -> /api/orders_app" in out , (
            f"the default /api/<name> route must be reported:\n{out}"
        );
        assert "main -> / (gateway host)" in out , (
            f"the served app must be reported as the gateway host:\n{out}"
        );
    }
}


test "an app without service apps deploys as a single pod behind the gateway" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        (rc, out, err) = _realize_capturing(None, app);
        assert rc == 0;
        assert "single pod behind a gateway" in out + err;
    }
}
