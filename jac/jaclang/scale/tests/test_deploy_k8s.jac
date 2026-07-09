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

import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.config.config_loader { JacScaleConfig, get_scale_config }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.deploy.database.factory { DatabaseProviderFactory }
import from jaclang.scale.deploy.database { kubernetes_redis as redis_module }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerSpec, Trigger }

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
        code_folder=todo_app_path, file_name="app_err.jac", no_image=True
    );

    result: DeploymentResult = deployment_target.deploy(app_config);
    details = result.details;
    failure_message = result.message;
    print(f"Deployment result: {details}");
    # app_err.jac has compile errors, so it cannot be sealed into a .jab. The
    # deploy now fails fast at binary prep rather than shipping a source bundle
    # that would crash-loop in the cluster; it never reaches the health check.
    assert result.success is False;
    assert "health_check_of_deployment" not in details;
    assert failure_message is not None;
    assert (
        "jac runtime" in failure_message or "seal" in failure_message.lower()
    ) , failure_message;
}

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

    service_url = deployment_target.get_service_url(app_name);
    assert service_url is None or isinstance(service_url, str);

    try {
        status = deployment_target.get_status(app_name);
        assert status is not None;
    } except Exception {
        0;
    }
}

def _make_fleet_target(app_name: str = "svc-a", namespace: str = "fleet-ns") -> any {
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;
    logger = UtilityFactory.create_logger("standard");
    return DeploymentTargetFactory.create(
        "kubernetes-microservice", target_config, logger
    );
}

def _fleet_bundle(app_name: str = "svc-a") -> dict[str, any] {
    return {
        "deployments": {
            app_name: {
                "metadata": {
                    "name": f"{app_name}-deployment",
                    "labels": {"app": app_name}
                }
            }
        }
    };
}

# Patches the AppsV1Api/CoreV1Api used by _wait_for_fleet_rollout with the
# given fakes and runs the rollout wait, returning whatever it raised (or
# None on a clean return) so each test can assert on outcome, not plumbing.
def _run_fleet_rollout(
    deployment_target: any,
    bundle: dict[str, any],
    fake_apps_v1: any,
    fake_core_v1: any,
    timeout: int = 30
) -> (Exception | None) {
    caught: (Exception | None) = None;
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.microservice.target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.microservice.target.client.AppsV1Api",
            return_value=fake_apps_v1
        ) {
            with unittest.mock.patch(
                "jaclang.scale.deploy.target.kubernetes.microservice.target.client.CoreV1Api",
                return_value=fake_core_v1
            ) {
                with unittest.mock.patch.object(time, "sleep") {
                    try {
                        deployment_target._wait_for_fleet_rollout(
                            bundle, timeout=timeout
                        );
                    } except Exception as e {
                        caught = e;
                    }
                }
            }
        }
    }
    return caught;
}

test "fleet rollout ignores crash-looping pod from a stale replica set" {
    deployment_target = _make_fleet_target();
    bundle = _fleet_bundle();

    current_hash = "new-hash";
    stale_hash = "old-hash";

    current_rs = unittest.mock.MagicMock();
    current_rs.metadata.labels = {"pod-template-hash": current_hash, "app": "svc-a"};
    current_rs.metadata.annotations = {"deployment.kubernetes.io/revision": "2"};

    stale_rs = unittest.mock.MagicMock();
    stale_rs.metadata.labels = {"pod-template-hash": stale_hash, "app": "svc-a"};
    stale_rs.metadata.annotations = {"deployment.kubernetes.io/revision": "1"};

    fake_apps_v1 = unittest.mock.MagicMock();
    fake_apps_v1.list_namespaced_replica_set.return_value.items = [
        stale_rs,
        current_rs
    ];
    fake_apps_v1.read_namespaced_deployment.side_effect = [
        SimpleNamespace(status=SimpleNamespace(ready_replicas=0)),
        SimpleNamespace(status=SimpleNamespace(ready_replicas=1)),

    ];

    healthy_pod = unittest.mock.MagicMock();
    healthy_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": current_hash};
    healthy_pod.metadata.name = "svc-a-healthy";
    healthy_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=0)];
    healthy_pod.status.phase = "Running";

    stale_pod = unittest.mock.MagicMock();
    stale_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": stale_hash};
    stale_pod.metadata.name = "svc-a-stale-crash";
    stale_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=5)];
    stale_pod.status.phase = "Running";

    fake_core_v1 = unittest.mock.MagicMock();
    fake_core_v1.list_namespaced_pod.return_value.items = [stale_pod, healthy_pod];

    caught = _run_fleet_rollout(deployment_target, bundle, fake_apps_v1, fake_core_v1);

    assert caught is None , "stale crash-looping pod must not block the wait";
    assert fake_apps_v1.read_namespaced_deployment.call_count == 2 , "fleet must reach ready on the next poll";
}

