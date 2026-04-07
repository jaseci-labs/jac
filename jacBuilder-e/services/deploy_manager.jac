"""Deployment manager for jacBuilder — uses jac-scale to deploy user projects to K8s."""

import os;
import re;
import shutil;
import socket;
import tempfile;
import threading;
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.factories.utility_factory { UtilityFactory }

"""Slugify a string for use in K8s resource names (lowercase, hyphens, max length)."""
def _slugify(name: str, max_len: int = 40) -> str {
    slug = name.lower().strip();
    slug = re.sub(r'[^a-z0-9]+', '-', slug);
    slug = slug.strip('-');
    if len(slug) > max_len {
        slug = slug[:max_len].rstrip('-');
    }
    return slug or "app";
}

"""Generate deterministic app_name and namespace from user_id + project_name."""
def generate_deploy_identifiers(user_id: str, project_name: str) -> tuple[str, str] {
    slug = _slugify(project_name, 20);
    uid_short = user_id[:8].lower();
    namespace = f"jb-{uid_short}-{slug}";
    app_name = slug;
    return (app_name, namespace);
}

"""Copy project files to a temp directory, excluding .git and .jac-ide."""
def _copy_project(repo_path: str) -> str {
    tmp_dir = tempfile.mkdtemp(prefix="jac-deploy-");
    for item in os.listdir(repo_path) {
        if item in ('.git', '.jac-ide', '__pycache__', '.jac') {
            continue;
        }
        src = os.path.join(repo_path, item);
        dst = os.path.join(tmp_dir, item);
        if os.path.isdir(src) {
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns('.git', '.jac-ide', '__pycache__', '.jac'));
        } else {
            shutil.copy2(src, dst);
        }
    }
    return tmp_dir;
}

"""Wait until a hostname resolves in DNS (up to max_wait seconds)."""
def _wait_for_dns(hostname: str, max_wait: int = 300) -> bool {
    import time;
    interval = 10;
    elapsed = 0;
    while elapsed < max_wait {
        try {
            socket.getaddrinfo(hostname, 80);
            print(f"DNS resolved for {hostname} after {elapsed}s");
            return True;
        } except socket.gaierror {
            time.sleep(interval);
            elapsed += interval;
        }
    }
    print(f"Warning: DNS did not resolve for {hostname} within {max_wait}s");
    return False;
}

"""Get the deployment URL from the ingress-nginx LoadBalancer service.
jac-scale creates {app_name}-ingress-nginx-service as a LoadBalancer with an NLB.
Poll until the NLB hostname is available and DNS resolves.
"""
def _make_internet_facing_and_get_url(app_name: str, namespace: str) -> str {
    try {
        import from kubernetes { client, config as k8s_config }
        import time;
        k8s_config.load_kube_config();
        v1 = client.CoreV1Api();
        ingress_svc_name = f"{app_name}-ingress-nginx-service";

        # Poll until the ingress NLB hostname appears (up to 3 min)
        for i in range(18) {  # 18 × 10s = 3 min max
            try {
                svc = v1.read_namespaced_service(ingress_svc_name, namespace);
                ingress = svc.status.load_balancer.ingress;
                if ingress and len(ingress) > 0 {
                    hostname = ingress[0].hostname or ingress[0].ip or "";
                    if hostname {
                        print(f"NLB hostname ready: {hostname}, waiting for DNS...");
                        _wait_for_dns(hostname, max_wait=300);
                        return f"http://{hostname}";
                    }
                }
            } except Exception {
                _ = 0;
            }
            time.sleep(10);
        }
        print("Warning: timed out waiting for ingress NLB hostname");
    } except Exception as e {
        print(f"Warning: could not get ingress URL: {e}");
    }
    return "";
}

"""Get the service URL from the ingress-nginx LoadBalancer (quick check)."""
def _get_service_url(app_name: str, namespace: str, retries: int = 3) -> str {
    try {
        import from kubernetes { client, config as k8s_config }
        import time;
        k8s_config.load_kube_config();
        v1 = client.CoreV1Api();
        ingress_svc_name = f"{app_name}-ingress-nginx-service";
        for _ in range(retries) {
            try {
                svc = v1.read_namespaced_service(ingress_svc_name, namespace);
                ingress = svc.status.load_balancer.ingress;
                if ingress and len(ingress) > 0 {
                    endpoint = ingress[0].hostname or ingress[0].ip;
                    if endpoint {
                        return f"http://{endpoint}";
                    }
                }
            } except Exception {}
            time.sleep(5);
        }
    } except Exception {}
    return "";
}

