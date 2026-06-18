"""Tests for no-image microservice deploy (copy local source, install at startup)."""

import io;
import tarfile;
import base64;
import tempfile;
import shutil;
import unittest.mock as mock;
import from pathlib { Path }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.microservice.source_bundle {
    pack_source,
    build_source_configmap,
    source_configmap_name,
    build_bootstrap_init_container,
    pinned_install_specs,
    auto_no_image_fallback,
    SOURCE_ARCHIVE_KEY,
    APP_MOUNT_PATH,
    PYDEPS_DIR
}

# =============================================================================
# source_bundle: packing
# =============================================================================
test "pack_source archives jac files and skips build artifacts" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");
    (Path(tmp) / "orders_app.jac").write_text("to sv:\n");
    sub = Path(tmp) / "shared";
    sub.mkdir();
    (sub / "models.jac").write_text("obj X {}\n");
    # excluded artifacts
    cache = Path(tmp) / ".jac";
    cache.mkdir();
    (cache / "junk.jbc").write_text("nope");
    nm = Path(tmp) / "node_modules";
    nm.mkdir();
    (nm / "dep.js").write_text("nope");

    raw = pack_source(tmp);
    names = set();
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        for m in tar.getmembers() {
            names.add(m.name);
        }
    }

    assert "main.jac" in names;
    assert "orders_app.jac" in names;
    assert "shared/models.jac" in names;
    assert not any([n.startswith(".jac/") for n in names]);
    assert not any([n.startswith("node_modules/") for n in names]);

    shutil.rmtree(tmp);
}

test "pack_source excludes secret files (.env, keys, certs, jac.toml)" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");
    (Path(tmp) / ".env").write_text("DB_PASSWORD=hunter2\n");
    (Path(tmp) / ".env.production").write_text("API_KEY=sk_live\n");
    (Path(tmp) / "jac.toml").write_text("[plugins.scale.kubernetes]\ndocker_password='p'\n");
    (Path(tmp) / "tls.key").write_text("PRIVATE KEY");
    (Path(tmp) / "server.pem").write_text("CERT");

    raw = pack_source(tmp);
    names = set();
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        for m in tar.getmembers() {
            names.add(m.name);
        }
    }

    assert "main.jac" in names;
    for secret in [".env", ".env.production", "jac.toml", "tls.key", "server.pem"] {
        assert secret not in names , f"{secret} must not be packed into the ConfigMap";
    }

    shutil.rmtree(tmp);
}

# =============================================================================
# auto_no_image_fallback: zero-config default
# =============================================================================
test "auto_no_image_fallback: no image/registry/build -> True (fallback)" {
    assert auto_no_image_fallback(False, "jac-shop:latest", "jac-shop:latest", "") == True;
    # bare default image still counts as 'no explicit image'
    assert auto_no_image_fallback(False, "", "jac-shop:latest", "") == True;
}

test "auto_no_image_fallback: explicit image or registry or --build -> False" {
    # explicit (non-default) image
    assert auto_no_image_fallback(False, "myrepo/app:v1", "jac-shop:latest", "") == False;
    # registry configured
    assert auto_no_image_fallback(False, "jac-shop:latest", "jac-shop:latest", "ghcr.io/me") == False;
    # --build forces the image pipeline
    assert auto_no_image_fallback(True, "jac-shop:latest", "jac-shop:latest", "") == False;
}

test "build_source_configmap holds the base64 archive in binaryData" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");

    cm = build_source_configmap("jac-shop", "jac-shop-dev", tmp);

    assert cm["kind"] == "ConfigMap";
    assert cm["metadata"]["name"] == "jac-shop-source";
    assert cm["metadata"]["namespace"] == "jac-shop-dev";
    assert cm["metadata"]["labels"]["jac-scale.role"] == "source";
    # binaryData value round-trips back to a valid gzip tar
    encoded = cm["binaryData"][SOURCE_ARCHIVE_KEY];
    raw = base64.b64decode(encoded);
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        assert "main.jac" in [m.name for m in tar.getmembers()];
    }

    shutil.rmtree(tmp);
}

