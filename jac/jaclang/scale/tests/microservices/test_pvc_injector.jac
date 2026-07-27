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
    build_loader_pod,
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


test "the loader pod keeps fsGroup for storage that honors it (#7432)" {
    pod = build_loader_pod("orders-bundle-loader", "orders-bundles", "busybox:1.36");
    assert pod["kind"] == "Pod";
    assert pod["metadata"]["name"] == "orders-bundle-loader";
    spec = pod["spec"];
    assert spec["securityContext"]["fsGroup"] == LOADER_GID;
    assert spec["securityContext"]["runAsUser"] == LOADER_UID;
    claims = [
        v["persistentVolumeClaim"]["claimName"]
        for v in spec["volumes"]
        if "persistentVolumeClaim" in v
    ];
    assert claims == ["orders-bundles"];
}


test "the loader pod makes the bundle volume root writable without fsGroup (#7432)" {
    # fsGroup alone is not enough: kubelet never applies it to hostPath or NFS
    # volumes, and CSI drivers with the default fsGroupPolicy skip ReadWriteMany
    # volumes -- exactly what the bundle PVC must be. On any such storage the
    # non-root loader hits "mkdir: Permission denied" at the root-owned volume
    # root. The pod must therefore hand the mount to the loader's uid/gid itself.
    pod = build_loader_pod("orders-bundle-loader", "orders-bundles", "busybox:1.36");
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
