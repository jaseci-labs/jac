"""Tests for Kubernetes deployment using new factory-based architecture."""

import base64;
import json;
import os;
import subprocess;
import time;
import requests;
import importlib.resources;
import from pathlib { Path }
import from typing { Any }

import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }

import unittest.mock;
import from types { SimpleNamespace }

import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.abstractions.models.deployment_result { DeploymentResult }
import from jac_scale.config_loader { JacScaleConfig, get_scale_config }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.factories.database_factory { DatabaseProviderFactory }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.ingress { IngressDeployer }
import from jac_scale.factories.autoscaler_factory { AutoscalerFactory }
import from jac_scale.abstractions.autoscaler { AutoscalerSpec, Trigger }

"""Get current git repository URL, branch, and commit hash.

Returns:
    Tuple of (repo_url, branch, commit_hash)
"""
def _get_git_config -> tuple[str, str, str] {
    try {
        current_dir = os.path.dirname(os.path.abspath(__file__));
        git_root = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=current_dir,
            text=True,
            stderr=subprocess.PIPE
        ).strip();

        repo_url = None;
        branch = None;
        commit = None;

        # Check if this is a Pull Request with event data available
        if (
            "GITHUB_HEAD_REF" in os.environ
            and os.environ["GITHUB_HEAD_REF"]
            and "GITHUB_EVENT_PATH" in os.environ
        ) {
            try {
                with open(os.environ["GITHUB_EVENT_PATH"]) as f {
                    event_data = json.load(f);
                }

                if "pull_request" in event_data {
                    pr_data = event_data["pull_request"];
                    head_repo = pr_data.get("head", {}).get("repo");
                    base_repo = pr_data.get("base", {}).get("repo");
                    if head_repo and base_repo {
                        head_full_name = head_repo.get("full_name", "");
                        base_full_name = base_repo.get("full_name", "");
                        if head_full_name != base_full_name {
                            repo_url = head_repo.get("clone_url");
                            branch = os.environ.get("GITHUB_HEAD_REF");
                            commit = pr_data.get("head", {}).get("sha");
                            print(f"Detected fork-based PR from {head_full_name}");
                        } else {
                            repo_url = base_repo.get("clone_url");
                            branch = "main";
                            commit = pr_data.get("base", {}).get("sha");
                            print(
                                f"Detected non-fork PR in {base_full_name}, using main branch"
                            );
                        }
                    }
                }
            } except (FileNotFoundError, json.JSONDecodeError, KeyError) as e {
                print(f"Warning: Could not parse GitHub event data: {e}");
            }
        }

        if not repo_url {
            repo_url = subprocess.check_output(
                ["git", "remote", "get-url", "origin"], cwd=git_root, text=True
            ).strip();
        }

        if not branch {
            if "GITHUB_HEAD_REF" in os.environ and os.environ["GITHUB_HEAD_REF"] {
                branch = os.environ["GITHUB_HEAD_REF"];
            } elif "GITHUB_REF_NAME" in os.environ {
                branch = os.environ["GITHUB_REF_NAME"];
            } elif "GITHUB_REF" in os.environ {
                ref = os.environ["GITHUB_REF"];
                if ref.startswith("refs/heads/") {
                    branch = ref.replace("refs/heads/", "");
                } elif ref.startswith("refs/tags/") {
                    branch = ref.replace("refs/tags/", "");
                }
            }
            if not branch {
                branch = subprocess.check_output(
                    ["git", "branch", "--show-current"], cwd=git_root, text=True
                ).strip();
            }
            if not branch {
                try {
                    branch = subprocess.check_output(
                        ["git", "symbolic-ref", "--short", "HEAD"],
                        cwd=git_root,
                        text=True,
                        stderr=subprocess.PIPE
                    ).strip();
                } except subprocess.CalledProcessError {
                    try {
                        branches = (
                            subprocess.check_output(
                                ["git", "branch", "-r", "--contains", "HEAD"],
                                cwd=git_root,
                                text=True
                            ).strip().split(
                                "\n"
                            )
                        );

                        if branches and branches[0] {
                            branch = (
                                branches[0].strip().replace("origin/", "").replace(
                                    "*", ""
                                ).strip()
                            );
                        }
                    } except subprocess.CalledProcessError {
                        0;
                    }

                    if not branch {
                        branch = subprocess.check_output(
                            ["git", "rev-parse", "--short", "HEAD"],
                            cwd=git_root,
                            text=True
                        ).strip();
                        print(
                            f"Warning: Detached HEAD state, using short commit as branch: {branch}"
                        );
                    }
                }
            }
        }

        if not commit {
            commit = subprocess.check_output(
                ["git", "rev-parse", "HEAD"], cwd=git_root, text=True
            ).strip();
        }

        return (repo_url, branch, commit);
    } except subprocess.CalledProcessError as e {
        print(f"Error getting git config: {e}");
        raise;
    }
}

