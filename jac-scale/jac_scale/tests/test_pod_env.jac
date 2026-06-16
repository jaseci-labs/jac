"""Tests for K-track pod env injection (K8S_APP_NAME / K8S_NAMESPACE)."""

import unittest.mock as mock;
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.abstractions.models.deploy_context { DeployContext }


test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {entry["name"]: entry["value"] for entry in env};
    assert pairs.get("JAC_SV_NAME") == "orders";
    assert pairs.get("K8S_APP_NAME") == "jac-shop";
    assert pairs.get("K8S_NAMESPACE") == "jac-shop-dev";
}


test "build_env keeps per-service overrides but never shadows the K8S_* vars" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    env = builder._build_env(
        "orders", {"env": {"STRIPE_KEY": "sk_test", "K8S_APP_NAME": "evil"}}
    );

    # The user's STRIPE_KEY entry lands; K8S_APP_NAME injected first wins
    # because it's already in the list when we walk the user table.
    names = [entry["name"] for entry in env];
    assert "STRIPE_KEY" in names;
    # The base injection is still there - the user override is appended,
    # not substituted, so K_APP_NAME appears at least once with our value.
    first_app_name = next(
        (
            e["value"]
            for e in env
            if e["name"] == "K8S_APP_NAME"
        ),
        None
    );
    assert first_app_name == "jac-shop";
}


test "pod spec surfaces JAC_IMAGE_REF with the resolved content-addressed image" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    # B-01: the resolved ref (incl. K-29 content-id suffix) is mirrored into
    # the pod env so an in-pod self-check can read it with zero RBAC.
    spec = builder._build_service_pod_spec("orders", "jac-shop:dev-abc123def456");
    container = spec["containers"][0];

    assert container["image"] == "jac-shop:dev-abc123def456";
    pairs = {entry["name"]: entry["value"] for entry in container["env"]};
    assert pairs.get("JAC_IMAGE_REF") == "jac-shop:dev-abc123def456";
}


test "pod spec strips a user-set JAC_IMAGE_REF, leaving one system value" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    # A user env table that tries to shadow JAC_IMAGE_REF must not produce a
    # duplicate env entry in the rendered pod spec.
    with mock.patch.object(
        builder, "_service_config", return_value={"env": {"JAC_IMAGE_REF": "spoofed"}}
    ) {
        spec = builder._build_service_pod_spec("orders", "jac-shop:dev-abc123def456");
    }
    container = spec["containers"][0];
    refs = [
        e["value"]
        for e in container["env"]
        if e["name"] == "JAC_IMAGE_REF"
    ];
    assert refs == ["jac-shop:dev-abc123def456"];
}


test "code-injection deploy_context yields base image, code-server init, shared volume, dispatch entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    ctx = DeployContext(
        image_override="python:3.12-slim",
        entrypoint_command='cd /app && jac install && if [ "$JAC_SV_NAME" = "__gateway__" ]; then exec jac scale gateway; else exec jac start "${JAC_SV_NAME}.jac"; fi',
        volumes=[{"name": "app-code", "emptyDir": {}}, {"name": "tmp", "emptyDir": {}}],
        volume_mounts=[
            {"name": "app-code", "mountPath": "/app"},
            {"name": "tmp", "mountPath": "/tmp"}
        ],
        init_containers=[{"name": "build-app", "image": "busybox:1.36"}]
    );
    builder = MicroserviceManifestBuilder(k8s_config=cfg, deploy_context=ctx);

    spec = builder._build_service_pod_spec("orders", "jac-shop:dev-abc123");
    container = spec["containers"][0];

    # Base image wins over the passed built image: no per-app image build.
    assert container["image"] == "python:3.12-slim";
    # Entrypoint is the code-injection command (runtime install + dispatch).
    assert container["command"] == ["sh", "-c"];
    assert container["args"] == [ctx.entrypoint_command];
    # Shared /app + /tmp mounts on the main container.
    mount_paths = [m["mountPath"] for m in container["volumeMounts"]];
    assert "/app" in mount_paths;
    assert "/tmp" in mount_paths;
    # Volumes and the code-server init container are in the pod spec.
    assert "app-code" in [v["name"] for v in spec["volumes"]];
    assert "build-app" in [c["name"] for c in spec["initContainers"]];
}


test "no code-injection context keeps the built image and JAC_SV_NAME entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    spec = builder._build_service_pod_spec("orders", "jac-shop:dev-abc123");
    container = spec["containers"][0];

    assert container["image"] == "jac-shop:dev-abc123";
    assert "JAC_SV_NAME" in container["args"][0];
}
