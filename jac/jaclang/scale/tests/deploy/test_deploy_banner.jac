import io;
import os;
import tempfile;
import unittest.mock;
import from contextlib { redirect_stderr, redirect_stdout }
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.scale.config.app_config { deployed_tree }
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


def _realize_capturing(
    fleet: any, app: str, served_app: str = "", plans: (list | None) = None
) -> tuple[any, ...] {
    out = io.StringIO();
    err = io.StringIO();
    fake_target = unittest.mock.MagicMock();

    def _plan(target: any, app_config: any, **kwargs: any) -> tuple[dict, list] {
        if plans is not None {
            plans.append(app_config);
        }
        return ({}, []);
    }
    with unittest.mock.patch.object(
        realizer_mod, "get_scale_config", return_value=_fake_scale_config()
    ), unittest.mock.patch(
        "jaclang.scale.runtime.cli.plan.print_plan", side_effect=_plan
    ), unittest.mock.patch.object(
        DeploymentTargetFactory, "create", return_value=fake_target
    ), redirect_stdout(out), redirect_stderr(err) {
        rc = KubernetesRealizer(fleet=fleet, served_app=served_app).realize(
            app, dry_run=True
        );
    }
    return (rc, out.getvalue(), err.getvalue());
}


glob _WORKSPACE_TOML: str = '[project]\nname = "shop"\ndefault-app = "web"\n\n[apps.web]\nkind = "web-app"\nentry-point = "web.main"\n\n[apps.svc]\nkind = "service"\nentry-point = "core.svc"\n';


def _write_workspace(tmpdir: str) -> str {
    base = Path(tmpdir);
    (base / "jac.toml").write_text(_WORKSPACE_TOML, encoding="utf-8");
    for (folder, module) in (("web", "main"), ("core", "svc")) {
        (base / folder).mkdir();
        (base / folder / f"{module}.jac").write_text(
            "with entry {}\n", encoding="utf-8"
        );
    }
    return str(base / "web" / "main.jac");
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


test "a workspace deploys from the project root, not the served app's folder (issue 9256)" {
    for served_app in ("", "web") {
        with tempfile.TemporaryDirectory() as tmpdir {
            entry_file = _write_workspace(tmpdir);
            plans: list = [];
            (rc, out, err) = _realize_capturing(None, entry_file, served_app, plans);
            assert rc == 0 , f"served_app={served_app!r}:\n{out}{err}";
            assert "outside the deployed tree" not in out + err , (
                f"served_app={served_app!r}: a service beside the served app "
                f"must not fall outside the tree:\n{out}{err}"
            );
            assert "svc -> /api/svc" in out , (
                f"served_app={served_app!r}: the service app must join the "
                f"fleet:\n{out}"
            );
            assert len(plans) == 1 , f"served_app={served_app!r}: {plans}";
            proj_root = os.path.realpath(tmpdir);
            assert os.path.realpath(plans[0].code_folder) == proj_root , (
                f"served_app={served_app!r}: the deployed tree must be the "
                f"project root, got {plans[0].code_folder!r}"
            );
            assert plans[0].file_name == "web/main.jac" , (
                f"served_app={served_app!r}: the entry must stay addressable "
                f"inside the tree, got {plans[0].file_name!r}"
            );
        }
    }
}


test "the deployed tree is the project root only for a workspace (issue 9256)" {
    with tempfile.TemporaryDirectory() as tmpdir {
        base = Path(tmpdir);
        workspace = base / "ws";
        workspace.mkdir();
        _write_workspace(str(workspace));
        solo = base / "solo";
        solo.mkdir();
        (solo / "jac.toml").write_text('[project]\nname = "solo"\n', encoding="utf-8");
        (solo / "main.jac").write_text("with entry {}\n", encoding="utf-8");
        loose = base / "loose";
        loose.mkdir();
        (loose / "main.jac").write_text("with entry {}\n", encoding="utf-8");
        cases = [
            (str(workspace / "web" / "main.jac"), str(workspace), "web/main.jac"),
            (str(solo / "main.jac"), str(solo), "main.jac"),
            (str(loose / "main.jac"), str(loose), "main.jac")
        ];
        for (entry_file, want_folder, want_name) in cases {
            (folder, name) = deployed_tree(entry_file);
            assert os.path.realpath(folder) == os.path.realpath(want_folder) , (
                f"{entry_file}: expected tree {want_folder!r}, got {folder!r}"
            );
            assert name == want_name , (
                f"{entry_file}: expected entry {want_name!r}, got {name!r}"
            );
        }
    }
}
