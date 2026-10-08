import base64;
import hmac;
import logging;
import os;
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.serving.datatypes { JSONResponse, Request, Response }
import from jaclang.server.serving.drain { HEALTH_PATHS }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jaclang.scale.admin.llm_telemetry { JacAPIServerLLMTelemetry }
import from jaclang.scale.admin.logs { JacAPIServerLogs }
import from jaclang.scale.admin.network { JacAPIServerNetwork }
import from jaclang.scale.admin.ops { JacAPIServerOps }
import from jaclang.scale.admin.podenv { JacAPIServerPodEnv }
import from jaclang.scale.admin.traces { JacAPIServerTraces }
import from jaclang.scale.admin.workloads { JacAPIServerWorkloads }
import from jaclang.scale.config.config_loader { ADMIN_PASSWORD_ENV, get_scale_config }
import from jaclang.server.identity.policy { check_password }
import from jaclang.scale.emailer.emailer { Emailer }
import from jaclang.scale.observability.metrics { MetricsCollector }
import from jaclang.scale.server.jobs_ext { JobsExtension }
import from jaclang.scale.server.sso_ext { ApiKeyExtension, SSOExtension }
import from jaclang.scale.server.webhook_ext { WebhookExtension }
import from jaclang.scale.server.websocket_ext { WebSocketExtension }

glob logger: logging.Logger = logging.getLogger(__name__);


def validate_events_url(url: (str | None)) {
    if url and not str(url).startswith(('postgres://', 'postgresql://')) {
        raise ValueError(
            f"Unknown [scale.events].url scheme: {url!r}. The event stream rides "
            "Postgres; expected a postgresql:// URL (or unset, to fall back to "
            "[scale.database].url / JAC_DB_URL)."
        );
    }
}


def fleet_provisions_unknown_users(sv_name: str) -> bool {
    if not sv_name or sv_name == '__gateway__' {
        return False;
    }
    identity_cfg = dict(get_scale_config().get_gateway_config().get('identity', {}));
    return bool(identity_cfg.get('gateway_owned', True));
}


obj FleetIdentityExtension(ServerExtension) {
    def register(server: JacAPIServer) {
        import os;
        server.user_manager.provision_unknown_users = fleet_provisions_unknown_users(
            os.environ.get('JAC_SV_NAME', '').strip()
        );
    }
}


obj ObservabilityExtension(ServerExtension) {
    def register(server: JacAPIServer) {
        import from jaclang.scale.runtime.context.auth_ctx {
            reset_current_auth,
            set_current_auth
        }
        import from jaclang.scale.runtime.context.log_emit {
            install_structured_logging
        }
        import from jaclang.scale.runtime.context.trace_ctx {
            ensure_trace_id,
            reset_current_trace,
            set_current_trace
        }
        import from jaclang.scale.runtime.context.tracing {
            end_span,
            install_tracing,
            start_server_span,
            tracing_installed
        }
        install_structured_logging();
        if not tracing_installed() {
            trc = get_scale_config().get_gateway_config().get('tracing', {});
            install_tracing(
                enabled=trc.get('enabled', False),
                endpoint=trc.get('endpoint'),
                sample_ratio=float(trc.get('sample_ratio', 1.0))
            );
        }

        async def observability_middleware(
            request: Request, call_next: any
        ) -> Response {
            next_fn: any = call_next;
            if request.url.path in HEALTH_PATHS {
                return await next_fn(request);
            }
            auth_token = set_current_auth(request.headers.get('Authorization'));
            trace_id = ensure_trace_id(
                request.headers.get('X-Trace-Id') or request.request_id
            );
            trace_token = set_current_trace(trace_id);
            span = start_server_span(
                f"{request.method} {request.url.path}",
                trace_id,
                request.headers.get('traceparent'),
                {'http.method': request.method, 'http.target': request.url.path}
            );
            try {
                response = await next_fn(request);
                if trace_id {
                    response.headers.set('X-Trace-Id', trace_id);
                }
                if span is not None {
                    span.set_attribute('http.status_code', response.status_code);
                }
                return response;
            } finally {
                try {
                    end_span(span);
                } except Exception as e {
                    logger.debug(f"failed to end span: {e}");
                }
                reset_current_trace(trace_token);
                reset_current_auth(auth_token);
            }
        }
        server.add_middleware(observability_middleware);
    }
}


