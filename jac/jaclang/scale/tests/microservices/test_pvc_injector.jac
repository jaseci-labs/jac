import os;
import io;
import tarfile;
import tempfile;
import tomllib;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { sanitized_jac_toml, pack_jab }
import from jaclang.scale.tests.support { pod_binary, require_pod_binary }
import from jaclang.scale.injector.pvc_injector {
    PvcInjector,
    build_bundle_pvc,
    build_loader_pod,
    BUNDLE_MOUNT_PATH,
    RUNTIME_UID,
    RUNTIME_GID,
    build_pvc_init_container,
    bundle_keys_from_pod_spec
}


glob _JAC_BIN: Path = pod_binary();


def _make_project(project: str, toml: str) {
    with open(os.path.join(project, "app.jac"), "w") as handle {
        handle.write("walker Main {}");
    }
    with open(os.path.join(project, "jac.toml"), "w") as handle {
        handle.write(toml);
    }
}


def _sanitized_toml(project: str) -> dict {
    # sanitized_jac_toml owns the strip logic pack_jab ships verbatim, so
    # assert it directly instead of running a full (binary-dependent) seal.
    return tomllib.loads(sanitized_jac_toml(Path(project)) or "");
}


test "secrets are stripped and secret-bearing files excluded from the sealed .jab" {
    require_pod_binary();
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
                "plugins.scale.secrets.jwt = \"topsecret\"\n"
                    + "[project]\nname = \"x\"\n"
                    + "[plugins.scale.database]\nurl = \"env:JAC_DB_URL\"\n"
                    + "# s3 access creds\n[scale.secrets]\napi_key = \"shhhh\"\n"
                    + "db_password = \"p@ssw0rd\"\ntoken = \"nestedshh\"\n"
            );
        }
        raw = pack_jab(project, _JAC_BIN.read_bytes());
        names: list[str] = [];
        toml_text = "";
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
            names = tar.getnames();
            toml_member = tar.extractfile("jac.toml");
            assert toml_member is not None;
            toml_text = toml_member.read().decode("utf-8");
        }
        assert "app.jac" in names;
        assert "_precompiled/MANIFEST.json" in names;
        assert ".env" not in names;
        assert "tls.key" not in names;
        assert "[plugins.scale.database]" in toml_text;
        assert "[plugins.scale.secrets]" not in toml_text;
        assert "[scale.secrets]" not in toml_text;
        assert "topsecret" not in toml_text;
        assert "p@ssw0rd" not in toml_text;
        assert "shhhh" not in toml_text;
        assert "nestedshh" not in toml_text;
    }
}


test "a dotted secret key inside a plugin table is stripped with its annotation" {
    with tempfile.TemporaryDirectory() as project {
        _make_project(
            project,
            "[project]\nname = \"x\"\n"
                + "[plugins.scale]\n# nested creds annotation\nsecrets.token = \"nestedshh\"\n"
                + "[plugins.scale.database]\nurl = \"env:JAC_DB_URL\"\n"
        );
        text = sanitized_jac_toml(Path(project)) or "";
        assert "nestedshh" not in text , text;
        assert "nested creds annotation" not in text , text;
        data = tomllib.loads(text);
        assert "secrets" not in data["plugins"]["scale"] , data;
        assert data["plugins"]["scale"]["database"]["url"] == "env:JAC_DB_URL";
    }
}


test "no database intent is fabricated into the shipped manifest (#8000)" {
    # bake_database_intent used to append a backend the pod's install would
    # map to a data capability; INTENT_RULES no longer maps any database
    # value, so the whole baking path is gone and the toml ships as written.
    with tempfile.TemporaryDirectory() as project {
        _make_project(project, "[project]\nname = \"x\"\nversion = \"0.1.0\"\n");
        data = _sanitized_toml(project);
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
    assert spec["securityContext"]["fsGroup"] == RUNTIME_GID;
    assert spec["securityContext"]["runAsUser"] == RUNTIME_UID;
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
    assert f"{RUNTIME_UID}:{RUNTIME_GID}" in script;
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


# Bundle retention (#8089): the keep-set has to be derived from what a pod
# template actually mounts, so the reader is driven by the writer's own output
# rather than a hand-written arg string. A consumer that reimplements this
# parsing hardcodes the container name and the mount layout.
test "bundle keys round-trip from the init container the injector builds" {
    keys = ["bundles/orders/aaa.jab", "toolchain/orders/bbb.tar.gz"];
    pod_spec = {
        "initContainers": [
            build_pvc_init_container(
                "python:3.12-slim", [f"{BUNDLE_MOUNT_PATH}/{k}" for k in keys]
            )
        ]
    };

    assert bundle_keys_from_pod_spec(pod_spec) == keys;
}


test "a pod spec with no bootstrap container references no bundles" {
    assert bundle_keys_from_pod_spec({}) == [];
    assert bundle_keys_from_pod_spec(
        {"initContainers": [{"name": "wait-for-postgres", "args": ["sleep 1"]}]}
    )
        == [];
}
