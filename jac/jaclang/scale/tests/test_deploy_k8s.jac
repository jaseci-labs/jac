import os;
import time;
import importlib.resources;
import from pathlib { Path }
import from typing { cast }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }

import unittest.mock;
import from types { SimpleNamespace }

import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.resource_status { ResourceStatus }
import from jaclang.scale.config.config_loader {
    JacScaleConfig,
    get_scale_config,
    reset_scale_config
}
import from tempfile { mkdtemp }
import shutil;
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.deploy.database.kubernetes_postgres {
    KubernetesPostgresProvider
}
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.runtime.realizer.kubernetes_realizer { KubernetesRealizer }
import from jaclang.scale.deploy.target.kubernetes.ingress { IngressDeployer }
import from jaclang.scale.deploy.autoscale.factory { AutoscalerFactory }
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerSpec, Trigger }

test "early exit" {
    config.load_kube_config();

    namespace = "early-exit";
    app_name = namespace;

    test_dir = os.path.dirname(os.path.abspath(__file__));
    todo_app_path = os.path.join(test_dir, "../examples/early-exit");

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

    # get_status swallows k8s errors internally and returns UNKNOWN rather than
    # raising, so an app that was never deployed must report UNKNOWN - not crash,
    # and not spuriously report RUNNING.
    status = deployment_target.get_status(app_name);
    assert status is not None;
    assert status.status == ResourceStatus.UNKNOWN , (
        f"Expected UNKNOWN status for undeployed app '{app_name}', got {status.status}"
    );
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

def _fleet_deployment(available: int = 0, desired: int = 1) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(generation=1),
        spec=SimpleNamespace(replicas=desired),
        status=SimpleNamespace(
            replicas=available,
            updated_replicas=available,
            available_replicas=available,
            ready_replicas=available,
            observed_generation=1,
            conditions=[]
        )
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
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.target.client.AppsV1Api",
            return_value=fake_apps_v1
        ) {
            with unittest.mock.patch(
                "jaclang.scale.deploy.target.kubernetes.target.client.CoreV1Api",
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
        _fleet_deployment(available=0),
        _fleet_deployment(available=1),

    ];

    healthy_pod = unittest.mock.MagicMock();
    healthy_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": current_hash};
    healthy_pod.metadata.name = "svc-a-healthy";
    healthy_pod.metadata.deletion_timestamp = None;
    healthy_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=0)];
    healthy_pod.status.phase = "Running";

    stale_pod = unittest.mock.MagicMock();
    stale_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": stale_hash};
    stale_pod.metadata.name = "svc-a-stale-crash";
    stale_pod.metadata.deletion_timestamp = None;
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
    fake_apps_v1.read_namespaced_deployment.return_value = _fleet_deployment();

    crash_pod = unittest.mock.MagicMock();
    crash_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": current_hash};
    crash_pod.metadata.name = "svc-a-crash";
    crash_pod.metadata.deletion_timestamp = None;
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
    fake_apps_v1.read_namespaced_deployment.return_value = _fleet_deployment();

    healthy_pod = unittest.mock.MagicMock();
    healthy_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": current_hash};
    healthy_pod.metadata.name = "svc-a-healthy";
    healthy_pod.metadata.deletion_timestamp = None;
    healthy_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=0)];
    healthy_pod.status.phase = "Running";

    # The database is provisioned separately from the fleet's own
    # microservice Deployments (bundle["deployments"]), so "svc-a-postgres"
    # is never in fleet_app_names and its pod-template-hash was never
    # resolved into current_hashes - it must still be checked for crashes.
    # This is the test that actually guards the fleet_app_names bypass in
    # _scan_for_crash_loop.
    companion_pod = unittest.mock.MagicMock();
    companion_pod.metadata.labels = {
        "app": "svc-a-postgres",
        "pod-template-hash": "companion-hash-not-in-current-hashes"
    };
    companion_pod.metadata.name = "svc-a-postgres-789";
    companion_pod.metadata.deletion_timestamp = None;
    companion_pod.status.container_statuses = [
        unittest.mock.MagicMock(restart_count=5)
    ];
    companion_pod.status.phase = "Running";

    fake_core_v1 = unittest.mock.MagicMock();
    fake_core_v1.list_namespaced_pod.return_value.items = [healthy_pod, companion_pod];

    caught = _run_fleet_rollout(deployment_target, bundle, fake_apps_v1, fake_core_v1);

    assert caught is not None and "crash-looping" in str(caught) , "a crash-looping companion database pod outside the fleet's own Deployments must still fail the rollout wait";
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
    fake_apps_v1.read_namespaced_deployment.return_value = _fleet_deployment();

    crash_pod = unittest.mock.MagicMock();
    crash_pod.metadata.labels = {"app": "svc-a", "pod-template-hash": "whatever-hash"};
    crash_pod.metadata.name = "svc-a-crash";
    crash_pod.metadata.deletion_timestamp = None;
    crash_pod.status.container_statuses = [unittest.mock.MagicMock(restart_count=5)];
    crash_pod.status.phase = "Running";

    fake_core_v1 = unittest.mock.MagicMock();
    fake_core_v1.list_namespaced_pod.return_value.items = [crash_pod];

    caught = _run_fleet_rollout(deployment_target, bundle, fake_apps_v1, fake_core_v1);

    assert caught is not None , "crash must still be detected via broad scan when RS lookup fails";
}


