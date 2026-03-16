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
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }

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
    networking_v1 = client.NetworkingV1Api();
    custom_api = client.CustomObjectsApi();

    namespace = "all-in-one";
    app_name = namespace;
    ksm_name = f"{app_name}-kube-state-metrics";
    ne_name = f"{app_name}-node-exporter";
    cluster_role_name = f"{namespace}-{ksm_name}";

    test_secret_value = "test-secret-value-12345";

    test_dir = os.path.dirname(os.path.abspath(__file__));
    todo_app_path = os.path.join(
        test_dir, "../../../jac-client/jac_client/examples/all-in-one"
    );

    app_scale_config = JacScaleConfig(Path(os.path.normpath(todo_app_path)));
    target_config = app_scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;
    target_config["ingress_node_port"] = 30080;
    target_config["redis_dashboard"] = True;
    target_config["mongodb_dashboard"] = True;

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

    deployment_target.secrets = {"TEST_SECRET_KEY": test_secret_value};

    app_config = AppConfig(
        code_folder=todo_app_path, file_name="main.jac", build=False, experimental=True
    );

    result = deployment_target.deploy(app_config);
    details = result.details;
    assert len(details) == 11;
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
    assert "NGINX Ingress" in component_names;
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

    # Validate main service is ClusterIP (all traffic goes through NGINX ingress)
    service = core_v1.read_namespaced_service(
        name=f"{app_name}-service", namespace=namespace
    );
    assert service.spec.type == "ClusterIP";
    ingress_node_port = target_config["ingress_node_port"];
    print(f"App service is ClusterIP; ingress NodePort: {ingress_node_port}");

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

    # Validate MongoDB secret exists with correct credential keys
    mongodb_secret = core_v1.read_namespaced_secret(
        name=f"{app_name}-mongodb-secret", namespace=namespace
    );
    assert mongodb_secret.metadata.name == f"{app_name}-mongodb-secret";
    assert "username" in mongodb_secret.data;
    assert "password" in mongodb_secret.data;
    assert base64.b64decode(mongodb_secret.data["username"]).decode() == "admin";
    assert base64.b64decode(mongodb_secret.data["password"]).decode() == "password";
    print(f"MongoDB Secret '{app_name}-mongodb-secret' exists with correct credentials");

    # Validate MongoDB StatefulSet uses secretKeyRef (env value is None when secretKeyRef is used)
    mongo_user_value = next(
        (
            e.value
            for e in mongodb_stateful.spec.template.spec.containers[0].env
            if e.name == "MONGO_INITDB_ROOT_USERNAME"
        ),
        "NOT_FOUND"
    );
    assert mongo_user_value is None;
    mongo_pass_value = next(
        (
            e.value
            for e in mongodb_stateful.spec.template.spec.containers[0].env
            if e.name == "MONGO_INITDB_ROOT_PASSWORD"
        ),
        "NOT_FOUND"
    );
    assert mongo_pass_value is None;
    print(
        "MongoDB StatefulSet uses secretKeyRef for root credentials (env values are None)"
    );

    # Validate Redis Deployment and Service
    redis_deploy = apps_v1.read_namespaced_deployment(
        name=f"{app_name}-redis", namespace=namespace
    );
    assert redis_deploy.metadata.name == f"{app_name}-redis";

    redis_service = core_v1.read_namespaced_service(
        name=f"{app_name}-redis-service", namespace=namespace
    );
    assert redis_service.spec.ports[0].port == 6379;

    # Validate Redis secret exists with correct credential keys
    redis_secret = core_v1.read_namespaced_secret(
        name=f"{app_name}-redis-secret", namespace=namespace
    );
    assert redis_secret.metadata.name == f"{app_name}-redis-secret";
    assert "username" in redis_secret.data;
    assert "password" in redis_secret.data;
    assert base64.b64decode(redis_secret.data["username"]).decode() == "admin";
    assert base64.b64decode(redis_secret.data["password"]).decode() == "password";
    print(f"Redis Secret '{app_name}-redis-secret' exists with correct credentials");

    # Validate Redis Deployment uses secretKeyRef (env value is None when secretKeyRef is used)
    redis_pass_value = next(
        (
            e.value
            for e in redis_deploy.spec.template.spec.containers[0].env
            if e.name == "REDIS_PASSWORD"
        ),
        "NOT_FOUND"
    );
    assert redis_pass_value is None;
    print("Redis Deployment uses secretKeyRef for password (env value is None)");

    # Validate RedisInsight dashboard Deployment and Service
    insight_name = f"{app_name}-redis-insight";
    insight_deploy = apps_v1.read_namespaced_deployment(
        name=insight_name, namespace=namespace
    );
    assert insight_deploy.metadata.name == insight_name;
    assert insight_deploy.spec.replicas == 1;
    insight_container = insight_deploy.spec.template.spec.containers[0];
    assert insight_container.image == "redis/redisinsight:3.2.0";
    ri_host_env = next(
        (
            e.value
            for e in insight_container.env
            if e.name == "RI_REDIS_HOST"
        ),
        None
    );
    ri_port_env = next(
        (
            e.value
            for e in insight_container.env
            if e.name == "RI_REDIS_PORT"
        ),
        None
    );
    assert ri_host_env == f"{app_name}-redis-service";
    assert ri_port_env == "6379";
    ri_proxy_path_env = next(
        (
            e.value
            for e in insight_container.env
            if e.name == "RIPROXYPATH"
        ),
        None
    );
    assert ri_proxy_path_env == "/cache-dashboard";
    print(
        f"RedisInsight Deployment '{insight_name}' exists with RI_REDIS_HOST/PORT pre-configured and RIPROXYPATH=/cache-dashboard"
    );

    insight_service = core_v1.read_namespaced_service(
        name=f"{insight_name}-service", namespace=namespace
    );
    assert insight_service.spec.type == "ClusterIP";
    print(f"RedisInsight Service '{insight_name}-service' (ClusterIP) exists");

    # Validate mongo-express dashboard Deployment and Service
    express_name = f"{app_name}-mongo-express";
    express_deploy = apps_v1.read_namespaced_deployment(
        name=express_name, namespace=namespace
    );
    assert express_deploy.metadata.name == express_name;
    assert express_deploy.spec.replicas == 1;
    express_container = express_deploy.spec.template.spec.containers[0];
    assert express_container.image == 'mongo-express:1.0.2-20';
    mongo_server_env = next(
        (
            e.value
            for e in express_container.env
            if e.name == "ME_CONFIG_MONGODB_SERVER"
        ),
        None
    );
    assert mongo_server_env == f"{app_name}-mongodb-service";
    mongo_admin_user_value = next(
        (
            e.value
            for e in express_container.env
            if e.name == "ME_CONFIG_MONGODB_ADMINUSERNAME"
        ),
        "NOT_FOUND"
    );
    assert mongo_admin_user_value is None;
    mongo_admin_pass_value = next(
        (
            e.value
            for e in express_container.env
            if e.name == "ME_CONFIG_MONGODB_ADMINPASSWORD"
        ),
        "NOT_FOUND"
    );
    assert mongo_admin_pass_value is None;
    print(
        f"mongo-express Deployment '{express_name}' exists with MongoDB credentials via secretKeyRef"
    );

    express_service = core_v1.read_namespaced_service(
        name=f"{express_name}-service", namespace=namespace
    );
    assert express_service.spec.type == "ClusterIP";
    print(f"mongo-express Service '{express_name}-service' (ClusterIP) exists");

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
    assert grafana_service.spec.type == "ClusterIP";
    assert grafana_service.spec.ports[0].port == 3000;
    print(f"Grafana Service '{grafana_name}-service' (ClusterIP) exists");

    gf_root_url_env = next(
        (
            e.value
            for e in grafana_container.env
            if e.name == "GF_SERVER_ROOT_URL"
        ),
        None
    );
    gf_subpath_env = next(
        (
            e.value
            for e in grafana_container.env
            if e.name == "GF_SERVER_SERVE_FROM_SUB_PATH"
        ),
        None
    );
    assert gf_root_url_env is not None , "GF_SERVER_ROOT_URL must be set";
    assert "grafana" in gf_root_url_env , f"GF_SERVER_ROOT_URL should contain 'grafana', got: {gf_root_url_env}";
    assert gf_subpath_env == "true" , f"GF_SERVER_SERVE_FROM_SUB_PATH must be 'true', got: {gf_subpath_env}";
    print(
        f"Grafana subpath env vars verified: GF_SERVER_ROOT_URL={gf_root_url_env}, GF_SERVER_SERVE_FROM_SUB_PATH={gf_subpath_env}"
    );

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

    # Validate kube-state-metrics Deployment, Service, ServiceAccount, ClusterRole,ClusterRoleBinding
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

    # Validate NGINX Ingress controller resources
    nginx_controller_name = f"{app_name}-ingress-nginx";
    nginx_cluster_resource_name = f"{namespace}-{nginx_controller_name}";
    ingress_class_name = f"{namespace}-{app_name}-nginx";
    nginx_configmap_name = f"{app_name}-nginx-configuration";
    nginx_service_name = f"{nginx_controller_name}-service";
    ingress_name = f"{app_name}-ingress";
    redis_ingress_name = f"{app_name}-redis-insight-ingress";

    nginx_sa = core_v1.read_namespaced_service_account(
        name=nginx_controller_name, namespace=namespace
    );
    assert nginx_sa.metadata.name == nginx_controller_name;
    print(f"NGINX Ingress ServiceAccount '{nginx_controller_name}' exists");

    nginx_cluster_role = rbac_v1.read_cluster_role(name=nginx_cluster_resource_name);
    assert nginx_cluster_role.metadata.name == nginx_cluster_resource_name;
    print(f"NGINX Ingress ClusterRole '{nginx_cluster_resource_name}' exists");

    nginx_crb = rbac_v1.read_cluster_role_binding(name=nginx_cluster_resource_name);
    assert nginx_crb.metadata.name == nginx_cluster_resource_name;
    print(f"NGINX Ingress ClusterRoleBinding '{nginx_cluster_resource_name}' exists");

    nginx_cm = core_v1.read_namespaced_config_map(
        name=nginx_configmap_name, namespace=namespace
    );
    assert nginx_cm.metadata.name == nginx_configmap_name;
    print(f"NGINX Ingress ConfigMap '{nginx_configmap_name}' exists");

    nginx_ingress_class = networking_v1.read_ingress_class(name=ingress_class_name);
    assert nginx_ingress_class.metadata.name == ingress_class_name;
    print(f"NGINX IngressClass '{ingress_class_name}' exists");

    nginx_deploy = apps_v1.read_namespaced_deployment(
        name=nginx_controller_name, namespace=namespace
    );
    assert nginx_deploy.metadata.name == nginx_controller_name;
    assert nginx_deploy.spec.replicas == 1;
    nginx_container = nginx_deploy.spec.template.spec.containers[0];
    assert "ingress-nginx/controller" in nginx_container.image;
    print(f"NGINX Ingress controller Deployment '{nginx_controller_name}' exists");

    nginx_service = core_v1.read_namespaced_service(
        name=nginx_service_name, namespace=namespace
    );
    assert nginx_service.spec.type == "NodePort";
    nginx_node_port = next(
        (
            p.node_port
            for p in nginx_service.spec.ports
            if p.name == "http"
        ),
        None
    );
    assert nginx_node_port == ingress_node_port , (
        f"Expected ingress NodePort {ingress_node_port}, got {nginx_node_port}"
    );
    print(
        f"NGINX Ingress Service '{nginx_service_name}' (NodePort:{ingress_node_port}) exists"
    );

    main_ingress = networking_v1.read_namespaced_ingress(
        name=ingress_name, namespace=namespace
    );
    assert main_ingress.metadata.name == ingress_name;
    assert main_ingress.spec.ingress_class_name == ingress_class_name;
    ingress_paths = [
        p.path for rule in main_ingress.spec.rules for p in rule.http.paths
    ];
    assert "/" in ingress_paths , f"Main ingress must route '/'; got paths: {ingress_paths}";
    assert "/grafana" in ingress_paths , f"Main ingress must route '/grafana'; got paths: {ingress_paths}";
    assert "/db-dashboard" in ingress_paths , f"Main ingress must route '/db-dashboard'; got paths: {ingress_paths}";
    print(f"Main Ingress '{ingress_name}' exists with routes: {ingress_paths}");

    ri_ingress = networking_v1.read_namespaced_ingress(
        name=redis_ingress_name, namespace=namespace
    );
    assert ri_ingress.metadata.name == redis_ingress_name;
    ri_paths = [p.path for rule in ri_ingress.spec.rules for p in rule.http.paths];
    assert any(p.startswith("/cache-dashboard") for p in ri_paths) , f"Redis Insight ingress must route '/cache-dashboard'; got: {ri_paths}";
    print(f"Redis Insight Ingress '{redis_ingress_name}' exists with route: {ri_paths}");

    # Send POST request to create a todo (with retry for 503)
    url = f"http://localhost:{ingress_node_port}/walker/create_todo";
    payload = {"text": "first-task"};
    response = _request_with_retry("POST", url, json=payload, timeout=10);
    assert response.status_code == 200;
    print(f"Successfully created todo at {url}");
    print(f"  Response: {response.json()}");

    url = f"http://localhost:{ingress_node_port}/cl/app";
    response = _request_with_retry("GET", url, timeout=100);
    print(f"Response status code for app page: {response.status_code}");
    assert response.status_code == 200;
    print(f"Successfully reached app page at {url}");

    # --- Port conflict test ---
    # Deploy the same app into a different namespace using the same ingress_node_port.
    # check_node_ports_available must detect the conflict and the deploy must fail.
    duplicate_namespace = "all-in-one-duplicate";
    duplicate_app_name = duplicate_namespace;

    duplicate_target_config = app_scale_config.get_kubernetes_config();
    duplicate_target_config["app_name"] = duplicate_app_name;
    duplicate_target_config["namespace"] = duplicate_namespace;
    duplicate_target_config["ingress_node_port"] = target_config[
        "ingress_node_port"
    ];  # same port — must conflict
    duplicate_target_config["redis_dashboard"] = True;
    duplicate_target_config["mongodb_dashboard"] = True;
    duplicate_target_config["jaseci_repo_url"] = repo_url;
    duplicate_target_config["jaseci_branch"] = branch;
    duplicate_target_config["jaseci_commit"] = commit;

    duplicate_target = DeploymentTargetFactory.create(
        "kubernetes", duplicate_target_config, logger
    );

    conflict_result = duplicate_target.deploy(app_config);
    assert conflict_result.success is False , (
        "Deploying with a conflicting NodePort should fail"
    );
    assert "NodePort conflict detected" in conflict_result.message , (
        f"Expected NodePort conflict error, got: {conflict_result.message}"
    );
    print(f"Port conflict correctly detected: {conflict_result.message}");

    # --- Component destroy: application ---
    # Destroy only the application component and verify HPA, Deployment, Service,
    # Secret, code-server, and PVCs are all removed while cache and database remain intact.
    deployment_target.destroy(app_name, "application");
    print("Application component destroy called");

    # Verify HPA is gone
    autoscaling_v2 = client.AutoscalingV2Api();
    try {
        autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(
            name=f"{app_name}-hpa", namespace=namespace
        );
        raise AssertionError(
            "HPA should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify main Deployment is gone
    try {
        apps_v1.read_namespaced_deployment(app_name, namespace=namespace);
        raise AssertionError(
            "App Deployment should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify main Service is gone
    try {
        core_v1.read_namespaced_service(f"{app_name}-service", namespace=namespace);
        raise AssertionError(
            "App Service should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify Secret is gone
    try {
        core_v1.read_namespaced_secret(f"{app_name}-secrets", namespace=namespace);
        raise AssertionError(
            "K8s Secret should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify code-server Deployment is gone
    try {
        apps_v1.read_namespaced_deployment(
            f"{app_name}-code-server", namespace=namespace
        );
        raise AssertionError(
            "Code-server Deployment should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify code-server Service is gone
    try {
        core_v1.read_namespaced_service(f"{app_name}-code-server", namespace=namespace);
        raise AssertionError(
            "Code-server Service should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify code PVC is gone (the billable-storage bug fix)
    # PVC may briefly be in Terminating state while the pvc-protection finalizer
    # is cleared after code-server pods finish terminating — poll up to 60s.
    pvc_deleted = False;
    for _ in range(30) {
        try {
            core_v1.read_namespaced_persistent_volume_claim(
                name=f"{app_name}-code-pvc", namespace=namespace
            );
            time.sleep(2);
        } except ApiException as e {
            assert e.status == 404 , f"Expected 404, got {e.status}";
            pvc_deleted = True;
            break;
        }
    }
    assert pvc_deleted , "code-pvc should have been deleted within 60s of application component destroy";

    print(
        "Application component (HPA + Deployment + Service + Secret + code-server + PVCs) removed"
    );

    # Verify cache and database are still running
    try {
        core_v1.read_namespaced_secret(
            f"{app_name}-mongodb-secret", namespace=namespace
        );
    } except ApiException as e {
        raise AssertionError(
            f"MongoDB Secret should still exist after application destroy, got {e.status}"
        );
    }

    try {
        apps_v1.read_namespaced_deployment(f"{app_name}-redis", namespace=namespace);
    } except ApiException as e {
        raise AssertionError(
            f"Redis deployment should still exist after application destroy, got {e.status}"
        );
    }

    try {
        apps_v1.read_namespaced_stateful_set(
            f"{app_name}-mongodb", namespace=namespace
        );
    } except ApiException as e {
        raise AssertionError(
            f"MongoDB StatefulSet should still exist after application destroy, got {e.status}"
        );
    }

    print(
        "Cache and database components confirmed still running after application destroy"
    );

    # --- Component destroy: cache ---
    # Destroy only the cache stack and verify all three resources (Deployment,
    # Service, ConfigMap) are removed while the database remains intact.
    deployment_target.destroy(app_name, "cache");
    print("Cache component destroy called");

    # Verify Redis Deployment is gone
    try {
        core_v1.read_namespaced_secret(f"{app_name}-redis-secret", namespace=namespace);
        raise AssertionError("Redis Secret should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("Redis secret cleanup verified");

    # Verify RedisInsight dashboard cleanup
    insight_name = f"{app_name}-redis-insight";
    try {
        apps_v1.read_namespaced_deployment(f"{app_name}-redis", namespace=namespace);
        raise AssertionError(
            "Redis Deployment should have been deleted by cache component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify Redis Service is gone
    try {
        core_v1.read_namespaced_service(
            f"{app_name}-redis-service", namespace=namespace
        );
        raise AssertionError(
            "Redis Service should have been deleted by cache component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify Redis ConfigMap is gone (the orphaned-ConfigMap bug fix)
    try {
        core_v1.read_namespaced_config_map(
            f"{app_name}-redis-config", namespace=namespace
        );
        raise AssertionError(
            "Redis ConfigMap should have been deleted by cache component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("Cache component (Redis Deployment + Service + ConfigMap) removed");

    # Verify database is still running
    try {
        apps_v1.read_namespaced_stateful_set(
            f"{app_name}-mongodb", namespace=namespace
        );
    } except ApiException as e {
        raise AssertionError(
            f"MongoDB StatefulSet should still exist after cache destroy, got {e.status}"
        );
    }

    print("Database component confirmed still running after cache destroy");

    # --- Full cleanup ---
    deployment_target.destroy(app_name);

    # Verify database cleanup (first destroyed by full destroy)
    try {
        apps_v1.read_namespaced_stateful_set(f"{app_name}-mongodb", namespace=namespace);
        raise AssertionError("MongoDB StatefulSet should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(
            f"{app_name}-mongodb-service", namespace=namespace
        );
        raise AssertionError("MongoDB Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_secret(
            f"{app_name}-mongodb-secret", namespace=namespace
        );
        raise AssertionError("MongoDB Secret should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify RedisInsight dashboard cleanup
    insight_name = f"{app_name}-redis-insight";
    try {
        apps_v1.read_namespaced_deployment(insight_name, namespace=namespace);
        raise AssertionError("RedisInsight Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{insight_name}-service", namespace=namespace);
        raise AssertionError("RedisInsight Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_config_map(
            f"{insight_name}-nginx-config", namespace=namespace
        );
        raise AssertionError(
            "RedisInsight nginx-config ConfigMap should have been deleted"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_secret(f"{insight_name}-auth", namespace=namespace);
        raise AssertionError("RedisInsight auth Secret should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify mongo-express dashboard cleanup
    express_name = f"{app_name}-mongo-express";
    try {
        apps_v1.read_namespaced_deployment(express_name, namespace=namespace);
        raise AssertionError("mongo-express Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{express_name}-service", namespace=namespace);
        raise AssertionError("mongo-express Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("Dashboard (RedisInsight + mongo-express) cleanup verified");

    # Verify monitoring stack cleanup
    prometheus_name = f"{app_name}-prometheus";
    try {
        apps_v1.read_namespaced_deployment(prometheus_name, namespace=namespace);
        raise AssertionError("Prometheus Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(
            f"{prometheus_name}-service", namespace=namespace
        );
        raise AssertionError("Prometheus Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_config_map(
            f"{prometheus_name}-config", namespace=namespace
        );
        raise AssertionError("Prometheus ConfigMap should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        apps_v1.read_namespaced_deployment(ksm_name, namespace=namespace);
        raise AssertionError("kube-state-metrics Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{ksm_name}-service", namespace=namespace);
        raise AssertionError("kube-state-metrics Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    grafana_name = f"{app_name}-grafana";
    try {
        apps_v1.read_namespaced_deployment(grafana_name, namespace=namespace);
        raise AssertionError("Grafana Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{grafana_name}-service", namespace=namespace);
        raise AssertionError("Grafana Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_secret(f"{grafana_name}-secret", namespace=namespace);
        raise AssertionError("Grafana Secret should have been deleted");
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
            );
        } except ApiException as e {
            assert e.status == 404 , f"Expected 404 for '{cm_name}', got {e.status}";
        }
    }

    try {
        core_v1.read_namespaced_service_account(
            name=f"{ksm_name}-sa", namespace=namespace
        );
        raise AssertionError(
            "kube-state-metrics ServiceAccount should have been deleted"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify NGINX Ingress controller cleanup
    nginx_controller_name = f"{app_name}-ingress-nginx";
    nginx_cluster_resource_name = f"{namespace}-{app_name}-ingress-nginx";
    ingress_class_name = f"{namespace}-{app_name}-nginx";
    nginx_configmap_name = f"{app_name}-nginx-configuration";
    nginx_service_name = f"{nginx_controller_name}-service";
    ingress_name = f"{app_name}-ingress";
    redis_ingress_name = f"{app_name}-redis-insight-ingress";
    redis_auth_secret_name = f"{app_name}-redis-insight-auth";

    try {
        networking_v1.read_namespaced_ingress(name=ingress_name, namespace=namespace);
        raise AssertionError("Main Ingress should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        networking_v1.read_namespaced_ingress(
            name=redis_ingress_name, namespace=namespace
        );
        raise AssertionError("Redis Insight Ingress should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_secret(name=redis_auth_secret_name, namespace=namespace);
        raise AssertionError("Redis Insight auth Secret should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        apps_v1.read_namespaced_deployment(nginx_controller_name, namespace=namespace);
        raise AssertionError("NGINX controller Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(nginx_service_name, namespace=namespace);
        raise AssertionError("NGINX controller Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service_account(
            name=nginx_controller_name, namespace=namespace
        );
        raise AssertionError(
            "NGINX controller ServiceAccount should have been deleted"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_config_map(
            name=nginx_configmap_name, namespace=namespace
        );
        raise AssertionError("NGINX ConfigMap should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role(name=nginx_cluster_resource_name);
        raise AssertionError("NGINX controller ClusterRole should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role_binding(name=nginx_cluster_resource_name);
        raise AssertionError(
            "NGINX controller ClusterRoleBinding should have been deleted"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        networking_v1.read_ingress_class(name=ingress_class_name);
        raise AssertionError("NGINX IngressClass should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("NGINX Ingress controller cleanup verified");

    # Verify TLS / cert-manager resource cleanup
    tls_secret_name = f"{app_name}-tls";
    try {
        core_v1.read_namespaced_secret(name=tls_secret_name, namespace=namespace);
        raise AssertionError("TLS Secret should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404 for TLS Secret, got {e.status}";
    }

    try {
        core_v1.read_namespaced_secret(name='letsencrypt-prod-key', namespace=namespace);
        raise AssertionError("ACME private key Secret should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404 for letsencrypt-prod-key Secret, got {e.status}";
    }

    try {
        custom_api.get_namespaced_custom_object(
            group='cert-manager.io',
            version='v1',
            namespace=namespace,
            plural='certificates',
            name=tls_secret_name
        );
        raise AssertionError("cert-manager Certificate CRD should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404 for Certificate CRD, got {e.status}";
    }

    try {
        custom_api.get_namespaced_custom_object(
            group='cert-manager.io',
            version='v1',
            namespace=namespace,
            plural='issuers',
            name='letsencrypt-prod'
        );
        raise AssertionError("cert-manager Issuer should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404 for Issuer, got {e.status}";
    }

    print("TLS / cert-manager resource cleanup verified");

    # Verify K8s Secret cleanup
    try {
        rbac_v1.read_cluster_role(name=cluster_role_name);
        raise AssertionError("kube-state-metrics ClusterRole should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role_binding(name=cluster_role_name);
        raise AssertionError(
            "kube-state-metrics ClusterRoleBinding should have been deleted"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        apps_v1.read_namespaced_daemon_set(ne_name, namespace=namespace);
        raise AssertionError("node-exporter DaemonSet should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{ne_name}-service", namespace=namespace);
        raise AssertionError("node-exporter Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print(
        "Monitoring component (Prometheus + Grafana + kube-state-metrics + node-exporter) cleanup verified"
    );

    # Verify namespace was deleted (since it is not 'default')
    try {
        core_v1.read_namespace(name=namespace);
        raise AssertionError("Namespace should have been deleted");
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
    assert len(details) == 10;
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