"""Make an HTTP request with retry logic for 503 responses."""
def _request_with_retry(
    method: str,
    url: str,
    json: dict[str, any] | None = None,
    timeout: int = 10,
    max_retries: int = 60,
    retry_interval: float = 2.0
) -> requests.Response {
    response = None;
    for attempt in range(max_retries) {
        response = requests.request(method=method, url=url, json=json, timeout=timeout);

        if response.status_code == 503 {
            print(
                f"[DEBUG] {url} returned 503, retrying ({attempt + 1}/{max_retries})..."
            );
            time.sleep(retry_interval);
            continue;
        }

        return response;
    }

    assert response is not None , "No response received";
    return response;
}

"""Test deployment early exit on failure."""
test "early exit" {
    config.load_kube_config();

    namespace = "early-exit";
    app_name = namespace;

    test_dir = os.path.dirname(os.path.abspath(__file__));
    todo_app_path = os.path.join(test_dir, "../../examples/early-exit");

    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;
    target_config["ingress_node_port"] = 30081;

    logger = UtilityFactory.create_logger("standard");

    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    );

    app_config = AppConfig(
        code_folder=todo_app_path,
        file_name="app_err.jac",
        build=False,
        experimental=True
    );

    result: DeploymentResult = deployment_target.deploy(app_config);
    details = result.details;
    failure_message = result.message;
    print(f"Deployment result: {details}");
    assert "health_check_of_deployment" not in details;
    assert len(details) == 13;
    assert result.success is False;
    assert failure_message is not None and "Containers restarted" in failure_message;
}

"""Test individual methods of KubernetesTarget."""
test "deployment target methods" {
    config.load_kube_config();

    namespace = "test-methods";
    app_name = "test-methods-app";

    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;

    logger = UtilityFactory.create_logger("standard");
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    );

    # Test get_service_url (before deployment, should return None or handle gracefully)
    service_url = deployment_target.get_service_url(app_name);
    assert service_url is None or isinstance(service_url, str);

    # Test get_status (before deployment, should handle gracefully)
    try {
        status = deployment_target.get_status(app_name);
        assert status is not None;
    } except Exception {
        0;
    }
}

"""Test that redis.conf.template is included in package distribution."""
test "redis template file in package" {
    try {
        ref = importlib.resources.files("jac_scale") / "providers" / "database" / "redis.conf.template";
        assert ref.is_file() , (
            "redis.conf.template not discoverable as package data. "
            "Ensure it's included via pyproject.toml package-data"
        );

        # Verify it's readable and has content
        content = ref.read_text(encoding='utf-8');
        assert len(content) > 0 , "redis.conf.template should not be empty";
        assert 'maxmemory-policy' in content , (
            "redis.conf.template should contain Redis configuration directives"
        );
    } except (FileNotFoundError, ModuleNotFoundError) as e {
        raise AssertionError(
            f"redis.conf.template not found via importlib.resources: {e}. "
            "Ensure it's included via pyproject.toml package-data"
        );
    }
}


# Unit tests for security hardening patterns (dict construction)
# These tests do not require a live Kubernetes cluster.

# Verify database provider manifests include secure container security contexts.
test "kubernetes database provider security context" {
    mongo_provider = DatabaseProviderFactory.create(
        'kubernetes_mongo', None, {'app_name': 'test-app'}
    );
    mongo_deploy = mongo_provider.deploy();
    mongo_container = mongo_deploy['deployment']['spec']['template']['spec'][
        'containers'
    ][0];
    mongo_sc = mongo_container['securityContext'];
    assert mongo_sc['runAsNonRoot'] is True;
    assert mongo_sc['readOnlyRootFilesystem'] is True;
    assert mongo_sc['allowPrivilegeEscalation'] is False;
    assert mongo_sc['capabilities']['drop'] == ['ALL'];
    assert mongo_sc['seccompProfile']['type'] == 'RuntimeDefault';

    redis_provider = DatabaseProviderFactory.create(
        'kubernetes_redis', None, {'app_name': 'test-app'}
    );
    redis_deploy = redis_provider.deploy();
    redis_container = redis_deploy['deployment']['spec']['template']['spec'][
        'containers'
    ][0];
    redis_sc = redis_container['securityContext'];
    assert redis_sc['runAsNonRoot'] is True;
    assert redis_sc['readOnlyRootFilesystem'] is True;
    assert redis_sc['allowPrivilegeEscalation'] is False;
    assert redis_sc['capabilities']['drop'] == ['ALL'];
    assert redis_sc['seccompProfile']['type'] == 'RuntimeDefault';

    # ServiceAccounts should not auto-mount tokens
    assert mongo_deploy['service_account']['automountServiceAccountToken'] is False;
    assert redis_deploy['service_account']['automountServiceAccountToken'] is False;
}

