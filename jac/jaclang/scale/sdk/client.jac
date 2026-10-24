import os;
import pathlib;

def deploy(
    path: str, config: (dict[str, any] | None) = None, on_event: any = None
) -> DeploymentResult;


obj ScaleClient {
    has kube_context: str = '',
        logger: (Logger | None) = None;

    def deploy(spec: DeploySpec, on_event: any = None) -> DeploymentResult;
    def preview(spec: DeploySpec) -> dict[str, any];
    def destroy(
        app_name: str, namespace: str, component: str = '', target: str = 'auto'
    );

    def status(app_name: str, namespace: str, target: str = 'auto') -> dict[str, any];
    def resource_status(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> ResourceStatusInfo;

    def autoscaler_status(
        app_name: str, namespace: str, service: str = '', target: str = 'auto'
    ) -> AutoscalerRuntimeStatus;

    def watch_autoscaler_transitions(
        app_name: str,
        namespace: str,
        label_selector: (str | None) = None,
        timeout_seconds: (int | None) = None,
        target: str = 'auto'
    ) -> any;

    def _scale_target_name(svc_name: str) -> str;
    def _autoscaler_for(app_name: str, namespace: str, target: str) -> any;
    def service_url(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> (str | None);

    def revisions(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> list[dict[str, any]];

    def rollback(
        app_name: str, namespace: str, revision: int, target: str = 'auto'
    ) -> DeploymentResult;

    def bundle_keys(app_name: str, namespace: str, target: str = 'auto') -> set[str];
    def scale(app_name: str, namespace: str, replicas: int, target: str = 'auto');
    def _emit(
        sink: EventSink,
        phase: str,
        status: str,
        message: str,
        detail: dict[str, any] = {}
    );

    def _pick_logger(sink: EventSink, use_event_logger: bool) -> Logger;
    def _target_config(spec: DeploySpec, dry_run: bool = False) -> KubernetesConfig;
    def _make_target(
        spec: DeploySpec,
        sink: EventSink = NoopSink(),
        dry_run: bool = False,
        use_event_logger: bool = False
    ) -> KubernetesTarget;

    def _lifecycle_target(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> KubernetesTarget;

    def _app_config(spec: DeploySpec) -> AppConfig;
}
