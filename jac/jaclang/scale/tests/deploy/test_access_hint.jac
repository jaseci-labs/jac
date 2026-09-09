import os;
import tempfile;
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.runtime.fleet { fleet_of }


def _builder(gateway: dict, project_dir: str) -> ManifestBuilder {
    return ManifestBuilder(
        k8s_config=KubernetesConfig(
            app_name="shop", namespace="shop-ns", bundle_storage_class="standard"
        ),
        project_dir=project_dir,
        fleet=fleet_of({}, root_app="shop"),
        gateway_config=gateway,
        client_entry="",
        dry_run=True
    );
}


def _bundle(gateway: dict) -> dict {
    with tempfile.TemporaryDirectory() as project {
        with open(os.path.join(project, "main.jac"), "w") as f {
            f.write("with entry {}\n");
        }
        return _builder(gateway, project).generate_manifests(
            AppConfig(code_folder=project, app_name="shop"), ""
        );
    }
}


test "a bundle built without an ingress block carries no ingress manifest" {
    bundle = _bundle({});
    assert bundle.get("ingress") is None;
}


test "a bundle built with an enabled ingress block carries its manifest" {
    bundle = _bundle({"ingress": {"enabled": True, "host": "shop.example.com"}});
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
