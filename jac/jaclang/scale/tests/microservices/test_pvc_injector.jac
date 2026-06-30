import os;
import io;
import tarfile;
import tempfile;
import from jaclang.scale.injector.bundle { pack_source }
import from jaclang.scale.injector.pvc_injector { PvcInjector, build_bundle_pvc }


test "pack_source keeps scale capability intents but strips only the secrets sub-table (both forms)" {
    with tempfile.TemporaryDirectory() as project {
        with open(os.path.join(project, "app.jac"), "w") as handle {
            handle.write("walker Main {}");
        }
        with open(os.path.join(project, ".env"), "w") as handle {
            handle.write("SECRET=1");
        }
        with open(os.path.join(project, "tls.key"), "w") as handle {
            handle.write("PRIVATE");
        }
        with open(os.path.join(project, "jac.toml"), "w") as handle {
            # plugins.scale.secrets.* = a top-level dotted secret key (must strip);
            # [plugins.scale.database] = a capability intent (must survive so the
            # pod's `jac install` resolves it); [plugins.scale.secrets] and
            # [scale.secrets] = the secrets sub-table in both forms (must strip).
            handle.write(
                "plugins.scale.secrets.jwt = \"topsecret\"\n" + "[project]\nname = \"x\"\n" + "[plugins.scale.database]\nbackend = \"mongo\"\n" + "[plugins.scale.secrets]\nmongodb_uri = \"mongodb://u:p@h\"\n" + "[scale.secrets]\napi_key = \"shhhh\"\n"
            );
        }
        raw = pack_source(project);
        names: list[str] = [];
        toml_text = "";
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
            names = tar.getnames();
            toml_text = tar.extractfile("jac.toml").read().decode("utf-8");
        }
        assert "app.jac" in names;
        assert ".env" not in names;
        assert "tls.key" not in names;
        assert "[project]" in toml_text;
        assert "name = \"x\"" in toml_text;
        # capability intent survives the bundle (the #7069 regression)
        assert "[plugins.scale.database]" in toml_text;
        assert "backend = \"mongo\"" in toml_text;
        # secrets are stripped symmetrically in both forms
        assert "[plugins.scale.secrets]" not in toml_text;
        assert "[scale.secrets]" not in toml_text;
        assert "topsecret" not in toml_text;
        assert "mongodb" not in toml_text;
        assert "shhhh" not in toml_text;
    }
}


test "the bundle pvc is ReadWriteMany so every pod can mount it" {
    pvc = build_bundle_pvc("orders", "prod", "5Gi", "efs-sc");
    assert pvc["kind"] == "PersistentVolumeClaim";
    assert pvc["spec"]["accessModes"] == ["ReadWriteMany"];
    assert pvc["spec"]["storageClassName"] == "efs-sc";
}


test "prepare + mutate_pod_spec wires the pvc, an init container, and the app mount" {
    with tempfile.TemporaryDirectory() as project {
        with open(os.path.join(project, "app.jac"), "w") as handle {
            handle.write("walker Main {}");
        }
        injector = PvcInjector();
        injector.prepare("orders", "prod", project);
        pod_spec: dict[str, any] = {
            "_jac_meta": {"app_name": "orders", "namespace": "prod"},
            "containers": [{"name": "app", "image": "python:3.12-slim"}]
        };
        result = injector.mutate_pod_spec(pod_spec, "python:3.12-slim");
        volume_names = [volume["name"] for volume in result["volumes"]];
        assert "jac-app" in volume_names;
        assert "jac-bundles" in volume_names;
        assert len(result["initContainers"]) == 1;
        mount_names = [
            mount["name"] for mount in result["containers"][0]["volumeMounts"]
        ];
        assert "jac-app" in mount_names;
    }
}