# Fake networking client for use in kubernetes target security policy dicts test.
obj FakeNetworkingV1 {
    has created_policies: list = [];

    def read_namespaced_network_policy(name: str, namespace: str) {
        e = ApiException();
        e.status = 404;
        raise e;
    }

    def create_namespaced_network_policy(namespace: str, body: dict[(str, Any)]) {
        self.created_policies.append(body);
    }

    def replace_namespaced_network_policy(
        name: str, namespace: str, body: dict[(str, Any)]
    ) {
        # Not used in this test
        self.created_policies.append(body);
    }
}

# Verify KubernetesTarget container/security settings and NetworkPolicy structure.
test "kubernetes target security policy dicts" {
    # Build a target with default config
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config['app_name'] = 'test-app';
    target_config['namespace'] = 'test-ns';
    logger = UtilityFactory.create_logger('standard');
    deployment_target = DeploymentTargetFactory.create(
        'kubernetes', target_config, logger
    );

    # Verify container security context produced by _build_container_config
    probe_configs = deployment_target._build_probe_config('/health');
    resources = deployment_target._build_resource_config();
    container = deployment_target._build_container_config(
        'test-app',
        'example/image:latest',
        probe_configs,
        resources,
        secret_ref_name='test-secret'
    );
    sc = container['securityContext'];
    assert sc['runAsNonRoot'] is True;
    assert sc['readOnlyRootFilesystem'] is True;
    assert sc['allowPrivilegeEscalation'] is False;
    assert sc['capabilities']['drop'] == ['ALL'];
    assert sc['seccompProfile']['type'] == 'RuntimeDefault';

    # Verify NetworkPolicy dict structure via deploy function (using fake client)
    app_name = 'test-app';
    namespace = 'test-ns';

    fake_net = FakeNetworkingV1();
    deployment_target._deploy_network_policy(app_name, namespace, fake_net);

    # Should have created all component policies
    expected_policy_names = [
        f"{app_name}-network-policy",
        f"{app_name}-mongodb-network-policy",
        f"{app_name}-redis-network-policy",
        f"{app_name}-prometheus-network-policy",
        f"{app_name}-grafana-network-policy",
        f"{app_name}-code-server-network-policy",
        f"{app_name}-kube-state-metrics-network-policy",
        f"{app_name}-node-exporter-network-policy",

    ];
    created_names = [p['metadata']['name'] for p in fake_net.created_policies];
    for name in expected_policy_names {
        assert name in created_names;
    }

    # Verify common metadata/structure for all policies
    for p in fake_net.created_policies {
        assert p['metadata']['labels']['app'] == app_name;
        assert p['metadata']['labels']['managed'] == 'jac-scale';
        assert p['spec']['policyTypes'] == ['Ingress', 'Egress'];
        assert p['spec']['podSelector']['matchLabels']['app'] is not None;
        # Egress should include DNS access to kube-system
        egress_rules = p['spec']['egress'];
        assert any(
            rule.get('to', [])[0].get('namespaceSelector', {}).get(
                'matchLabels', {}
            ).get(
                'kubernetes.io/metadata.name'
            ) == 'kube-system'
            for rule in egress_rules
            if rule.get('to')
        );
    }

    # Verify app policy allows inbound traffic on correct container port
    app_policy = next(
        (
            p
            for p in fake_net.created_policies
            if p['metadata']['name'] == f"{app_name}-network-policy"
        ),
        None
    );
    assert app_policy is not None;
    app_ports = app_policy['spec']['ingress'][0]['ports'];
    assert app_ports[0]['port'] == deployment_target.k8s_config.container_port;

    # Verify MongoDB and Redis policies allow traffic from both app and dashboard pods.
    mongo_policy = next(
        (
            p
            for p in fake_net.created_policies
            if p['metadata']['name'] == f"{app_name}-mongodb-network-policy"
        ),
        None
    );
    assert mongo_policy is not None;
    mongo_from = mongo_policy['spec']['ingress'][0]['from'];
    assert {'podSelector': {'matchLabels': {'app': app_name}}} in mongo_from;
    assert {
        'podSelector': {'matchLabels': {'app': f"{app_name}-mongo-express"}}
    } in mongo_from;
    assert mongo_policy['spec']['ingress'][0]['ports'][0]['port'] == 27017;

    redis_policy = next(
        (
            p
            for p in fake_net.created_policies
            if p['metadata']['name'] == f"{app_name}-redis-network-policy"
        ),
        None
    );
    assert redis_policy is not None;
    redis_from = redis_policy['spec']['ingress'][0]['from'];
    assert {'podSelector': {'matchLabels': {'app': app_name}}} in redis_from;
    assert {
        'podSelector': {'matchLabels': {'app': f"{app_name}-redis-insight"}}
    } in redis_from;
    assert redis_policy['spec']['ingress'][0]['ports'][0]['port'] == 6379;
}
# ---------------------------------------------------------------------------
# Domain / TLS configuration tests (mocked - no live cluster required)
# ---------------------------------------------------------------------------
test "get service url switches between http and https based on tls state" {
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = "myapp";
    target_config["namespace"] = "default";
    target_config["domain"] = "app.example.com";
    logger = UtilityFactory.create_logger("standard");
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    );

    mock_networking_v1 = unittest.mock.MagicMock();

    # Case 1: TLS active -> https
    tls_entry = SimpleNamespace(hosts=["app.example.com"], secret_name="myapp-tls");
    mock_networking_v1.read_namespaced_ingress.return_value = SimpleNamespace(
        spec=SimpleNamespace(tls=[tls_entry])
    );
    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jac_scale.targets.kubernetes.kubernetes_target.client.NetworkingV1Api",
            return_value=mock_networking_v1
        ) {
            assert deployment_target.get_service_url("myapp") == "https://app.example.com";
        }
    }

    # Case 2: no TLS yet -> http
    mock_networking_v1.read_namespaced_ingress.return_value = SimpleNamespace(
        spec=SimpleNamespace(tls=[])
    );
    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jac_scale.targets.kubernetes.kubernetes_target.client.NetworkingV1Api",
            return_value=mock_networking_v1
        ) {
            assert deployment_target.get_service_url("myapp") == "http://app.example.com";
        }
    }
}

