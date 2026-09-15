import os;
import tempfile;
import unittest.mock;
import from jaclang.project.capabilities { CAPABILITY_SPECS }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.deploy.target.kubernetes { ingress as ingress_mod }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import from jaclang.scale.injector.binary_injector { BinaryInjector }
import jaclang.scale.injector.binary as binary_mod;
import jaclang.scale.injector.binary_injector as binary_injector_mod;
import jaclang.scale.runtime.realizer.kubernetes_realizer as realizer_mod;
import from jaclang.project.config { JacConfig }
import from jaclang.scale.runtime.fleet { fleet_of }

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
    cfg.get_gateway_config.return_value = {};
    cfg.get_jac_config.return_value = JacConfig();
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
            rc = KubernetesRealizer().realize(
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
            KubernetesRealizer().realize(
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
    # kubernetes_utils imports requests at module scope; deploy tooling is
    # auto-installed from this dep set, so omitting it breaks a real deploy.
    assert "requests" in deps , "deploy.k8s must close over requests";
    # RedisInsight is gone (#8000); its htpasswd hasher was bcrypt's only user.
    assert "bcrypt" not in deps , "bcrypt has no remaining deploy-path consumer";
}


test "importing the kubernetes deploy target does not require bcrypt" {
    # The RedisInsight dashboard branch was bcrypt's only consumer; the module
    # must stay import-clean without it.
    assert not hasattr(ingress_mod, "bcrypt") , "ingress must not import bcrypt at module scope";
}


test "--dry-run reads no cluster state, downloads nothing, and builds nothing" {
    # Issue #7431: the plan flow reached generate_manifests -> _prepare_injector
    # -> BinaryInjector.prepare(), which read /api/v1/nodes off the live
    # cluster, downloaded the pod release binary and admin console, ran a host
    # `jac build` for the client bundle, and probed Docker Hub -- all under a
    # flag that promises to touch nothing.
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        with open(os.path.join(tmpdir, "svc.jac"), "w") as f {
            f.write("with entry {\n    print(\"svc\");\n}\n");
        }
        cfg = _fake_scale_config(bundle_storage_class="standard");
        with unittest.mock.patch.object(
            realizer_mod, "get_scale_config", return_value=cfg
        ), unittest.mock.patch(
            "jaclang.scale.config.config_loader.get_scale_config", return_value=cfg
        ), unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.node_arch"
        ) as mock_cluster, unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.download_release_binary"
        ) as mock_download, unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.stage_admin_dist"
        ) as mock_console, unittest.mock.patch(
            "jaclang.scale.injector.binary._http_get_bytes"
        ) as mock_http, unittest.mock.patch("subprocess.run") as mock_subprocess {
            rc = KubernetesRealizer().realize(
                app, target="kubernetes-microservice", dry_run=True
            );
            mock_cluster.assert_not_called();
            mock_download.assert_not_called();
            mock_console.assert_not_called();
            mock_http.assert_not_called();
            mock_subprocess.assert_not_called();
            assert rc == 0;
        }
    }
}


test "selecting an injector for a dry run neither downloads nor probes the cluster" {
    with tempfile.TemporaryDirectory() as tmpdir {
        with unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.node_arch"
        ) as mock_arch, unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.download_release_binary"
        ) as mock_download, unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.stage_admin_dist"
        ) as mock_stage {
            (injector, toolchain_key) = binary_injector_mod.select_injector(
                "standard", "app", "ns", tmpdir, dry_run=True
            );
            mock_arch.assert_not_called();
            mock_download.assert_not_called();
            mock_stage.assert_not_called();
        }
        # The plan still renders content-addressed slots; placeholder digests
        # make it explicit that a real deploy computes the real ones.
        assert binary_injector_mod.DRY_RUN_DIGEST in injector._object_key;
        assert binary_injector_mod.DRY_RUN_DIGEST in toolchain_key;
        assert injector.extra_manifests("app", "ns");
    }
}


