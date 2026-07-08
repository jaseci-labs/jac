import unittest.mock as mock;
import json;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }


glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent / "fixtures" / "k8s_e2e";


test "generate_service_pod_specs auto-discovers services when no routes declared" {
    # The #7137 companion: a microservice app with no
    # [scale.microservices.routes] section still deploys - services are
    # discovered from `sv import` under the project root.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE)
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");
    with mock.patch.object(builder, "_ms_cfg", return_value={}), mock.patch.object(
        builder, "_build_service_pod_spec", return_value={}
    ), mock.patch.object(builder, "_build_gateway_pod_spec", return_value={}) {
        specs = builder.generate_service_pod_specs(app_cfg, "img");
    }
    # discovered from the fixture's sv graph, no toml routes needed
    assert "products_app" in specs;
    assert "orders_app" in specs;
    assert "cart_app" in specs;
    assert GATEWAY_NAME in specs;
}


test "build_env injects JAC_SV_ROUTES so pods get routes without a toml table" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);
    routes = {"orders_app": "/api/orders", "cart_app": "/api/cart"};
    with mock.patch.object(builder, "_microservice_routes", return_value=routes) {
        env = builder._build_env("orders_app", {});
    }
    pairs = {e["name"]: e["value"] for e in env};
    assert "JAC_SV_ROUTES" in pairs;
    assert json.loads(pairs["JAC_SV_ROUTES"]) == routes;
}

test "build_env omits JAC_SV_ROUTES when there are no routes" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = MicroserviceManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_microservice_routes", return_value={}) {
        env = builder._build_env("orders_app", {});
    }
    assert "JAC_SV_ROUTES" not in {e["name"] for e in env};
}

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

    names = [entry["name"] for entry in env];
    assert "STRIPE_KEY" in names;

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
