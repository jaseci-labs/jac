import os;
import tempfile;
import unittest.mock;
import from pathlib { Path }

import from jaclang.scale.config.config_loader { JacScaleConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.microservice.database_provisioner {
    MicroserviceDatabaseProvisioner
}
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jaclang.scale.models.deploy_context { DeployContext }


glob PROJECT_HEADER: str = (
         '[project]\nname = "byoapp"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n'
     ),
     BYO_TOML: str = (
         '[project]\nname = "byoapp"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n'
         '[scale.database.db]\ntype = "postgres"\nsource = "external"\n'
         'url = "postgres://app:pw@db.host:5432/app"\n\n'
         '[scale.database.cache]\ntype = "redis"\nsource = "external"\n'
         'url = "redis://cache.host:6379/0"\n\n'
         '[scale.auth]\ntype = "custom"\n'
         'issuer = "https://ref.supabase.co/auth/v1"\naudience = "authenticated"\n'
     );


def _k8s_config_from_toml(toml_text: str) -> dict[str, any] {
    tmp = tempfile.mkdtemp();
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(toml_text);
    }
    return JacScaleConfig(project_dir=Path(tmp)).get_kubernetes_config();
}


test "byo declarations are the inventory: nothing managed, urls wired" {
    cfg = _k8s_config_from_toml(BYO_TOML);
    assert cfg["mongodb_enabled"] is False;
    assert cfg["redis_enabled"] is False;
    backends = cfg["backends"];
    assert sorted(backends.keys()) == ["cache", "db"];
    assert backends["db"] == {
        "type": "postgres",
        "source": "external",
        "url": "postgres://app:pw@db.host:5432/app",
        "env": "DATABASE_URL"
    };
    assert backends["cache"]["env"] == "REDIS_URL";
    auth = cfg["external_auth"];
    assert auth["type"] == "custom";
    assert auth["issuer"] == "https://ref.supabase.co/auth/v1";
}


test "zero-config default still provisions managed mongo and redis" {
    cfg = _k8s_config_from_toml(PROJECT_HEADER);
    assert cfg["mongodb_enabled"] is True;
    assert cfg["redis_enabled"] is True;
    assert cfg["backends"]["mongo"] == {"type": "mongo", "source": "managed"};
    assert cfg["backends"]["redis"] == {"type": "redis", "source": "managed"};
    assert cfg["external_auth"]["type"] == "managed";
}


test "a declared inventory replaces the defaults entirely" {
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER + '[scale.database.graph]\ntype = "mongo"\nsource = "managed"\n'
    );
    assert cfg["mongodb_enabled"] is True;
    assert cfg["redis_enabled"] is False;
    assert list(cfg["backends"].keys()) == ["graph"];
}


test "url implies source external; source disabled drops the backend" {
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER + '[scale.database.db]\ntype = "postgres"\nurl = "postgres://h/app"\n\n' + '[scale.database.graph]\ntype = "mongo"\nsource = "disabled"\n'
    );
    assert cfg["backends"]["db"]["source"] == "external";
    assert "graph" not in cfg["backends"];
    assert cfg["mongodb_enabled"] is False;
}


test "provision = false with no declarations is a compute-only deploy" {
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER + '[scale.database]\nprovision = false\n'
    );
    assert cfg["backends"] == {};
    assert cfg["mongodb_enabled"] is False;
    assert cfg["redis_enabled"] is False;
}


test "legacy kubernetes flags still work when nothing is declared" {
    cfg = _k8s_config_from_toml(
        PROJECT_HEADER + '[scale.kubernetes]\nmongodb_enabled = false\n'
    );
    assert cfg["mongodb_enabled"] is False;
    assert cfg["redis_enabled"] is True;
    assert list(cfg["backends"].keys()) == ["redis"];
}


test "urls resolve from the environment via interpolation" {
    os.environ["BYO_TEST_DB_URL"] = "postgres://resolved.host/app";
    try {
        cfg = _k8s_config_from_toml(
            PROJECT_HEADER + '[scale.database.db]\ntype = "postgres"\n' + 'url = "${BYO_TEST_DB_URL}"\n'
        );
        assert cfg["backends"]["db"]["url"] == "postgres://resolved.host/app";
    } finally {
        del os.environ["BYO_TEST_DB_URL"];
    }
}


