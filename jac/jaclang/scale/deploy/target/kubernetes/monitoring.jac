import re;
import hashlib;

glob KUBE_STATE_METRICS_RESOURCES: dict[str, list[str]] = {
         '': [
             'nodes',
             'pods',
             'services',
             'resourcequotas',
             'replicationcontrollers',
             'limitranges',
             'persistentvolumeclaims',
             'persistentvolumes',
             'namespaces',
             'endpoints'
         ],
         'apps': ['statefulsets', 'daemonsets', 'deployments', 'replicasets'],
         'batch': ['cronjobs', 'jobs'],
         'autoscaling': ['horizontalpodautoscalers'],
         'policy': ['poddisruptionbudgets'],
         'storage.k8s.io': ['storageclasses', 'volumeattachments']
     };

obj MonitoringDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    def ensure_service(core_v1: any, name: str, namespace: str, body: dict[str, any]);
    def _deploy_prometheus(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        provider: ClusterProvider,
        scrape_target_service: str = ""
    );

    def _kube_state_metrics_rbac(app_name: str, namespace: str) -> dict[str, any];
    def _deploy_kube_state_metrics(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    );

    def _deploy_node_exporter(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    );

    def _deploy_grafana(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _deploy_tempo(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _deploy_loki(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _deploy_alloy(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def deploy(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        provider: ClusterProvider,
        scrape_target_service: str = ""
    );

    def destroy(app_name: str, namespace: str, apps_v1: any, core_v1: any);
}