test "the deploy hands the config it resolves pods for to the injector" {
    with tempfile.TemporaryDirectory() as tmpdir {
        _write_app(tmpdir);
        builder = ManifestBuilder(
            k8s_config=KubernetesConfig.from_dict(
                KubernetesConfig, {"app_name": "test-app", "namespace": "default"}
            ),
            project_dir=tmpdir,
            fleet=fleet_of({}, root_app="main"),
            dry_run=True
        );
        injector = builder._prepare_injector(AppConfig(code_folder=tmpdir));
        assert injector._fleet is builder.fleet;
        assert injector._fleet.root_app == "main";
    }
}


glob _PREP_SEEN: list[dict[str, any] | None] = [];


def _spy_prepare(
    inj: BinaryInjector, _app_name: str, _namespace: str, _project_dir: str
) {
    _PREP_SEEN.append(inj._fleet);
}


test "the packing config is on the injector before prepare runs" {
    with tempfile.TemporaryDirectory() as tmpdir {
        cfg = fleet_of({"svc": "/svc"});
        with unittest.mock.patch.object(
            binary_injector_mod.BinaryInjector, "prepare", new=_spy_prepare
        ) {
            (injector, _) = binary_injector_mod.select_injector(
                "standard", "app", "ns", tmpdir, fleet=cfg
            );
        }
        assert _PREP_SEEN == [cfg] , _PREP_SEEN;
        assert injector._fleet is cfg;
    }
}


test "a dry run injector refuses to seed placeholder bytes" {
    with tempfile.TemporaryDirectory() as tmpdir {
        (injector, _) = binary_injector_mod.select_injector(
            "standard", "app", "ns", tmpdir, dry_run=True
        );
        seed_failed = False;
        try {
            injector.seed("app", "ns");
        } except ValueError {
            seed_failed = True;
        }
        assert seed_failed , "seeding a dry-run injector must fail loudly";
    }
}


test "a dry run skips the host client bundle build" {
    with tempfile.TemporaryDirectory() as tmpdir {
        _write_app(tmpdir);
        builder = ManifestBuilder(
            k8s_config=KubernetesConfig.from_dict(
                KubernetesConfig, {"app_name": "test-app", "namespace": "default"}
            ),
            project_dir=tmpdir,
            client_entry="main.jac",
            dry_run=True
        );
        with unittest.mock.patch("subprocess.run") as mock_run {
            builder._build_client_bundle(tmpdir);
            mock_run.assert_not_called();
        }
    }
}


test "resolving the pod base image for a dry run makes no network probe" {
    with tempfile.TemporaryDirectory() as tmpdir {
        with unittest.mock.patch(
            "jaclang.scale.injector.binary._http_get_bytes"
        ) as mock_http, unittest.mock.patch.dict(
            os.environ, {"JAC_SCALE_BINARY_PATH": ""}
        ) {
            image = binary_mod.resolve_pod_base_image(tmpdir, "", probe=False);
            mock_http.assert_not_called();
        }
        # No [dev] stanza and no override: the stable channel's official image.
        assert image == "jaseci/jaclang:latest";
    }
}


test "--dry-run never hands the deploy to the pinned jac" {
    # Delegating fetches the pinned release before it can run it, and --dry-run
    # promises no downloads, so the plan stays on the local jac even when the
    # app pins another line.
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write('[project]\nname = "x"\njac-version = "==0.1.0"\n');
        }
        with unittest.mock.patch(
            "jaclang.scale.injector.binary._http_get_bytes"
        ) as mock_http {
            r = KubernetesRealizer();
            assert r._deploy_on_pinned_jac(app, "kubernetes", False, True) is None;
            mock_http.assert_not_called();
        }
    }
}


test "--dry-run refuses a cross-generation pin instead of planning it" {
    # An exact pin resolves with no network, so a plan the real deploy would
    # never use is refused rather than printed.
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        with open(os.path.join(tmpdir, "jac.toml"), "w") as f {
            f.write('[project]\nname = "x"\njac-version = "==0.1.0"\n');
        }
        with unittest.mock.patch(
            "jaclang.scale.injector.binary._http_get_bytes"
        ) as mock_http {
            rc = KubernetesRealizer().realize(
                app, target="kubernetes-microservice", dry_run=True
            );
            assert rc == 2 , f"a plan for the wrong generation was printed (rc={rc})";
            mock_http.assert_not_called();
        }
    }
}
