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

    namespace = "all-in-one";
    app_name = namespace;

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

    scale_config = get_scale_config();
    target_config = scale_config.get_kubernetes_config();
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

    app_scale_config = JacScaleConfig(Path(os.path.normpath(todo_app_path)));
    deployment_target.secrets = app_scale_config.get_secrets_config();

    app_config = AppConfig(
        code_folder=todo_app_path, file_name="main.jac", build=False, experimental=True
    );

    result = deployment_target.deploy(app_config);
    result = deployment_target.deploy(app_config);
    details = result.details;
    assert len(details) == 9;
    assert result.success is True;
    print(f"Deployment successful: {result.message}");

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
        apps_v1.read_namespaced_stateful_set(
            f"{app_name}-mongodb", namespace=namespace
        );
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

    # Verify K8s Secret cleanup
    try {
        core_v1.read_namespaced_secret(f"{app_name}-secrets", namespace=namespace);
        raise AssertionError("K8s Secret should have been deleted") ;
    } except ApiException as e {
        assert e.status == 404 , f"Expected 404, got {e.status}";
    }

    # Verify PVC cleanup
    pvcs = core_v1.list_namespaced_persistent_volume_claim(namespace=namespace);
    for pvc in pvcs.items {
        assert not pvc.metadata.name.startswith(app_name) , (
            f"PVC '{pvc.metadata.name}' should have been deleted"
        );
    }

    print("Cleanup verification complete - all resources properly deleted");
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
    assert len(details) == 8;
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
