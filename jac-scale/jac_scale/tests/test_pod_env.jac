"""Tests for K-track pod env injection (K8S_APP_NAME / K8S_NAMESPACE)."""

import unittest.mock as mock;
import from jac_scale.targets.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder
}
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.microservice.target {
    KubernetesMicroserviceTarget
}
import from jac_scale.abstractions.models.deploy_context { DeployContext }


test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {entry["name"]: entry.get("value") for entry in env};
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
    pairs = {entry["name"]: entry.get("value") for entry in container["env"]};
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


# G2 of #6728: in_cluster_namespace() builds peer DNS from POD_NAMESPACE;
# without the downward-API entry it falls back to "default" and a
# non-default namespace never resolves siblings.
test "every pod gets POD_NAMESPACE via the downward API (G2)" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jb-abc-shop");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);

    for svc in ["orders", "__gateway__"] {
        spec = builder._build_service_pod_spec(svc, "jac-shop:dev-abc123");
        container = spec["containers"][0];
        pod_ns = [
            e
            for e in container["env"]
            if e["name"] == "POD_NAMESPACE"
        ];
        assert len(pod_ns) == 1;
        assert "value" not in pod_ns[0];
        assert pod_ns[0]["valueFrom"]["fieldRef"]["fieldPath"] == "metadata.namespace";
    }
}


# A0 / greptile fix on #6730: the code-injection dispatch must export
# JAC_SV_SIBLING=1, else every sibling pod re-enters orchestration and
# tries to spawn its own fleet.
test "code-injection dispatch exports JAC_SV_SIBLING and dispatches on JAC_SV_NAME" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    t = KubernetesMicroserviceTarget(config=cfg);

    dispatch = t._code_inject_dispatch();
    assert "export JAC_SV_SIBLING=1" in dispatch;
    assert "exec jac scale gateway" in dispatch;
    assert 'exec jac start "${JAC_SV_NAME}.jac"' in dispatch;
}


# G4 of #6728: a platform deploying a DIFFERENT app injects that app's
# config; with it set, the process jac.toml is never consulted.
test "code-injection pods get a startup probe; built-image pods do not" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    ci = MicroserviceManifestBuilder(
        k8s_config=cfg, microservices_config={"code_inject": True}
    );

    c = ci._build_service_pod_spec("orders", "img:1")["containers"][0];
    assert "startupProbe" in c;
    assert c["startupProbe"]["httpGet"]["path"] == "/healthz/live";
    # 90 * 10s = ~15min boot budget; liveness/readiness suppressed until it passes.
    assert c["startupProbe"]["failureThreshold"] == 90;

    plain = MicroserviceManifestBuilder(k8s_config=cfg);
    pc = plain._build_service_pod_spec("orders", "img:1")["containers"][0];
    assert "startupProbe" not in pc;
}


test "code-injection sibling defaults to 2Gi memory; built-image sibling stays 1Gi" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    ci = MicroserviceManifestBuilder(
        k8s_config=cfg, microservices_config={"code_inject": True}
    );
    ci_mem = ci._build_service_pod_spec("orders", "img:1")["containers"][0]["resources"][
        "limits"
    ]["memory"];
    assert ci_mem == "2Gi";

    plain = MicroserviceManifestBuilder(k8s_config=cfg);
    plain_mem = plain._build_service_pod_spec("orders", "img:1")["containers"][0][
        "resources"
    ]["limits"]["memory"];
    assert plain_mem == "1Gi";
}


test "injected microservices_config overrides the process config (G4)" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    injected = {"routes": {"orders": "/api/orders"}, "code_inject": True};
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, microservices_config=injected
    );

    assert builder._ms_cfg() == injected;

    t_on = KubernetesMicroserviceTarget(
        config=cfg, microservices_config={"code_inject": True}
    );
    assert t_on._code_inject_enabled() == True;
    t_off = KubernetesMicroserviceTarget(
        config=cfg, microservices_config={"code_inject": False}
    );
    assert t_off._code_inject_enabled() == False;
}