test "enable tls raises when no domain configured" {
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = "myapp";
    target_config["namespace"] = "default";
    target_config["domain"] = "";
    logger = UtilityFactory.create_logger("standard");
    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    );

    # Return an ingress with no annotations so domain falls back to the empty
    # config value, causing IngressDeployer.enable_tls to raise "No domain found"
    mock_networking_v1 = unittest.mock.MagicMock();
    mock_networking_v1.read_namespaced_ingress.return_value = SimpleNamespace(
        metadata=SimpleNamespace(annotations=None)
    );

    raised = False;
    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jac_scale.targets.kubernetes.kubernetes_target.client.NetworkingV1Api",
            return_value=mock_networking_v1
        ) {
            with unittest.mock.patch(
                "jac_scale.targets.kubernetes.kubernetes_target.client.CustomObjectsApi"
            ) {
                with unittest.mock.patch(
                    "jac_scale.targets.kubernetes.kubernetes_target.client.CoreV1Api"
                ) {
                    with unittest.mock.patch(
                        "jac_scale.targets.kubernetes.kubernetes_target.client.AppsV1Api"
                    ) {
                        try {
                            deployment_target.enable_tls("myapp");
                        } except Exception {
                            raised = True;
                        }
                    }
                }
            }
        }
    }
    assert raised , "enable_tls should raise when no domain is configured";
}

test "deploy with domain set stores domain in annotation not ingress host rule" {
    # Regression test: setting domain in jac.toml before the first deployment
    # must NOT add a host field to the ingress rule.  Adding a host before TLS
    # exists causes nginx to reject traffic from the raw NLB hostname, making
    # the app unreachable.  The fix stores the domain in a jac-scale/domain
    # annotation so --enable-tls can read it later and add the host + TLS
    # together in one atomic step.
    k8s_config = KubernetesConfig(
        domain="app.example.com", cert_manager_email="user@example.com"
    );
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_networking_v1 = unittest.mock.MagicMock();
    # Simulate ingress not yet existing (first deploy) so create path is taken
    mock_networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    mock_core_v1 = unittest.mock.MagicMock();
    # Simulate basic-auth secret not yet existing (replace returns 404, so create path is taken)
    mock_core_v1.replace_namespaced_secret.side_effect = ApiException(status=404);

    ingress_deployer._deploy_ingress_resource(
        app_name="myapp",
        namespace="default",
        ingress_class="myapp-nginx",
        service_port=8000,
        grafana_enabled=False,
        redis_dashboard=False,
        mongo_dashboard=False,
        networking_v1=mock_networking_v1,
        core_v1=mock_core_v1
    );

    assert mock_networking_v1.create_namespaced_ingress.called , "ingress should be created on first deploy";
    created_body = mock_networking_v1.create_namespaced_ingress.call_args[1]["body"];

    # Rule must NOT have a host - wildcard routing keeps the app reachable via
    # IP/NLB before TLS is enabled (the original bug: host set here caused nginx
    # to reject requests arriving via the raw NLB address)
    rule = created_body["spec"]["rules"][0];
    assert "host" not in rule , "ingress rule must not set host before TLS is enabled";

    # Domain must be persisted in the annotation so --enable-tls can read it later
    annotations = created_body["metadata"]["annotations"];
    assert annotations.get("jac-scale/domain") == "app.example.com" , "domain must be stored in jac-scale/domain annotation for --enable-tls";
    assert annotations.get("jac-scale/cert-email") == "user@example.com" , "cert_manager_email must be stored in jac-scale/cert-email annotation for --enable-tls";
}

