def build_service_apt_prefix(k8s_config: KubernetesConfig) -> str;


def build_runtime_install_commands(
    k8s_config: KubernetesConfig, prefer_image_binary: bool = False
) -> list[str];


def runtime_path -> str;


def runtime_container_env -> list[dict[str, str]];


def build_bootstrap_init_container(
    k8s_config: KubernetesConfig, base_image: str, unpack_script: str = ""
) -> dict[str, any];


def image_pull_policy(image: str) -> str;
