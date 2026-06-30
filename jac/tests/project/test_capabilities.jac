"""Tests for jaclang.project.capabilities -- the capability registry."""

import os;
import tempfile;
import shutil;
import from pathlib { Path }
import from unittest.mock { patch }

import from jaclang.project.config { JacConfig }
import from jaclang.project.dependencies {
    DependencyInstaller,
    capability_specs_for_install
}
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
    get_capability,
    get_capability_registry,
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

glob SERVE_PKGS = [
         "fastapi",
         "uvicorn[standard]",
         "pyjwt",
         "python-multipart",
         "bcrypt"
     ],
     DEPLOY_PKGS = ["kubernetes", "docker"];

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
    assert "data.mongo" in all_capability_names();
}

# ===== Intent derivation =====
test "config backend implies data capability" {
    caps = derive_capabilities({"database": {"backend": "mongo"}}, []);
    assert "data.mongo" in caps;
    assert "data.redis" not in caps;

    caps2 = derive_capabilities({"database": {"backend": "redis"}}, []);
    assert "data.redis" in caps2;
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

test "events redis and storage backends derive capabilities" {
    caps = derive_capabilities(
        {"events": {"backend": "redis"}, "storage": {"backend": "s3"}}, []
    );
    assert "data.redis" in caps;
    assert "storage.s3" in caps;
}

test "command-implied capabilities are merged in" {
    caps = derive_capabilities(
        {"database": {"backend": "mongo"}}, command_capabilities("serve", scale=True)
    );
    assert "serve" in caps;
    assert "deploy.k8s" in caps;
    assert "data.mongo" in caps;
}

test "empty or non-dict intent yields only command caps" {
    assert derive_capabilities({}, ["serve"]) == {"serve"};
    assert derive_capabilities(None, ["serve"]) == {"serve"};
    assert derive_capabilities({}, None) == set();
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
    closure = resolve_closure({"data.mongo"}, RUNTIME);
    assert closure.deps["pymongo"] == ">=4.15.4,<5.0.0";
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
    closures = resolve_closures({"serve", "data.mongo", "deploy.k8s"});
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
test "k8s split -- pod runtime never carries kubernetes or docker" {
    intent = {"database": {"backend": "mongo"}};
    caps = derive_capabilities(intent, command_capabilities("serve", scale=True));
    closures = resolve_closures(caps);

    runtime = closures[RUNTIME];
    deploy = closures[DEPLOY];

    # Runtime (pod image): serve + mongo, never deploy clients.
    assert "fastapi" in runtime.deps;
    assert "pymongo" in runtime.deps;
    assert "kubernetes" not in runtime.deps;
    assert "docker" not in runtime.deps;

    # Deploy (operator/CI): everything, including kubernetes + docker.
    assert "pymongo" in deploy.deps;
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
        '[project]\nname = "svc"\nversion = "0.1.0"\n\n[scale.database]\nbackend = "mongo"\n'
    );
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        intent = scale_intent_from_config(config);
        assert intent["database"]["backend"] == "mongo";

        closures = resolve_config_closures(config, action="serve", scale=True);
        assert "pymongo" in closures[RUNTIME].deps;
        assert "fastapi" in closures[RUNTIME].deps;
        assert "kubernetes" not in closures[RUNTIME].deps;
        assert "kubernetes" in closures[DEPLOY].deps;
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
    assert capability_for_package("pymongo") == "data.mongo";
    assert capability_for_package("kubernetes") == "deploy.k8s";
    assert capability_for_package("prometheus_client") == "monitoring";  # underscore normalized
    assert capability_for_package("nonexistent") is None;
}

test "missing_capability_error is capability-oriented, never mentions jac-scale extras" {
    msg = missing_capability_error("data.mongo");
    assert "data.mongo" in msg;
    assert "pymongo" in msg;
    assert "jac install" in msg;
    assert "jac-scale[" not in msg;
    assert "pip install" not in msg;

    deploy_msg = missing_capability_error("deploy.k8s");
    assert "operator machine" in deploy_msg;

    assert "Unknown capability" in missing_capability_error("bogus");
}

test "package_missing_error routes through the providing capability" {
    msg = package_missing_error("pymongo");
    assert "pymongo" in msg;
    assert "data.mongo" in msg;
    assert "jac-scale[" not in msg;

    orphan = package_missing_error("some-random-lib");
    assert "jac add some-random-lib" in orphan;
}

# ===== Installer integration (.jac/venv sync) =====
test "get_capability_specs renders sorted pip specs" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        closure = resolve_closure({"data.mongo", "data.redis"}, RUNTIME);
        specs = installer.get_capability_specs(closure);
        assert "pymongo>=4.15.4,<5.0.0" in specs;
        assert "redis>=7.1.0,<8.0.0" in specs;
        assert specs == sorted(specs);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "sync_capabilities installs the closure into .jac/venv" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        closure = resolve_closure({"serve", "deploy.k8s"}, RUNTIME);
        with patch.object(installer, "ensure_venv") as _ev, patch.object(
            installer, "_run_pip"
        ) as mock_pip {
            mock_pip.return_value = (0, "Successfully installed", "");
            result = installer.sync_capabilities(closure);
            assert result;
            install_calls = [
                c
                for c in mock_pip.call_args_list
                if c[0][0] and c[0][0][0] == "install"
            ];
            assert install_calls , "expected a pip install call";
            installed_args: list = list(install_calls[0][0][0]);
            assert "fastapi>=0.121.3,<0.122.0" in installed_args;
            # runtime closure must not push deploy clients to pip
            assert "kubernetes>=34.1.0,<35.0.0" not in installed_args;
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "sync_capabilities on empty closure is a no-op success" {
    reset_config();
    (tmp, project_dir) = make_project('[project]\nname = "svc"\nversion = "0.1.0"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        with patch.object(installer, "install_package") as mock_install {
            result = installer.sync_capabilities(resolve_closure(set(), RUNTIME));
            assert result;
            mock_install.assert_not_called();
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

# ===== Install wiring (capability_specs_for_install) =====
def make_service_project(scale_toml: str) -> tuple[str, Path] {
    tmp = tempfile.mkdtemp(prefix="jac_capinst_");
    project_dir = Path(tmp) / "svc";
    project_dir.mkdir();
    (project_dir / "jac.toml").write_text(
        '[project]\nname = "svc"\nversion = "0.1.0"\nkind = "service"\n'
        'entry-point = "main.sv.jac"\n\n' + scale_toml
    );
    (project_dir / "main.sv.jac").write_text("with entry {\n    print(\"hi\");\n}\n");
    return (tmp, project_dir);
}

test "capability_specs_for_install resolves runtime closure from config + kind" {
    reset_config();
    (tmp, project_dir) = make_service_project('[scale.database]\nbackend = "mongo"\n');
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        specs = capability_specs_for_install(config, installer, scale=False);
        joined = " ".join(specs);
        # serve (command-implied by the service kind) + mongo (config-implied)
        assert "fastapi>=0.121.3,<0.122.0" in specs;
        assert "pymongo>=4.15.4,<5.0.0" in specs;
        # runtime closure must never carry deploy-only clients
        assert "kubernetes" not in joined;
        assert "docker" not in joined;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "capability_specs_for_install --scale adds the deploy closure" {
    reset_config();
    (tmp, project_dir) = make_service_project(
        '[scale.database]\nbackend = "mongo"\n\n[scale.deploy]\ntarget = "kubernetes"\n'
    );
    try {
        config = JacConfig.load(project_dir / "jac.toml");
        installer = DependencyInstaller(config=config);
        specs = capability_specs_for_install(config, installer, scale=True);
        joined = " ".join(specs);
        assert "pymongo>=4.15.4,<5.0.0" in specs;
        assert "kubernetes>=34.1.0,<35.0.0" in specs;
        assert "docker>=7.1.0,<8.0.0" in specs;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}

test "capability_specs_for_install is empty for a plain cli project" {
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
        installer = DependencyInstaller(config=config);
        assert capability_specs_for_install(config, installer, scale=False) == [];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
        reset_config();
    }
}
