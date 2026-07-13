import os;
import tempfile;
import unittest.mock;
import from jaclang.project.capabilities { CAPABILITY_SPECS }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.deploy.target.kubernetes { ingress as ingress_mod }
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import jaclang.scale.runtime.realizer.kubernetes_realizer as realizer_mod;

# What an operator machine is missing when the 'deploy.k8s' capability is unsynced.
glob _MISSING: list[str] = ["docker>=7.1.0,<8.0.0", "kubernetes>=34.1.0,<35.0.0"];


def _write_app(tmpdir: str) -> str {
    path = os.path.join(tmpdir, "main.jac");
    with open(path, "w") as f {
        f.write("with entry {\n    print(\"hello\");\n}\n");
    }
    return path;
}


def _fake_scale_config(**overrides: any) -> any {
    k8s = {"app_name": "test-app", "namespace": "default", "container_port": 8000};
    k8s.update(overrides);
    cfg = unittest.mock.MagicMock();
    cfg.get_kubernetes_config.return_value = k8s;
    cfg.get_secrets_config.return_value = {};
    cfg.get_microservices_config.return_value = {};
    cfg.load.return_value = {};
    return cfg;
}


test "--dry-run never installs deploy tooling into the jac global site" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        with unittest.mock.patch.object(
            realizer_mod, "get_scale_config", return_value=_fake_scale_config()
        ), unittest.mock.patch(
            "jaclang.scale.runtime.cli.plan.print_plan", return_value=({}, [])
        ), unittest.mock.patch(
            "jaclang.scale.deploy.target.factory.missing_capability_dists",
            return_value=list(_MISSING)
        ), unittest.mock.patch(
            "jaclang.scale.deploy.target.factory.ensure_global_capability"
        ) as mock_ensure {
            rc = KubernetesRealizer(ms_config={"enabled": True}).realize(
                app, target="kubernetes-microservice", dry_run=True
            );
            assert rc == 0;
            mock_ensure.assert_not_called();
        }
    }
}


test "--dry-run never contacts the cluster to issue TLS certificates" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        fake_target = unittest.mock.MagicMock();
        tls_config = _fake_scale_config(
            domain="example.com", cert_manager_email="ops@example.com"
        );
        with unittest.mock.patch.object(
            realizer_mod, "get_scale_config", return_value=tls_config
        ), unittest.mock.patch(
            "jaclang.scale.runtime.cli.plan.print_plan", return_value=({}, [])
        ), unittest.mock.patch.object(
            DeploymentTargetFactory, "create", return_value=fake_target
        ) {
            KubernetesRealizer(ms_config={"enabled": True}).realize(
                app, target="kubernetes-microservice", enable_tls=True, dry_run=True
            );
            fake_target.enable_tls.assert_not_called();
        }
    }
}


test "building a target for a dry run installs nothing and probes nothing" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.missing_capability_dists",
        return_value=list(_MISSING)
    ), unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.ensure_global_capability"
    ) as mock_ensure, unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.require_optional"
    ) as mock_require {
        target = DeploymentTargetFactory.create(
            "kubernetes-microservice", config, dry_run=True
        );
        assert target is not None;
        mock_ensure.assert_not_called();
        mock_require.assert_not_called();
    }
}


test "a real deploy still syncs missing deploy tooling" {
    config = {"app_name": "test-app", "namespace": "default", "container_port": 8000};

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.missing_capability_dists",
        return_value=list(_MISSING)
    ), unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.ensure_global_capability"
    ) as mock_ensure {
        DeploymentTargetFactory.create("kubernetes-microservice", config);
        mock_ensure.assert_called_once_with("deploy.k8s");
    }
}


test "deploy.k8s declares every dist the deploy path imports" {
    deps = CAPABILITY_SPECS["deploy.k8s"]["deps"];

    assert "kubernetes" in deps;
    assert "docker" in deps;
    # The ingress deployer bcrypt-hashes the RedisInsight basic-auth htpasswd
    # entry. Deploy tooling is auto-installed from this dep set, so omitting
    # bcrypt crashed a real deploy with "No module named 'bcrypt'".
    assert "bcrypt" in deps , "deploy.k8s must close over bcrypt";
}


test "importing the kubernetes deploy target does not require bcrypt" {
    # bcrypt is reachable only through the RedisInsight dashboard branch, so a
    # module-scope import made every deploy -- and every --dry-run, which merely
    # renders manifests -- hard-fail when bcrypt was absent.
    assert not hasattr(ingress_mod, "bcrypt") , "ingress must import bcrypt at its point of use, not at module scope";
}


test "redis dashboard htpasswd entry is a bcrypt 2y hash" {
    line = ingress_mod._htpasswd_line("admin", "s3cret");

    (user, hashed) = line.split(":", 1);
    assert user == "admin";
    # nginx's auth-file reader wants the $2y$ prefix, not bcrypt's native $2b$.
    assert hashed.startswith("$2y$") , f"expected a $2y$ htpasswd hash, got {hashed!r}";
}
