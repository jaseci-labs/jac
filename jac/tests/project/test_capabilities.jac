"""Tests for jaclang.project.capabilities -- the capability registry."""

import os;
import tempfile;
import shutil;
import from pathlib { Path }
import from unittest.mock { patch }

import from jaclang.project.config { JacConfig }
import from jaclang.project.providers {
    InstallContext,
    PythonProvider,
    capability_dependencies,
    get_python_provider
}
import from jaclang.project.pyvenv { make_pip_spec }
import from jaclang.project.capabilities {
    Capability,
    CapabilityClosure,
    CAPABILITY_SPECS,
    RUNTIME,
    DEPLOY,
    all_capability_names,
    capability_for_package,
    command_capabilities,
    derive_capabilities,
    ensure_global_capability,
    get_capability,
    get_capability_registry,
    missing_capability_dists,
    missing_capability_error,
    package_missing_error,
    resolve_closure,
    resolve_closures,
    resolve_config_closures,
    scale_intent_from_config
}

def reset_config {
    import from jaclang.project { config as config_mod }
    config_mod._config = None;
}

def make_project(toml: str) -> tuple[str, Path] {
    tmp = tempfile.mkdtemp(prefix="jac_cap_test_");
    project_dir = Path(tmp) / "proj";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(toml);
    return (tmp, project_dir);
}

glob SERVE_PKGS = ["python-dotenv"],
     DEPLOY_PKGS = ["kubernetes", "docker"],
     DB_DRIVER_PKGS = ["pymongo", "redis", "sqlalchemy", "psycopg", "psycopg2"];

# ===== Registry =====
test "registry builds a Capability per spec entry" {
    registry = get_capability_registry();
    assert set(registry.keys()) == set(CAPABILITY_SPECS.keys());
    for (name, cap) in registry.items() {
        assert isinstance(cap, Capability);
        assert cap.name == name;
        assert cap.context in (RUNTIME, DEPLOY);
        assert len(cap.deps) >= 1;
    }
}

test "registry is a cached singleton" {
    assert get_capability_registry() is get_capability_registry();
}

test "serve is runtime, deploy.k8s is deploy-context" {
    registry = get_capability_registry();
    assert registry["serve"].context == RUNTIME;
    assert registry["deploy.k8s"].context == DEPLOY;
    assert "kubernetes" in registry["deploy.k8s"].deps;
    assert "docker" in registry["deploy.k8s"].deps;
}

test "get_capability returns None for unknown" {
    assert get_capability("nope") is None;
    assert "serve" in all_capability_names();
    assert "monitoring" in all_capability_names();
}

# ===== Intent derivation =====
test "retired data capabilities are gone from the registry (#8000)" {
    for retired in ["data.mongo", "data.redis", "data.sql"] {
        assert get_capability(retired) is None;
        assert retired not in all_capability_names();
    }
}

test "legacy database backends imply no capability (#8000)" {
    # Pre-0.36 tomls carried [scale.database] backend = "mongo"/"redis"; those
    # drivers are gone, so the intent maps to nothing rather than closing a
    # served app over pymongo/redis.
    assert derive_capabilities({"database": {"backend": "mongo"}}, []) == set();
    assert derive_capabilities({"database": {"backend": "redis"}}, []) == set();
    assert derive_capabilities({"events": {"backend": "redis"}}, []) == set();
}

test "deploy target implies deploy.k8s" {
    caps = derive_capabilities({"deploy": {"target": "kubernetes"}}, []);
    assert "deploy.k8s" in caps;
}

test "enabled flags imply capabilities" {
    caps = derive_capabilities(
        {
            "monitoring": {"enabled": True},
            "tracing": {"enabled": True},
            "scheduler": {"enabled": False}
        },
        []
    );
    assert "monitoring" in caps;
    assert "tracing" in caps;
    assert "scheduler" not in caps;
}

test "storage backends derive capabilities" {
    caps = derive_capabilities({"storage": {"backend": "s3"}}, []);
    assert "storage.s3" in caps;
}

test "command-implied capabilities are merged in" {
    caps = derive_capabilities(
        {"monitoring": {"enabled": True}}, command_capabilities("serve", scale=True)
    );
    assert "serve" in caps;
    assert "deploy.k8s" in caps;
    assert "monitoring" in caps;
}

test "empty or non-dict intent yields only command caps" {
    assert derive_capabilities({}, ["serve"]) == {"serve"};
    assert derive_capabilities(None, ["serve"]) == {"serve"};
    assert derive_capabilities({}, None) == set();
}

