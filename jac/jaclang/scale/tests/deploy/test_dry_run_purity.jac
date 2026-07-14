import os;
import pathlib;
import re;
import sys;
import tempfile;
import unittest.mock;
import from jaclang.project.capabilities { CAPABILITY_SPECS }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.deploy.target.kubernetes { ingress as ingress_mod }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils as k8s_utils_mod;
import jaclang.scale.injector.binary as binary_mod;
import jaclang.scale.injector.binary_injector as binary_injector_mod;
import jaclang.scale.runtime.realizer.kubernetes_realizer as realizer_mod;

# What an operator machine is missing when the 'deploy.k8s' capability is unsynced.
glob _MISSING: list[str] = ["docker>=7.1.0,<8.0.0", "kubernetes>=34.1.0,<35.0.0"],
     # Import roots the deploy path may use and the deploy.k8s dist that provides
     # each one. The auto-install syncs exactly the declared pins, so every root
     # here must stay declared in CAPABILITY_SPECS["deploy.k8s"]["deps"].
     _DIST_FOR_MODULE: dict[str, str] = {
         "kubernetes": "kubernetes",
         "docker": "docker",
         "bcrypt": "bcrypt",
         "dotenv": "python-dotenv"
     },
     # Shipped by a declared pin's own dependency tree, so the auto-install provides
     # them without a direct pin: the kubernetes client requires pyyaml, requests,
     # and urllib3.
     _TRANSITIVE_OF_PINS: set[str] = {"yaml", "requests", "urllib3"},
     # Imported at point of use behind require_optional(...) for a capability other
     # than deploy.k8s: database provisioning checks owned by data.mongo/data.redis.
     _GUARDED_BY_OTHER_CAPABILITY: set[str] = {"pymongo", "redis"};


def _deploy_path_third_party_imports -> dict[str, str] {
    # Scan every source the deploy path can reach for third-party import
    # roots, keyed to one representative site. Regex over source instead of
    # importing modules so lazily imported (point-of-use) deps are seen too.
    scale_dir = pathlib.Path(realizer_mod.__file__).resolve().parent.parent.parent;
    sources = [scale_dir / "runtime" / "realizer" / "kubernetes_realizer.jac"];
    for sub in ["deploy", "injector", "runtime/cli"] {
        tree = scale_dir / sub;
        assert tree.is_dir() , f"deploy-path source tree missing: {tree}";
        sources.extend(sorted(tree.rglob("*.jac")));
    }
    pattern = re.compile(r"^\s*import\s+(?:from\s+)?([A-Za-z_][\w.]*)");
    found: dict[str, str] = {};
    for src in sources {
        for (lineno, line) in enumerate(src.read_text().splitlines(), 1) {
            hit = pattern.match(line);
            if not hit {
                continue;
            }
            pkg_root = hit.group(1).split(".")[0];
            if pkg_root == "jaclang" or pkg_root in sys.stdlib_module_names {
                continue;
            }
            found.setdefault(pkg_root, f"{src.relative_to(scale_dir)}:{lineno}");
        }
    }
    return found;
}


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
    # Deploy tooling is auto-installed from this dep set, so any import the
    # set does not close over crashes a clean operator machine with
    # "No module named ...": bcrypt did, then dotenv did.
    deps = CAPABILITY_SPECS["deploy.k8s"]["deps"];
    imports = _deploy_path_third_party_imports();

    assert "kubernetes" in imports , "scan found no kubernetes import; the deploy-path scan is broken";
    for (module, site) in sorted(imports.items()) {
        if module in _TRANSITIVE_OF_PINS or module in _GUARDED_BY_OTHER_CAPABILITY {
            continue;
        }
        dist = _DIST_FOR_MODULE.get(module);
        assert dist is not None , (
            f"deploy path imports '{module}' ({site}) but it is not accounted "
            f"for: pin its dist in deploy.k8s (and map it in _DIST_FOR_MODULE) "
            f"or guard it behind require_optional for the owning capability"
        );
        assert dist in deps , (
            f"deploy.k8s must close over '{dist}': the deploy path imports "
            f"'{module}' ({site}) and the auto-install syncs only declared pins"
        );
    }
}


