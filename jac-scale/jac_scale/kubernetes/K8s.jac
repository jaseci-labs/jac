"""File covering K8s automation - compatibility wrapper.

This file now delegates to the new architecture in targets/kubernetes/.
Kept for backward compatibility with existing code.
"""
import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
import from jac_scale.engine.models.app_config { AppConfig }
import from jac_scale.engine.config.k8s_config { KubernetesConfig }
import from jac_scale.config_loader { get_scale_config }
import os;

def deploy_K8s(
    code_folder: str,
    file_name: str = 'none',
    build: bool = False,
    testing: bool = False
) -> None {
    # Load configuration
    scale_config = get_scale_config();
    k8s_config_dict = scale_config.get_kubernetes_config();

    # Create config object
    config = KubernetesConfig(
        app_name=k8s_config_dict.get('app_name', 'jaseci'),
        namespace=os.getenv('K8s_NAMESPACE')
        or k8s_config_dict.get('namespace', 'default'),
        target_type='kubernetes',
        build=build,
        code_folder=code_folder,
        file_name=file_name
    );

    # Create target and deploy
    target = KubernetesTarget(config=config);

    # Create app config
    app_name = os.getenv('APP_NAME') or k8s_config_dict.get('app_name', 'jaseci');
    image_name = k8s_config_dict.get('docker_image_name', f"{app_name}:latest");

    app_config = AppConfig(
        name=app_name, image=image_name, env_vars=[], resources=None, health_check=None
    );

    # Deploy
    result = target.deploy(app_config);
    if not result.success {
        raise RuntimeError(f"Deployment failed: {result.errors}") ;
    }
}
