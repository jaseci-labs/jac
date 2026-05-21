"""Tests for TLS-state preservation in IngressDeployer._deploy_ingress_resource.

Every redeployment via jac start --scale calls _deploy_ingress_resource, which
uses replace_namespaced_ingress (a full PUT).  Without reading the existing
Ingress first, the PUT wipes spec.tls, the rule host, and the TLS annotations
that --enable-tls previously wrote.  These tests guard that regression.
"""

import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jac_scale.targets.kubernetes { ingress as ingress_module }
import from jac_scale.targets.kubernetes.ingress { IngressDeployer }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }

# ── Helpers ───────────────────────────────────────────────────────────────────

def _tls_ingress_dict(host: str, secret: str) -> dict {
    return {
        'metadata': {
            'annotations': {
                'cert-manager.io/issuer': 'letsencrypt-prod',
                'nginx.ingress.kubernetes.io/ssl-redirect': 'true',
                'nginx.ingress.kubernetes.io/force-ssl-redirect': 'true',
                'jac-scale/domain': host
            }
        },
        'spec': {
            'ingressClassName': 'test-ns-myapp-nginx',
            'rules': [{'host': host, 'http': {'paths': [{'path': '/'}]}}],
            'tls': [{'hosts': [host], 'secretName': secret}]
        }
    };
}

def _no_tls_ingress_dict() -> dict {
    return {
        'metadata': {'annotations': {}},
        'spec': {
            'ingressClassName': 'test-ns-myapp-nginx',
            'rules': [{'http': {'paths': [{'path': '/'}]}}],
            'tls': []
        }
    };
}

def _make_deployer(domain: str = '', cert_email: str = '') -> IngressDeployer {
    cfg = KubernetesConfig(domain=domain, cert_manager_email=cert_email);
    return IngressDeployer(k8s_config=cfg);
}

# ── Tests ─────────────────────────────────────────────────────────────────────

test "deploy ingress resource preserves tls spec on redeployment" {
    # Verifies the primary regression: a redeployment after --enable-tls must
    # keep spec.tls, the rule host, and the three TLS annotations intact.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    mock_api_client = unittest.mock.MagicMock();
    mock_api_client.sanitize_for_serialization.return_value = _tls_ingress_dict(
        'example.com', 'myapp-tls'
    );

    with unittest.mock.patch.object(
        ingress_module.client, 'ApiClient', lambda: mock_api_client
    ) {
        deployer = _make_deployer(domain='example.com', cert_email='a@b.com');
        deployer._deploy_ingress_resource(
            'myapp', 'test-ns', 'test-ns-myapp-nginx', 8000,
            False, False, False, networking_v1, core_v1
        );
    }

    call_args = networking_v1.replace_namespaced_ingress.call_args;
    body = call_args[1]['body'];

    assert body['spec'].get('tls') == [{'hosts': ['example.com'], 'secretName': 'myapp-tls'}] ,
        "spec.tls must be carried forward from the existing Ingress";
    assert body['spec']['rules'][0].get('host') == 'example.com' ,
        "rule host must be carried forward from the existing Ingress";
    ann = body['metadata']['annotations'];
    assert ann.get('cert-manager.io/issuer') == 'letsencrypt-prod' ,
        "cert-manager.io/issuer annotation must be preserved";
    assert ann.get('nginx.ingress.kubernetes.io/ssl-redirect') == 'true' ,
        "ssl-redirect annotation must be preserved";
    assert ann.get('nginx.ingress.kubernetes.io/force-ssl-redirect') == 'true' ,
        "force-ssl-redirect annotation must be preserved";
}

test "deploy ingress resource uses wildcard rule when no existing ingress" {
    # First deploy: Ingress does not exist yet (read returns 404).
    # The new body must have no host and no tls — behaviour identical to before the fix.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.read_namespaced_ingress.side_effect = ApiException(status=404);

    deployer = _make_deployer();
    deployer._deploy_ingress_resource(
        'myapp', 'test-ns', 'test-ns-myapp-nginx', 8000,
        False, False, False, networking_v1, core_v1
    );

    call_args = networking_v1.replace_namespaced_ingress.call_args;
    body = call_args[1]['body'];
    assert body['spec'].get('tls') is None ,
        "spec.tls must be absent on first deploy";
    assert body['spec']['rules'][0].get('host') is None ,
        "rule host must be absent on first deploy";
}

test "deploy ingress resource re-raises non-404 read error" {
    # A 500 (or any non-404) from read_namespaced_ingress is a real API failure
    # and must not be swallowed — only 404 (Ingress not yet created) is expected.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    networking_v1.read_namespaced_ingress.side_effect = ApiException(status=500);

    deployer = _make_deployer();
    raised = False;
    try {
        deployer._deploy_ingress_resource(
            'myapp', 'test-ns', 'test-ns-myapp-nginx', 8000,
            False, False, False, networking_v1, core_v1
        );
    } except ApiException as e {
        raised = e.status == 500;
    }
    assert raised , "Non-404 ApiException from read_namespaced_ingress must propagate";
}

test "deploy ingress resource preserves redis insight tls on redeployment" {
    # The RedisInsight Ingress has the same PUT-wipe risk as the main Ingress.
    # sanitize_for_serialization is called once per Ingress; side_effect drives
    # the main-ingress read to return no TLS and the redis read to return TLS.
    networking_v1 = unittest.mock.MagicMock();
    core_v1 = unittest.mock.MagicMock();
    mock_api_client = unittest.mock.MagicMock();
    mock_api_client.sanitize_for_serialization.side_effect = [
        _no_tls_ingress_dict(),
        _tls_ingress_dict('example.com', 'myapp-tls')
    ];

    with unittest.mock.patch.object(
        ingress_module.client, 'ApiClient', lambda: mock_api_client
    ) {
        cfg = KubernetesConfig(
            domain='example.com',
            cert_manager_email='a@b.com',
            redis_insight_username='admin',
            redis_insight_password='secret'
        );
        deployer = IngressDeployer(k8s_config=cfg);
        deployer._deploy_ingress_resource(
            'myapp', 'test-ns', 'test-ns-myapp-nginx', 8000,
            False, True, False, networking_v1, core_v1
        );
    }

    # replace_namespaced_ingress is called twice: main ingress first, redis second.
    all_calls = networking_v1.replace_namespaced_ingress.call_args_list;
    assert len(all_calls) == 2 , "Expected two replace_namespaced_ingress calls";
    redis_body = all_calls[1][1]['body'];

    assert redis_body['spec'].get('tls') == [{'hosts': ['example.com'], 'secretName': 'myapp-tls'}] ,
        "RedisInsight Ingress spec.tls must be preserved on redeployment";
    assert redis_body['spec']['rules'][0].get('host') == 'example.com' ,
        "RedisInsight Ingress rule host must be preserved on redeployment";
    ann = redis_body['metadata']['annotations'];
    assert ann.get('cert-manager.io/issuer') == 'letsencrypt-prod' ,
        "cert-manager.io/issuer must be preserved on RedisInsight Ingress";
}