test "build_source_configmap rejects oversized source trees" {
    tmp = tempfile.mkdtemp();
    # ~2MB of incompressible random-ish content blows the ConfigMap limit.
    import os;
    (Path(tmp) / "big.bin").write_bytes(os.urandom(2 * 1024 * 1024));
    raised = False;
    try {
        build_source_configmap("jac-shop", "default", tmp);
    } except ValueError {
        raised = True;
    }
    assert raised;
    shutil.rmtree(tmp);
}

test "pinned_install_specs pins jaclang and jac-scale" {
    specs = pinned_install_specs();
    joined = " ".join(specs);
    assert "jaclang" in joined;
    assert "jac-scale" in joined;
}

test "bootstrap init container extracts source and installs to pydeps" {
    init = build_bootstrap_init_container("python:3.12-slim");
    assert init["name"] == "jac-bootstrap";
    assert init["image"] == "python:3.12-slim";
    script = init["args"][0];
    assert "tar xzf" in script;
    assert f"--target={PYDEPS_DIR}" in script;
    mount_names = {m["name"] for m in init["volumeMounts"]};
    assert "jac-app" in mount_names;
    assert "jac-source" in mount_names;
}

# =============================================================================
# manifest_builder: no-image pod spec
# =============================================================================
test "no-image pod spec runs the python base image with source volumes" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg, no_image=True);

    spec = builder._build_service_pod_spec("orders_app", "ignored:image");
    container = spec["containers"][0];

    # Generic base image, not a built app image.
    assert container["image"] == "python:3.12-slim";
    assert container["workingDir"] == APP_MOUNT_PATH;

    pairs = {e["name"]: e["value"] for e in container["env"]};
    assert pairs.get("PYTHONPATH") == PYDEPS_DIR;
    assert PYDEPS_DIR in pairs.get("PATH", "");

    mount_paths = {m["mountPath"] for m in container["volumeMounts"]};
    assert APP_MOUNT_PATH in mount_paths;

    vol_names = {v["name"] for v in spec["volumes"]};
    assert "jac-app" in vol_names;
    assert "jac-source" in vol_names;
    # source ConfigMap volume references the right ConfigMap name
    src_vol = next((v for v in spec["volumes"] if v["name"] == "jac-source"), None);
    assert src_vol["configMap"]["name"] == source_configmap_name("jac-shop");

    init_names = {c["name"] for c in spec["initContainers"]};
    assert "jac-bootstrap" in init_names;
}

test "generate_manifests (no-image) emits a source ConfigMap + python-base pods" {
    tmp = tempfile.mkdtemp();
    (Path(tmp) / "main.jac").write_text("to cl:\n");
    (Path(tmp) / "orders_app.jac").write_text("to sv:\n");

    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, no_image=True, project_dir=tmp
    );
    app_config = AppConfig(code_folder=tmp, file_name="main.jac", no_image=True);

    fake_cfg = mock.MagicMock();
    fake_cfg.get_microservices_config.return_value = {
        "routes": {"orders_app": "/api/orders"},
        "services": {},
        "ingress": {},
        "shared_volumes": [],
        "logs": {},
        "drain_timeout_seconds": 10
    };
    with mock.patch(
        "jac_scale.config_loader.get_scale_config", return_value=fake_cfg
    ) {
        bundle = builder.generate_manifests(app_config, "python:3.12-slim");
    }

    # The source ConfigMap is in the bundle and carries the packed archive.
    assert "source_configmap" in bundle;
    cm = bundle["source_configmap"];
    assert cm["metadata"]["name"] == "jac-shop-source";
    assert SOURCE_ARCHIVE_KEY in cm["binaryData"];

    # Both the service and the gateway run on the python base image.
    orders_dep = bundle["deployments"]["orders_app"];
    pod = orders_dep["spec"]["template"]["spec"];
    assert pod["containers"][0]["image"] == "python:3.12-slim";
    assert "jac-bootstrap" in {c["name"] for c in pod["initContainers"]};

    shutil.rmtree(tmp);
}


test "image-mode pod spec is unchanged (no source volumes / bootstrap)" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg, no_image=False);

    spec = builder._build_service_pod_spec("orders_app", "jac-shop:dev-abc123");
    container = spec["containers"][0];

    assert container["image"] == "jac-shop:dev-abc123";
    assert "workingDir" not in container;
    assert "volumes" not in spec;
    assert "initContainers" not in spec;
}