test "an unresolved url env var fails instead of shipping the literal" {
    os.environ.pop("BYO_TEST_MISSING_URL", None);
    error = "";
    try {
        _k8s_config_from_toml(
            PROJECT_HEADER + '[scale.database.db]\ntype = "postgres"\n' + 'url = "${BYO_TEST_MISSING_URL}"\n'
        );
    } except ValueError as e {
        error = str(e);
    }
    assert "BYO_TEST_MISSING_URL" in error and "not set" in error;
}


test "invalid declarations fail with clear errors" {
    cases = {
        "external needs url": (
            '[scale.database.db]\ntype = "postgres"\nsource = "external"\n',
            "'url'"
        ),
        "managed rejects url": (
            '[scale.database.cache]\ntype = "redis"\nsource = "managed"\n'
            'url = "redis://h:6379"\n',
            "does not apply to a managed backend"
        ),
        "managed postgres unsupported": (
            '[scale.database.db]\ntype = "postgres"\nsource = "managed"\n',
            "not supported yet"
        ),
        "type required": ('[scale.database.db]\nsource = "managed"\n', "'type'"),
        "env collision": (
            '[scale.database.a]\ntype = "redis"\nurl = "redis://a"\n\n'
            '[scale.database.b]\ntype = "redis"\nurl = "redis://b"\n',
            "both inject the env var"
        ),
        "bad source": (
            '[scale.database.db]\ntype = "postgres"\nsource = "remote"\n',
            "source must be"
        ),
        "bad auth type": ('[scale.auth]\ntype = "supabase"\n', "[scale.auth].type")
    };
    for (label, case) in cases.items() {
        (snippet, expected) = case;
        error = "";
        try {
            _k8s_config_from_toml(PROJECT_HEADER + snippet);
        } except ValueError as e {
            error = str(e);
        }
        assert expected in error , f"{label}: expected {expected!r} in {error!r}";
    }
}


test "provisioner ships external urls through the app secret, provisions nothing" {
    mock_target = unittest.mock.MagicMock();
    mock_target.env_list = [];
    mock_target.secrets = {"EXISTING": "kept"};
    mock_target.k8s_config = KubernetesConfig.from_dict(
        KubernetesConfig, _k8s_config_from_toml(BYO_TOML)
    );

    provisioner = MicroserviceDatabaseProvisioner(k8s_target=mock_target, enabled=True);
    ctx = provisioner.provision("byo-app");

    mock_target._deploy_databases.assert_not_called();
    mock_target._load_kube_config.assert_not_called();
    assert ctx.init_containers == [];
    assert mock_target.secrets == {
        "EXISTING": "kept",
        "DATABASE_URL": "postgres://app:pw@db.host:5432/app",
        "REDIS_URL": "redis://cache.host:6379/0"
    };
    by_name = {e["name"]: e["value"] for e in ctx.env_list};
    assert by_name["JAC_AUTH_TYPE"] == "custom";
    assert by_name["JAC_AUTH_ISSUER"] == "https://ref.supabase.co/auth/v1";
    assert by_name["JAC_AUTH_AUDIENCE"] == "authenticated";
}


def _identity_mutate(spec: dict[str, any], image: str) -> dict[str, any] {
    return spec;
}


test "the app secret reaches service pods as envFrom" {
    builder = MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="byo", namespace="byo-ns", python_image="img"
        ),
        secrets={"DATABASE_URL": "postgres://app:pw@db.host:5432/app"},
        deploy_context=DeployContext(),
        microservices_config={"routes": {"svc_a": "/a"}, "services": {"svc_a": {}}},
        dry_run=True
    );
    secret_manifest = builder._build_user_secret_manifest();
    assert secret_manifest["stringData"]["DATABASE_URL"] == "postgres://app:pw@db.host:5432/app";

    with unittest.mock.patch(
        "jaclang.scale.injector.binary_injector.BinaryInjector"
    ) as mock_injector {
        mock_injector.return_value.mutate_pod_spec.side_effect = _identity_mutate;
        spec = builder._build_pod_spec("svc_a", "img");
    }
    env_from = spec["containers"][0]["envFrom"];
    assert {"secretRef": {"name": "byo-secrets"}} in env_from;
}
