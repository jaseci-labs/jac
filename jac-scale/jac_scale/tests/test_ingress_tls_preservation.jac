"""Tests for TLS-safe redeployment in IngressDeployer._deploy_ingress_resource.

_deploy_ingress_resource uses patch_namespaced_ingress so it only sends the
fields jac-scale owns.  spec.tls and spec.rules[*].host are written exclusively
by enable_tls and are intentionally absent from the patch body; the API server
leaves them untouched without any read-before-write logic.
"""

import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jac_scale.targets.kubernetes.ingress { IngressDeployer }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }

# ── Helpers ───────────────────────────────────────────────────────────────────
def _make_deployer(domain: str = '', cert_email: str = '') -> IngressDeployer {
    cfg = KubernetesConfig(domain=domain, cert_manager_email=cert_email);
    return IngressDeployer(k8s_config=cfg);
}

def _call_deploy(
    deployer: IngressDeployer,
    networking_v1: any,
    core_v1: any,
    redis_dashboard: bool = False
) {
    deployer._deploy_ingress_resource(
        'myapp',
        'test-ns',
        'test-ns-myapp-nginx',
        8000,
        False,
        redis_dashboard,
        False,
        networking_v1,
        core_v1
    );
}

# ── Tests ─────────────────────────────────────────────────────────────────────
test "deploy uses patch not replace for main ingress" {
    # _deploy_ingress_resource must call patch_namespaced_ingress, never
    # replace_namespaced_ingress, so that spec.tls is never sent as part of the
    # body and is therefore never wiped by a full PUT.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.patch_namespaced_ingress.called , "patch_namespaced_ingress must be called on redeployment";
    assert not networking_v1.replace_namespaced_ingress.called , "replace_namespaced_ingress must never be called";
}

test "patch body never contains spec.tls or host" {
    # The patch body must not include spec.tls or rules[*].host; those fields
    # belong to enable_tls and must be left untouched by redeployment.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in body.get('spec', {}) , "spec.tls must not appear in the patch body";
    rules = body.get('spec', {}).get('rules', []);
    assert len(rules) > 0 , "patch body must include at least one rule";
    assert 'host' not in rules[0] , "rules[*].host must not appear in the patch body";
}

test "patch body contains jac-scale-owned annotations" {
    # The patch must carry jac-scale's own annotations so nginx limits and
    # session affinity settings are applied on every deploy.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    ann = body['metadata']['annotations'];
    assert 'nginx.ingress.kubernetes.io/proxy-body-size' in ann , "proxy-body-size annotation must be present";
    assert 'nginx.ingress.kubernetes.io/limit-rps' in ann , "limit-rps annotation must be present";
    assert ann.get('jac-scale/domain') == 'example.com' , "jac-scale/domain annotation must match config";
    # TLS annotations must NOT be written by _deploy_ingress_resource
    assert 'cert-manager.io/issuer' not in ann , "cert-manager.io/issuer must not be set by _deploy_ingress_resource";
    assert 'nginx.ingress.kubernetes.io/ssl-redirect' not in ann , "ssl-redirect must not be set by _deploy_ingress_resource";
    assert 'nginx.ingress.kubernetes.io/force-ssl-redirect' not in ann , "force-ssl-redirect must not be set by _deploy_ingress_resource";
}

test "first deploy creates ingress when patch returns 404" {
    # On a brand-new cluster there is no Ingress yet; patch returns 404 so
    # the code must fall back to create_namespaced_ingress.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    deployer = _make_deployer();
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.create_namespaced_ingress.called , "create_namespaced_ingress must be called when patch returns 404";
    # Created body must also not contain tls or host
    create_body = networking_v1.create_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in create_body.get('spec', {}) , "spec.tls must not appear in create body";
    assert 'host' not in create_body.get('spec', {}).get('rules', [{}])[0] , "host must not appear in create body";
}

test "non-404 patch error propagates" {
    # A 500 (or any non-404) from patch_namespaced_ingress is a real API
    # failure and must not be swallowed.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=500);

    deployer = _make_deployer();
    raised = False;
    try {
        _call_deploy(deployer, networking_v1, core_v1);
    } except ApiException as e {
        raised = e.status == 500;
    }
    assert raised , "Non-404 ApiException from patch_namespaced_ingress must propagate";
}

test "redis ingress patch body never contains spec.tls or host" {
    # The RedisInsight Ingress patch must also omit spec.tls and rules[*].host.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    cfg = KubernetesConfig(
        domain='example.com',
        cert_manager_email='a@b.com',
        redis_insight_username='admin',
        redis_insight_password='secret'
    );
    deployer = IngressDeployer(k8s_config=cfg);
    _call_deploy(deployer, networking_v1, core_v1, redis_dashboard=True);

    # patch_namespaced_ingress is called twice: main ingress, then redis ingress.
    all_calls = networking_v1.patch_namespaced_ingress.call_args_list;
    assert len(all_calls) == 2 , "Expected two patch_namespaced_ingress calls";
    redis_body = all_calls[1][1]['body'];
    assert 'tls' not in redis_body.get('spec', {}) , "RedisInsight Ingress spec.tls must not appear in patch body";
    redis_rules = redis_body.get('spec', {}).get('rules', []);
    assert len(redis_rules) > 0 , "RedisInsight patch body must include at least one rule";
    assert 'host' not in redis_rules[0] , "RedisInsight Ingress rules[*].host must not appear in patch body";
}
