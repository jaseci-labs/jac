"""Direct, mock-free tests of service_routing.jac -- the single source of
truth resolving whether a K8s peer service is reached directly or through
the KEDA HTTP Add-on interceptor. Every function under test here is
pure dict-in/dict-out, so no Kubernetes API client or config-loader mocking
is needed anywhere in this file."""

import from jaclang.scale.runtime.context.service_routing {
    ServiceRoute,
    KEDA_INTERCEPTOR_SERVICE_ADDRESS,
    k8s_service_dns_host,
    resolve_interceptor_service_address,
    resolve_http_activation_config,
    resolve_service_route
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.target.kubernetes.runtime_resolver {
    build_k8s_registry_routes
}
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }


test "resolve_http_activation_config merges per-service over top-level and honors enabled on both" {
    for (label, top, app, expect_port) in [
        ("neither side configured", {}, {}, None),
        (
            "top-level only, per-service inherits it",
            {"enabled": True, "target_port": 8080},
            {},
            8080
        ),
        (
            "per-service only, no top-level default",
            {},
            {"http_activation": {"enabled": True, "target_port": 9090}},
            9090
        ),
        (
            "per-service key wins, unset keys still inherit",
            {"enabled": True, "target_port": 8080, "concurrency_target": 10},
            {"http_activation": {"target_port": 9090}},
            9090
        ),
        (
            "per-service enabled=false opts out of an enabled default",
            {"enabled": True, "target_port": 8080},
            {"http_activation": {"enabled": False}},
            None
        )
    ] {
        cfg = resolve_http_activation_config(top, app);
        if expect_port is None {
            assert cfg is None , label;
        } else {
            assert cfg is not None , label;
            assert cfg["target_port"] == expect_port , label;
        }
    }
    # the inherit-an-unset-key half of label 4, which the port assert alone
    # cannot distinguish from a per-service value that happened to match
    merged = resolve_http_activation_config(
        {"enabled": True, "target_port": 8080, "concurrency_target": 10},
        {"http_activation": {"target_port": 9090}}
    );
    assert merged["concurrency_target"] == 10;
}


test "resolve_service_route sends activated services to the interceptor and everything else direct" {
    for (label, k8s_cfg, expect_url, expect_host) in [
        (
            "not activated",
            {},
            "http://orders-app-service.shop.svc.cluster.local:8000",
            None
        ),
        (
            "activated",
            {"http_activation": {"enabled": True}},
            f"http://{KEDA_INTERCEPTOR_SERVICE_ADDRESS}",
            "orders-app-service.shop.svc.cluster.local"
        )
    ] {
        route = resolve_service_route("orders_app", "shop", 8000, k8s_cfg, {});
        assert route.url == expect_url , label;
        assert route.host_header == expect_host , label;
    }
    # The activated Host must be the exact string k8s_service_dns_host
    # builds, because build_http_activation_spec's auto-derived
    # InterceptorRoute rule is keyed to that same call. Any drift here and
    # the interceptor stops matching the request the gateway forwards. This
    # also covers RFC1123 sanitization of the underscore-bearing name above.
    activated = resolve_service_route(
        "orders_app", "shop", 8000, {"http_activation": {"enabled": True}}, {}
    );
    assert activated.host_header == k8s_service_dns_host("orders-app-service", "shop");
}


test "a configured interceptor address matches what AutoscalerFactory hands the KEDA autoscaler" {
    # A cluster running the HTTP Add-on under a non-default Helm release or
    # namespace sets [scale.kubernetes.http_activation].interceptor_service_address.
    # If the runtime resolver and the deploy-time autoscaler each derived
    # that address independently, one could point at a service the other
    # never created -- exactly the drift class this PR exists to remove.
    assert resolve_interceptor_service_address({}) == KEDA_INTERCEPTOR_SERVICE_ADDRESS;
    assert resolve_interceptor_service_address({"http_activation": {}})
        == KEDA_INTERCEPTOR_SERVICE_ADDRESS;

    custom_address = "keda-add-ons-http-interceptor-proxy.custom-ns:8080";
    autoscaler = AutoscalerFactory.create(
        "keda", {"http_activation": {"interceptor_service_address": custom_address}}
    );
    assert isinstance(autoscaler, KEDAAutoscaler);
    assert autoscaler.interceptor_service_address == custom_address , (
        "AutoscalerFactory must thread the configured address into the "
        "autoscaler it builds, not silently fall back to the default"
    );

    route = resolve_service_route(
        "orders_app",
        "shop",
        8000,
        {
            "http_activation": {
                "enabled": True,
                "interceptor_service_address": custom_address
            }
        },
        {}
    );
    assert route.url == f"http://{autoscaler.interceptor_service_address}";
}


# --- build_k8s_registry_routes: no cross-talk between services --------------
# Exercised through the real production entry point (runtime_resolver.jac),
# backed by the real mixed-activation fixture the RPC-wake e2e deploys
# (worker activated, app not), so a drift in that fixture fails here too.

test "mixed activation states in one call resolve independently, no cross-talk" {
    import os;
    import from pathlib { Path }

    fixture = Path(__file__).parent.parent
        / "fixtures"
        / "keda_http_activation_rpc_wake_e2e";
    saved_ns = os.environ.get("POD_NAMESPACE");
    os.environ["POD_NAMESPACE"] = "shop";
    reset_scale_config();
    try {
        get_scale_config(project_dir=fixture);
        resolved = build_k8s_registry_routes(["worker", "app"], 8000);

        assert resolved["worker"].host_header
            == "worker-service.shop.svc.cluster.local";
        assert resolved["app"].url == "http://app-service.shop.svc.cluster.local:8000";
        assert resolved["app"].host_header is None;
    } finally {
        if saved_ns is None {
            os.environ.pop("POD_NAMESPACE", None);
        } else {
            os.environ["POD_NAMESPACE"] = saved_ns;
        }
        reset_scale_config();
    }
}


test "ManifestBuilder resolves the same activation config and the same direct URL as service_routing" {
    # _get_http_activation_config now delegates to resolve_http_activation_config,
    # and _peer_dns_url must derive the identical ClusterIP URL for a peer that
    # is not activated -- otherwise a pod's baked JAC_APP_<PEER>_URL and the
    # live registry would disagree about the same unactivated peer. (An
    # activated peer gets no baked URL at all; test_pod_env covers that.)
    cfg = KubernetesConfig(
        app_name="jac-shop",
        namespace="shop",
        container_port=8000,
        http_activation={"enabled": True, "target_port": 8080, "concurrency_target": 10}
    );
    for (label, overrides, expect_port) in [
        ("per-service override", {"http_activation": {"target_port": 9090}}, 9090),
        ("per-service opt-out", {"http_activation": {"enabled": False}}, None)
    ] {
        builder = ManifestBuilder(
            k8s_config=cfg, app_overrides={"orders_app": overrides}
        );
        via_builder = builder._get_http_activation_config("orders_app");
        via_resolver = resolve_http_activation_config(
            dict(cfg.http_activation), builder._service_config("orders_app")
        );
        assert via_builder == via_resolver , label;
        if expect_port is None {
            assert via_builder is None , label;
        } else {
            assert via_builder["target_port"] == expect_port , label;
        }
    }

    plain_cfg = KubernetesConfig(
        app_name="jac-shop", namespace="shop", container_port=8000
    );
    plain_builder = ManifestBuilder(k8s_config=plain_cfg);
    assert plain_builder._peer_dns_url("orders_app")
        == resolve_service_route("orders_app", "shop", 8000, {}, {}).url;
}
