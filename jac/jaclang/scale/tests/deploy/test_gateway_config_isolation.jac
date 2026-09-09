"""Kubernetes names and an unreadable gateway config.

`k8s_safe_name` must only ever yield an RFC 1123 label, and a jac.toml the
loader cannot read must fail the deploy at every reader instead of answering
the same default an unconfigured app gets."""

import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    GATEWAY_NAME,
    ManifestBuilder,
    k8s_safe_name
}


def _load_broken_config -> str {
    # An unterminated section header: the loader cannot parse this file, so
    # the readers below must refuse rather than answer {}.
    project_dir = tempfile.mkdtemp(prefix="jac-broken-config-");
    (Path(project_dir) / "jac.toml").write_text(
        '[project]\nname = "broken-app"\n[scale.gateway\n'
    );
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}


def _unload_config(project_dir: str) {
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}


def _builder -> ManifestBuilder {
    return ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="standup", namespace="jb-standup")
    );
}


test "k8s_safe_name only ever yields an RFC 1123 name" {
    import re;
    rfc1123 = re.compile(r"^[a-z0-9]([-a-z0-9]*[a-z0-9])?$");
    for raw in [
        "shared_data_pvc",
        "Orders_App",
        "-leading",
        "trailing-",
        "vol!name",
        "a" * 300,
        "under__scores"
    ] {
        safe = k8s_safe_name(raw);
        assert rfc1123.`match(safe) , f"{raw!r} produced non-RFC-1123 name {safe!r}";
        assert len(safe) <= 253 , f"{raw!r} produced a {len(safe)}-char name";
    }
}


test "k8s_safe_name refuses an unresolved env placeholder" {
    raised = False;
    try {
        k8s_safe_name("${SHARED_DATA_PVC}");
    } except ValueError as e {
        raised = True;
        assert "SHARED_DATA_PVC" in str(e);
        assert "placeholder" in str(e);
    }
    assert raised , "expected an unresolved placeholder to raise";
}


test "k8s_safe_name rejects a name with nothing usable left" {
    raised = False;
    try {
        k8s_safe_name("!!!");
    } except ValueError as e {
        raised = True;
        assert "!!!" in str(e);
    }
    assert raised , "expected a name with no usable characters to raise";
}


test "the gateway keeps its reserved short name" {
    assert k8s_safe_name(GATEWAY_NAME) == "gateway";
}


test "an unreadable jac.toml fails the deploy, not into a default topology" {
    project_dir = _load_broken_config();
    try {
        builder = _builder();
        raised = "";
        try {
            builder._service_config(GATEWAY_NAME);
        } except Exception as e {
            raised = str(e);
        }
        assert raised != "" , (
            "an unreadable jac.toml answered a default instead of raising, so "
            "the deploy would have proceeded on a topology the user never "
            "configured"
        );
        assert "jac.toml" in raised , (
            f"the failure {raised!a} does not name the file it could not read"
        );
    } finally {
        _unload_config(project_dir);
    }
}


test "every gateway reader refuses a config it could not read" {
    project_dir = _load_broken_config();
    try {
        builder = _builder();
        answered: list[str] = [];
        try {
            builder._drain_timeout();
            answered.append("_drain_timeout");
        } except Exception {}
        try {
            builder._shared_volumes_config();
            answered.append("_shared_volumes_config");
        } except Exception {}
        try {
            builder._service_config(GATEWAY_NAME);
            answered.append("_service_config");
        } except Exception {}
        try {
            builder._gateway_cfg();
            answered.append("_gateway_cfg");
        } except Exception {}
        assert sorted(answered) == [] , (
            f"{sorted(answered)} answered a default for a config that could not "
            "be read"
        );
    } finally {
        _unload_config(project_dir);
    }
}
