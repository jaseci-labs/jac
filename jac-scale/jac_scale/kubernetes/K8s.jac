"""File covering K8s automation."""
import os;
import time;
import from typing { Any }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }
import from .database.mongo { mongo_db }
import from .database.redis { redis_db }
import from .utils {
    check_deployment_status,
    check_K8s_status,
    cluster_type,
    delete_if_exists,
    ensure_namespace_exists,
    ensure_pvc_exists,
    load_env_variables,
    sync_code_to_pvc
}
import from jac_scale.config_loader { get_scale_config }

# Load kubernetes configuration from jac.toml with env var overrides
glob _k8s_config = get_scale_config().get_kubernetes_config();

def deploy_K8s(
    code_folder: str,
    file_name: str = 'none',
    build: bool = False,
    testing: bool = False
) -> None;
