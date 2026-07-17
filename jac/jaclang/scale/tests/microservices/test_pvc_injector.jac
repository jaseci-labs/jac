import os;
import io;
import tarfile;
import tempfile;
import tomllib;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.scale.injector.bundle {
    bake_database_intent,
    sanitized_jac_toml,
    pack_jab
}
import from jaclang.scale.injector.pvc_injector {
    PvcInjector,
    build_bundle_pvc,
    BUNDLE_MOUNT_PATH,
    LOADER_UID,
    LOADER_GID
}


glob _JAC_BIN: Path = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";


def _make_project(project: str, toml: str) {
    with open(os.path.join(project, "app.jac"), "w") as handle {
        handle.write("walker Main {}");
    }
    with open(os.path.join(project, "jac.toml"), "w") as handle {
        handle.write(toml);
    }
}


def _baked_toml(project: str, database: str = "") -> dict {
    # sanitized_jac_toml owns the strip + bake logic pack_jab ships verbatim, so
    # assert it directly instead of running a full (binary-dependent) seal.
    return tomllib.loads(sanitized_jac_toml(Path(project), database) or "");
}


test "secrets are stripped and secret-bearing files excluded from the sealed .jab" {
    if not _JAC_BIN.is_file() {
        return;
    }
    with tempfile.TemporaryDirectory() as project {
        with open(os.path.join(project, "app.jac"), "w") as handle {
            handle.write("with entry { print(\"ok\"); }");
        }
        with open(os.path.join(project, ".env"), "w") as handle {
            handle.write("SECRET=1");
        }
        with open(os.path.join(project, "tls.key"), "w") as handle {
            handle.write("PRIVATE");
        }
        with open(os.path.join(project, "jac.toml"), "w") as handle {
            handle.write(
                "plugins.scale.secrets.jwt = \"topsecret\"\n" + "[project]\nname = \"x\"\n" + "[plugins.scale.database]\nbackend = \"mongo\"\n" + "[plugins.scale]\n# nested creds annotation\nsecrets.token = \"nestedshh\"\n" + "[plugins.scale.secrets]\nmongodb_uri = \"mongodb://u:p@h\"\n" + "# s3 access creds\n[scale.secrets]\napi_key = \"shhhh\"\n"
            );
        }
        raw = pack_jab(project, "", _JAC_BIN.read_bytes());
        names: list[str] = [];
        toml_text = "";
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
            names = tar.getnames();
            toml_text = tar.extractfile("jac.toml").read().decode("utf-8");
        }
        assert "app.jac" in names;
        assert "_precompiled/MANIFEST.json" in names;
        assert ".env" not in names;
        assert "tls.key" not in names;
        assert "[plugins.scale.database]" in toml_text;
        assert "backend = \"mongo\"" in toml_text;
        assert "[plugins.scale.secrets]" not in toml_text;
        assert "[scale.secrets]" not in toml_text;
        assert "topsecret" not in toml_text;
        assert "mongodb" not in toml_text;
        assert "shhhh" not in toml_text;
        assert "nestedshh" not in toml_text;
    }
}


test "the provisioned database is baked into an intent-less manifest (#7137)" {
    with tempfile.TemporaryDirectory() as project {
        _make_project(project, "[project]\nname = \"x\"\nversion = \"0.1.0\"\n");
        data = _baked_toml(project, "mongo");
        assert data["plugins"]["scale"]["database"]["backend"] == "mongo";
    }
}


test "a declared database backend is never overridden" {
    with tempfile.TemporaryDirectory() as project {
        _make_project(
            project,
            "[project]\nname = \"x\"\n\n[plugins.scale.database]\nbackend = \"redis\"\n"
        );
        data = _baked_toml(project, "mongo");
        assert data["plugins"]["scale"]["database"]["backend"] == "redis";
    }
}


test "the database bakes into [scale.database] when the project uses the [scale] form" {
    with tempfile.TemporaryDirectory() as project {
        _make_project(
            project, "[project]\nname = \"x\"\n\n[scale.events]\nbackend = \"redis\"\n"
        );
        data = _baked_toml(project, "mongo");
        # scale_intent_from_config prefers [scale] over [plugins.scale], so the
        # baked intent must land where the pod will actually read it.
        assert data["scale"]["database"]["backend"] == "mongo";
        assert "plugins" not in data;
    }
}


