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


# --- resolve_http_activation_config: precedence and enabled-gating ----------

test "neither top-level nor per-service config set: not activated" {
    assert resolve_http_activation_config({}, {}) is None;
}

test "top-level enabled, no per-service block: activated, inherits top-level values" {
    cfg = resolve_http_activation_config({"enabled": True, "target_port": 8080}, {});
    assert cfg is not None;
    assert cfg["target_port"] == 8080;
}

test "per-service enabled with no top-level default: activated" {
    app_cfg = {"http_activation": {"enabled": True}};
    cfg = resolve_http_activation_config({}, app_cfg);
    assert cfg is not None;
}

test "per-service overrides a top-level key, both merge into one config" {
    app_cfg = {"http_activation": {"target_port": 9090}};
    cfg = resolve_http_activation_config(
        {"enabled": True, "target_port": 8080, "concurrency_target": 10}, app_cfg
    );
    assert cfg["target_port"] == 9090 , "per-service value must win over the top-level default";
    assert cfg["concurrency_target"] == 10 , "unset per-service keys still inherit the default";
}

test "per-service enabled=false opts a service out even when the top-level default is enabled" {
    app_cfg = {"http_activation": {"enabled": False}};
    assert resolve_http_activation_config({"enabled": True}, app_cfg) is None;
}


# --- resolve_service_route: the one decision point ---------------------------

test "not activated: direct ClusterIP URL, no host header" {
    route = resolve_service_route("orders_app", "shop", 8000, {}, {});
    assert route.url == "http://orders-app-service.shop.svc.cluster.local:8000";
    assert route.host_header is None;
}

test "activated: URL is the interceptor's address, host header is the real Service DNS name" {
    route = resolve_service_route(
        "orders_app", "shop", 8000, {"http_activation": {"enabled": True}}, {}
    );
    assert route.url == f"http://{KEDA_INTERCEPTOR_SERVICE_ADDRESS}";
    assert route.host_header == "orders-app-service.shop.svc.cluster.local";
}

test "a configured interceptor address matches what AutoscalerFactory hands the KEDA autoscaler" {
    # A cluster running the HTTP Add-on under a non-default Helm release or
    # namespace sets [scale.kubernetes.http_activation].interceptor_service_address.
    # If the runtime resolver and the deploy-time autoscaler each derived
    # that address independently, one could point at a service the other
    # never created -- exactly the drift class this PR exists to remove.
    custom_address = "keda-add-ons-http-interceptor-proxy.custom-ns:8080";
    config = {"http_activation": {"interceptor_service_address": custom_address}};

    autoscaler = AutoscalerFactory.create("keda", config);
    assert isinstance(autoscaler, KEDAAutoscaler);
    assert autoscaler.interceptor_service_address == custom_address , (
        "AutoscalerFactory must thread the configured address into the "
        "autoscaler it builds, not silently fall back to the default"
    );
    assert autoscaler.interceptor_service_address != KEDA_INTERCEPTOR_SERVICE_ADDRESS;

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
    assert route.url == f"http://{custom_address}";
    assert route.url == f"http://{autoscaler.interceptor_service_address}";
}

test "resolve_interceptor_service_address falls back to the default when unset" {
    assert resolve_interceptor_service_address({}) == KEDA_INTERCEPTOR_SERVICE_ADDRESS;
    default_via_empty_activation = resolve_interceptor_service_address(
        {"http_activation": {}}
    );
    assert default_via_empty_activation == KEDA_INTERCEPTOR_SERVICE_ADDRESS;
}

test "an underscore-bearing jac.toml name is RFC1123-sanitized the same way on both sides" {
    route = resolve_service_route(
        "orders_app", "shop", 8000, {"http_activation": {"enabled": True}}, {}
    );
    # k8s_service_dns_host is exactly what build_http_activation_spec's
    # auto-derived InterceptorRoute rule uses for the same service -- if
    # this string ever drifted from that one, the interceptor would never
    # match a request carrying this Host header.
    assert route.host_header == k8s_service_dns_host("orders-app-service", "shop");
}


# --- build_k8s_registry_routes: no cross-talk between services --------------
# Exercised through the real production entry point (runtime_resolver.jac),
# backed by a real on-disk jac.toml, not a hand-built kubernetes_cfg /
# app_scale_configs pair -- build_k8s_service_routes took those as explicit
# params but nothing outside this file ever called it; production always
# resolves per-app config itself through get_scale_config().