obj MetricsExtension(ServerExtension) {
    def register(server: JacAPIServer) -> None {
        import from jaclang.scale.observability.factory { UtilityFactory }
        cfg = get_scale_config().get_monitoring_config();
        collector: MetricsCollector = UtilityFactory.create_metrics(
            'prometheus', cfg, server.resolved_settings().workers.count
        );
        server.metrics = collector;
        server.execution_manager.metrics = collector;
        if not collector.is_enabled() {
            return;
        }
        endpoint = str(cfg.get('endpoint', '/metrics'));
        server.metrics_path = endpoint;
        scrape_password = str(cfg.get('prometheus_admin_password', ''));
        admin_username = str(
            get_scale_config().get_admin_config().get('username', 'admin')
        );
        users = server.user_manager;
        expose: any = collector.get_endpoint_handler();

        def _authorized(request: Request) -> bool {
            authorization = request.headers.get('Authorization') or '';
            if authorization.startswith('Bearer ') {
                user_id = users.validate_jwt_token(authorization[7:]);
                return bool(user_id) and users.is_admin(str(user_id));
            }
            if authorization.startswith('Basic ') and scrape_password {
                try {
                    decoded = base64.b64decode(authorization[6:]).decode('utf-8');
                } except Exception {
                    return False;
                }
                parts: list[str] = decoded.split(':', 1);
                name: str = parts[0];
                secret: str = parts[1] if len(parts) > 1 else '';
                return bool(
                    hmac.compare_digest(
                        name.encode('utf-8'), admin_username.encode('utf-8')
                    )
                )
                    and bool(
                        hmac.compare_digest(
                            secret.encode('utf-8'), scrape_password.encode('utf-8')
                        )
                    );
            }
            return False;
        }

        async def metrics_handler(request: Request) -> Response {
            if not _authorized(request) {
                return JSONResponse(
                    status_code=403,
                    content={
                        'ok': False,
                        'error': {
                            'code': 'FORBIDDEN',
                            'message': 'Admin access required'
                        }
                    }
                );
            }
            return expose();
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.GET,
                path=endpoint,
                callback=metrics_handler,
                parameters=[],
                tags=['Monitoring'],
                summary='Prometheus metrics (admin only)',
                description='Application metrics in Prometheus exposition format. Requires an admin token or the scrape credential.',
                requires_auth=True
            )
        );
        logger.info(f"Prometheus metrics enabled at {endpoint} (admin-only)");
    }

    def on_worker_exit(server: JacAPIServer, pid: int) {
        server.metrics.worker_exited(pid);
    }
}


obj MailExtension(ServerExtension) {
    has emailer: (Emailer | None) = None,
        resolved: bool = False;

    def transport -> Emailer | None {
        if not self.resolved {
            import from jaclang.scale.emailer.factory { create as create_emailer }
            self.emailer = create_emailer(get_scale_config().get_emailer_config());
            self.resolved = True;
        }
        return self.emailer;
    }

    def validate(server: JacAPIServer) -> list[str] {
        mode = server.resolved_settings().auth.email.verification;
        emailer = self.transport();
        if mode == 'none' or (emailer is not None and emailer.is_ready()) {
            return [];
        }
        problem = f"[serve.auth.email] verification = '{mode}' needs a mail "
        "transport, and [scale.emailer] configures none";
        if mode == 'required' {
            return [problem];
        }
        logger.warning(problem + '; verification mail will not be sent');
        return [];
    }

    def register(server: JacAPIServer) {
        server.emailer = self.transport();
    }
}


