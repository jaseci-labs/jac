import json;
import unittest.mock as mock;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.manifest_builder {
    ManifestBuilder,
    GATEWAY_NAME
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.app_config { AppConfig }


glob _K8S_E2E_FIXTURE: Path = Path(__file__).parent / "fixtures" / "k8s_e2e",
     _DISCOVERED_ROUTES: dict[str, str] = {
         "cart_app": "/cart",
         "orders_app": "/orders",
         "products_app": "/products",
         "main": "/__main__"
     };


# A declared [scale.microservices.routes] table (#7772) is the authoritative
# service cut: every key becomes its own pod. Driven through the real builder via
# a real microservices_config, not a patched _ms_cfg / _build_*_pod_spec.
test "generate_service_pod_specs builds one pod per declared route" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    declared = {
        "routes": {
            "products_app": "/products",
            "orders_app": "/orders",
            "cart_app": "/cart"
        }
    };
    builder = ManifestBuilder(
        k8s_config=cfg, project_dir=str(_K8S_E2E_FIXTURE), microservices_config=declared
    );
    app_cfg = AppConfig(code_folder=str(_K8S_E2E_FIXTURE), app_name="jac-shop");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    assert set(specs.keys())
        == {"products_app", "orders_app", "cart_app", "main", GATEWAY_NAME};
    orders_env = {
        e["name"]: e["value"] for e in specs["orders_app"]["containers"][0]["env"]
    };
    assert json.loads(orders_env["JAC_SV_ROUTES"]) == _DISCOVERED_ROUTES;
}


test "an app with no declared routes deploys as one service plus the gateway" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});
    app_cfg = AppConfig(code_folder="/apps/littlex", file_name="main.jac");

    specs = builder.generate_service_pod_specs(app_cfg, "img");

    # named after the app, not its entry file: main.jac must not turn every
    # monolith into a "main" service.
    assert set(specs.keys()) == {"littlex", GATEWAY_NAME};
    assert builder.microservices_config["routes"] == {"littlex": "/littlex"};
    env = {e["name"]: e["value"] for e in specs["littlex"]["containers"][0]["env"]};
    assert env["JAC_SV_NAME"] == "littlex";
    assert env["JAC_SV_FILE"] == "main.jac";
}


test "a solo app whose name shadows a builtin route is rejected" {
    cfg = KubernetesConfig(app_name="admin", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});
    app_cfg = AppConfig(code_folder="/apps/admin", file_name="main.jac");

    raised = False;
    try {
        builder.generate_service_pod_specs(app_cfg, "img");
    } except ValueError as e {
        raised = True;
        assert "builtin" in str(e);
    }
    assert raised , "expected the reserved-name guard to fire";
}


test "every generated deployment rolls with surge, never delete-and-recreate" {
    cfg = KubernetesConfig(app_name="littlex", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    for name in ["littlex", GATEWAY_NAME] {
        manifest = builder._build_deployment_manifest(name, {});
        strategy = manifest["spec"]["strategy"];
        assert strategy["type"] == "RollingUpdate";
        assert strategy["rollingUpdate"] == {"maxSurge": 1, "maxUnavailable": 0};
    }
}


test "build_env omits JAC_SV_ROUTES when no routes are declared" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg, microservices_config={"routes": {}});

    env = builder._build_env("orders_app", {});

    assert "JAC_SV_ROUTES" not in {e["name"] for e in env};
}

test "build_env injects K8S_APP_NAME and K8S_NAMESPACE from k8s_config" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

    env = builder._build_env("orders", {});

    pairs = {entry["name"]: entry["value"] for entry in env};
    assert pairs.get("JAC_SV_NAME") == "orders";
    assert pairs.get("K8S_APP_NAME") == "jac-shop";
    assert pairs.get("K8S_NAMESPACE") == "jac-shop-dev";
}


test "build_env keeps per-service overrides but never shadows the K8S_* vars" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="jac-shop-dev");
    builder = ManifestBuilder(k8s_config=cfg);

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


test "the gateway pod never rebuilds the client at boot" {
    # The deploy builds the client bundle on the host and fails fast when
    # that build fails; the pod serves what shipped and must not retry.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="main.jac") {
        entry = builder._pod_entrypoint();
    }
    args = entry["args"][0];
    assert "jac build" not in args;
    assert "exec jac scale gateway" in args;
}


test "no client entry means no client build in the gateway entrypoint" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="ns");
    builder = ManifestBuilder(k8s_config=cfg);
    with mock.patch.object(builder, "_client_entry", return_value="") {
        entry = builder._pod_entrypoint();
    }
    assert "jac build" not in entry["args"][0];
}


test "a single-file full-stack app still gets its client bundle built" {
    import tempfile;
    import os;
    with tempfile.TemporaryDirectory() as tmp {
        with open(os.path.join(tmp, "jac.toml"), "w") as f {
            f.write("[project]\nname = \"todo-app\"\n\n[client]\n");
        }
        cfg = KubernetesConfig(app_name="todo-app", namespace="ns");
        builder = ManifestBuilder(k8s_config=cfg, project_dir=tmp);
        assert builder._has_client_source();
        assert builder._client_entry() == "main.jac";
    }
}