test "bake_database_intent warns and ships unbaked when the toml will not parse" {
    broken = "[project\nname = \"x\"\n";
    with patch("logging.Logger.warning") as mock_warn {
        assert bake_database_intent(broken, "mongo") == broken;
        mock_warn.assert_called_once();
    }
}


test "nothing is baked when no database is provisioned" {
    with tempfile.TemporaryDirectory() as project {
        _make_project(project, "[project]\nname = \"x\"\n");
        data = _baked_toml(project);
        assert "plugins" not in data;
        assert "scale" not in data;
    }
}


test "the bundle pvc is ReadWriteMany so every pod can mount it" {
    pvc = build_bundle_pvc("orders", "prod", "5Gi", "efs-sc");
    assert pvc["kind"] == "PersistentVolumeClaim";
    assert pvc["spec"]["accessModes"] == ["ReadWriteMany"];
    assert pvc["spec"]["storageClassName"] == "efs-sc";
}


test "the bundle pvc fails fast when RWX is requested without a storage class" {
    raised = False;
    try {
        build_bundle_pvc("orders", "prod", "5Gi", "");
    } except ValueError as e {
        raised = True;
        assert "orders-bundles" in str(e);
        assert "ReadWriteMany" in str(e);
        assert "bundle_storage_class" in str(e);
    }
    assert raised , "Expected ValueError for an RWX bundle PVC without a storage class";
}


test "host_path mode emits no bundle PVC (#7433)" {
    injector = PvcInjector(host_path="/mnt/jac/bundles");
    assert injector.extra_manifests("orders", "prod") == [];
}


test "host_path mode mounts the host directory instead of a PVC claim (#7433)" {
    injector = PvcInjector(host_path="/mnt/jac/bundles");
    injector._object_key = "bundles/orders/aaa.jab";
    injector._bundle_bytes = b"jab";
    pod_spec: dict[str, any] = {
        "_jac_meta": {"app_name": "orders", "namespace": "prod"},
        "containers": [{"name": "app", "image": "python:3.12-slim"}]
    };
    result = injector.mutate_pod_spec(pod_spec, "python:3.12-slim");
    bundle_vols = [
        volume
        for volume in result["volumes"]
        if volume["name"] == "jac-bundles"
    ];
    assert len(bundle_vols) == 1;
    assert bundle_vols[0]["hostPath"] == {
        "path": "/mnt/jac/bundles",
        "type": "DirectoryOrCreate"
    };
    assert bundle_vols[0].get("persistentVolumeClaim") is None;
}


test "the loader pod stages bundles onto the host directory in host_path mode (#7433)" {
    injector = PvcInjector(host_path="/mnt/jac/bundles");
    pod = injector._loader_pod_manifest("orders");
    volumes = {volume["name"]: volume for volume in pod["spec"]["volumes"]};
    assert volumes["bundles"]["hostPath"] == {
        "path": "/mnt/jac/bundles",
        "type": "DirectoryOrCreate"
    };
    # kubelet never chowns hostPath volumes (fsGroup does not apply) and creates
    # missing directories root-owned, so the loader must run as root to write
    # there - acceptable for a local-single-node-only mode. runAsUser is set
    # explicitly (not left to the image default) so this is image-independent.
    assert pod["spec"]["securityContext"].get("runAsNonRoot") is None;
    assert pod["spec"]["securityContext"]["runAsUser"] == 0;
    assert pod["spec"]["containers"][0]["securityContext"]["runAsUser"] == 0;
    # A root loader writes the mount directly, so no bundle-perms init container.
    assert pod["spec"].get("initContainers") is None;
}


test "the loader pod keeps fsGroup for storage that honors it in PVC mode (#7432)" {
    injector = PvcInjector(storage_class="efs-sc");
    pod = injector._loader_pod_manifest("orders");
    assert pod["kind"] == "Pod";
    assert pod["metadata"]["name"] == "orders-bundle-loader";
    spec = pod["spec"];
    assert spec["securityContext"]["runAsNonRoot"];
    assert spec["securityContext"]["fsGroup"] == LOADER_GID;
    assert spec["securityContext"]["runAsUser"] == LOADER_UID;
    claims = [
        v["persistentVolumeClaim"]["claimName"]
        for v in spec["volumes"]
        if "persistentVolumeClaim" in v
    ];
    assert claims == ["orders-bundles"];
}