obj EventsExtension(ServerExtension) {
    has broker: any = None;

    def register(server: JacAPIServer) -> None {
        import from jaclang.scale.events.publisher { set_broker }
        import from jaclang.scale.events.subscriber { get_subscriptions }
        import from jaclang.server.shared_store { scale_db_url }
        cfg = get_scale_config().get_events_config();
        if not cfg.get('enabled', False) {
            return;
        }
        url = cfg.get('url') or scale_db_url();
        validate_events_url(url);
        if url {
            import from jaclang.scale.events.streams.postgres { PgEventStream }
            broker_cfg = dict(cfg);
            broker_cfg['url'] = url;
            self.broker = PgEventStream(config=broker_cfg);
        } else {
            import from jaclang.scale.events.streams.local { LocalEventStream }
            self.broker = LocalEventStream(config=cfg);
            logger.warning(
                "events enabled with no database url; using LocalEventStream "
                "(in-memory, single process). Set events.url or JAC_DB_URL for "
                "cross-process streaming via Postgres."
            );
        }
        set_broker(self.broker);
        for `entry in get_subscriptions() {
            try {
                self.broker.register_handler(
                    `entry.topic,
                    `entry.handler,
                    group=`entry.group,
                    retry=`entry.retry,
                    start_from=`entry.start_from
                );
            } except Exception as e {
                logger.error(f"Failed to register handler for '{`entry.topic}': {e}");
            }
        }
        broker = self.broker;
        async def _stop {
            broker.stop();
        }
        server.add_shutdown_hook(_stop);
    }

    def validate(server: JacAPIServer) -> list[str] {
        import from jaclang.server.shared_store { scale_db_url }
        cfg = get_scale_config().get_events_config();
        settings = server.resolved_settings();
        if cfg.get('enabled', False)
            and settings.workers.multi_process()
            and not (cfg.get('url') or scale_db_url()) {
            return [
                "[scale.events] is enabled with no database url, which keeps events "
                f"inside one process; with {settings.workers.count} workers a "
                "subscriber only sees what its own worker publishes. Set "
                "[scale.events] url or JAC_DB_URL, or run with workers = 1."
            ];
        }
        return [];
    }

    def on_worker_start(server: JacAPIServer) {
        if self.broker is not None {
            self.broker.start();
        }
    }
}


obj AdminExtension(ServerExtension, JacAPIServerAdmin, JacAPIServerLLMTelemetry, JacAPIServerWorkloads, JacAPIServerLogs, JacAPIServerTraces, JacAPIServerOps, JacAPIServerDeployHealth, JacAPIServerNetwork, JacAPIServerPodEnv) {
    def validate(server: JacAPIServer) -> list[str] {
        admin = get_scale_config().get_admin_config();
        password = str(admin.get('default_password') or '');
        if not admin.get('enabled', True)
            or not password
            or os.environ.get(ADMIN_PASSWORD_ENV) {
            return [];
        }
        violations = check_password(password, [str(admin.get('username') or '')]);
        return [
            "[scale.admin] default_password does not meet [serve.auth.password]: "
                + ', '.join([v.value for v in violations])
        ]
            if violations
            else [];
    }

    def register(server: JacAPIServer) -> None {
        if not get_scale_config().get_admin_config().get('enabled', True) {
            return;
        }
        self.server = server;
        self.user_manager = server.user_manager;
        self._metrics = server.metrics;
        self.register_admin_endpoints();
        self.register_llm_telemetry_endpoints();
        self.register_workloads_endpoints();
        self.register_logs_endpoints();
        self.register_traces_endpoints();
        self.register_ops_endpoints();
        self.register_deploy_health_endpoints();
        self.register_network_endpoints();
        self.register_podenv_endpoints();
    }
}


def scale_extensions -> list[ServerExtension] {
    return [
        FleetIdentityExtension(),
        ObservabilityExtension(),
        MetricsExtension(),
        MailExtension(),
        SSOExtension(),
        ApiKeyExtension(),
        WebhookExtension(),
        WebSocketExtension(),
        JobsExtension(),
        EventsExtension(),
        AdminExtension()
    ];
}
