"""Tests for source bundling and the PVC code injector."""

import os;
import io;
import tarfile;
import tempfile;
import from jac_scale.injector.bundle {
    pack_source,
    content_address,
    bundle_object_key,
    pinned_install_specs
}
import from jac_scale.injector.pvc_injector {
    PvcInjector,
    build_bundle_pvc,
    build_pvc_init_container,
    bundle_pvc_name,
    bundle_pvc_path
}


test "content_address is deterministic and sha256-shaped" {
    first = content_address("hello".encode("utf-8"));
    same = content_address("hello".encode("utf-8"));
    other = content_address("world".encode("utf-8"));
    assert first == same;
    assert first != other;
    assert len(first) == 64;
}


test "bundle_object_key namespaces by app and addresses by digest" {
    assert bundle_object_key("orders", "abc123") == "bundles/orders/abc123.tar.gz";
}


test "pinned_install_specs always includes jaclang and the scale extras" {
    joined = " ".join(pinned_install_specs());
    assert "jaclang" in joined;
    assert "jac-scale[all]" in joined;
    assert "requests" in joined;
}


test "pack_source keeps app files but drops secrets and strips plugins.scale" {
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
            handle.write("[project]\nname = \"x\"\n[plugins.scale.kubernetes]\nimage_registry = \"creds\"\n");
        }
        raw = pack_source(project);
        names: list[str] = [];
        toml_text = "";
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
            names = tar.getnames();
            member = tar.extractfile("jac.toml");
            toml_text = member.read().decode("utf-8");
        }
        assert "app.jac" in names;
        assert ".env" not in names;
        assert "tls.key" not in names;
        assert "[project]" in toml_text;
        assert "plugins.scale" not in toml_text;
    }
}


test "bundle pvc is ReadWriteMany and carries the configured size" {
    pvc = build_bundle_pvc("orders", "prod", "5Gi", "efs-sc");
    assert pvc["kind"] == "PersistentVolumeClaim";
    assert pvc["metadata"]["name"] == bundle_pvc_name("orders");
    assert pvc["spec"]["accessModes"] == ["ReadWriteMany"];
    assert pvc["spec"]["resources"]["requests"]["storage"] == "5Gi";
    assert pvc["spec"]["storageClassName"] == "efs-sc";
}


test "bundle pvc omits storageClassName when none is set (cluster default)" {
    pvc = build_bundle_pvc("orders", "prod", "1Gi", "");
    assert "storageClassName" not in pvc["spec"];
}


test "init container extracts the bundle from the mounted pvc and installs" {
    container = build_pvc_init_container("python:3.12-slim", "/jac-bundles/bundles/orders/abc.tar.gz");
    script = container["args"][0];
    assert "tar xzf /jac-bundles/bundles/orders/abc.tar.gz" in script;
    assert "pip install" in script;
    mount_names = [mount["name"] for mount in container["volumeMounts"]];
    assert "jac-bundles" in mount_names;
    assert "jac-app" in mount_names;
}


test "mutate_pod_spec mounts the pvc, adds an init container and an app mount" {
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
        mount_names = [mount["name"] for mount in result["containers"][0]["volumeMounts"]];
        assert "jac-app" in mount_names;
    }
}


test "extra_manifests returns exactly the bundle pvc" {
    injector = PvcInjector();
    manifests = injector.extra_manifests("orders", "prod");
    assert len(manifests) == 1;
    assert manifests[0]["kind"] == "PersistentVolumeClaim";
}