test "kubernetes database provider security context" {
    pg_provider = KubernetesPostgresProvider(config={'app_name': 'test-app'});
    pg_deploy = pg_provider.deploy({});
    pg_container = pg_deploy['statefulset']['spec']['template']['spec']['containers'][
        0
    ];
    pg_sc = pg_container['securityContext'];
    assert pg_sc['runAsNonRoot'] is True;
    assert pg_sc['allowPrivilegeEscalation'] is False;
    assert pg_sc['capabilities']['drop'] == ['ALL'];
    assert pg_sc['seccompProfile']['type'] == 'RuntimeDefault';
    assert pg_deploy['service_account']['automountServiceAccountToken'] is False;
}

test "get service url switches between http and https based on tls state" {
    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = "myapp";
    target_config["namespace"] = "default";
    target_config["domain"] = "app.example.com";
    logger = UtilityFactory.create_logger("standard");
    deployment_target: any = DeploymentTargetFactory.create(
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
            assert deployment_target.get_service_url("myapp")
                == "https://app.example.com";
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
            assert deployment_target.get_service_url("myapp")
                == "http://app.example.com";
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
    deployment_target: any = DeploymentTargetFactory.create(
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

test "deploy with domain set renders host plus catch-all rules and stores domain annotation" {
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
        networking_v1=mock_networking_v1,
        core_v1=mock_core_v1
    );

    assert mock_networking_v1.create_namespaced_ingress.called , "ingress should be created on first deploy";
    created_body = mock_networking_v1.create_namespaced_ingress.call_args[1]["body"];

    rules: list = created_body["spec"]["rules"];
    assert len(rules) == 2 , "domain app must render a host rule plus a catch-all";
    assert rules[0].get("host") == "app.example.com" , "first rule must bind the domain host so redeploys keep the TLS cert served (#7707)";
    assert "host" not in rules[1] , "catch-all rule must keep the raw load-balancer hostname serving before DNS/TLS";

    annotations = created_body["metadata"]["annotations"];
    assert annotations.get("jac-scale/domain") == "app.example.com" , "domain must be stored in jac-scale/domain annotation for --enable-tls";
    assert annotations.get("jac-scale/cert-email") == "user@example.com" , "cert_manager_email must be stored in jac-scale/cert-email annotation for --enable-tls";
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
            provider=cast(any, unittest.mock.MagicMock()),
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
    ) as raw_mock_client {
        mock_client: any = raw_mock_client;
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

    app_config = AppConfig(code_folder='/tmp', file_name='main.jac');

    result = deployment_target.deploy(app_config);

    assert result.success is False , "deploy must fail when shared_ingress=True but domain is empty";
    assert "domain" in (result.message or "").lower() , "error message must mention domain requirement";
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

test "k8s safe slug normalizes names into valid k8s identifiers" {
    import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
        k8s_safe_slug
    }

    cases = [
        ("this-is-jac", "this-is-jac"),
        ("My App", "my-app"),
        ("My_Cool_App!!", "my-cool-app"),
        ("-lead-and-trail-", "lead-and-trail"),
        ("UPPER", "upper"),
        ("a" * 100, "a" * 63),
        ("", "jaseci")
    ];
    for (raw, expected) in cases {
        result = k8s_safe_slug(raw);
        assert result == expected , f"k8s_safe_slug({raw!r}) = {result!r}, expected {expected!r}";
    }
}

"""Resolve get_kubernetes_config() against a temp project with the given jac.toml."""
def _k8s_config_for_toml(toml_content: str) -> dict {
    tmp_dir = Path(mkdtemp());
    (tmp_dir / "jac.toml").write_text(toml_content);
    # get_scale_config() caches a process-wide singleton; reset around the temp project.
    reset_scale_config();
    try {
        return get_scale_config(tmp_dir).get_kubernetes_config();
    } finally {
        reset_scale_config();
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "unconfigured app_name derives from [project].name; namespace stays default" {
    cfg = _k8s_config_for_toml(
        "[project]\nname = \"My App\"\nentry-point = \"main.jac\"\n"
    );
    assert cfg["app_name"] == "my-app" , f"got {cfg['app_name']!r}";
    assert cfg["namespace"] == "default" , f"got {cfg['namespace']!r}";
}

test "explicit app_name wins over the derived default" {
    cfg = _k8s_config_for_toml(
        "[project]\nname = \"My App\"\n\n[scale.kubernetes]\napp_name = \"custom-app\"\n"
    );
    assert cfg["app_name"] == "custom-app" , f"got {cfg['app_name']!r}";
}

test "no usable project name falls back to legacy app_name 'jaseci'" {
    for toml in [
        "[project]\nentry-point = \"main.jac\"\n",
        "[project]\nname = \"---\"\n",
        "[project]\nname = \"   \"\n"
    ] {
        cfg = _k8s_config_for_toml(toml);
        assert cfg["app_name"] == "jaseci" , f"{toml!r}: got {cfg['app_name']!r}";
        assert cfg["namespace"] == "default" , f"{toml!r}: got {cfg['namespace']!r}";
    }
}

test "rollout wait defaults to the fast gate and reads 'full' from jac.toml" {
    default_cfg = _k8s_config_for_toml("[project]\nname = \"My App\"\n");
    assert default_cfg["rollout_wait"] == "ready" , (
        f"got {default_cfg['rollout_wait']!r}"
    );
    assert default_cfg["rollout_timeout"] == 1200 , (
        f"got {default_cfg['rollout_timeout']!r}"
    );

    full_cfg = _k8s_config_for_toml(
        "[project]\nname = \"My App\"\n\n[scale.kubernetes]\n"
        "rollout_wait = \"full\"\nrollout_timeout = 2400\n"
    );
    assert full_cfg["rollout_wait"] == "full" , f"got {full_cfg['rollout_wait']!r}";
    assert full_cfg["rollout_timeout"] == 2400 , (
        f"got {full_cfg['rollout_timeout']!r}"
    );
}

def _status_for(deployment: any) -> any {
    target = KubernetesTarget(
        config=KubernetesConfig(app_name="svc-a", namespace="fleet-ns")
    );
    apps = unittest.mock.MagicMock();
    apps.read_namespaced_deployment.return_value = deployment;
    with unittest.mock.patch(
        "jaclang.scale.deploy.target.kubernetes.kubernetes_target.k8s_cluster_config"
    ) {
        with unittest.mock.patch(
            "jaclang.scale.deploy.target.kubernetes.kubernetes_target.client.AppsV1Api",
            return_value=apps
        ) {
            return target.get_status("svc-a");
        }
    }
}

def _revision_deployment(
    desired: int, updated: int, available: int, total: int
) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(generation=1),
        spec=SimpleNamespace(replicas=desired),
        status=SimpleNamespace(
            replicas=total,
            updated_replicas=updated,
            available_replicas=available,
            ready_replicas=available,
            observed_generation=1,
            conditions=[]
        )
    );
}

test "status is RUNNING only once the applied revision is fully available" {
    mid = _status_for(_revision_deployment(desired=3, updated=1, available=3, total=4));
    assert mid.status != ResourceStatus.RUNNING , (
        f"old-revision pods are not a finished rollout: {mid.status}"
    );
    assert mid.ready_replicas == 0 , (
        f"only new-revision replicas count as ready, got {mid.ready_replicas}"
    );
    assert not mid.is_ready() , "a rollout in flight is not ready";

    done = _status_for(
        _revision_deployment(desired=3, updated=3, available=3, total=3)
    );
    assert done.status == ResourceStatus.RUNNING , (
        f"a completed rollout is RUNNING: {done.status}"
    );
    assert done.is_ready() , "a completed rollout is ready";
}

test "status stays PENDING while old replicas serve a redeploy that placed no pod" {
    blocked = _status_for(
        _revision_deployment(desired=3, updated=0, available=3, total=3)
    );
    assert blocked.status == ResourceStatus.PENDING , (
        f"a redeploy still served by its predecessor is not failed: {blocked.status}"
    );

    down = _status_for(
        _revision_deployment(desired=3, updated=0, available=0, total=0)
    );
    assert down.status == ResourceStatus.FAILED , (
        f"nothing serving and nothing rolling out is failed: {down.status}"
    );
}

test "status reports the stall the deploy gate would fail on" {
    stalled = _revision_deployment(desired=3, updated=1, available=3, total=4);
    stalled.status.conditions = [
        SimpleNamespace(
            type="Progressing",
            status="False",
            reason="ProgressDeadlineExceeded",
            message="ReplicaSet 'svc-a-abc' has timed out progressing.",
            last_update_time="2026-08-11T10:00:00Z"
        )
    ];

    info = _status_for(stalled);

    assert info.status != ResourceStatus.RUNNING , f"got {info.status}";
    assert info.message and "ProgressDeadlineExceeded" in info.message , (
        f"the stall reason must reach the caller: {info.message!r}"
    );
    assert "2026-08-11T10:00:00Z" in info.message and "may predate" in info.message , (
        "a status poller has no baseline, so the verdict must carry when it "
        f"was stamped: {info.message!r}"
    );
}

"""Run a dry-run realize and hand back the deployment target it built."""
def _realized_target(toml_wait: str, wait_flag: str) -> any {
    tmp_dir = Path(mkdtemp());
    (tmp_dir / "main.jac").write_text("with entry {\n    print(\"ok\");\n}\n");
    scale_cfg = unittest.mock.MagicMock();
    scale_cfg.get_kubernetes_config.return_value = {
        "app_name": "svc-a",
        "namespace": "fleet-ns",
        "rollout_wait": toml_wait
    };
    scale_cfg.get_secrets_config.return_value = {};
    scale_cfg.load.return_value = {};
    try {
        with unittest.mock.patch(
            "jaclang.scale.runtime.realizer.kubernetes_realizer.get_scale_config",
            return_value=scale_cfg
        ), unittest.mock.patch(
            "jaclang.scale.runtime.cli.plan.print_plan", return_value=({}, [])
        ) as print_plan {
            rc = KubernetesRealizer(ms_config={}).realize(
                str(tmp_dir / "main.jac"), dry_run=True, rollout_wait=wait_flag
            );
            assert rc == 0 , f"dry-run realize failed with {rc}";
            return print_plan.call_args.args[0];
        }
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
}

test "--wait overrides jac.toml on the target that runs the deploy" {
    overridden = _realized_target("ready", "full");
    assert overridden.k8s_config.rollout_wait == "full" , (
        "--wait full must reach the target, got "
        f"{overridden.k8s_config.rollout_wait!r}"
    );

    configured = _realized_target("full", "");
    assert configured.k8s_config.rollout_wait == "full" , (
        "without --wait the configured mode stands, got "
        f"{configured.k8s_config.rollout_wait!r}"
    );
}

def _rollout_gate_for(cfg: dict) -> any {
    return KubernetesTarget(
        config=KubernetesConfig.from_dict(KubernetesConfig, cfg)
    )._rollout_gate();
}

test "an unusable rollout setting fails the deploy, not every config read" {
    for (setting, bad) in [
        ("rollout_wait = \"everything\"", "everything"),
        ("rollout_wait = \"\"", "''"),
        ("rollout_timeout = 0", "0"),
        ("rollout_timeout = 30.5", "30.5"),
        ("rollout_timeout = true", "True"),
        ("rollout_timeout = \"soon\"", "soon")
    ] {
        cfg = _k8s_config_for_toml(
            "[project]\nname = \"My App\"\n\n[scale.kubernetes]\n"
            "namespace = \"shop\"\n"
                + setting
                + "\n"
        );
        assert cfg["namespace"] == "shop" , (
            f"{setting}: an unusable rollout knob must not cost in-pod readers "
            f"the rest of the config, got {cfg['namespace']!r}"
        );

        caught = None;
        try {
            _rollout_gate_for(cfg);
        } except ValueError as e {
            caught = e;
        }

        assert caught is not None , f"{setting} must not be silently accepted";
        assert bad in str(caught) , (
            f"{setting}: the bad value must be echoed, got {caught}"
        );
    }
}

test "an env interpolated rollout_timeout string stays accepted" {
    toml = (
        "[project]\nname = \"My App\"\n\n[scale.kubernetes]\n"
        "rollout_timeout = \"${JAC_TEST_ROLLOUT_TIMEOUT:-1200}\"\n"
    );

    os.environ["JAC_TEST_ROLLOUT_TIMEOUT"] = "90";
    try {
        (_, timeout) = _rollout_gate_for(_k8s_config_for_toml(toml));
        assert timeout == 90 , f"got {timeout!r}";
    } finally {
        os.environ.pop("JAC_TEST_ROLLOUT_TIMEOUT", None);
    }

    (_, fallback_timeout) = _rollout_gate_for(_k8s_config_for_toml(toml));
    assert fallback_timeout == 1200 , f"got {fallback_timeout!r}";
}