test "mixed activation states in one call resolve independently, no cross-talk" {
    import os;
    import shutil;
    import tempfile;
    import from pathlib { Path }

    d = tempfile.mkdtemp(prefix="jac-route-crosstalk-");
    (Path(d) / "jac.toml").write_text(
        '[project]\n'
        'name = "shop"\n'
        'default-app = "web"\n'
        '\n'
        '[apps.web]\n'
        'kind = "web-app"\n'
        'entry-point = "main"\n'
        '\n'
        '[apps.orders_app]\n'
        'kind = "service"\n'
        'entry-point = "orders_app"\n'
        '\n'
        '[apps.orders_app.scale.http_activation]\n'
        'enabled = true\n'
        '\n'
        '[apps.cart_app]\n'
        'kind = "service"\n'
        'entry-point = "cart_app"\n',
        encoding="utf-8"
    );
    (Path(d) / "main.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "orders_app.jac").write_text("with entry {}\n", encoding="utf-8");
    (Path(d) / "cart_app.jac").write_text("with entry {}\n", encoding="utf-8");

    saved_ns = os.environ.get("POD_NAMESPACE");
    os.environ["POD_NAMESPACE"] = "shop";
    reset_scale_config();
    try {
        get_scale_config(project_dir=Path(d));
        resolved = build_k8s_registry_routes(["orders_app", "cart_app"], 8000);

        assert resolved["orders_app"].host_header
            == "orders-app-service.shop.svc.cluster.local";
        assert resolved["cart_app"].url
            == "http://cart-app-service.shop.svc.cluster.local:8000";
        assert resolved["cart_app"].host_header is None;
    } finally {
        if saved_ns is None {
            os.environ.pop("POD_NAMESPACE", None);
        } else {
            os.environ["POD_NAMESPACE"] = saved_ns;
        }
        reset_scale_config();
        shutil.rmtree(d, ignore_errors=True);
    }
}


# --- Parity with ManifestBuilder._peer_dns_url (the deploy-time env-var ----
# baking path) for the not-activated case: both must derive the identical
# ClusterIP URL, or a pod's baked JAC_SV_<PEER>_URL and the live registry's
# resolution would disagree for the exact same, unactivated peer.

test "matches ManifestBuilder._peer_dns_url for a not-activated peer" {
    cfg = KubernetesConfig(app_name="jac-shop", namespace="shop", container_port=8000);
    builder = ManifestBuilder(k8s_config=cfg);
    baked = builder._peer_dns_url("orders_app");

    route = resolve_service_route("orders_app", "shop", 8000, {}, {});
    assert route.url == baked;
}

test "known gap: deploy-time env-var baking stays ClusterIP-direct even for an activated peer" {
    # _peer_dns_url (manifest_builder.jac) is intentionally out of scope
    # here -- it only feeds the *fallback* env var a pod reads if the live
    # dynamic registry has no entry for a peer. Documenting this here so a
    # future reader doesn't mistake the gap for an oversight.
    cfg = KubernetesConfig(app_name="jac-shop", namespace="shop", container_port=8000);
    builder = ManifestBuilder(
        k8s_config=cfg,
        app_overrides={"orders_app": {"http_activation": {"enabled": True}}}
    );
    baked = builder._peer_dns_url("orders_app");
    assert baked == "http://orders-app-service.shop.svc.cluster.local:8000" , (
        "if this ever changes, the known-gap note above (and the doc update "
        "in jac-scale-kubernetes.md) needs to change with it"
    );
}


# --- Parity with ManifestBuilder._get_http_activation_config: both now go --
# through the same resolve_http_activation_config merge. This exercises the
# delegation directly, so a future edit to one side without the other would
# fail here instead of only showing up as silent drift in production.

test "ManifestBuilder._get_http_activation_config agrees with resolve_http_activation_config for a per-service override" {
    cfg = KubernetesConfig(
        app_name="jac-shop",
        namespace="shop",
        container_port=8000,
        http_activation={"enabled": True, "target_port": 8080, "concurrency_target": 10}
    );
    builder = ManifestBuilder(
        k8s_config=cfg,
        app_overrides={"orders_app": {"http_activation": {"target_port": 9090}}}
    );

    via_builder = builder._get_http_activation_config("orders_app");
    via_resolver = resolve_http_activation_config(
        dict(cfg.http_activation), builder._service_config("orders_app")
    );
    assert via_builder == via_resolver;
    assert via_builder["target_port"] == 9090 , "per-service override must win on both paths";
}

test "ManifestBuilder._get_http_activation_config agrees with resolve_http_activation_config for a per-service opt-out" {
    cfg = KubernetesConfig(
        app_name="jac-shop",
        namespace="shop",
        container_port=8000,
        http_activation={"enabled": True, "target_port": 8080, "concurrency_target": 10}
    );
    builder = ManifestBuilder(
        k8s_config=cfg,
        app_overrides={"orders_app": {"http_activation": {"enabled": False}}}
    );

    via_builder = builder._get_http_activation_config("orders_app");
    via_resolver = resolve_http_activation_config(
        dict(cfg.http_activation), builder._service_config("orders_app")
    );
    assert via_builder is None;
    assert via_builder == via_resolver;
}
