import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jac_scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jac_scale.deploy.target.kubernetes.kubernetes_config { KubernetesConfig }

def _make_deployer(domain: str = '', cert_email: str = '') -> IngressDeployer {
    cfg = KubernetesConfig(domain=domain, cert_manager_email=cert_email);
    return IngressDeployer(k8s_config=cfg);
}

def _make_shared_deployer(annotations: dict) -> IngressDeployer {
    cfg = KubernetesConfig(
        domain='app.example.com',
        shared_ingress=True,
        shared_ingress_tls=True,
        shared_ingress_class='jb-custom',
        shared_ingress_annotations=annotations
    );
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

test "deploy uses patch not replace for main ingress" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.patch_namespaced_ingress.called , "patch_namespaced_ingress must be called on redeployment";
    assert not networking_v1.replace_namespaced_ingress.called , "replace_namespaced_ingress must never be called";
}

test "patch body never contains spec.tls or host" {
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
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    ann = body['metadata']['annotations'];
    assert 'nginx.ingress.kubernetes.io/proxy-body-size' in ann , "proxy-body-size annotation must be present";
    assert 'nginx.ingress.kubernetes.io/limit-rps' in ann , "limit-rps annotation must be present";
    assert ann.get('jac-scale/domain') == 'example.com' , "jac-scale/domain annotation must match config";

    assert 'cert-manager.io/issuer' not in ann , "cert-manager.io/issuer must not be set by _deploy_ingress_resource";
    assert 'nginx.ingress.kubernetes.io/ssl-redirect' not in ann , "ssl-redirect must not be set by _deploy_ingress_resource";
    assert 'nginx.ingress.kubernetes.io/force-ssl-redirect' not in ann , "force-ssl-redirect must not be set by _deploy_ingress_resource";
}

test "first deploy creates ingress when patch returns 404" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    deployer = _make_deployer();
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.create_namespaced_ingress.called , "create_namespaced_ingress must be called when patch returns 404";

    create_body = networking_v1.create_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in create_body.get('spec', {}) , "spec.tls must not appear in create body";
    assert 'host' not in create_body.get('spec', {}).get('rules', [{}])[0] , "host must not appear in create body";
}

test "non-404 patch error propagates" {
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

test "shared ingress with a cert-manager issuer annotation adds spec.tls" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_shared_deployer(
        {'cert-manager.io/cluster-issuer': 'letsencrypt-prod'}
    );
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    tls = body.get('spec', {}).get('tls');
    assert tls , "shared ingress + cert-manager annotation must add spec.tls";
    assert tls[0]['hosts'] == ['app.example.com'] , "tls host must be the domain";
    assert tls[0]['secretName'] == 'myapp-tls' , "tls secretName must be {app}-tls";
}

test "shared ingress without a cert-manager annotation adds no cert tls block" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_shared_deployer({});
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert body.get('spec', {}).get('tls') is None , "no issuer annotation must not add a cert tls block";
}

test "redis ingress patch body never contains spec.tls or host" {
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

    all_calls = networking_v1.patch_namespaced_ingress.call_args_list;
    assert len(all_calls) == 2 , "Expected two patch_namespaced_ingress calls";
    redis_body = all_calls[1][1]['body'];
    assert 'tls' not in redis_body.get('spec', {}) , "RedisInsight Ingress spec.tls must not appear in patch body";
    redis_rules = redis_body.get('spec', {}).get('rules', []);
    assert len(redis_rules) > 0 , "RedisInsight patch body must include at least one rule";
    assert 'host' not in redis_rules[0] , "RedisInsight Ingress rules[*].host must not appear in patch body";
}
