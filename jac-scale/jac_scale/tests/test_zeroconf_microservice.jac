"""Tests for zero-config microservice mode: source-driven service discovery
(no [plugins.scale.microservices] block), route auto-fill, and the
--no-image ConfigMap source-injection deploy path."""

import os;
import from pathlib { Path }
import from jac_scale.microservices.discovery {
    discover_services,
    resolve_microservices_config,
    reset_discovery_cache
}
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.microservices.images.base_image { base_image_tag }


glob _FIXTURE: str = os.path.join(
         os.path.dirname(__file__), "fixtures", "zeroconf_ms"
     );


# --------------------------------------------------------------------------
# Discovery
# --------------------------------------------------------------------------
test "discover_services finds `to sv:` modules and excludes the entry/gateway" {
    reset_discovery_cache();
    routes = discover_services(_FIXTURE);
    # greeter + counter_app are services; main (entry) and models (pure data)
    # are not.
    assert set(routes.keys()) == {"greeter", "counter_app"} , f"got {routes}";
}

test "discover_services derives conventional prefixes (strips _app)" {
    reset_discovery_cache();
    routes = discover_services(_FIXTURE);
    assert routes["greeter"] == "/api/greeter";
    assert routes["counter_app"] == "/api/counter";
}

test "discover_services excludes a module passed as the explicit entry file" {
    reset_discovery_cache();
    # Pretend greeter is the entry: it should drop out of the service set.
    routes = discover_services(_FIXTURE, entry_file="greeter.jac");
    assert "greeter" not in routes;
    assert "counter_app" in routes;
}

test "discover_services returns {} for a project with no `to sv:` modules" {
    import tempfile;
    reset_discovery_cache();
    tmp = tempfile.mkdtemp(prefix="zc-noservices-");
    # A lone data module (no `to sv:` endpoints) is not a service.
    (Path(tmp) / "models.jac").write_text("node Tally { has total: int = 0; }\n");
    routes = discover_services(tmp, entry_file="main.jac");
    assert routes == {} , f"expected no services, got {routes}";
}


# --------------------------------------------------------------------------
# resolve_microservices_config
# --------------------------------------------------------------------------
test "resolve fills routes + enables when none declared (zero-config)" {
    reset_discovery_cache();
    resolved = resolve_microservices_config({"enabled": False, "routes": {}}, _FIXTURE);
    assert resolved["enabled"] is True;
    assert set(resolved["routes"].keys()) == {"greeter", "counter_app"};
}

test "resolve leaves an explicit routes block untouched (no discovery)" {
    reset_discovery_cache();
    explicit = {"enabled": True, "routes": {"only_app": "/api/only"}};
    resolved = resolve_microservices_config(explicit, _FIXTURE);
    assert resolved["routes"] == {"only_app": "/api/only"};
}

test "resolve does not mutate the input config" {
    reset_discovery_cache();
    original = {"enabled": False, "routes": {}};
    _ = resolve_microservices_config(original, _FIXTURE);
    assert original["routes"] == {};
    assert original["enabled"] is False;
}


# --------------------------------------------------------------------------
# --no-image: source ConfigMap + pod volume injection
# --------------------------------------------------------------------------
test "no_image builder packs project source into a ConfigMap" {
    cfg = KubernetesConfig(app_name="zc", namespace="zc-dev");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, no_image=True, project_root=_FIXTURE
    );
    cm = builder._build_source_configmap();
    assert cm is not None;
    assert cm["kind"] == "ConfigMap";
    assert cm["metadata"]["name"] == "zc-source";
    # The .jac + .toml sources are packed.
    files = set(builder._source_key_map.keys());
    assert "main.jac" in files;
    assert "greeter.jac" in files;
    assert "jac.toml" in files;
    # A content hash was computed for rollout triggering.
    assert builder._source_hash != "";
}

test "no_image off yields no source ConfigMap" {
    cfg = KubernetesConfig(app_name="zc", namespace="zc-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg, project_root=_FIXTURE);
    assert builder._build_source_configmap() is None;
}

test "no_image pod spec mounts source at /app and stamps JAC_SOURCE_HASH" {
    cfg = KubernetesConfig(app_name="zc", namespace="zc-dev");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, no_image=True, project_root=_FIXTURE
    );
    # Populate the key map + hash (done by _build_source_configmap).
    _ = builder._build_source_configmap();
    spec = builder._build_service_pod_spec("greeter", "jac-scale-base:1.0");
    container = spec["containers"][0];

    mounts = container.get("volumeMounts", []);
    mount_paths = [m["mountPath"] for m in mounts];
    assert "/app" in mount_paths;

    vols = spec.get("volumes", []);
    src_vol = next(
        (
            v
            for v in vols
            if v["name"] == "jac-source"
        ),
        None
    );
    assert src_vol is not None;
    assert src_vol["configMap"]["name"] == "zc-source";
    # items[].path restores the real layout from sanitized keys.
    paths = {it["path"] for it in src_vol["configMap"]["items"]};
    assert "greeter.jac" in paths;

    pairs = {e["name"]: e["value"] for e in container["env"]};
    assert pairs.get("JAC_SOURCE_HASH") == builder._source_hash;
}


# --------------------------------------------------------------------------
# Base image
# --------------------------------------------------------------------------
test "base_image_tag is registry-prefixed only when a registry is given" {
    bare = base_image_tag();
    assert bare.startswith("jac-scale-base:");
    prefixed = base_image_tag("reg.example.com/org");
    assert prefixed == f"reg.example.com/org/{bare}";
}