# A current-RS crash pod is never filtered out by the hash scoping, so this
# also passes under an unconditional broad scan; kept as an over-suppression
# guard, not a test of the RS-scoping fix itself.
test "fleet rollout still fails when a current replica set pod is crash-looping" {
    deployment_target = _make_fleet_target();
    bundle = _fleet_bundle();

    current_hash = "new-hash";

    current_rs = unittest.mock.MagicMock();
    current_rs.metadata.labels = {"pod-template-hash": current_hash, "app": "svc-a"};
    current_rs.metadata.annotations = {"deployment.kubernetes.io/revision": "2"};

    fake_apps_v1 = unittest.mock.MagicMock();
    fake_apps_v1.list_namespaced_replica_set.return_value.items = [current_rs];
    fake_apps_v1.read_namespaced_deployment.return_value = SimpleNamespace(
        status=SimpleNamespace(ready_replicas=0)
    );

    crash_pod = unittest.mock.MagicMock();
    crash_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": current_hash};
    crash_pod.metadata.name = "svc-a-crash";
    crash_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=5)];
    crash_pod.status.phase = "Running";

    fake_core_v1 = unittest.mock.MagicMock();
    fake_core_v1.list_namespaced_pod.return_value.items = [crash_pod];

    caught = _run_fleet_rollout(deployment_target, bundle, fake_apps_v1, fake_core_v1);

    assert caught is not None and "crash-looping" in str(caught) , "a crash-looping pod from the current RS must still fail the rollout wait";
}

test "fleet rollout still fails when a companion Deployment pod outside the fleet is crash-looping" {
    deployment_target = _make_fleet_target();
    bundle = _fleet_bundle();

    current_hash = "new-hash";

    current_rs = unittest.mock.MagicMock();
    current_rs.metadata.labels = {"pod-template-hash": current_hash, "app": "svc-a"};
    current_rs.metadata.annotations = {"deployment.kubernetes.io/revision": "2"};

    fake_apps_v1 = unittest.mock.MagicMock();
    fake_apps_v1.list_namespaced_replica_set.return_value.items = [current_rs];
    fake_apps_v1.read_namespaced_deployment.return_value = SimpleNamespace(
        status=SimpleNamespace(ready_replicas=0)
    );

    healthy_pod = unittest.mock.MagicMock();
    healthy_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": current_hash};
    healthy_pod.metadata.name = "svc-a-healthy";
    healthy_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=0)];
    healthy_pod.status.phase = "Running";

    # Redis is provisioned separately from the fleet's own microservice
    # Deployments (bundle["deployments"]), so "svc-a-redis" is never in
    # fleet_app_names and its pod-template-hash was never resolved into
    # current_hashes - it must still be checked for crashes. This is the
    # test that actually guards the fleet_app_names bypass in
    # _scan_for_crash_loop.
    redis_pod = unittest.mock.MagicMock();
    redis_pod.metadata.labels = {
        "app": "svc-a-redis",
        "pod-template-hash": "redis-hash-not-in-current-hashes"
    };
    redis_pod.metadata.name = "svc-a-redis-789";
    redis_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=5)];
    redis_pod.status.phase = "Running";

    fake_core_v1 = unittest.mock.MagicMock();
    fake_core_v1.list_namespaced_pod.return_value.items = [healthy_pod, redis_pod];

    caught = _run_fleet_rollout(deployment_target, bundle, fake_apps_v1, fake_core_v1);

    assert caught is not None and "crash-looping" in str(caught) , "a crash-looping companion Deployment pod (e.g. Redis) outside the fleet's own Deployments must still fail the rollout wait";
}

