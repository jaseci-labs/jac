import os;
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

# The host's own jac.toml, in the shape of the builder service that hit this in
# production: a jac-scale app that deploys other apps in-process, whose
# shared_volumes name is an env placeholder its own pod never resolved.
glob _HOST_TOML: str = '[project]\n'
     'name = "builder"\n'
     'entry-point = "main.jac"\n'
     '\n'
     '[scale.microservices]\n'
     'routes = { builder_sv = "/builder" }\n'
     'shared_volumes = [{ name = "${SHARED_DATA_PVC}", '
     'mount_path = "/app/.jachome", services = ["builder_sv"], '
     'size = "10Gi", access_mode = "ReadWriteMany", storage_class = "efs-sc" }]\n';


def _load_host_config -> str {
    # Load a real jac.toml process-globally, the way a running host app has its
    # own config loaded while it deploys a guest.
    project_dir = tempfile.mkdtemp(prefix="jac-host-config-");
    (Path(project_dir) / "jac.toml").write_text(_HOST_TOML);
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}


def _unload_host_config(project_dir: str) {
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}


def _guest_builder(ms_config: (dict[str, any] | None)) -> ManifestBuilder {
    # A guest app that declares no [scale.microservices] of its own; the SDK
    # hands the builder the spec's config, which for such an app is empty.
    return ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="standup", namespace="jb-standup"),
        microservices_config=ms_config
    );
}


test "the host's config really loads, so the leak tests are meaningful" {
    project_dir = _load_host_config();
    try {
        host_cfg = get_scale_config().get_microservices_config();
        # Normalization injects the implicit main service alongside the
        # declared routes; both belong to the host's own serving topology.
        assert host_cfg.get("routes", {})
            == {"builder_sv": "/builder", "main": "/__main__"};
        assert len(host_cfg.get("shared_volumes", [])) == 1;
    } finally {
        _unload_host_config(project_dir);
    }
}


test "a guest that declares no microservices config gets none of the host's" {
    project_dir = _load_host_config();
    try {
        resolved = _guest_builder({})._ms_cfg();
    } finally {
        _unload_host_config(project_dir);
    }

    assert resolved.get("shared_volumes", []) == [] , f"guest inherited the host's shared_volumes: {resolved.get(
        'shared_volumes'
    )}";
    assert resolved.get("routes", {}) == {} , f"guest inherited the host's routes: {resolved.get(
        'routes'
    )}";
}


test "a guest's manifest bundle carries no PVC built from the host's config" {
    project_dir = _load_host_config();
    try {
        pvcs = _guest_builder({})._build_shared_pvc_manifests();
    } finally {
        _unload_host_config(project_dir);
    }

    assert pvcs == {} , f"host shared_volumes leaked into the guest bundle: {pvcs}";
}


test "an omitted microservices config still falls back to the loaded one" {
    project_dir = _load_host_config();
    try {
        resolved = _guest_builder(None)._ms_cfg();
    } finally {
        _unload_host_config(project_dir);
    }

    assert resolved.get("routes", {})
        == {"builder_sv": "/builder", "main": "/__main__"} , "the CLI path must keep reading the app's own loaded config";
}


test "a supplied config does not take routes from JAC_SV_ROUTES" {
    project_dir = _load_host_config();
    previous = os.environ.get("JAC_SV_ROUTES");
    os.environ["JAC_SV_ROUTES"] = '{"builder_sv": "/builder"}';
    try {
        resolved = _guest_builder({})._ms_cfg();
    } finally {
        if previous is None {
            os.environ.pop("JAC_SV_ROUTES", None);
        } else {
            os.environ["JAC_SV_ROUTES"] = previous;
        }
        _unload_host_config(project_dir);
    }

    assert resolved.get("routes", {}) == {} , f"guest inherited the host's routes via env: {resolved.get(
        'routes'
    )}";
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


# An unresolved placeholder is an operator error, not a name to be cleaned up:
# sanitizing "${SHARED_DATA_PVC}" to "shared-data-pvc" would quietly provision a
# volume nobody asked for.
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