test "redis ingress rule must not set host before TLS is enabled" {
    # Regression test: the Redis ingress had the same if self.k8s_config.domain →
    # host-in-rule bug as the main ingress.  Ensure the Redis rule is also
    # wildcard (no host) when domain is set but --enable-tls has not run yet.
    k8s_config = KubernetesConfig(
        domain="app.example.com", cert_manager_email="user@example.com"
    );
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_networking_v1 = unittest.mock.MagicMock();
    # Simulate ingress not yet existing for both main and Redis ingresses
    mock_networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    mock_core_v1 = unittest.mock.MagicMock();
    # Simulate basic-auth secret not yet existing (replace returns 404, so create path is taken)
    mock_core_v1.replace_namespaced_secret.side_effect = ApiException(status=404);

    ingress_deployer._deploy_ingress_resource(
        app_name="myapp",
        namespace="default",
        ingress_class="myapp-nginx",
        service_port=8000,
        grafana_enabled=False,
        redis_dashboard=True,
        mongo_dashboard=False,
        networking_v1=mock_networking_v1,
        core_v1=mock_core_v1
    );

    # Two ingresses should be created: main (index 0) and Redis (index 1)
    assert mock_networking_v1.create_namespaced_ingress.call_count == 2 , "both main and Redis ingresses should be created on first deploy";
    redis_created_body = mock_networking_v1.create_namespaced_ingress.call_args_list[1][
        1
    ]["body"];

    # Redis rule must NOT have a host — same requirement as the main ingress
    redis_rule = redis_created_body["spec"]["rules"][0];
    assert "host" not in redis_rule , "Redis ingress rule must not set host before TLS is enabled";
}
# ---------------------------------------------------------------------------
# Startup probe + resilient experimental runtime setup (no live cluster)
# Covers: startup-probe gating, SSH->HTTPS clone normalization, and the
# deb822-aware, non-blocking apt-get update.
# ---------------------------------------------------------------------------
test "startup probe gates liveness and experimental setup is resilient" {
    scale_config = get_scale_config();
    logger = UtilityFactory.create_logger('standard');

    # --- startup probe: present, on the health path, generous window so the
    # slow experimental install can't trip liveness into a crash loop ---
    base_cfg = scale_config.get_kubernetes_config();
    base_cfg['app_name'] = 'test-app';
    target = DeploymentTargetFactory.create('kubernetes', base_cfg, logger);
    probes = target._build_probe_config('/docs');
    assert 'startup' in probes , "startup probe must be built";
    sp = probes['startup'];
    assert sp['httpGet']['path'] == '/docs';
    assert sp['httpGet']['port'] == target.k8s_config.container_port;
    assert sp['failureThreshold'] >= 60 , "startup window too small for experimental install";
    container = target._build_container_config(
        'test-app', 'example/image:latest', probes, target._build_resource_config()
    );
    assert container['startupProbe'] == sp , "container must carry the startup probe";

    # --- experimental runtime setup: SSH urls normalized to anonymous HTTPS
    # (pod has no SSH key) and apt-get update is deb822-aware + non-fatal ---
    app_config = AppConfig(
        code_folder='/tmp', file_name='main.jac', build=False, experimental=True
    );
    # _build_runtime_setup_command returns ['bash', '-c', '<cmd && cmd && ...>']
    for (repo_in, expected) in [
        ('git@github.com:owner/repo.git', 'https://github.com/owner/repo.git'),
        ('ssh://git@github.com/owner/repo.git', 'https://github.com/owner/repo.git'),
        ('https://github.com/owner/repo.git', 'https://github.com/owner/repo.git')
    ] {
        cfg = scale_config.get_kubernetes_config();
        cfg['app_name'] = 'test-app';
        cfg['jaseci_repo_url'] = repo_in;
        t = DeploymentTargetFactory.create('kubernetes', cfg, logger);
        cmds = t._build_runtime_setup_command(app_config);
        assert cmds[0] == 'bash' and cmds[1] == '-c' , "runtime setup must be a bash -c script";
        steps = cmds[2].split(' && ');
        clone = next(
            (
                s
                for s in steps
                if s.startswith('git clone')
            ),
            ''
        );
        assert expected in clone , f"{repo_in} not normalized: {clone}";
        assert 'git@' not in clone and 'ssh://' not in clone , f"SSH url leaked: {clone}";
    }
    # apt assertions are repo-independent; check once on the last script
    assert any(
        'sources.list.d/*.sources' in s and 'trixie-updates' in s for s in steps
    ) , "deb822 .sources trixie-updates strip missing";
    assert any(
        s.startswith('apt-get') and 'Acquire::Retries' in s and '|| true' in s
        for s in steps
    ) , "resilient (bounded, non-fatal) apt-get update missing";
    assert 'apt-get update' not in steps , "bare blocking apt-get update must be replaced";
}
# ---------------------------------------------------------------------------
# RedisInsight (cache-dashboard) spec construction (no live cluster)
# Covers the PR's EULA auto-accept + encryption key, the sub-path proxy
# config, and secret-backed (never inlined) Redis credentials.
# ---------------------------------------------------------------------------
test "redis insight cache dashboard spec is correctly built" {
    provider = DatabaseProviderFactory.create(
        'kubernetes_redis', None, {'app_name': 'test-app'}
    );
    dash = provider.deploy_dashboard();
    assert dash['deployment_name'] == 'test-app-redis-insight';
    assert dash['service_name'] == 'test-app-redis-insight-service';

    container = dash['deployment']['spec']['template']['spec']['containers'][0];
    assert container['image'] == 'redis/redisinsight:3.2.0';
    assert container['ports'][0]['containerPort'] == 5540;
    sc = container['securityContext'];
    assert sc['runAsNonRoot'] is True;
    assert sc['readOnlyRootFilesystem'] is True;
    assert sc['allowPrivilegeEscalation'] is False;
    assert sc['capabilities']['drop'] == ['ALL'];

    env = {e['name']: e for e in container['env']};
    # EULA auto-accept + explicit encryption key (container has no OS keyring)
    assert env['RI_ACCEPT_TERMS_AND_CONDITIONS']['value'] == 'true';
    assert env['RI_ENCRYPTION_KEY']['value'] , "RI_ENCRYPTION_KEY must be set";
    # Pre-seeded connection to the in-cluster Redis service, served under the
    # ingress sub-path
    assert env['RI_REDIS_HOST']['value'] == 'test-app-redis-service';
    assert env['RI_REDIS_PORT']['value'] == '6379';
    assert env['RIPROXYPATH']['value'] == '/cache-dashboard';
    # Credentials come from the redis secret, never inlined as plaintext
    u = env['RI_REDIS_USERNAME']['valueFrom']['secretKeyRef'];
    p = env['RI_REDIS_PASSWORD']['valueFrom']['secretKeyRef'];
    assert u['name'] == 'test-app-redis-secret' and u['key'] == 'username';
    assert p['name'] == 'test-app-redis-secret' and p['key'] == 'password';
    assert 'value' not in env['RI_REDIS_PASSWORD'] , "password must not be inlined";

    assert dash['service']['spec']['ports'][0]['port'] == 5540;
    assert dash['service_account']['automountServiceAccountToken'] is False;
}

