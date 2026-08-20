import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.config.app_config { AppConfig }


def _builder(ms_config: dict) -> ManifestBuilder {
    return ManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="shop", namespace="shop-ns", bundle_storage_class="standard"
        ),
        microservices_config=ms_config,
        dry_run=True
    );
}


test "a bundle built without an ingress block carries no ingress manifest" {
    bundle = _builder({"services": {}}).generate_manifests(
        AppConfig(code_folder=".", app_name="shop"), ""
    );
    assert bundle.get("ingress") is None;
}


test "a bundle built with an enabled ingress block carries its manifest" {
    ms_config = {
        "services": {},
        "ingress": {"enabled": True, "host": "shop.example.com"}
    };
    bundle = _builder(ms_config).generate_manifests(
        AppConfig(code_folder=".", app_name="shop"), ""
    );
    ingress = bundle.get("ingress");
    assert ingress is not None;
    assert ingress["kind"] == "Ingress";
}


test "the port-forward hint names the deployed namespace and container port" {
    target = KubernetesTarget(
        config=KubernetesConfig(
            app_name="shop", namespace="shop-ns", container_port=8000
        ),
        dry_run=True
    );
    hint = target.port_forward_hint();
    assert "kubectl -n shop-ns port-forward svc/gateway-service 8080:8000" in hint;
    assert "http://localhost:8080" in hint;
    assert "No ingress is configured" in hint;
}


test "the hint follows the configured container port" {
    target = KubernetesTarget(
        config=KubernetesConfig(
            app_name="shop", namespace="shop-ns", container_port=9000
        ),
        dry_run=True
    );
    assert "8080:9000" in target.port_forward_hint();
}