# Exercises the `except Exception` fallback in _wait_for_fleet_rollout, not
# the RS-scoping fix itself: it passes as long as the plain broad pod scan
# still detects crashes, independent of whether hash scoping exists at all.
test "fleet rollout falls back to broad pod scan when RS lookup fails" {
    deployment_target = _make_fleet_target();
    bundle = _fleet_bundle();

    fake_apps_v1 = unittest.mock.MagicMock();
    fake_apps_v1.list_namespaced_replica_set.side_effect = Exception(
        "RS API unavailable"
    );
    fake_apps_v1.read_namespaced_deployment.return_value = SimpleNamespace(
        status=SimpleNamespace(ready_replicas=0)
    );

    crash_pod = unittest.mock.MagicMock();
    crash_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": "whatever-hash"};
    crash_pod.metadata.name = "svc-a-crash";
    crash_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=5)];
    crash_pod.status.phase = "Running";

    fake_core_v1 = unittest.mock.MagicMock();
    fake_core_v1.list_namespaced_pod.return_value.items = [crash_pod];

    caught = _run_fleet_rollout(deployment_target, bundle, fake_apps_v1, fake_core_v1);

    assert caught is not None , "crash must still be detected via broad scan when RS lookup fails";
}

test "redis template file in package" {
    try {
        import jaclang.scale;
        import from pathlib { Path }
        # jaclang.scale is a .jac package (custom loader) that importlib.resources
        # can't traverse; resolve bundled data via the package __file__ instead.
        ref = Path(jaclang.scale.__file__).parent / "deploy" / "database" / "redis.conf.template";
        assert ref.is_file() , (
            "redis.conf.template not discoverable as package data. "
            "Ensure it ships next to the jaclang.scale package."
        );

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

    assert mongo_deploy['service_account']['automountServiceAccountToken'] is False;
    assert redis_deploy['service_account']['automountServiceAccountToken'] is False;
}

test "redis pod resources default to configured values" {
    redis_provider = DatabaseProviderFactory.create(
        'kubernetes_redis', None, {'app_name': 'test-app'}
    );
    redis_deploy = redis_provider.deploy();
    resources = redis_deploy['deployment']['spec']['template']['spec']['containers'][0][
        'resources'
    ];

    assert resources['requests']['cpu'] == '100m';
    assert resources['requests']['memory'] == '128Mi';
    assert resources['limits']['cpu'] == '500m';
    assert resources['limits']['memory'] == '1Gi';
}

test "default redis memory limit does not emit a headroom warning" {
    mock_logger = unittest.mock.MagicMock();

    with unittest.mock.patch.object(redis_module, 'logger', mock_logger) {
        redis_provider = DatabaseProviderFactory.create(
            'kubernetes_redis', None, {'app_name': 'test-app'}
        );
        redis_provider.deploy();
    }

    warned = any(
        'redis_memory_limit' in str(call) for call in mock_logger.warning.call_args_list
    );
    assert not warned , "default 1Gi limit over 200mb maxmemory must not warn";
}

test "redis pod resources propagate from [scale.database] config" {
    fake_config = SimpleNamespace(
        get_database_config=lambda :
            {
                'redis_max_memory': '200mb',
                'redis_cpu_request': '500m',
                'redis_cpu_limit': '2000m',
                'redis_memory_request': '1Gi',
                'redis_memory_limit': '4Gi'
            },
        get_kubernetes_config=lambda : {}
    );

    with unittest.mock.patch.object(
        redis_module, 'get_scale_config', lambda : fake_config
    ) {
        redis_provider = DatabaseProviderFactory.create(
            'kubernetes_redis', None, {'app_name': 'test-app'}
        );
        redis_deploy = redis_provider.deploy();
    }

    resources = redis_deploy['deployment']['spec']['template']['spec']['containers'][0][
        'resources'
    ];

    assert resources['requests']['cpu'] == '500m';
    assert resources['requests']['memory'] == '1Gi';
    assert resources['limits']['cpu'] == '2000m';
    assert resources['limits']['memory'] == '4Gi';
}

test "redis warns when memory limit lacks headroom over maxmemory" {
    fake_config = SimpleNamespace(
        get_database_config=lambda :
            {
                'redis_max_memory': '200mb',
                'redis_cpu_request': '250m',
                'redis_cpu_limit': '1000m',
                'redis_memory_request': '128Mi',
                'redis_memory_limit': '256Mi'
            },
        get_kubernetes_config=lambda : {}
    );
    mock_logger = unittest.mock.MagicMock();

    with unittest.mock.patch.object(
        redis_module, 'get_scale_config', lambda : fake_config
    ) {
        with unittest.mock.patch.object(redis_module, 'logger', mock_logger) {
            redis_provider = DatabaseProviderFactory.create(
                'kubernetes_redis', None, {'app_name': 'test-app'}
            );
            redis_provider.deploy();
        }
    }

    warned = any(
        'redis_memory_limit' in str(call) for call in mock_logger.warning.call_args_list
    );
    assert warned , "expected a headroom warning when limit <= 2x maxmemory";
}

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
        self.created_policies.append(body);
    }
}