"""Deploy a project to K8s using jac-scale."""
def deploy_project(user_id: str, project_name: str, repo_path: str) -> dict {
    (app_name, namespace) = generate_deploy_identifiers(user_id, project_name);
    tmp_dir = None;
    try {
        tmp_dir = _copy_project(repo_path);
        logger = UtilityFactory.create_logger('standard');
        config = KubernetesConfig(app_name=app_name, namespace=namespace);
        target = KubernetesTarget(config=config, logger=logger);
        app_config = AppConfig(
            code_folder=tmp_dir,
            file_name="main.jac",
            build=False,
            app_name=app_name,
            experimental=False
        );
        result = target.deploy(app_config);
        if result.success {
            url = _make_internet_facing_and_get_url(app_name, namespace);
            if not url {
                url = result.service_url or "";
            }
            return {
                "success": True,
                "url": url,
                "namespace": namespace,
                "app_name": app_name,
                "message": result.message or ""
            };
        }
        return {
            "success": False,
            "url": "",
            "namespace": namespace,
            "app_name": app_name,
            "message": result.message or "Deployment failed"
        };
    } except Exception as e {
        return {
            "success": False,
            "url": "",
            "namespace": namespace,
            "app_name": app_name,
            "message": str(e)
        };
    } finally {
        if tmp_dir and os.path.exists(tmp_dir) {
            shutil.rmtree(tmp_dir, ignore_errors=True);
        }
    }
}

"""Destroy a deployment from K8s."""
def destroy_deployment(app_name: str, namespace: str) -> dict {
    try {
        logger = UtilityFactory.create_logger('standard');
        config = KubernetesConfig(app_name=app_name, namespace=namespace);
        target = KubernetesTarget(config=config, logger=logger);
        target.destroy(app_name);
        return {"success": True, "message": f"Deployment '{app_name}' destroyed"};
    } except Exception as e {
        return {"success": False, "message": str(e)};
    }
}

"""Get deployment status from K8s."""
def get_deployment_status(app_name: str, namespace: str) -> dict {
    try {
        config = KubernetesConfig(app_name=app_name, namespace=namespace);
        target = KubernetesTarget(config=config);
        status_info = target.get_status(app_name);
        url = _get_service_url(app_name, namespace, retries=1);
        if not url {
            url = target.get_service_url(app_name) or "";
        }
        return {
            "success": True,
            "status": status_info.status.value if status_info.status else "unknown",
            "url": url,
            "replicas": status_info.replicas if hasattr(status_info, 'replicas') else 0,
            "ready_replicas": status_info.ready_replicas if hasattr(status_info, 'ready_replicas') else 0,
            "message": status_info.message if hasattr(status_info, 'message') else ""
        };
    } except Exception as e {
        return {
            "success": False,
            "status": "unknown",
            "url": "",
            "message": str(e)
        };
    }
}

# Registry for in-progress deployment threads and their results.
# _deploy_results stores completed deploy results so walkers can read them
# (background thread callbacks can't persist graph mutations).
glob _deploy_threads: dict = {};
glob _deploy_results: dict = {};

"""Check if a deployment result is available (called from walker context)."""
def get_deploy_result(user_id: str, project_name: str) -> dict {
    key = f"{user_id}:{project_name}";
    return _deploy_results.pop(key, {});
}

"""Run deployment in a background thread. Result stored in _deploy_results."""
def deploy_async(user_id: str, project_name: str, repo_path: str, callback: Any) -> None {
    def _run() -> None {
        result = deploy_project(user_id, project_name, repo_path);
        key = f"{user_id}:{project_name}";
        _deploy_results[key] = result;
        if callback {
            callback(result);
        }
        if key in _deploy_threads {
            del _deploy_threads[key];
        }
    }
    key = f"{user_id}:{project_name}";
    t = threading.Thread(target=_run, daemon=True);
    _deploy_threads[key] = t;
    t.start();
}
