import time;
import subprocess;

obj IngressDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    def _deploy_nginx_controller(
        app_name: str,
        namespace: str,
        provider: ClusterProvider,
        apps_v1: any,
        core_v1: any,
        rbac_v1: any,
        networking_v1: any
    );

    def _resolve_ingress_class(app_name: str, namespace: str) -> str;
    def _ingress_path(
        path: str, svc: str, port: int, path_type: str = 'Prefix'
    ) -> dict[str, any];

    def _domain_rules(http_block: dict[str, any], domain: str) -> list[dict[str, any]];
    def _wait_for_nginx_ready(
        app_name: str, namespace: str, apps_v1: any, max_wait: int = 180
    ) -> None;

    def _deploy_ingress_resource(
        app_name: str,
        namespace: str,
        ingress_class: str,
        service_port: int,
        grafana_enabled: bool,
        networking_v1: any,
        core_v1: any
    );

    def start_controller(
        app_name: str,
        namespace: str,
        provider: ClusterProvider,
        apps_v1: any,
        core_v1: any,
        rbac_v1: any,
        networking_v1: any
    );

    def finish_ingress(
        app_name: str,
        namespace: str,
        service_port: int,
        grafana_enabled: bool,
        apps_v1: any,
        core_v1: any,
        networking_v1: any
    );

    def _install_cert_manager(
        app_name: str,
        namespace: str,
        cert_manager_email: str,
        core_v1: any,
        apps_v1: any,
        custom_api: any
    ) -> None;

    def enable_tls(
        app_name: str,
        namespace: str,
        networking_v1: any,
        custom_api: any,
        core_v1: any,
        apps_v1: any
    ) -> None;

    def destroy(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        rbac_v1: any,
        networking_v1: any
    );
}
