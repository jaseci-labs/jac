import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}

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

"""networking mock for an app with no live ingress (first deploy)."""
def _fresh_networking -> any {
    networking_v1 = unittest.mock.MagicMock();
    networking_v1.read_namespaced_ingress.side_effect = ApiException(status=404);
    return networking_v1;
}

"""networking mock whose live ingress carries the fields enable_tls writes."""
def _tls_enabled_networking(domain: str) -> any {
    networking_v1 = unittest.mock.MagicMock();
    live = unittest.mock.MagicMock();
    live.spec.tls = [{'hosts': [domain], 'secretName': 'myapp-tls'}];
    live.metadata.annotations = {
        'jac-scale/domain': domain,
        'nginx.ingress.kubernetes.io/ssl-redirect': 'true'
    };
    networking_v1.read_namespaced_ingress.return_value = live;
    return networking_v1;
}

"""networking mock with a live ingress that never had enable_tls run."""
def _pre_tls_networking(domain_annotation: str = '') -> any {
    networking_v1 = unittest.mock.MagicMock();
    live = unittest.mock.MagicMock();
    live.spec.tls = None;
    ann = {};
    if domain_annotation {
        ann['jac-scale/domain'] = domain_annotation;
    }
    live.metadata.annotations = ann;
    networking_v1.read_namespaced_ingress.return_value = live;
    return networking_v1;
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
    networking_v1 = _fresh_networking();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    assert networking_v1.patch_namespaced_ingress.called , "patch_namespaced_ingress must be called on redeployment";
    assert not networking_v1.replace_namespaced_ingress.called , "replace_namespaced_ingress must never be called";
}

test "pre-TLS deploy body contains no spec.tls or host even with domain in config" {
    networking_v1 = _fresh_networking();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in body.get('spec', {}) , "spec.tls must not appear before enable_tls has run";
    rules = body.get('spec', {}).get('rules', []);
    assert len(rules) > 0 , "patch body must include at least one rule";
    assert 'host' not in rules[0] , "rules[*].host must stay a catch-all before enable_tls has run";
}

test "redeploy of a live pre-TLS ingress stays a catch-all" {
    networking_v1 = _pre_tls_networking(domain_annotation='example.com');
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert 'tls' not in body.get('spec', {}) , "domain presence alone must not add spec.tls";
    assert 'host' not in body['spec']['rules'][0] , "domain presence alone must not bind the rule host";
}

test "redeploy after enable_tls preserves host, spec.tls and TLS annotations" {
    networking_v1 = _tls_enabled_networking('example.com');
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert body['spec']['rules'][0].get('host') == 'example.com' , "redeploy must keep the rule host enable_tls bound";
    tls = body['spec'].get('tls');
    assert tls == [{'hosts': ['example.com'], 'secretName': 'myapp-tls'}] , "redeploy must re-emit the spec.tls block";
    ann = body['metadata']['annotations'];
    assert ann.get('cert-manager.io/issuer') == 'letsencrypt-prod' , "redeploy must keep the cert-manager issuer annotation";
    assert ann.get('nginx.ingress.kubernetes.io/ssl-redirect') == 'true' , "redeploy must keep ssl-redirect";
    assert ann.get('nginx.ingress.kubernetes.io/force-ssl-redirect') == 'true' , "redeploy must keep force-ssl-redirect";
    assert ann.get('jac-scale/domain') == 'example.com' , "redeploy must keep jac-scale/domain";
}

test "redeploy after enable_tls works without domain in config" {
    networking_v1 = _tls_enabled_networking('example.com');
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer();
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert body['spec']['rules'][0].get('host') == 'example.com' , "domain must be read back from the jac-scale/domain annotation";
}

test "config domain wins over annotation domain on redeploy" {
    networking_v1 = _tls_enabled_networking('old.example.com');
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='new.example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    assert body['spec']['rules'][0].get('host') == 'new.example.com' , "an explicitly configured domain must win over the annotation";
}

test "patch body contains jac-scale-owned annotations" {
    networking_v1 = _fresh_networking();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
    _call_deploy(deployer, networking_v1, core_v1);

    body = networking_v1.patch_namespaced_ingress.call_args[1]['body'];
    ann = body['metadata']['annotations'];
    assert 'nginx.ingress.kubernetes.io/proxy-body-size' in ann , "proxy-body-size annotation must be present";
    assert 'nginx.ingress.kubernetes.io/limit-rps' in ann , "limit-rps annotation must be present";
    assert ann.get('jac-scale/domain') == 'example.com' , "jac-scale/domain annotation must match config";

    assert 'cert-manager.io/issuer' not in ann , "cert-manager.io/issuer must not be set before enable_tls has run";
    assert 'nginx.ingress.kubernetes.io/ssl-redirect' not in ann , "ssl-redirect must not be set before enable_tls has run";
    assert 'nginx.ingress.kubernetes.io/force-ssl-redirect' not in ann , "force-ssl-redirect must not be set before enable_tls has run";
}

test "first deploy creates ingress when patch returns 404" {
    networking_v1 = _fresh_networking();
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
    networking_v1 = _fresh_networking();
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

test "non-404 error from the live-state read propagates" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.read_namespaced_ingress.side_effect = ApiException(status=500);

    deployer = _make_deployer();
    raised = False;
    try {
        _call_deploy(deployer, networking_v1, core_v1);
    } except ApiException as e {
        raised = e.status == 500;
    }
    assert raised , "Non-404 ApiException from read_namespaced_ingress must propagate";
}

test "shared ingress with a cert-manager issuer annotation adds spec.tls" {
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();

    deployer = _make_shared_deployer(
        {'cert-manager.io/cluster-issuer': 'letsencrypt-prod'}
    );
    _call_deploy(deployer, networking_v1, core_v1);

    assert not networking_v1.read_namespaced_ingress.called , "shared ingress must not read live TLS state";
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

test "pre-TLS redis ingress patch body contains no spec.tls or host" {
    networking_v1 = _fresh_networking();
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
    assert 'tls' not in redis_body.get('spec', {}) , "RedisInsight Ingress spec.tls must not appear before enable_tls has run";
    redis_rules = redis_body.get('spec', {}).get('rules', []);
    assert len(redis_rules) > 0 , "RedisInsight patch body must include at least one rule";
    assert 'host' not in redis_rules[0] , "RedisInsight Ingress rules[*].host must stay a catch-all before enable_tls has run";
}

test "redeploy after enable_tls preserves redis ingress host and spec.tls" {
    networking_v1 = _tls_enabled_networking('example.com');
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
    assert redis_body['spec']['rules'][0].get('host') == 'example.com' , "redeploy must keep the RedisInsight rule host";
    assert redis_body['spec'].get('tls') == [
        {'hosts': ['example.com'], 'secretName': 'myapp-tls'}
    ] , "redeploy must re-emit the RedisInsight spec.tls block";
    redis_ann = redis_body['metadata']['annotations'];
    assert redis_ann.get('nginx.ingress.kubernetes.io/ssl-redirect') == 'true' , "redeploy must keep RedisInsight ssl-redirect";
}