test "importing the kubernetes deploy target does not require bcrypt" {
    # bcrypt is reachable only through the RedisInsight dashboard branch, so a
    # module-scope import made every deploy -- and every --dry-run, which merely
    # renders manifests -- hard-fail when bcrypt was absent.
    assert not hasattr(ingress_mod, "bcrypt") , "ingress must import bcrypt at its point of use, not at module scope";
}


test "importing the kubernetes deploy path does not require dotenv" {
    # The realizer is imported before the deploy.k8s closure is synced, so a
    # module-scope dotenv import crashed `jac start --scale` on a clean
    # operator machine before the auto-install could run.
    assert not hasattr(realizer_mod, "load_dotenv") , "the realizer must import dotenv at its point of use, not at module scope";
    assert not hasattr(k8s_utils_mod, "dotenv_values") , "kubernetes_utils must import dotenv at its point of use, not at module scope";
}


test "a real deploy syncs deploy tooling before reading .env" {
    # Ordering is the other half of the dotenv fix: the pin only helps if the
    # sync runs before the deploy path's first dotenv use.
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        order = unittest.mock.MagicMock();
        fake_target = unittest.mock.MagicMock();
        with unittest.mock.patch.object(
            realizer_mod, "get_scale_config", return_value=_fake_scale_config()
        ), unittest.mock.patch.object(
            realizer_mod, "ensure_deploy_tooling", order.ensure_deploy_tooling
        ), unittest.mock.patch("dotenv.load_dotenv", order.load_dotenv), unittest.mock.patch.object(
            DeploymentTargetFactory, "create", return_value=fake_target
        ) {
            rc = KubernetesRealizer(ms_config={"enabled": False}).realize(app);
            assert rc == 0;
        }
        calls = [name for (name, args, kwargs) in order.mock_calls];
        assert "ensure_deploy_tooling" in calls , "realize() must sync the deploy.k8s closure";
        assert "load_dotenv" in calls;
        assert calls.index("ensure_deploy_tooling") < calls.index("load_dotenv") , "the deploy.k8s sync must run before the first dotenv use";
test "--dry-run reads no cluster state, downloads nothing, and builds nothing" {
    # Issue #7431: the plan flow reached generate_manifests -> _prepare_injector
    # -> BinaryInjector.prepare(), which read /api/v1/nodes off the live
    # cluster, downloaded the pod release binary and admin console, ran a host
    # `jac build` for the client bundle, and probed Docker Hub -- all under a
    # flag that promises to touch nothing.
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        cfg = _fake_scale_config(bundle_storage_class="standard");
        with unittest.mock.patch.object(
            realizer_mod, "get_scale_config", return_value=cfg
        ), unittest.mock.patch(
            "jaclang.scale.config.config_loader.get_scale_config", return_value=cfg
        ), unittest.mock.patch(
            "jaclang.scale.runtime.discovery.discovery.resolve_routes",
            return_value={"svc": "/svc"}
        ), unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.node_arch"
        ) as mock_cluster, unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.download_release_binary"
        ) as mock_download, unittest.mock.patch(
            "jaclang.scale.injector.binary_injector.stage_admin_dist"
        ) as mock_console, unittest.mock.patch(
            "jaclang.scale.injector.binary._http_get_bytes"
        ) as mock_http, unittest.mock.patch("subprocess.run") as mock_subprocess {
            rc = KubernetesRealizer(ms_config={"enabled": True}).realize(
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
        builder = MicroserviceManifestBuilder(
            k8s_config=KubernetesConfig.from_dict(
                KubernetesConfig, {"app_name": "test-app", "namespace": "default"}
            ),
            project_dir=tmpdir,
            microservices_config={"client": {"entry": "main.jac"}},
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


test "redis dashboard htpasswd entry is a bcrypt 2y hash" {
    line = ingress_mod._htpasswd_line("admin", "s3cret");

    (user, hashed) = line.split(":", 1);
    assert user == "admin";
    # nginx's auth-file reader wants the $2y$ prefix, not bcrypt's native $2b$.
    assert hashed.startswith("$2y$") , f"expected a $2y$ htpasswd hash, got {hashed!r}";
}
