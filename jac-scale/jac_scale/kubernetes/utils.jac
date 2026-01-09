"""Kubernetes utility functions - compatibility wrapper.

This file now re-exports from the new architecture in targets/kubernetes/k8s_utils.jac.
Kept for backward compatibility with existing code.
"""
# Re-export all utility functions from the new location
import from jac_scale.targets.kubernetes.k8s_utils {
    load_env_variables,
    check_K8s_status,
    ensure_namespace_exists,
    delete_if_exists,
    cluster_type,
    check_deployment_status,
    ensure_pvc_exists,
    sync_code_to_pvc,
    validate_resource_limits,
    create_tarball,
    wait_for_pod_phase,
    wait_for_pod_deletion,
    run_kubectl_command,
    parse_cpu_quantity,
    parse_memory_quantity
}

# Cleanup function wrapper
def cleanup_K8s_resources -> None {
    import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
    import from jac_scale.engine.config.k8s_config { KubernetesConfig }
    import from jac_scale.config_loader { get_scale_config }
    import os;

    scale_config = get_scale_config();
    k8s_config_dict = scale_config.get_kubernetes_config();

    config = KubernetesConfig(
        app_name=os.getenv('APP_NAME', 'jaseci'),
        namespace=os.getenv('K8s_NAMESPACE')
        or k8s_config_dict.get('namespace', 'default'),
        target_type='kubernetes',
        build=False,
        code_folder='',
        file_name=''
    );

    target = KubernetesTarget(config=config);
    app_name = os.getenv('APP_NAME', 'jaseci');
    target.destroy(app_name);
}
