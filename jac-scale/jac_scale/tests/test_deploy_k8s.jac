"""Tests for Kubernetes deployment using new factory-based architecture."""

import base64;
import json;
import os;
import subprocess;
import time;
import requests;
import from pathlib { Path }
import from typing { Any }

import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }

import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.config_loader { JacScaleConfig, get_scale_config }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.factories.utility_factory { UtilityFactory }

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
        raise ;
    }
}

"""Make an HTTP request with retry logic for 503 responses."""
def _request_with_retry(
    method: str,
    url: str,
    json: dict[str, Any] | None = None,
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

"""Test deployment using the new factory-based architecture.
Deploys the all-in-one app against a live Kubernetes cluster.
Validates deployment, services, sends HTTP request, and tests cleanup."""
test "deploy all in one" {
    config.load_kube_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();
    rbac_v1 = client.RbacAuthorizationV1Api();

    namespace = "all-in-one";
    app_name = namespace;
    ksm_name = f"{app_name}-kube-state-metrics";
    ne_name = f"{app_name}-node-exporter";
    cluster_role_name = f"{namespace}-{ksm_name}";

    test_secret_value = "test-secret-value-12345";
    os.environ.update(
        {
            "APP_NAME": app_name,
            "K8s_NAMESPACE": namespace,
            "TEST_SECRET_KEY": test_secret_value
        }
    );

    test_dir = os.path.dirname(os.path.abspath(__file__));
    todo_app_path = os.path.join(
        test_dir, "../../../jac-client/jac_client/examples/all-in-one"
    );

    app_scale_config = JacScaleConfig(Path(os.path.normpath(todo_app_path)));
    target_config = app_scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;
    target_config["node_port"] = 30001;

    (repo_url, branch, commit) = _get_git_config();
    assert repo_url , "repo_url must be a non-empty string";
    assert branch , "branch must be a non-empty string";
    assert commit , "commit must be a non-empty string";
    target_config["jaseci_repo_url"] = repo_url;
    target_config["jaseci_branch"] = branch;
    target_config["jaseci_commit"] = commit;
    print(f"Using Jaseci repo: {repo_url}, branch: {branch}, commit: {commit}");

    logger = UtilityFactory.create_logger("standard");

    deployment_target = DeploymentTargetFactory.create(
        "kubernetes", target_config, logger
    );

    deployment_target.secrets = app_scale_config.get_secrets_config();

    app_config = AppConfig(
        code_folder=todo_app_path, file_name="main.jac", build=False, experimental=True
    );

    result = deployment_target.deploy(app_config);
    details = result.details;
    assert len(details) == 10;
    assert result.success is True;
    print(f"Deployment successful: {result.message}");

    full_status = deployment_target.get_full_status(app_name);
    assert full_status is not None;
    assert full_status["app_name"] == app_name;
    assert full_status["namespace"] == namespace;
    assert "components" in full_status;
    assert len(full_status["components"]) > 0;
    component_names = [c["name"] for c in full_status["components"]];
    assert "Jaseci App" in component_names;
    assert "Redis" in component_names;
    assert "MongoDB" in component_names;
    for component in full_status["components"] {
        assert "name" in component;
        assert "status" in component;
        assert "ready" in component;
        assert "total" in component;
        assert component["status"] == "running";
        assert component["ready"] == component["total"];
    }
    assert "urls" in full_status;
    assert "app" in full_status["urls"];
    assert "grafana" in full_status["urls"];
    assert full_status["urls"]["app"].startswith("http://");
    assert full_status["urls"]["grafana"].startswith("http://");
    print(f"Full status: {full_status}");

    time.sleep(5);

    # Validate the main deployment exists
    deployment = apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace);
    assert deployment.metadata.name == app_name;
    assert deployment.spec.replicas == 1;

    # Validate main service
    service = core_v1.read_namespaced_service(
        name=f"{app_name}-service", namespace=namespace
    );
    assert service.spec.type == "NodePort";
    node_port = service.spec.ports[0].node_port;
    print(f"Service is exposed on NodePort: {node_port}");

    # Validate MongoDB StatefulSet and Service
    mongodb_stateful = apps_v1.read_namespaced_stateful_set(
        name=f"{app_name}-mongodb", namespace=namespace
    );
    assert mongodb_stateful.metadata.name == f"{app_name}-mongodb";
    assert mongodb_stateful.spec.service_name == f"{app_name}-mongodb-service";

    mongodb_service = core_v1.read_namespaced_service(
        name=f"{app_name}-mongodb-service", namespace=namespace
    );
    assert mongodb_service.spec.ports[0].port == 27017;

    # Validate Redis Deployment and Service
    redis_deploy = apps_v1.read_namespaced_deployment(
        name=f"{app_name}-redis", namespace=namespace
    );
    assert redis_deploy.metadata.name == f"{app_name}-redis";

    redis_service = core_v1.read_namespaced_service(
        name=f"{app_name}-redis-service", namespace=namespace
    );
    assert redis_service.spec.ports[0].port == 6379;

    # Validate Prometheus Deployment, Service, and ConfigMap
    prometheus_name = f"{app_name}-prometheus";
    prometheus_deploy = apps_v1.read_namespaced_deployment(
        name=prometheus_name, namespace=namespace
    );
    assert prometheus_deploy.metadata.name == prometheus_name;
    assert prometheus_deploy.spec.replicas == 1;
    prometheus_container = prometheus_deploy.spec.template.spec.containers[0];
    assert prometheus_container.image == "prom/prometheus:latest";
    print(f"Prometheus Deployment '{prometheus_name}' exists");

    prometheus_service = core_v1.read_namespaced_service(
        name=f"{prometheus_name}-service", namespace=namespace
    );
    assert prometheus_service.spec.type == "ClusterIP";
    assert prometheus_service.spec.ports[0].port == 9090;
    print(f"Prometheus Service '{prometheus_name}-service' (ClusterIP:9090) exists");

    prometheus_config = core_v1.read_namespaced_config_map(
        name=f"{prometheus_name}-config", namespace=namespace
    );
    assert "prometheus.yml" in prometheus_config.data;
    scrape_cfg = prometheus_config.data["prometheus.yml"];
    assert f"{app_name}-service" in scrape_cfg;
    assert f"{ksm_name}-service:8080" in scrape_cfg;
    assert f"{ne_name}-service:9100" in scrape_cfg;
    print(
        f"Prometheus ConfigMap '{prometheus_name}-config' exists with all three scrape targets"
    );

    # Validate Grafana Deployment, Service, Secret, and ConfigMaps
    grafana_name = f"{app_name}-grafana";
    grafana_deploy = apps_v1.read_namespaced_deployment(
        name=grafana_name, namespace=namespace
    );
    assert grafana_deploy.metadata.name == grafana_name;
    assert grafana_deploy.spec.replicas == 1;
    grafana_container = grafana_deploy.spec.template.spec.containers[0];
    assert grafana_container.image == "grafana/grafana:latest";
    assert len(grafana_container.volume_mounts) == 3;
    print(f"Grafana Deployment '{grafana_name}' exists with 3 volume mounts");

    grafana_service = core_v1.read_namespaced_service(
        name=f"{grafana_name}-service", namespace=namespace
    );
    assert grafana_service.spec.type == "NodePort";
    assert grafana_service.spec.ports[0].port == 3000;
    print(f"Grafana Service '{grafana_name}-service' (NodePort) exists");

    grafana_secret = core_v1.read_namespaced_secret(
        name=f"{grafana_name}-secret", namespace=namespace
    );
    assert grafana_secret.metadata.name == f"{grafana_name}-secret";
    print(f"Grafana Secret '{grafana_name}-secret' exists");

    grafana_ds = core_v1.read_namespaced_config_map(
        name=f"{grafana_name}-datasources", namespace=namespace
    );
    assert "datasource.yaml" in grafana_ds.data;
    assert "prometheus" in grafana_ds.data["datasource.yaml"];
    print("Grafana datasource ConfigMap exists with Prometheus datasource");

    grafana_dashboard = core_v1.read_namespaced_config_map(
        name=f"{grafana_name}-dashboard", namespace=namespace
    );
    assert "jac-scale.json" in grafana_dashboard.data;
    assert "Jac Scale - App Metrics" in grafana_dashboard.data["jac-scale.json"];
    assert "k8s-metrics.json" in grafana_dashboard.data;
    assert "Kubernetes Cluster Metrics" in grafana_dashboard.data["k8s-metrics.json"];
    print(
        "Grafana dashboard ConfigMap exists with Jac Scale + Kubernetes Cluster Metrics dashboards"
    );

    grafana_provider = core_v1.read_namespaced_config_map(
        name=f"{grafana_name}-dashboard-provider", namespace=namespace
    );
    assert "provider.yaml" in grafana_provider.data;
    print("Grafana dashboard provider ConfigMap exists");

    # Validate kube-state-metrics Deployment, Service, ServiceAccount, ClusterRole, ClusterRoleBinding
    ksm_deploy = apps_v1.read_namespaced_deployment(name=ksm_name, namespace=namespace);
    assert ksm_deploy.metadata.name == ksm_name;
    assert ksm_deploy.spec.replicas == 1;
    assert "kube-state-metrics" in ksm_deploy.spec.template.spec.containers[0].image;
    print(f"kube-state-metrics Deployment '{ksm_name}' exists");

    ksm_service = core_v1.read_namespaced_service(
        name=f"{ksm_name}-service", namespace=namespace
    );
    assert ksm_service.spec.type == "ClusterIP";
    assert ksm_service.spec.ports[0].port == 8080;
    print(f"kube-state-metrics Service '{ksm_name}-service' (ClusterIP:8080) exists");

    ksm_sa = core_v1.read_namespaced_service_account(
        name=f"{ksm_name}-sa", namespace=namespace
    );
    assert ksm_sa.metadata.name == f"{ksm_name}-sa";
    print(f"kube-state-metrics ServiceAccount '{ksm_name}-sa' exists");

    ksm_cluster_role = rbac_v1.read_cluster_role(name=cluster_role_name);
    assert ksm_cluster_role.metadata.name == cluster_role_name;
    print(f"kube-state-metrics ClusterRole '{cluster_role_name}' exists");

    ksm_crb = rbac_v1.read_cluster_role_binding(name=cluster_role_name);
    assert ksm_crb.metadata.name == cluster_role_name;
    print(f"kube-state-metrics ClusterRoleBinding '{cluster_role_name}' exists");

    # Validate node-exporter DaemonSet and Service
    ne_daemonset = apps_v1.read_namespaced_daemon_set(name=ne_name, namespace=namespace);
    assert ne_daemonset.metadata.name == ne_name;
    print(f"node-exporter DaemonSet '{ne_name}' exists");

    ne_service = core_v1.read_namespaced_service(
        name=f"{ne_name}-service", namespace=namespace
    );
    assert ne_service.spec.type == "ClusterIP";
    assert ne_service.spec.ports[0].port == 9100;
    print(f"node-exporter Service '{ne_name}-service' (ClusterIP:9100) exists");

    # Validate code-server Deployment and Service
    code_server_deploy = apps_v1.read_namespaced_deployment(
        name=f"{app_name}-code-server", namespace=namespace
    );
    assert code_server_deploy.metadata.name == f"{app_name}-code-server";
    assert code_server_deploy.spec.replicas == 1;
    print(f"Code-server deployment verified: {app_name}-code-server");

    code_server_service = core_v1.read_namespaced_service(
        name=f"{app_name}-code-server", namespace=namespace
    );
    assert code_server_service.spec.type == "ClusterIP";
    assert code_server_service.spec.ports[0].port == 8080;
    print("Code-server service verified: ClusterIP on port 8080");

    # Validate K8s Secret was created with correct data
    secret = core_v1.read_namespaced_secret(
        name=f"{app_name}-secrets", namespace=namespace
    );
    assert secret.metadata.name == f"{app_name}-secrets";
    secret_value = base64.b64decode(secret.data["TEST_SECRET_KEY"]).decode();
    assert secret_value == test_secret_value;
    print(f"K8s Secret '{app_name}-secrets' created with correct data");

    # Validate envFrom.secretRef is in the container spec
    deployment = apps_v1.read_namespaced_deployment(name=app_name, namespace=namespace);
    container = deployment.spec.template.spec.containers[0];
    assert container.env_from is not None , "envFrom should be set on container";
    secret_refs = [
        ef.secret_ref.name
        for ef in container.env_from
        if ef.secret_ref is not None
    ];
    assert f"{app_name}-secrets" in secret_refs;
    print(f"Container has envFrom.secretRef for '{app_name}-secrets'");

    # Test get_status
    status = deployment_target.get_status(app_name);
    assert status is not None;
    assert status.replicas >= 0;
    print(
        f"Deployment status: {status.status.value}, replicas: {status.replicas}/{status.ready_replicas}"
    );

    # Validate HPA was created with correct configuration
    autoscaling_v2 = client.AutoscalingV2Api();
    hpa = autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(
        name=f"{app_name}-hpa", namespace=namespace
    );
    assert hpa.metadata.name == f"{app_name}-hpa";
    assert hpa.spec.min_replicas == 1;
    assert hpa.spec.max_replicas == 3;
    assert hpa.spec.metrics[0].resource.target.average_utilization == 50;
    print(
        f"HPA verified: min_replicas={hpa.spec.min_replicas}, max_replicas={hpa.spec.max_replicas}, cpu_target=50%"
    );

    # Send POST request to create a todo (with retry for 503)
    url = f"http://localhost:{node_port}/walker/create_todo";
    payload = {"text": "first-task"};
    response = _request_with_retry("POST", url, json=payload, timeout=10);
    assert response.status_code == 200;
    print(f"Successfully created todo at {url}");
    print(f"  Response: {response.json()}");

    url = f"http://localhost:{node_port}/cl/app";
    response = _request_with_retry("GET", url, timeout=100);
    print(f"Response status code for app page: {response.status_code}");
    assert response.status_code == 200;
    print(f"Successfully reached app page at {url}");

    # --- Port conflict test ---
    # Deploy the same app into a different namespace using the same node_port.
    # check_node_ports_available must detect the conflict and the deploy must fail.
    duplicate_namespace = "all-in-one-duplicate";
    duplicate_app_name = duplicate_namespace;

    os.environ.update(
        {"APP_NAME": duplicate_app_name, "K8s_NAMESPACE": duplicate_namespace}
    );

    duplicate_target_config = app_scale_config.get_kubernetes_config();
    duplicate_target_config["app_name"] = duplicate_app_name;
    duplicate_target_config["namespace"] = duplicate_namespace;
    duplicate_target_config["node_port"] = target_config[
        "node_port"
    ];  # same port — must conflict
    duplicate_target_config["jaseci_repo_url"] = repo_url;
    duplicate_target_config["jaseci_branch"] = branch;
    duplicate_target_config["jaseci_commit"] = commit;

    duplicate_target = DeploymentTargetFactory.create(
        "kubernetes", duplicate_target_config, logger
    );
    duplicate_target.secrets = app_scale_config.get_secrets_config();

    conflict_result = duplicate_target.deploy(app_config);
    assert conflict_result.success is False , (
        "Deploying with a conflicting NodePort should fail"
    );
    assert "NodePort conflict detected" in conflict_result.message , (
        f"Expected NodePort conflict error, got: {conflict_result.message}"
    );
    print(f"Port conflict correctly detected: {conflict_result.message}");

    # Restore env vars to point back at the original namespace for cleanup
    os.environ.update({"APP_NAME": app_name, "K8s_NAMESPACE": namespace});

    # Cleanup using new architecture
    deployment_target.destroy(app_name);

    # Verify cleanup - resources should no longer exist
    try {
        apps_v1.read_namespaced_deployment(app_name, namespace=namespace);
        raise AssertionError("Deployment should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{app_name}-service", namespace=namespace);
        raise AssertionError("Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        autoscaling_v2 = client.AutoscalingV2Api();
        autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(
            name=f"{app_name}-hpa", namespace=namespace
        );
        raise AssertionError("HPA should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        apps_v1.read_namespaced_stateful_set(f"{app_name}-mongodb", namespace=namespace);
        raise AssertionError("MongoDB StatefulSet should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(
            f"{app_name}-mongodb-service", namespace=namespace
        );
        raise AssertionError("MongoDB Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        apps_v1.read_namespaced_deployment(f"{app_name}-redis", namespace=namespace);
        raise AssertionError("Redis Deployment should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(
            f"{app_name}-redis-service", namespace=namespace
        );
        raise AssertionError("Redis Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify code-server cleanup
    try {
        apps_v1.read_namespaced_deployment(
            f"{app_name}-code-server", namespace=namespace
        );
        raise AssertionError("Code-server Deployment should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{app_name}-code-server", namespace=namespace);
        raise AssertionError("Code-server Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify Prometheus cleanup
    prometheus_name = f"{app_name}-prometheus";
    try {
        apps_v1.read_namespaced_deployment(prometheus_name, namespace=namespace);
        raise AssertionError("Prometheus Deployment should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(
            f"{prometheus_name}-service", namespace=namespace
        );
        raise AssertionError("Prometheus Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_config_map(
            name=f"{prometheus_name}-config", namespace=namespace
        );
        raise AssertionError("Prometheus ConfigMap should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify kube-state-metrics cleanup
    try {
        apps_v1.read_namespaced_deployment(ksm_name, namespace=namespace);
        raise AssertionError("kube-state-metrics Deployment should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{ksm_name}-service", namespace=namespace);
        raise AssertionError("kube-state-metrics Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service_account(
            name=f"{ksm_name}-sa", namespace=namespace
        );
        raise AssertionError(
            "kube-state-metrics ServiceAccount should have been deleted"
        ) ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role(name=cluster_role_name);
        raise AssertionError(
            "kube-state-metrics ClusterRole should have been deleted"
        ) ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role_binding(name=cluster_role_name);
        raise AssertionError(
            "kube-state-metrics ClusterRoleBinding should have been deleted"
        ) ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify node-exporter cleanup
    try {
        apps_v1.read_namespaced_daemon_set(ne_name, namespace=namespace);
        raise AssertionError("node-exporter DaemonSet should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{ne_name}-service", namespace=namespace);
        raise AssertionError("node-exporter Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("K8s metrics stack (kube-state-metrics + node-exporter) cleanup verified");

    # Verify Grafana cleanup
    grafana_name = f"{app_name}-grafana";
    try {
        apps_v1.read_namespaced_deployment(grafana_name, namespace=namespace);
        raise AssertionError("Grafana Deployment should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{grafana_name}-service", namespace=namespace);
        raise AssertionError("Grafana Service should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_secret(f"{grafana_name}-secret", namespace=namespace);
        raise AssertionError("Grafana Secret should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    for cm_name in [
        f"{grafana_name}-datasources",
        f"{grafana_name}-dashboard-provider",
        f"{grafana_name}-dashboard"
    ] {
        try {
            core_v1.read_namespaced_config_map(name=cm_name, namespace=namespace);
            raise AssertionError(
                f"Grafana ConfigMap '{cm_name}' should have been deleted"
            ) ;
        } except ApiException as e {
            assert e.status == 404 , f"Expected 404 for '{cm_name}', got {e.status}";
        }
    }

    print("Monitoring stack (Prometheus + Grafana) cleanup verified");

    # Verify K8s Secret cleanup
    try {
        core_v1.read_namespaced_secret(f"{app_name}-secrets", namespace=namespace);
        raise AssertionError("K8s Secret should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify PVC cleanup
    try {
        pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace=namespace);
        for pvc in pvcs.items {
            assert not pvc.metadata.name.startswith(app_name) , (
                f"PVC '{pvc.metadata.name}' should have been deleted"
            );
        }
    } except ApiException as e {
        # Namespace already deleted - PVCs are gone too
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify namespace was deleted (since it is not 'default')
    try {
        core_v1.read_namespace(name=namespace);
        raise AssertionError("Namespace should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404 for namespace, got {e.status}";
    }

    print(
        "Cleanup verification complete - all resources and namespace properly deleted"
    );
}

"""Test deployment early exit on failure."""
test "early exit" {
    config.load_kube_config();

    namespace = "early-exit";
    app_name = namespace;

    os.environ.update({"APP_NAME": app_name, "K8s_NAMESPACE": namespace});

    test_dir = os.path.dirname(os.path.abspath(__file__));
    todo_app_path = os.path.join(test_dir, "../../examples/early-exit");

    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;
    target_config["node_port"] = 30002;

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

    result = deployment_target.deploy(app_config);
    details = result.details;
    print(f"Deployment result: {details}");
    assert "health_check_of_deployment" not in details;
    assert len(details) == 9;
    assert result.success is False;
}

"""Test individual methods of KubernetesTarget."""
test "deployment target methods" {
    config.load_kube_config();

    namespace = "test-methods";
    app_name = "test-methods-app";

    os.environ.update({"APP_NAME": app_name, "K8s_NAMESPACE": namespace});

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

    print("Deployment target methods tested");
}