test "the loader pod makes the bundle volume root writable without fsGroup in PVC mode (#7432)" {
    # fsGroup alone is not enough: kubelet never applies it to hostPath or NFS
    # volumes, and CSI drivers with the default fsGroupPolicy skip ReadWriteMany
    # volumes -- exactly what the bundle PVC must be. On any such storage the
    # non-root loader hits "mkdir: Permission denied" at the root-owned volume
    # root. The pod must therefore hand the mount to the loader's uid/gid itself.
    injector = PvcInjector(storage_class="efs-sc");
    pod = injector._loader_pod_manifest("orders");
    inits = pod["spec"].get("initContainers", []);
    assert len(inits) == 1 , (
        "the loader pod needs a volume-permission init container: fsGroup is "
        "not applied on hostPath/NFS or RWX CSI volumes (#7432)"
    );
    perms = inits[0];
    assert perms["image"] == "busybox:1.36";
    # It must run as root to chown a root-owned volume root, but stay hardened.
    sc = perms["securityContext"];
    assert sc["runAsUser"] == 0;
    assert sc["runAsNonRoot"] == False;
    assert sc["allowPrivilegeEscalation"] == False;
    assert sc["readOnlyRootFilesystem"] == True;
    assert sc["capabilities"]["drop"] == ["ALL"];
    assert set(sc["capabilities"]["add"]) == {"CHOWN", "FOWNER", "DAC_OVERRIDE"};
    # And it must actually chown/chmod the bundle mount to the loader identity.
    script = perms["command"][-1];
    assert f"{LOADER_UID}:{LOADER_GID}" in script;
    assert BUNDLE_MOUNT_PATH in script;
    assert "chown" in script;
    assert "chmod" in script;
    mounts = [m["mountPath"] for m in perms["volumeMounts"]];
    assert mounts == [BUNDLE_MOUNT_PATH];
}


test "bundle_storage_class and bundle_host_path are mutually exclusive" {
    import from jaclang.scale.injector.binary_injector { select_injector }
    raised = False;
    with tempfile.TemporaryDirectory() as project {
        try {
            select_injector(
                "efs-sc", "orders", "prod", str(project), host_path="/mnt/jac/bundles"
            );
        } except ValueError as e {
            raised = True;
            assert "bundle_storage_class" in str(e);
            assert "bundle_host_path" in str(e);
        }
    }
    assert raised , "Expected ValueError when both bundle stores are configured";
}


test "the missing-storage-class error points at bundle_host_path for local clusters" {
    raised = False;
    try {
        build_bundle_pvc("orders", "prod", "5Gi", "");
    } except ValueError as e {
        raised = True;
        assert "bundle_host_path" in str(e);
    }
    assert raised;
}


test "bundle_host_path flows from [scale.kubernetes] into the deploy config" {
    import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        KubernetesConfig
    }
    cfg = KubernetesConfig.from_dict(
        KubernetesConfig, {"bundle_host_path": "/mnt/jac/bundles"}
    );
    assert cfg.bundle_host_path == "/mnt/jac/bundles";
    assert cfg.to_dict()["bundle_host_path"] == "/mnt/jac/bundles";
    assert KubernetesConfig.from_dict(KubernetesConfig, {}).bundle_host_path == "";
}


test "a relative bundle_host_path is rejected at config-parse time" {
    import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        KubernetesConfig
    }
    raised = False;
    try {
        KubernetesConfig.from_dict(KubernetesConfig, {"bundle_host_path": "bundles"});
    } except ValueError as e {
        raised = True;
        assert "absolute path" in str(e);
        assert "bundle_host_path" in str(e);
    }
    assert raised , "Expected ValueError for a relative bundle_host_path";
}


test "mutate_pod_spec wires the pvc, an init container, and the app mount" {
    injector = PvcInjector();
    # Inject seeded state directly so this test exercises mutate_pod_spec wiring
    # without a pod binary (prepare() now seals into a .jab and requires one).
    injector._object_key = "bundles/orders/aaa.jab";
    injector._bundle_bytes = b"jab";
    pod_spec: dict[str, any] = {
        "_jac_meta": {"app_name": "orders", "namespace": "prod"},
        "containers": [{"name": "app", "image": "python:3.12-slim"}]
    };
    result = injector.mutate_pod_spec(pod_spec, "python:3.12-slim");
    volume_names = [volume["name"] for volume in result["volumes"]];
    assert "jac-app" in volume_names;
    assert "jac-bundles" in volume_names;
    assert len(result["initContainers"]) == 1;
    mount_names = [mount["name"] for mount in result["containers"][0]["volumeMounts"]];
    assert "jac-app" in mount_names;
}