test "serve derives no database capability under any intent (#8000)" {
    # #7137's auto-added data.mongo silently closed every served/deployed scale
    # app over pymongo, which no code path can use since #7947. The Postgres
    # driver is vendored with the runtime, never installed as a capability.
    for intent in [
        {},
        {"gateway": {"colocate": False}},
        {"database": {"type": "postgres"}}
    ] {
        for caps_cmds in [
            command_capabilities("serve"),
            command_capabilities("serve", scale=True)
        ] {
            caps = derive_capabilities(intent, caps_cmds);
            data_caps = [
                c
                for c in caps
                if c.startswith("data.")
            ];
            assert data_caps == [] , f"intent {intent} derived {data_caps}";
        }
    }
}

# ===== command_capabilities =====
test "command_capabilities maps action and scale flag" {
    assert command_capabilities("serve") == ["serve"];
    assert command_capabilities("serve", scale=True) == ["serve", "deploy.k8s"];
    assert command_capabilities("execute") == [];
    assert command_capabilities("build") == [];
}

# ===== Closure resolution =====
test "runtime closure excludes deploy-context deps" {
    closure = resolve_closure({"serve", "deploy.k8s"}, RUNTIME);
    assert "deploy.k8s" not in closure.capabilities;
    assert "serve" in closure.capabilities;
    for pkg in DEPLOY_PKGS {
        assert pkg not in closure.deps;
    }
    for pkg in SERVE_PKGS {
        assert pkg in closure.deps;
    }
}

test "deploy closure includes everything" {
    closure = resolve_closure({"serve", "deploy.k8s"}, DEPLOY);
    assert "deploy.k8s" in closure.capabilities;
    assert "serve" in closure.capabilities;
    for pkg in DEPLOY_PKGS {
        assert pkg in closure.deps;
    }
}

test "closure deps carry the registry pins" {
    closure = resolve_closure({"monitoring"}, RUNTIME);
    assert closure.deps["prometheus-client"] == ">=0.21.0,<1.0.0";
}

test "resolve_closure raises on unknown capability" {
    raised = False;
    try {
        resolve_closure({"serve", "bogus"}, RUNTIME);
    } except ValueError as e {
        raised = True;
        assert "bogus" in str(e);
        assert "Available:" in str(e);
    }
    assert raised , "Expected ValueError for unknown capability";
}

test "resolve_closures returns both contexts" {
    closures = resolve_closures({"serve", "monitoring", "deploy.k8s"});
    assert closures[RUNTIME].context == RUNTIME;
    assert closures[DEPLOY].context == DEPLOY;
    assert "kubernetes" not in closures[RUNTIME].deps;
    assert "kubernetes" in closures[DEPLOY].deps;
}

test "CapabilityClosure helpers" {
    empty = resolve_closure(set(), RUNTIME);
    assert empty.is_empty();
    full = resolve_closure({"serve"}, RUNTIME);
    assert not full.is_empty();
    assert full.package_names() == sorted(full.deps.keys());
}

# ===== Headline acceptance: the k8s split =====
test "k8s split -- pod runtime never carries kubernetes, docker, or a db driver" {
    intent = {"monitoring": {"enabled": True}};
    caps = derive_capabilities(intent, command_capabilities("serve", scale=True));
    closures = resolve_closures(caps);

    runtime = closures[RUNTIME];
    deploy = closures[DEPLOY];

    # Runtime (pod image): serve + monitoring, never deploy clients and never
    # a database driver -- Postgres support is vendored with the runtime.
    assert "python-dotenv" in runtime.deps;
    assert "prometheus-client" in runtime.deps;
    assert "kubernetes" not in runtime.deps;
    assert "docker" not in runtime.deps;
    for pkg in DB_DRIVER_PKGS {
        assert pkg not in runtime.deps , f"serve closure must not carry {pkg}";
        assert pkg not in deploy.deps , f"deploy closure must not carry {pkg}";
    }

    # Deploy (operator/CI): everything, including kubernetes + docker.
    assert "kubernetes" in deploy.deps;
    assert "docker" in deploy.deps;
}

test "plain run pulls zero scale deps" {
    closures = resolve_closures(
        derive_capabilities({}, command_capabilities("execute"))
    );
    assert closures[RUNTIME].is_empty();
    assert closures[DEPLOY].is_empty();
}