test "redis ACL is secret mounted not in configmap and creds validated" {
    provider = DatabaseProviderFactory.create(
        'kubernetes_redis', None, {'app_name': 'test-app'}
    );
    dep = provider.deploy();

    conf = dep['configmap']['data']['redis.conf'];
    assert 'aclfile /etc/redis-acl/users.acl' in conf;
    assert 'user default on >' not in conf , "ACL (with password) inlined into ConfigMap";
    secret_sd = dep['secret']['stringData'];
    assert 'users.acl' in secret_sd , "ACL file must be in the Secret";
    assert secret_sd['users.acl'].startswith('user default on >password');

    # ACL is mounted from the Secret on its own path, read-only
    pod = dep['deployment']['spec']['template']['spec'];
    acl_vol = next(
        (
            v
            for v in pod['volumes']
            if v['name'] == 'redis-acl'
        ),
        None
    );
    assert acl_vol is not None , "redis-acl volume missing";
    assert acl_vol['secret']['secretName'] == dep['secret_name'];
    assert acl_vol['secret']['items'][0]['key'] == 'users.acl';
    assert any(
        m['name'] == 'redis-acl'
        and m['mountPath'] == '/etc/redis-acl'
        and m.get('readOnly') is True for m in pod['containers'][0]['volumeMounts']
    ) , "redis-acl must be mounted read-only at /etc/redis-acl";

    raised = False;
    try {
        provider._build_acl_file('admin', "pw\nuser eve on nopass ~* +@all");
    } except ValueError {
        raised = True;
    }
    assert raised , "newline in password must be rejected";
    raised2 = False;
    try {
        provider._build_acl_file("ad min", 'password');
    } except ValueError {
        raised2 = True;
    }
    assert raised2 , "ACL-significant chars in username must be rejected";

    assert provider._build_connection_string('default', 'pw', 'h') == 'redis://default:pw@h:6379/0';
    assert provider._build_connection_string('admin', 'pw', 'h') == 'redis://admin:pw@h:6379/0';
    assert secret_sd['connection-string'] == provider.get_connection_string();
}