test "kubernetes target security policy dicts" {
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config['app_name'] = 'test-app';
    target_config['namespace'] = 'test-ns';
    logger = UtilityFactory.create_logger('standard');
    deployment_target = DeploymentTargetFactory.create(
        'kubernetes', target_config, logger
    );

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

    app_name = 'test-app';
    namespace = 'test-ns';

    fake_net = FakeNetworkingV1();
    deployment_target._deploy_network_policy(app_name, namespace, fake_net);

    expected_policy_names = [
        f"{app_name}-network-policy",
        f"{app_name}-mongodb-network-policy",
        f"{app_name}-redis-network-policy",
        f"{app_name}-prometheus-network-policy",
        f"{app_name}-grafana-network-policy",
        f"{app_name}-kube-state-metrics-network-policy",
        f"{app_name}-node-exporter-network-policy",

    ];
    created_names = [p['metadata']['name'] for p in fake_net.created_policies];
    for name in expected_policy_names {
        assert name in created_names;
    }

    for p in fake_net.created_policies {
        assert p['metadata']['labels']['app'] == app_name;
        assert p['metadata']['labels']['managed'] == 'jac-scale';
        assert p['spec']['policyTypes'] == ['Ingress', 'Egress'];
        assert p['spec']['podSelector']['matchLabels']['app'] is not None;

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

    tls_entry = SimpleNamespace(hosts=["app.example.com"], secret_name="myapp-tls");
    mock_networking_v1.read_namespaced_ingress.return_value = SimpleNamespace(
        spec=SimpleNamespace(tls=[tls_entry])
    );
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.NetworkingV1Api",
            return_value=mock_networking_v1
        ) {
            assert deployment_target.get_service_url("myapp") == "https://app.example.com";
        }
    }

    mock_networking_v1.read_namespaced_ingress.return_value = SimpleNamespace(
        spec=SimpleNamespace(tls=[])
    );
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.NetworkingV1Api",
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

    mock_networking_v1 = unittest.mock.MagicMock();
    mock_networking_v1.read_namespaced_ingress.return_value = SimpleNamespace(
        metadata=SimpleNamespace(annotations=None)
    );

    raised = False;
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.NetworkingV1Api",
            return_value=mock_networking_v1
        ) {
            with unittest.mock.patch(
                "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.CustomObjectsApi"
            ) {
                with unittest.mock.patch(
                    "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.CoreV1Api"
                ) {
                    with unittest.mock.patch(
                        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.AppsV1Api"
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
    k8s_config = KubernetesConfig(
        domain="app.example.com", cert_manager_email="user@example.com"
    );
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_networking_v1 = unittest.mock.MagicMock();

    mock_networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    mock_core_v1 = unittest.mock.MagicMock();

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

    rule = created_body["spec"]["rules"][0];
    assert "host" not in rule , "ingress rule must not set host before TLS is enabled";

    annotations = created_body["metadata"]["annotations"];
    assert annotations.get("jac-scale/domain") == "app.example.com" , "domain must be stored in jac-scale/domain annotation for --enable-tls";
    assert annotations.get("jac-scale/cert-email") == "user@example.com" , "cert_manager_email must be stored in jac-scale/cert-email annotation for --enable-tls";
}

test "redis ingress rule must not set host before TLS is enabled" {
    k8s_config = KubernetesConfig(
        domain="app.example.com", cert_manager_email="user@example.com"
    );
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_networking_v1 = unittest.mock.MagicMock();

    mock_networking_v1.patch_namespaced_ingress.side_effect = ApiException(status=404);

    mock_core_v1 = unittest.mock.MagicMock();

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

    assert mock_networking_v1.create_namespaced_ingress.call_count == 2 , "both main and Redis ingresses should be created on first deploy";
    redis_created_body = mock_networking_v1.create_namespaced_ingress.call_args_list[1][
        1
    ]["body"];

    redis_rule = redis_created_body["spec"]["rules"][0];
    assert "host" not in redis_rule , "Redis ingress rule must not set host before TLS is enabled";
}

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

    assert env['RI_ACCEPT_TERMS_AND_CONDITIONS']['value'] == 'true';
    assert env['RI_ENCRYPTION_KEY']['value'] , "RI_ENCRYPTION_KEY must be set";

    assert env['RI_REDIS_HOST']['value'] == 'test-app-redis-service';
    assert env['RI_REDIS_PORT']['value'] == '6379';
    assert env['RIPROXYPATH']['value'] == '/cache-dashboard';

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

test "shared ingress skips deploying dedicated nginx controller" {
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
    k8s_config = KubernetesConfig(shared_ingress=True, domain="myapp.example.com");
    ingress_deployer = IngressDeployer(k8s_config, None);

    mock_apps_v1 = unittest.mock.MagicMock();
    mock_core_v1 = unittest.mock.MagicMock();
    mock_rbac_v1 = unittest.mock.MagicMock();
    mock_networking_v1 = unittest.mock.MagicMock();

    not_found = ApiException();
    not_found.status = 404;
    mock_networking_v1.delete_namespaced_ingress.side_effect = not_found;
    mock_core_v1.delete_namespaced_secret.side_effect = not_found;

    mock_custom_api = unittest.mock.MagicMock();
    mock_custom_api.delete_namespaced_custom_object.side_effect = not_found;

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.ingress.client"
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

    assert mock_networking_v1.delete_namespaced_ingress.called , "app Ingress resource must be deleted regardless of shared_ingress mode";

    assert not mock_apps_v1.delete_namespaced_deployment.called , "controller Deployment must not be deleted in shared ingress mode";
    assert not mock_core_v1.delete_namespaced_service_account.called , "controller ServiceAccount must not be deleted in shared ingress mode";
    assert not mock_rbac_v1.delete_cluster_role.called , "ClusterRole must not be deleted in shared ingress mode";
    assert not mock_rbac_v1.delete_cluster_role_binding.called , "ClusterRoleBinding must not be deleted in shared ingress mode";
    assert not mock_networking_v1.delete_ingress_class.called , "IngressClass must not be deleted in shared ingress mode";
}

test "shared ingress deploy fails fast when domain is not set" {
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config['app_name'] = 'test-app';
    target_config['namespace'] = 'test-ns';
    target_config['shared_ingress'] = True;
    target_config['domain'] = '';

    logger = UtilityFactory.create_logger('standard');
    deployment_target = DeploymentTargetFactory.create(
        'kubernetes', target_config, logger
    );

    app_config = AppConfig(code_folder='/tmp', file_name='main.jac', no_image=True);

    result = deployment_target.deploy(app_config);

    assert result.success is False , "deploy must fail when shared_ingress=True but domain is empty";
    assert "domain" in result.message.lower() , "error message must mention domain requirement";

    assert "validate_shared_ingress" not in result.details , "deploy must abort before recording validate_shared_ingress";
}

test "shared ingress deploy skips nodeport validation" {
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

    app_config = AppConfig(code_folder='/tmp', file_name='main.jac', no_image=True);

    mock_provider = unittest.mock.MagicMock();
    mock_provider.needs_nlb_wait.return_value = False;
    mock_provider.log_ingress_deployed.return_value = None;

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.kubernetes_target.check_K8s_status"
        ) {
            with unittest.mock.patch(
                "jaclang.scale.deploy.target.kubernetes.kubernetes_target.ensure_namespace_exists"
            ) {
                with unittest.mock.patch(
                    "jaclang.scale.deploy.target.kubernetes.kubernetes_target.load_env_variables",
                    return_value=[]
                ) {
                    with unittest.mock.patch(
                        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.get_cluster_provider",
                        return_value=mock_provider
                    ) {
                        with unittest.mock.patch(
                            "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client"
                        ) {
                            deployment_target.deploy(app_config);
                        }
                    }
                }
            }
        }
    }

    assert not mock_provider.validate_ports.called , "validate_ports must not be called when shared_ingress=True - no NodePort is created";
}

test "shared ingress merges caller-supplied annotations for non-nginx controllers" {
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
