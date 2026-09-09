import os;
import pathlib;
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.factory {
    ensure_deploy_tooling,
    require_deploy_tooling
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }
import from jaclang.scale.models.deployment_result { DeploymentResult }
import from jaclang.scale.models.resource_status { ResourceStatusInfo }
import from jaclang.scale.models.progress {
    CallbackSink,
    EventSink,
    NoopSink,
    ProgressEvent
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.sdk.spec { DeploySpec }
import from jaclang.scale.sdk.events { EventLogger }

def deploy(
    path: str, config: (dict[str, any] | None) = None, on_event: any = None
) -> DeploymentResult {
    return ScaleClient().deploy(
        DeploySpec.from_config(path, config), on_event=on_event
    );
}


obj ScaleClient {
    has kube_context: str = '',
        logger: (Logger | None) = None;

    def deploy(spec: DeploySpec, on_event: any = None) -> DeploymentResult {
        sink = CallbackSink(callback=on_event) if on_event is not None else NoopSink();
        target = self._make_target(
            spec, sink=sink, use_event_logger=on_event is not None
        );
        app_config = self._app_config(spec);
        self._emit(sink, 'deploy', 'start', f"Deploying '{spec.app_name}'");

        import from jaclang.scale.injector.binary { reset_deploy_version_cache }
        reset_deploy_version_cache();

        try {
            result = target.deploy(app_config);
        } except Exception as e {
            self._emit(sink, 'deploy', 'error', f"Deployment failed: {e}");
            return DeploymentResult(success=False, message=str(e));
        }

        if result.success {
            self._emit(
                sink,
                'deploy',
                'ok',
                f"Deployment of '{spec.app_name}' complete",
                detail={
                    'service_url': result.service_url,
                    'access_hint': result.access_hint
                }
            );
        } else {
            self._emit(
                sink,
                'deploy',
                'error',
                f"Deployment failed: {result.message or 'unknown error'}"
            );
        }
        return result;
    }

    def preview(spec: DeploySpec) -> dict[str, any] {
        target = self._make_target(spec, dry_run=True);
        return target.generate_manifests(self._app_config(spec));
    }

    def destroy(
        app_name: str, namespace: str, component: str = '', target: str = 'auto'
    ) {
        self._lifecycle_target(app_name, namespace, target).destroy(
            app_name, component
        );
    }

    def status(app_name: str, namespace: str, target: str = 'auto') -> dict[str, any] {
        return self._lifecycle_target(app_name, namespace, target).get_full_status(
            app_name
        );
    }

    def resource_status(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> ResourceStatusInfo {
        return self._lifecycle_target(app_name, namespace, target).get_status(app_name);
    }

    def service_url(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> (str | None) {
        return self._lifecycle_target(app_name, namespace, target).get_service_url(
            app_name
        );
    }

    def revisions(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> list[dict[str, any]] {
        return self._lifecycle_target(app_name, namespace, target).list_revisions(
            app_name
        );
    }

    def rollback(
        app_name: str, namespace: str, revision: int, target: str = 'auto'
    ) -> DeploymentResult {
        return self._lifecycle_target(app_name, namespace, target).rollback_to(
            app_name, revision
        );
    }

    def bundle_keys(app_name: str, namespace: str, target: str = 'auto') -> set[str] {
        return self._lifecycle_target(
            app_name, namespace, target
        ).referenced_bundle_keys(
            app_name
        );
    }

    def scale(app_name: str, namespace: str, replicas: int, target: str = 'auto') {
        self._lifecycle_target(app_name, namespace, target).scale(app_name, replicas);
    }

    def _emit(
        sink: EventSink,
        phase: str,
        status: str,
        message: str,
        detail: dict[str, any] = {}
    ) {
        sink.emit(
            ProgressEvent(phase=phase, status=status, message=message, detail=detail)
        );
    }

    def _pick_logger(sink: EventSink, use_event_logger: bool) -> Logger {
        if self.logger is not None {
            return self.logger;
        }
        if use_event_logger {
            return EventLogger(sink=sink);
        }
        import from jaclang.scale.observability.factory { UtilityFactory }
        return UtilityFactory.create_logger('standard');
    }

    def _target_config(spec: DeploySpec, dry_run: bool = False) -> KubernetesConfig {
        ensure_deploy_tooling(dry_run);
        require_deploy_tooling(dry_run);
        config = spec.to_target_config();
        if not config.get('kube_context') {
            config['kube_context'] = self.kube_context;
        }
        return KubernetesConfig.from_dict(KubernetesConfig, config);
    }

    def _make_target(
        spec: DeploySpec,
        sink: EventSink = NoopSink(),
        dry_run: bool = False,
        use_event_logger: bool = False
    ) -> KubernetesTarget {
        return KubernetesTarget(
            config=self._target_config(spec, dry_run),
            logger=self._pick_logger(sink, use_event_logger),
            dry_run=dry_run,
            secrets=dict(spec.secrets),
            env=dict(spec.env),
            events=sink,
            gateway_config=spec.to_gateway_config(),
            app_overrides=spec.app_overrides()
        );
    }

    def _lifecycle_target(
        app_name: str, namespace: str, target: str = 'auto'
    ) -> KubernetesTarget {
        spec = DeploySpec(app_name=app_name, namespace=namespace, target=target);
        return self._make_target(spec);
    }

    def _app_config(spec: DeploySpec) -> AppConfig {
        (code_folder, file_name) = spec.resolve_entry();

        posix_folder = pathlib.Path(os.path.relpath(code_folder)).as_posix();
        return AppConfig(
            code_folder=posix_folder, file_name=file_name, served_app=spec.app
        );
    }
}