# ---------------------------------------------------------------------------
# Shared ingress mode unit tests (no live cluster)
# Covers: controller skip, immediate host rule, destroy guard, domain
# validation, and NodePort validation skip.
# ---------------------------------------------------------------------------
test "shared ingress skips deploying dedicated nginx controller" {
    # start_controller must be a no-op for _deploy_nginx_controller when
    # shared_ingress=True — a pre-existing cluster-wide controller is used.
    k8s_config = KubernetesConfig(shared_ingress=True, domain="myapp.example.com");
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_ctrl = unittest.mock.MagicMock();
    with unittest.mock.patch.object(
        ingress_deployer, '_deploy_nginx_controller', mock_ctrl
    ) {
        ingress_deployer.start_controller(
            app_name="myapp",
            namespace="default",
            provider=unittest.mock.MagicMock(),
            apps_v1=unittest.mock.MagicMock(),
            core_v1=unittest.mock.MagicMock(),
            rbac_v1=unittest.mock.MagicMock(),
            networking_v1=unittest.mock.MagicMock()
        );
    }
    assert not mock_ctrl.called , "_deploy_nginx_controller must not be called when shared_ingress=True";
}

test "shared ingress rule sets host immediately without waiting for tls" {
    # Dedicated mode keeps the rule wildcard (no host) until --enable-tls.
    # Shared mode must set the host immediately because the shared controller
    # routes across many namespaces by hostname; without a host two apps would
    # both claim '/' and collide.  Mirror of the L2009 dedicated-mode test.
    k8s_config = KubernetesConfig(shared_ingress=True, domain="myapp.example.com");
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_networking_v1 = unittest.mock.MagicMock();
    mock_networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);
    mock_core_v1 = unittest.mock.MagicMock();
    mock_core_v1.replace_namespaced_secret.side_effect = ApiException(status=404);

    ingress_deployer._deploy_ingress_resource(
        app_name="myapp",
        namespace="default",
        ingress_class="nginx",
        service_port=8000,
        grafana_enabled=False,
        redis_dashboard=False,
        mongo_dashboard=False,
        networking_v1=mock_networking_v1,
        core_v1=mock_core_v1
    );

    assert mock_networking_v1.create_namespaced_ingress.called , "ingress must be created";
    created_body = mock_networking_v1.create_namespaced_ingress.call_args[1]["body"];
    rule = created_body["spec"]["rules"][0];
    assert rule.get("host") == "myapp.example.com" , "shared ingress rule must set host immediately so the shared controller can route by hostname";
    assert created_body["spec"]["ingressClassName"] == "nginx" , "ingressClassName must use shared_ingress_class";
}

test "shared ingress destroy skips controller resource teardown" {
    # App-level Ingress objects are always cleaned up.  The NGINX controller
    # Deployment, Service, ServiceAccount, ConfigMap, ClusterRole,
    # ClusterRoleBinding, and IngressClass must NOT be deleted — those belong
    # to the shared controller and are managed externally.
    k8s_config = KubernetesConfig(shared_ingress=True, domain="myapp.example.com");
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_apps_v1 = unittest.mock.MagicMock();
    mock_core_v1 = unittest.mock.MagicMock();
    mock_rbac_v1 = unittest.mock.MagicMock();
    mock_networking_v1 = unittest.mock.MagicMock();
    # delete_if_exists swallows 404; let all deletes appear as 404 so the
    # function stays a no-op while still recording the call.
    not_found = ApiException();
    not_found.status = 404;
    mock_networking_v1.delete_namespaced_ingress.side_effect = not_found;
    mock_core_v1.delete_namespaced_secret.side_effect = not_found;

    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.delete_namespaced_custom_object.side_effect = not_found;

    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.ingress.client"
    ) as mock_client {
        mock_client.CustomObjectsApi.return_value = mock_custom_api;
        ingress_deployer.destroy(
            app_name="myapp",
            namespace="default",
            apps_v1=mock_apps_v1,
            core_v1=mock_core_v1,
            rbac_v1=mock_rbac_v1,
            networking_v1=mock_networking_v1
        );
    }

    # App ingress objects must always be cleaned up
    assert mock_networking_v1.delete_namespaced_ingress.called , "app Ingress resource must be deleted regardless of shared_ingress mode";

    # Controller resources must be left untouched
    assert not mock_apps_v1.delete_namespaced_deployment.called , "controller Deployment must not be deleted in shared ingress mode";
    assert not mock_core_v1.delete_namespaced_service_account.called , "controller ServiceAccount must not be deleted in shared ingress mode";
    assert not mock_rbac_v1.delete_cluster_role.called , "ClusterRole must not be deleted in shared ingress mode";
    assert not mock_rbac_v1.delete_cluster_role_binding.called , "ClusterRoleBinding must not be deleted in shared ingress mode";
    assert not mock_networking_v1.delete_ingress_class.called , "IngressClass must not be deleted in shared ingress mode";
}

