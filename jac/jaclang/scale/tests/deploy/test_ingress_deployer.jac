"""Tests for IngressDeployer's per-app ingress rule rendering."""
import unittest.mock;
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
