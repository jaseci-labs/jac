"""Tests for IngressDeployer's per-app ingress rule rendering."""
import unittest.mock;
import from types { SimpleNamespace }
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes { ingress as ingress_module }
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}

def _render_rules(domain: str) -> list {
    config = KubernetesConfig(app_name="myapp", namespace="test-ns", domain=domain);
    deployer = IngressDeployer(k8s_config=config, logger=None);
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    deployer._deploy_ingress_resource(
        app_name="myapp",
        namespace="test-ns",
        ingress_class="test-ns-myapp-nginx",
        service_port=8000,
        grafana_enabled=False,
        redis_dashboard=False,
        mongo_dashboard=False,
        networking_v1=networking_v1,
        core_v1=core_v1
    );
    call_args = networking_v1.patch_namespaced_ingress.call_args;
    assert call_args is not None;
    return call_args.kwargs["body"]["spec"]["rules"];
}

test "per-app ingress with a domain keeps a host-bound rule across deploys" {
    # The host rule is what ingress-nginx binds the TLS cert to; without
    # it every redeploy of a TLS-enabled app dropped the binding set by
    # enable_tls and nginx served its self-signed fallback cert (#7707).
    rules = _render_rules("example.com");
    assert len(rules) == 2 , f"expected host rule + catch-all, got {rules}";
    assert rules[0].get("host") == "example.com";
    assert "host" not in rules[1] , "catch-all rule must keep serving the raw load-balancer hostname";
    assert rules[0]["http"] == rules[1]["http"];
}

test "per-app ingress without a domain renders a single catch-all rule" {
    rules = _render_rules("");
    assert len(rules) == 1 , f"expected one catch-all rule, got {rules}";
    assert "host" not in rules[0];
}

def _run_enable_tls(shared: bool) -> list {
    cfg = KubernetesConfig(
        app_name="myapp",
        namespace="test-ns",
        domain="example.com",
        cert_manager_email="a@b.com",
        shared_ingress=shared,
        shared_ingress_class=("nginx" if shared else "")
    );
    deployer = IngressDeployer(k8s_config=cfg, logger=None);
    ing = SimpleNamespace(
        metadata=SimpleNamespace(
            annotations={
                "jac-scale/domain": "example.com",
                "jac-scale/cert-email": "a@b.com"
            }
        )
    );
    networking_v1 = unittest.mock.MagicMock();
    networking_v1.read_namespaced_ingress.side_effect = [
        ing,
        ing,
        ApiException(status=404)
    ];
    custom_api = unittest.mock.MagicMock();
    custom_api.get_namespaced_custom_object.return_value = {
        "status": {"conditions": [{"type": "Ready", "status": "True"}]}
    };
    fake_api_client = unittest.mock.MagicMock();
    fake_api_client.sanitize_for_serialization.return_value = {
        "spec": {"rules": [{"http": {"paths": [{"path": "/"}]}}]}
    };
    with unittest.mock.patch.object(
        IngressDeployer, "_install_cert_manager", unittest.mock.MagicMock()
    ) {
        with unittest.mock.patch.object(
            ingress_module.client, "ApiClient", lambda { fake_api_client; }
        ) {
            deployer.enable_tls(
                "myapp",
                "test-ns",
                networking_v1,
                custom_api,
                unittest.mock.MagicMock(),
                unittest.mock.MagicMock()
            );
        }
    }
    body = networking_v1.patch_namespaced_ingress.call_args_list[0][1]["body"];
    return body["spec"]["rules"];
}

test "enable_tls on a per-app ingress renders host plus catch-all rules" {
    rules = _run_enable_tls(False);
    assert len(rules) == 2 , f"expected host rule + catch-all, got {rules}";
    assert rules[0].get("host") == "example.com";
    assert "host" not in rules[1];
}

test "enable_tls on a shared ingress stays host-scoped with no catch-all" {
    # A catch-all rule on a SHARED controller would swallow other apps'
    # unmatched traffic, so the shared path must keep exactly one
    # host-bound rule.
    rules = _run_enable_tls(True);
    assert len(rules) == 1 , f"expected a single host-bound rule, got {rules}";
    assert rules[0].get("host") == "example.com";
}