test "shared ingress deploy fails fast when domain is not set" {
    # The domain is mandatory in shared mode because the shared controller
    # routes by Host header; without it two apps cannot be told apart.
    # The check must fire before any Kubernetes API call is made.
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config['app_name'] = 'test-app';
    target_config['namespace'] = 'test-ns';
    target_config['shared_ingress'] = True;
    target_config['domain'] = '';  # explicitly empty — the invalid state

    logger = UtilityFactory.create_logger('standard');
    deployment_target = DeploymentTargetFactory.create(
        'kubernetes', target_config, logger
    );

    app_config = AppConfig(
        code_folder='/tmp', file_name='main.jac', build=False, experimental=False
    );

    result = deployment_target.deploy(app_config);

    assert result.success is False , "deploy must fail when shared_ingress=True but domain is empty";
    assert "domain" in result.message.lower() , "error message must mention domain requirement";
    # validate_shared_ingress must NOT be present — the exception fires before
    # details['validate_shared_ingress'] is written
    assert "validate_shared_ingress" not in result.details , "deploy must abort before recording validate_shared_ingress";
}

test "shared ingress deploy skips nodeport validation" {
    # validate_ports is the mechanism that rejects a conflicting NodePort on
    # local clusters.  In shared ingress mode no NodePort is created, so
    # calling validate_ports would be incorrect (it may also reject valid ports
    # that the shared controller already owns).
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config['app_name'] = 'test-app';
    target_config['namespace'] = 'test-ns';
    target_config['shared_ingress'] = True;
    target_config['domain'] = 'myapp.example.com';

    logger = UtilityFactory.create_logger('standard');
    deployment_target = DeploymentTargetFactory.create(
        'kubernetes', target_config, logger
    );

    app_config = AppConfig(
        code_folder='/tmp', file_name='main.jac', build=False, experimental=False
    );

    mock_provider = unittest.mock.MagicMock();
    mock_provider.needs_nlb_wait.return_value = False;
    mock_provider.log_ingress_deployed.return_value = None;

    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jac_scale.targets.kubernetes.kubernetes_target.check_K8s_status"
        ) {
            with unittest.mock.patch(
                "jac_scale.targets.kubernetes.kubernetes_target.ensure_namespace_exists"
            ) {
                with unittest.mock.patch(
                    "jac_scale.targets.kubernetes.kubernetes_target.load_env_variables",
                    return_value=[]
                ) {
                    with unittest.mock.patch(
                        "jac_scale.targets.kubernetes.kubernetes_target.get_cluster_provider",
                        return_value=mock_provider
                    ) {
                        with unittest.mock.patch(
                            "jac_scale.targets.kubernetes.kubernetes_target.client"
                        ) {
                            # deploy() may fail at a later step once mocked K8s
                            # APIs return generic MagicMocks — that is expected.
                            # We only care that the provider was obtained and
                            # validate_ports was never invoked on it.
                            deployment_target.deploy(app_config);
                        }
                    }
                }
            }
        }
    }

    assert not mock_provider.validate_ports.called , "validate_ports must not be called when shared_ingress=True — no NodePort is created";
}

test "shared ingress merges caller-supplied annotations for non-nginx controllers" {
    # A non-nginx shared controller (e.g. AWS ALB) is driven entirely by the
    # annotations the caller supplies. They must land on the Ingress metadata,
    # ingressClassName must be the shared class, and nginx-specific tuning must
    # NOT be emitted (it is meaningless to a non-nginx controller).
    custom = {
        "alb.ingress.kubernetes.io/group.name": "shared-alb",
        "alb.ingress.kubernetes.io/scheme": "internet-facing",
        "alb.ingress.kubernetes.io/certificate-arn": "arn:aws:acm:us-east-2:1:certificate/x"
    };
    k8s_config = KubernetesConfig(
        shared_ingress=True,
        shared_ingress_class="alb",
        shared_ingress_annotations=custom,
        domain="linkedin.jaseci.app"
    );
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_networking_v1 = unittest.mock.MagicMock();
    mock_networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);
    mock_core_v1 = unittest.mock.MagicMock();
    mock_core_v1.replace_namespaced_secret.side_effect = ApiException(status=404);

    ingress_deployer._deploy_ingress_resource(
        app_name="myapp",
        namespace="default",
        ingress_class="alb",
        service_port=8000,
        grafana_enabled=False,
        redis_dashboard=False,
        mongo_dashboard=False,
        networking_v1=mock_networking_v1,
        core_v1=mock_core_v1
    );

    assert mock_networking_v1.create_namespaced_ingress.called , "ingress must be created";
    created_body = mock_networking_v1.create_namespaced_ingress.call_args[1]["body"];
    annos = created_body["metadata"]["annotations"];
    assert annos["alb.ingress.kubernetes.io/group.name"] == "shared-alb" , "caller annotations must be merged onto the ingress";
    assert annos["alb.ingress.kubernetes.io/certificate-arn"].startswith(
        "arn:aws:acm"
    ) , "ACM cert annotation must be present";
    assert created_body["spec"]["ingressClassName"] == "alb" , "ingressClassName must be the shared class";
    for key in annos.keys() {
        assert not str(key).startswith("nginx.ingress.kubernetes.io/") , f"nginx annotation leaked onto non-nginx ingress: {key}";
    }
}
