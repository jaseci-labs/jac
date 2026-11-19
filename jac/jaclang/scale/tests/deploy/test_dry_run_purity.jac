import gzip;
import hashlib;
import io;
import json;
import os;
import shutil;
import subprocess;
import tarfile;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes { ingress as ingress_mod }

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
    import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
        KubectlCluster
    }
    with tempfile.TemporaryDirectory() as tmpdir {
        (injector, _) = binary_injector_mod.select_injector(
            "standard", "app", "ns", tmpdir, dry_run=True
        );
        seed_failed = False;
        try {
            injector.seed("app", "ns", KubectlCluster());
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
        ) as mock_http {
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


glob _BUILT: dict[str, str] = {};


"""Runs `jac scale <args>` in `project` the way a CI build step or a platform's
apply step would: no in-cluster env, no JAC_NODE_ARCH, and a kubeconfig that
cannot load, so any contact with a cluster fails the command."""
def _scale_cli(project: str, args: list[str]) -> any {
    blocked = ("JAC_NODE_ARCH", "KUBERNETES_SERVICE_HOST", "KUBERNETES_SERVICE_PORT");
    env = {
        k: v
        for (k, v) in os.environ.items()
        if k not in blocked
    };
    env["KUBECONFIG"] = project + "-kubeconfig";
    Path(env["KUBECONFIG"]).write_text("clusters: [not a kubeconfig\n");
    return subprocess.run(
        [jac_executable(), "scale", *args],
        cwd=project,
        env=env,
        capture_output=True,
        text=True,
        timeout=1500
    );
}


"""One real `jac scale build` of a small app, shared by the build and deploy
tests below. The project ships the zig-out binary as its [dev] pod_binary,
so the build downloads nothing and seals with that binary."""
def _built_app -> dict[str, str] {
    if _BUILT {
        return _BUILT;
    }
    binary = require_pod_binary();
    project = tempfile.mkdtemp(prefix="scale-build-");
    _write_app(project);
    Path(project, "jac.toml").write_text(
        '[project]\nname = "shop"\n\n[scale.kubernetes]\napp_name = "shop"\n'
            + 'namespace = "shop"\nbundle_storage_class = "standard"\n'
            + 'python_image = "python:3.12-slim"\n\n'
            + f'[dev]\npod_binary = "{binary}"\n'
    );
    os.mkdir(os.path.join(project, "tools"));
    Path(project, "tools", "jac.toml").write_text('[project]\nname = "tools"\n');
    out = project + "-build";
    result = _scale_cli(
        project, ["build", "main.jac", "--out", out, "--arch", "amd64"]
    );
    assert result.returncode == 0 , result.stdout + result.stderr;
    _BUILT.update({"project": project, "out": out});
    return _BUILT;
}


"""The bundle files a build directory holds."""
def _bundles(out: str) -> list[Path] {
    return sorted(
        path
        for path in Path(out).iterdir()
        if path.suffix == ".jab"
    );
}


def _apply_target(
    from_build: str = "",
    app_name: str = "shop",
    pod_arch: str = "x86_64",
    kubeconfig: str = ""
) -> KubernetesTarget {
    return KubernetesTarget(
        config=KubernetesConfig.from_dict(
            KubernetesConfig,
            {
                "app_name": app_name,
                "namespace": "shop",
                "bundle_storage_class": "standard",
                "python_image": "python:3.12-slim",
                "kubeconfig": kubeconfig
            }
        ),
        from_build=from_build,
        pod_arch=pod_arch
    );
}


test "jac scale build refuses to guess the node architecture" {
    with tempfile.TemporaryDirectory() as tmpdir {
        app = _write_app(tmpdir);
        out = os.path.join(tmpdir, "build");
        prior = os.environ.pop("JAC_NODE_ARCH", None);
        try {
            assert KubernetesRealizer().build(app, out_dir=out) == 2;
        } finally {
            if prior is not None {
                os.environ["JAC_NODE_ARCH"] = prior;
            }
        }
        assert not os.path.exists(out);
    }
}


test "jac scale build writes a bundle and a record that agree, with no cluster" {
    built = _built_app();
    record = json.loads(Path(built["out"], "build.json").read_text());
    raw = Path(built["out"], record["bundle_file"]).read_bytes();
    digest = hashlib.sha256(raw).hexdigest();
    assert record["bundle_sha256"] == digest , record;
    assert record["bundle_object_key"].endswith(f"/{digest}.jab") , record;
    assert record["bundle_size"] == len(raw) , record;
    assert (record["pod_arch"], record["channel"]) == ("x86_64", "local") , record;
    pod = hashlib.sha256(require_pod_binary().read_bytes()).hexdigest();
    assert record["pod_binary_sha256"] == pod , record;
    tomls: dict[str, str] = {};
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        for name in ("jac.toml", "tools/jac.toml") {
            member = tar.extractfile(name);
            assert member is not None , name;
            tomls[name] = member.read().decode("utf-8");
        }
    }
    canonical = json.dumps(tomls, sort_keys=True).encode("utf-8");
    assert record["config_sha256"] == hashlib.sha256(canonical).hexdigest() , record;
}


test "a deploy from a build renders the monolithic Deployments and builds nothing" {
    built = _built_app();
    project = built["project"];
    app = AppConfig(code_folder=project, file_name="main.jac");
    monolithic = _apply_target().generate_manifests(app)["deployments"];
    main = Path(project, "main.jac");
    source = main.read_text();
    # Any seal, install or client build of this tree now fails.
    main.write_text("this is not jac\n");
    plan_file = project + "-plan.json";
    try {
        applied = _apply_target(built["out"]).generate_manifests(app)["deployments"];
        result = _scale_cli(
            project,
            [
                "deploy",
                "main.jac",
                "--from-build",
                built["out"],
                "--dry-run",
                "--plan-out",
                plan_file
            ]
        );
    } finally {
        main.write_text(source);
    }
    assert applied == monolithic;
    assert result.returncode == 0 , result.stdout + result.stderr;
    plan = json.loads(Path(plan_file).read_text());
    by_name = {m["metadata"]["name"]: m for m in monolithic.values()};
    assert plan["expect"] == sorted(by_name) , plan["expect"];
    for (name, manifest) in by_name.items() {
        assert bundle_keys_from_pod_spec(
            plan["deployments"][name]["spec"]["template"]["spec"]
        )
            == bundle_keys_from_pod_spec(manifest["spec"]["template"]["spec"]) , name;
    }
}


test "a deploy from a build refuses a build that does not match it" {
    built = _built_app();
    project = built["project"];
    app = AppConfig(code_folder=project, file_name="main.jac");
    # (label, build.json edits, tamper the .jab, app, arch, jac.toml stamped, refusal)
    rows: list[tuple[str, dict[str, str], bool, str, str, str, str]] = [
        ("tampered bundle", {}, True, "shop", "x86_64", "", "is not the bundle"),
        (
            "other jac",
            {"jac_version": "0.0.1"},
            False,
            "shop",
            "x86_64",
            "",
            "built by jac 0.0.1"
        ),
        (
            "other app",
            {},
            False,
            "storefront",
            "x86_64",
            "",
            "and this deploy is 'storefront'"
        ),
        ("other arch", {}, False, "shop", "aarch64", "", "built for x86_64 nodes"),
        (
            "other runtime",
            {"pod_binary_sha256": "0" * 64},
            False,
            "shop",
            "x86_64",
            "",
            "pod jac runtime"
        ),
        (
            "stamped config",
            {},
            False,
            "shop",
            "x86_64",
            "jac.toml",
            "sealed into the build at jac.toml: scale.database.enabled"
        ),
        (
            "stamped nested config",
            {},
            False,
            "shop",
            "x86_64",
            "tools/jac.toml",
            "sealed into the build at tools/jac.toml: scale.database.enabled"
        ),

    ];
    for (label, edits, tamper, app_name, pod_arch, stamped, expected) in rows {
        copy = tempfile.mkdtemp(prefix="scale-build-copy-");
        shutil.rmtree(copy);
        shutil.copytree(built["out"], copy);
        if tamper {
            with open(_bundles(copy)[0], "ab") as f {
                f.write(b"\0");
            }
        }
        record_file = Path(copy, "build.json");
        record = json.loads(record_file.read_text());
        record.update(edits);
        record_file.write_text(json.dumps(record));
        toml = Path(project, stamped or "jac.toml");
        config = toml.read_text();
        if stamped {
            toml.write_text(config + "\n[scale.database]\nenabled = false\n");
        }
        refusal = "";
        try {
            _apply_target(
                copy, app_name=app_name, pod_arch=pod_arch
            ).generate_manifests(
                app
            );
        } except ValueError as e {
            refusal = str(e);
        } finally {
            toml.write_text(config);
            shutil.rmtree(copy, ignore_errors=True);
        }
        assert expected in refusal , f"{label}: {refusal!r}";
    }
}


test "a deploy refuses a mismatched build before it contacts the cluster" {
    built = _built_app();
    project = built["project"];
    copy = tempfile.mkdtemp(prefix="scale-build-copy-");
    shutil.rmtree(copy);
    shutil.copytree(built["out"], copy);
    record_file = Path(copy, "build.json");
    record = json.loads(record_file.read_text());
    record["jac_version"] = "0.0.1";
    record_file.write_text(json.dumps(record));
    # Any cluster contact (provisioning, namespace, nodes) fails on this kubeconfig
    # with a different error than the refusal.
    target = _apply_target(copy, kubeconfig=project + "-kubeconfig");
    result = target.deploy(AppConfig(code_folder=project, file_name="main.jac"));
    shutil.rmtree(copy, ignore_errors=True);
    assert not result.success;
    assert "built by jac 0.0.1" in str(result.message) , result.message;
}


test "publishing builds into one --out keeps exactly one complete build" {
    built = _built_app();
    project = built["project"];
    app = AppConfig(code_folder=project, file_name="main.jac");
    injector = _apply_target(built["out"])._manifest_builder(app)._injector_from_build(
        app
    );
    out = os.path.join(project, "build");
    problems: list[str] = [];
    try {
        first = _apply_target().build(app, out);
        second = _apply_target().build(app, out);
        if second["bundle_sha256"] != first["bundle_sha256"] {
            problems.append("an unchanged rebuild sealed a different bundle");
        }
        with tarfile.open(_bundles(out)[0], mode="r:gz") as tar {
            sealed = [
                name
                for name in tar.getnames()
                if name.endswith(".jab") or name.endswith("build.json")
            ];
        }
        if sealed {
            problems.append(f"the bundle sealed an earlier build: {sealed}");
        }
        injector._bundle_bytes = injector._bundle_bytes + gzip.compress(b"");
        injector.write_build(out, "shop");
        if len(_bundles(out)) != 1 {
            problems.append(f"a changed rebuild left {len(_bundles(out))} bundles");
        }
        refused = False;
        try {
            _apply_target().build(app, os.path.join(project, "artifacts"));
        } except ValueError {
            refused = True;
        }
        if not refused or os.path.exists(os.path.join(project, "artifacts")) {
            problems.append("an --out the bundle would ship was written");
        }
    } finally {
        shutil.rmtree(out, ignore_errors=True);
        shutil.rmtree(os.path.join(project, "artifacts"), ignore_errors=True);
    }
    parent = tempfile.mkdtemp(prefix="scale-publish-");
    again = os.path.join(parent, "again");
    injector.write_build(again, "shop");
    _bundles(again)[0].write_bytes(b"damaged");
    injector.write_build(again, "shop");
    if _bundles(again)[0].read_bytes() != injector._bundle_bytes {
        problems.append("a rebuild kept a damaged bundle");
    }
    owned = os.path.join(parent, ".mine.keep");
    os.mkdir(owned);
    Path(owned, "keep.txt").write_text("not a build");
    linked = os.path.join(parent, "mine");
    os.symlink(".mine.keep", linked);
    foreign = os.path.join(parent, "notes");
    os.mkdir(foreign);
    Path(foreign, "notes.txt").write_text("not a build");
    for candidate in (linked, foreign) {
        refused = False;
        try {
            injector.write_build(candidate, "shop");
        } except ValueError {
            refused = True;
        }
        if not refused {
            problems.append(f"{candidate} was published over");
        }
    }
    if not Path(owned, "keep.txt").is_file() {
        problems.append("a symlinked --out had its target deleted");
    }
    if os.listdir(foreign) != ["notes.txt"] {
        problems.append("a foreign --out was changed");
    }
    assert not problems , problems;
}
