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
    target_config["loki_enabled"] = True;

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
    print(f"Deployment result details: {details}");
    print(f"Deployment status: {result.message}");
    assert result.success is True;
    assert len(details) == 14;

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
    print(
        f"MongoDB Secret '{app_name}-mongodb-secret' exists with correct credentials"
    );

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
    ri_username_env = next(
        (
            e
            for e in insight_container.env
            if e.name == "RI_REDIS_USERNAME"
        ),
        None
    );
    assert ri_username_env is not None , "RI_REDIS_USERNAME env var must be set";
    assert ri_username_env.value_from is not None , "RI_REDIS_USERNAME must use secretKeyRef";
    assert ri_username_env.value_from.secret_key_ref.key == "username";
    ri_password_env = next(
        (
            e
            for e in insight_container.env
            if e.name == "RI_REDIS_PASSWORD"
        ),
        None
    );
    assert ri_password_env is not None , "RI_REDIS_PASSWORD env var must be set";
    assert ri_password_env.value_from is not None , "RI_REDIS_PASSWORD must use secretKeyRef";
    assert ri_password_env.value_from.secret_key_ref.key == "password";
    print(
        f"RedisInsight Deployment '{insight_name}' exists with RI_REDIS_HOST/PORT pre-configured, "
        f"RI_REDIS_USERNAME/PASSWORD from secret, and RIPROXYPATH=/cache-dashboard"
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
    assert len(grafana_container.volume_mounts) == 5;
    print(f"Grafana Deployment '{grafana_name}' exists with 5 volume mounts");

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
    ds_yaml = grafana_ds.data["datasource.yaml"];
    assert "prometheus" in ds_yaml.lower();
    assert "loki" in ds_yaml.lower();
    assert "uid: loki" in ds_yaml;
    assert "type: loki" in ds_yaml;
    print("Grafana datasource ConfigMap exists with Prometheus and Loki datasources");

    grafana_dashboard = core_v1.read_namespaced_config_map(
        name=f"{grafana_name}-dashboard", namespace=namespace
    );
    assert "jac-scale.json" in grafana_dashboard.data;
    assert "Jac Scale - App Metrics" in grafana_dashboard.data["jac-scale.json"];
    assert "k8s-metrics.json" in grafana_dashboard.data;
    assert "Kubernetes Cluster Metrics" in grafana_dashboard.data["k8s-metrics.json"];
    assert "pod-logs.json" in grafana_dashboard.data;
    assert "Pod Logs" in grafana_dashboard.data["pod-logs.json"];
    print(
        "Grafana dashboard ConfigMap exists with Jac Scale + K8s Metrics + Pod Logs dashboards"
    );

    grafana_provider = core_v1.read_namespaced_config_map(
        name=f"{grafana_name}-dashboard-provider", namespace=namespace
    );
    assert "provider.yaml" in grafana_provider.data;
    print("Grafana dashboard provider ConfigMap exists");

    # Validate Loki Deployment, Service, ConfigMap, and ServiceAccount
    loki_name = f"{app_name}-loki";
    loki_deploy = apps_v1.read_namespaced_deployment(
        name=loki_name, namespace=namespace
    );
    assert loki_deploy.metadata.name == loki_name;
    assert loki_deploy.spec.replicas == 1;
    loki_container = loki_deploy.spec.template.spec.containers[0];
    assert loki_container.image == "grafana/loki:3.4.2";
    loki_sc = loki_container.security_context;
    assert loki_sc.run_as_non_root is True;
    assert loki_sc.read_only_root_filesystem is True;
    assert loki_sc.allow_privilege_escalation is False;
    assert loki_sc.capabilities.drop == ["ALL"];
    print(f"Loki Deployment '{loki_name}' exists with hardened security context");

    loki_service = core_v1.read_namespaced_service(
        name=f"{loki_name}-service", namespace=namespace
    );
    assert loki_service.spec.type == "ClusterIP";
    assert loki_service.spec.ports[0].port == 3100;
    print(f"Loki Service '{loki_name}-service' (ClusterIP:3100) exists");

    loki_config = core_v1.read_namespaced_config_map(
        name=f"{loki_name}-config", namespace=namespace
    );
    assert "loki.yaml" in loki_config.data;
    assert "http_listen_port: 3100" in loki_config.data["loki.yaml"];
    assert "store: tsdb" in loki_config.data["loki.yaml"];
    print(f"Loki ConfigMap '{loki_name}-config' exists with correct config");

    loki_sa = core_v1.read_namespaced_service_account(
        name=f"{loki_name}-sa", namespace=namespace
    );
    assert loki_sa.metadata.name == f"{loki_name}-sa";
    assert loki_sa.automount_service_account_token is False;
    print(f"Loki ServiceAccount '{loki_name}-sa' exists with token automount disabled");

    # Validate Alloy DaemonSet, ConfigMap, ServiceAccount, ClusterRole, ClusterRoleBinding
    alloy_name = f"{app_name}-alloy";
    alloy_cr_name = f"{namespace}-{alloy_name}";

    alloy_ds = apps_v1.read_namespaced_daemon_set(name=alloy_name, namespace=namespace);
    assert alloy_ds.metadata.name == alloy_name;
    alloy_container = alloy_ds.spec.template.spec.containers[0];
    assert alloy_container.image.startswith("grafana/alloy:") , (
        f"expected grafana/alloy image, got {alloy_container.image}"
    );
    tolerations = alloy_ds.spec.template.spec.tolerations;
    assert any(
        t.operator == "Exists" and t.effect == "NoSchedule" for t in tolerations
    ) , "Alloy must tolerate NoSchedule to run on all nodes";
    print(f"Alloy DaemonSet '{alloy_name}' exists with NoSchedule toleration");

    alloy_config = core_v1.read_namespaced_config_map(
        name=f"{alloy_name}-config", namespace=namespace
    );
    assert "config.alloy" in alloy_config.data;
    alloy_river = alloy_config.data["config.alloy"];
    assert "/loki/api/v1/push" in alloy_river;
    assert f"{loki_name}-service" in alloy_river;
    # Alloy uses River blocks; assert the two components that drive
    # K8s SD + Loki push, equivalent to Promtail's kubernetes_sd_configs.
    assert "discovery.kubernetes" in alloy_river;
    assert "loki.write" in alloy_river;
    print(f"Alloy ConfigMap '{alloy_name}-config' exists pointing to Loki with K8s SD");

    alloy_sa = core_v1.read_namespaced_service_account(
        name=f"{alloy_name}-sa", namespace=namespace
    );
    assert alloy_sa.metadata.name == f"{alloy_name}-sa";
    print(f"Alloy ServiceAccount '{alloy_name}-sa' exists");

    alloy_cr = rbac_v1.read_cluster_role(name=alloy_cr_name);
    assert alloy_cr.metadata.name == alloy_cr_name;
    print(f"Alloy ClusterRole '{alloy_cr_name}' exists");

    alloy_crb = rbac_v1.read_cluster_role_binding(name=alloy_cr_name);
    assert alloy_crb.metadata.name == alloy_cr_name;
    print(f"Alloy ClusterRoleBinding '{alloy_cr_name}' exists");

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
    ne_daemonset = apps_v1.read_namespaced_daemon_set(
        name=ne_name, namespace=namespace
    );
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

    # Validate NetworkPolicies were created
    network_policy_names = [
        f"{app_name}-network-policy",
        f"{app_name}-mongodb-network-policy",
        f"{app_name}-redis-network-policy",
        f"{app_name}-prometheus-network-policy",
        f"{app_name}-grafana-network-policy",
        f"{app_name}-code-server-network-policy",
        f"{app_name}-kube-state-metrics-network-policy",
        f"{app_name}-node-exporter-network-policy",
        f"{app_name}-mongo-express-network-policy",
        f"{app_name}-redis-insight-network-policy"
    ];
    for policy_name in network_policy_names {
        policy = networking_v1.read_namespaced_network_policy(
            name=policy_name, namespace=namespace
        );
        assert policy.metadata.name == policy_name;
        assert policy.spec.policy_types == ["Ingress", "Egress"];
        print(f"NetworkPolicy '{policy_name}' exists with correct policy types");
    }

    # Validate MongoDB/Redis NetworkPolicy ingress allows dashboard pods
    mongo_policy = networking_v1.read_namespaced_network_policy(
        name=f"{app_name}-mongodb-network-policy", namespace=namespace
    );
    mongo_ingress = mongo_policy.spec.ingress[0];
    mongo_from = [f.pod_selector.match_labels for f in mongo_ingress._from];
    assert {'app': app_name} in mongo_from;
    assert {'app': f"{app_name}-mongo-express"} in mongo_from;

    redis_policy = networking_v1.read_namespaced_network_policy(
        name=f"{app_name}-redis-network-policy", namespace=namespace
    );
    redis_ingress = redis_policy.spec.ingress[0];
    redis_from = [f.pod_selector.match_labels for f in redis_ingress._from];
    assert {'app': app_name} in redis_from;
    assert {'app': f"{app_name}-redis-insight"} in redis_from;

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

    # Validate HPA is updated on redeploy (not silently ignored)
    AutoscalerFactory.create("hpa", {}).apply(
        AutoscalerSpec(
            scale_target_name=app_name,
            namespace=namespace,
            min_replicas=2,
            max_replicas=5,
            triggers=[Trigger(type="cpu", metadata={"averageUtilization": "70"})]
        )
    );
    hpa_updated = autoscaling_v2.read_namespaced_horizontal_pod_autoscaler(
        name=f"{app_name}-hpa", namespace=namespace
    );
    assert hpa_updated.spec.min_replicas == 2 , f"Expected min_replicas=2, got {hpa_updated.spec.min_replicas}";
    assert hpa_updated.spec.max_replicas == 5 , f"Expected max_replicas=5, got {hpa_updated.spec.max_replicas}";
    assert hpa_updated.spec.metrics[0].resource.target.average_utilization == 70 , (
        f"Expected cpu_target=70, got {hpa_updated.spec.metrics[
            0
        ].resource.target.average_utilization}"
    );
    print(
        f"HPA update verified: min_replicas={hpa_updated.spec.min_replicas}, max_replicas={hpa_updated.spec.max_replicas}, cpu_target=70%"
    );

    # Restore original HPA values for remaining tests
    AutoscalerFactory.create("hpa", {}).apply(
        AutoscalerSpec(
            scale_target_name=app_name,
            namespace=namespace,
            min_replicas=1,
            max_replicas=3,
            triggers=[Trigger(type="cpu", metadata={"averageUtilization": "50"})]
        )
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

    # Validate rate limiting annotations are present with correct default values
    ingress_annotations = main_ingress.metadata.annotations or {};
    assert ingress_annotations.get("nginx.ingress.kubernetes.io/limit-rps") == "20" , (
        f"Expected limit-rps=20, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/limit-rps'
        )}"
    );
    assert ingress_annotations.get(
        "nginx.ingress.kubernetes.io/limit-burst-multiplier"
    ) == "5" , (
        f"Expected limit-burst-multiplier=5, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/limit-burst-multiplier'
        )}"
    );
    assert ingress_annotations.get("nginx.ingress.kubernetes.io/limit-connections") == "20" , (
        f"Expected limit-connections=20, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/limit-connections'
        )}"
    );
    assert ingress_annotations.get(
        "nginx.ingress.kubernetes.io/limit-req-status-code"
    ) == "429" , (
        f"Expected limit-req-status-code=429, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/limit-req-status-code'
        )}"
    );
    print(
        f"Rate limiting annotations verified: rps=20, burst-multiplier=5, connections=20, status=429"
    );

    # Validate sticky session annotations are present (enabled by default)
    assert ingress_annotations.get("nginx.ingress.kubernetes.io/affinity") == "cookie" , (
        f"Expected affinity=cookie, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/affinity'
        )}"
    );
    assert ingress_annotations.get(
        "nginx.ingress.kubernetes.io/session-cookie-name"
    ) == "route" , (
        f"Expected session-cookie-name=route, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/session-cookie-name'
        )}"
    );
    assert ingress_annotations.get(
        "nginx.ingress.kubernetes.io/session-cookie-max-age"
    ) == "2147483647" , (
        f"Expected session-cookie-max-age=2147483647, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/session-cookie-max-age'
        )}"
    );
    assert ingress_annotations.get(
        "nginx.ingress.kubernetes.io/session-cookie-expires"
    ) == "2147483647" , (
        f"Expected session-cookie-expires=2147483647, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/session-cookie-expires'
        )}"
    );
    assert ingress_annotations.get(
        "nginx.ingress.kubernetes.io/session-cookie-change-on-failure"
    ) == "true" , (
        f"Expected session-cookie-change-on-failure=true, got: {ingress_annotations.get(
            'nginx.ingress.kubernetes.io/session-cookie-change-on-failure'
        )}"
    );
    print(
        "Sticky session annotations verified: affinity=cookie, cookie-name=route, max-age=2147483647"
    );

    ri_ingress = networking_v1.read_namespaced_ingress(
        name=redis_ingress_name, namespace=namespace
    );
    assert ri_ingress.metadata.name == redis_ingress_name;
    ri_paths = [p.path for rule in ri_ingress.spec.rules for p in rule.http.paths];
    assert any(p.startswith("/cache-dashboard") for p in ri_paths) , f"Redis Insight ingress must route '/cache-dashboard'; got: {ri_paths}";
    print(
        f"Redis Insight Ingress '{redis_ingress_name}' exists with route: {ri_paths}"
    );

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

    # Verify /metrics endpoint: unauthenticated should be 403, Basic Auth should return Prometheus text
    monitoring_cfg = app_scale_config.get_monitoring_config();
    prometheus_password = monitoring_cfg.get(
        'prometheus_admin_password', 'Adminpassword123'
    );
    admin_cfg = app_scale_config.get_admin_config();
    admin_user = admin_cfg.get('username', 'admin');
    metrics_url = f"http://localhost:{ingress_node_port}/metrics";
    unauthed = requests.get(metrics_url, timeout=10);
    assert unauthed.status_code == 403 , f"Expected 403 without auth, got {unauthed.status_code}";
    print(f"Metrics endpoint correctly returned 403 without auth");
    authed = requests.get(
        metrics_url, auth=(admin_user, prometheus_password), timeout=10
    );
    assert authed.status_code == 200 , f"Expected 200 with Basic Auth, got {authed.status_code}";
    assert "python_gc" in authed.text or "jac_scale" in authed.text , "Response does not look like Prometheus metrics";
    print(f"Metrics endpoint returned 200 with Basic Auth — Prometheus scraping OK");

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

    # Verify app ServiceAccount is gone
    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-sa", namespace=namespace
        );
        raise AssertionError(
            "App ServiceAccount should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify code-server ServiceAccount is gone
    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-code-server-sa", namespace=namespace
        );
        raise AssertionError(
            "Code-server ServiceAccount should have been deleted by application component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify NetworkPolicies are gone
    networking_v1 = client.NetworkingV1Api();
    network_policy_names = [
        f"{app_name}-network-policy",
        f"{app_name}-mongodb-network-policy",
        f"{app_name}-redis-network-policy",
        f"{app_name}-prometheus-network-policy",
        f"{app_name}-grafana-network-policy",
        f"{app_name}-code-server-network-policy",
        f"{app_name}-kube-state-metrics-network-policy",
        f"{app_name}-node-exporter-network-policy",
        f"{app_name}-mongo-express-network-policy",
        f"{app_name}-redis-insight-network-policy"
    ];
    for policy_name in network_policy_names {
        try {
            networking_v1.read_namespaced_network_policy(
                name=policy_name, namespace=namespace
            );
            raise AssertionError(
                f"NetworkPolicy '{policy_name}' should have been deleted by application component destroy"
            );
        } except ApiException as e {
            assert e.status == 404 , f"Expected 404 for {policy_name}, got {e.status}";
        }
    }

    print(
        "Application component (HPA + Deployment + Service + Secret + code-server + PVCs + SAs + NetworkPolicies) removed"
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

    # Verify Redis ServiceAccount is gone
    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-redis-sa", namespace=namespace
        );
        raise AssertionError(
            "Redis ServiceAccount should have been deleted by cache component destroy"
        );
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("Cache component (Redis Deployment + Service + ConfigMap + SA) removed");

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
        apps_v1.read_namespaced_stateful_set(
            f"{app_name}-mongodb", namespace=namespace
        );
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

    # Verify dashboard ServiceAccounts are gone
    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-mongo-express-sa", namespace=namespace
        );
        raise AssertionError("mongo-express ServiceAccount should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-redis-insight-sa", namespace=namespace
        );
        raise AssertionError("RedisInsight ServiceAccount should have been deleted");
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

    # Verify Loki resources are gone
    loki_name = f"{app_name}-loki";
    alloy_name = f"{app_name}-alloy";
    alloy_cr_name = f"{namespace}-{alloy_name}";

    try {
        apps_v1.read_namespaced_deployment(loki_name, namespace=namespace);
        raise AssertionError("Loki Deployment should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service(f"{loki_name}-service", namespace=namespace);
        raise AssertionError("Loki Service should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_config_map(f"{loki_name}-config", namespace=namespace);
        raise AssertionError("Loki ConfigMap should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service_account(
            name=f"{loki_name}-sa", namespace=namespace
        );
        raise AssertionError("Loki ServiceAccount should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify Alloy resources are gone
    try {
        apps_v1.read_namespaced_daemon_set(alloy_name, namespace=namespace);
        raise AssertionError("Alloy DaemonSet should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_config_map(f"{alloy_name}-config", namespace=namespace);
        raise AssertionError("Alloy ConfigMap should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service_account(
            name=f"{alloy_name}-sa", namespace=namespace
        );
        raise AssertionError("Alloy ServiceAccount should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role(name=alloy_cr_name);
        raise AssertionError("Alloy ClusterRole should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        rbac_v1.read_cluster_role_binding(name=alloy_cr_name);
        raise AssertionError("Alloy ClusterRoleBinding should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    print("Loki and Alloy cleanup verified");

    # Verify MongoDB ServiceAccount is gone
    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-mongodb-sa", namespace=namespace
        );
        raise AssertionError("MongoDB ServiceAccount should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
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
        core_v1.read_namespaced_secret(
            name=redis_auth_secret_name, namespace=namespace
        );
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
        core_v1.read_namespaced_secret(
            name='letsencrypt-prod-key', namespace=namespace
        );
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
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-prometheus-sa", namespace=namespace
        );
        raise AssertionError("Prometheus ServiceAccount should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    try {
        core_v1.read_namespaced_service_account(
            name=f"{app_name}-grafana-sa", namespace=namespace
        );
        raise AssertionError("Grafana ServiceAccount should have been deleted");
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

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
        "Monitoring component (Prometheus + Grafana + kube-state-metrics + node-exporter + SAs) cleanup verified"
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