# ===== Config integration =====
test "resolve_config_closures reads [scale] intent from jac.toml" {
    reset_config();
    (tmp, project_dir) = make_project(
        '[project]\nname = "svc"\nversion = "0.1.0"\n\n[scale.monitoring]\nenabled = true\n'
    );
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        intent = scale_intent_from_config(config);
        assert intent["monitoring"]["enabled"] is True;

        closures = resolve_config_closures(config, action="serve", scale=True);
        assert "prometheus-client" in closures[RUNTIME].deps;
        assert "kubernetes" not in closures[RUNTIME].deps;
        assert "kubernetes" in closures[DEPLOY].deps;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "scale serve with no scale sections carries no database driver (#8000)" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        closures = resolve_config_closures(config, action="serve", scale=True);
        for pkg in DB_DRIVER_PKGS {
            assert pkg not in closures[RUNTIME].deps;
            assert pkg not in closures[DEPLOY].deps;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "scale_intent_from_config empty when no scale section" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        assert scale_intent_from_config(config) == {};
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

# ===== Reverse lookup + capability-oriented errors =====
test "capability_for_package reverse lookup" {
    assert capability_for_package("pymongo") is None;  # retired with #8000
    assert capability_for_package("kubernetes") == "deploy.k8s";
    assert capability_for_package("prometheus_client") == "monitoring";  # underscore normalized
    assert capability_for_package("nonexistent") is None;
}

test "missing_capability_error is capability-oriented, never mentions jac-scale extras" {
    msg = missing_capability_error("storage.s3");
    assert "storage.s3" in msg;
    assert "boto3" in msg;
    assert "jac install" in msg;
    assert "jac-scale[" not in msg;
    assert "pip install" not in msg;

    deploy_msg = missing_capability_error("deploy.k8s");
    assert "operator machine" in deploy_msg;

    assert "Unknown capability" in missing_capability_error("bogus");
}

test "package_missing_error routes through the providing capability" {
    msg = package_missing_error("boto3");
    assert "boto3" in msg;
    assert "storage.s3" in msg;
    assert "jac-scale[" not in msg;

    orphan = package_missing_error("some-random-lib");
    assert "jac install some-random-lib" in orphan;
}

# ===== Installer integration (.jac/venv sync) =====
test "python provider installs a capability closure into .jac/venv" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        python = PythonProvider();
        closure = resolve_closure({"serve", "deploy.k8s"}, RUNTIME);
        specs = [
            make_pip_spec(pkg, ver) for (pkg, ver) in sorted(closure.deps.items())
        ];
        with patch("jaclang.project.providers.ensure_venv") as _ev, patch.object(
            PythonProvider, "_run_project_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "Successfully installed", "");
            result = python.install_specs(config, specs, InstallContext());
            assert result;
            install_calls = [
                c
                for c in mock_pip.call_args_list
                if c.args[1] and c.args[1][0] == "install"
            ];
            assert install_calls , "expected a pip install call";
            installed_args: list = list(install_calls[0].args[1]);
            assert "python-dotenv>=1.2.1,<2.0.0" in installed_args;
            # runtime closure must not push deploy clients to pip
            assert "kubernetes>=34.1.0,<35.0.0" not in installed_args;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "installing an empty spec list is a no-op success" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        python = PythonProvider();
        with patch.object(PythonProvider, "_run_project_pip") as mock_pip {
            result = python.install_specs(config, [], InstallContext());
            assert result;
            mock_pip.assert_not_called();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

# ===== Global capability sync (deploy tooling on the operator machine) =====
test "missing_capability_dists reports pinned specs for absent distributions" {
    import from importlib { metadata }
    with patch("importlib.metadata.distribution") as mock_dist {
        mock_dist.side_effect = metadata.PackageNotFoundError("gone");
        missing = missing_capability_dists("deploy.k8s");
        assert missing
            == [
                "docker>=7.1.0,<8.0.0",
                "kubernetes>=34.1.0,<35.0.0",
                "requests>=2.32.0,<3.0.0"
            ];
    }
    assert missing_capability_dists("bogus") == [];
}

test "ensure_global_capability pip-installs only the missing deploy tooling" {
    import sys;
    import from importlib { metadata }
    with patch("importlib.metadata.distribution") as mock_dist, patch(
        "subprocess.run"
    ) as mock_run {
        # first sweep: kubernetes + requests present, docker absent;
        # recheck: all three present
        mock_dist.side_effect = [
            object(),
            metadata.PackageNotFoundError("docker"),
            object(),
            object(),
            object(),
            object()
        ];
        mock_run.return_value.returncode = 0;
        assert ensure_global_capability("deploy.k8s");
        mock_run.assert_called_once();
        cmd: list = list(mock_run.call_args[0][0]);
        assert cmd
            == [
                sys.executable,
                "-m",
                "pip",
                "install",
                "--quiet",
                "docker>=7.1.0,<8.0.0"
            ];
    }
}

test "ensure_global_capability reports failure and logs when pip errors" {
    import from importlib { metadata }
    with patch("importlib.metadata.distribution") as mock_dist, patch(
        "subprocess.run"
    ) as mock_run, patch("logging.Logger.warning") as mock_warn {
        mock_dist.side_effect = metadata.PackageNotFoundError("gone");
        mock_run.return_value.returncode = 1;
        mock_run.return_value.stderr = "No matching distribution found";
        assert not ensure_global_capability("deploy.k8s");
        mock_warn.assert_called_once();
        assert "No matching distribution found" in mock_warn.call_args[0][0];
    }
}

test "ensure_global_capability is a no-op when tooling is already present" {
    with patch("importlib.metadata.distribution"), patch(
        "subprocess.run"
    ) as mock_run {
        assert ensure_global_capability("deploy.k8s");
        mock_run.assert_not_called();
    }
    assert not ensure_global_capability("bogus");
}

# ===== Install wiring (capability_dependencies) =====
def make_service_project(scale_toml: str) -> tuple[str, Path] {
    tmp = tempfile.mkdtemp(prefix="jac_capinst_");
    project_dir = Path(tmp) / "svc";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(
        '[project]\nname = "svc"\nversion = "0.1.0"\nkind = "service"\n'
        'entry-point = "main.jac"\n\n'
            + scale_toml
    );
    (project_dir / "main.jac").write_text("with entry {\n    print(\"hi\");\n}\n");
    return (tmp, project_dir);
}

def _capability_specs(config: JacConfig, scale: bool) -> list[str] {
    python = PythonProvider();
    return python.specs_for(capability_dependencies(config, scale=scale));
}

test "capability_dependencies resolves runtime closure from config + kind" {
    reset_config();
    (tmp, project_dir) = make_service_project('[scale.monitoring]\nenabled = true\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        deps = capability_dependencies(config, scale=False);
        specs = _capability_specs(config, scale=False);
        joined = " ".join(specs);
        # serve (command-implied by the service kind) + monitoring (config-implied)
        assert "python-dotenv>=1.2.1,<2.0.0" in specs;
        assert "prometheus-client>=0.21.0,<1.0.0" in specs;
        # runtime closure must never carry deploy-only clients or a db driver
        assert "kubernetes" not in joined;
        assert "docker" not in joined;
        assert "pymongo" not in joined;
        assert "sqlalchemy" not in joined;
        # every entry is traceable to the capability that pulled it in
        origins = {d.name: d.origin for d in deps};
        assert origins["prometheus-client"] == "capability:monitoring";
        assert origins["python-dotenv"] == "capability:serve";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "capability_dependencies --scale adds the deploy closure" {
    reset_config();
    (tmp, project_dir) = make_service_project(
        '[scale.deploy]\ntarget = "kubernetes"\n'
    );
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        specs = _capability_specs(config, scale=True);
        assert "kubernetes>=34.1.0,<35.0.0" in specs;
        assert "docker>=7.1.0,<8.0.0" in specs;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "scale app inferred as kind=cli still installs the serve closure (#7206)" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_capinst_");
    project_dir = Path(tmp) / "svc";
    project_dir.mkdir();
    # No [project] kind + plain main.jac -> resolve_app_kind infers "cli"
    # (action="execute"), yet [scale] means the app is served.
    (project_dir / "jac.toml").write_text(
        '[project]\nname = "svc"\nversion = "0.1.0"\nentry-point = "main.jac"\n\n'
        '[scale.monitoring]\nenabled = true\n'
    );
    (project_dir / "main.jac").write_text("with entry {\n    print(\"hi\");\n}\n");
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        # plain install: serve deps land despite kind=cli
        runtime = _capability_specs(config, scale=False);
        assert "python-dotenv>=1.2.1,<2.0.0" in runtime;
        assert "prometheus-client>=0.21.0,<1.0.0" in runtime;
        assert "kubernetes" not in " ".join(runtime);
        # --scale additionally pulls the deploy clients
        deploy = _capability_specs(config, scale=True);
        assert "kubernetes>=34.1.0,<35.0.0" in deploy;
        assert "docker>=7.1.0,<8.0.0" in deploy;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "capability_dependencies is empty for a plain cli project" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_capinst_");
    project_dir = Path(tmp) / "cli";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(
        '[project]\nname = "cli"\nversion = "0.1.0"\nkind = "cli"\nentry-point = "main.jac"\n'
    );
    (project_dir / "main.jac").write_text("with entry {\n    print(\"hi\");\n}\n");
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        assert capability_dependencies(config, scale=False) == [];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "capability_dependencies honors detected intents" {
    reset_config();
    tmp = tempfile.mkdtemp(prefix="jac_capinst_");
    project_dir = Path(tmp) / "cli";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(
        '[project]\nname = "cli"\nversion = "0.1.0"\nkind = "cli"\nentry-point = "main.jac"\n'
    );
    (project_dir / "main.jac").write_text("with entry {\n    print(\"hi\");\n}\n");
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        deps = capability_dependencies(config, detected_intents=["llm"]);
        names = {d.name for d in deps};
        assert "litellm" in names;
        origins = {d.origin for d in deps};
        assert origins == {"capability:llm"};
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}
