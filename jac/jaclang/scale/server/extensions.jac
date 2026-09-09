import base64;
import hmac;
import logging;
import from jaclang.server.identity.audit { client_ip, emit as audit }
import from jaclang.server.identity.auth_models {
    ForgotPasswordRequest,
    SendVerificationRequest
}
import from jaclang.server.identity.auth_tokens { AuthTokenStore }
import from jaclang.server.middleware { require_user }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.serving.datatypes { JSONResponse, Request, Response }
import from jaclang.server.serving.drain { HEALTH_PATHS }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.transport { Meta, TransportResponse }
import from jaclang.scale.admin.admin_portal { JacAPIServerAdmin }
import from jaclang.scale.admin.deploy_health { JacAPIServerDeployHealth }
import from jaclang.scale.admin.llm_telemetry { JacAPIServerLLMTelemetry }
import from jaclang.scale.admin.logs { JacAPIServerLogs }
import from jaclang.scale.admin.network { JacAPIServerNetwork }
import from jaclang.scale.admin.ops { JacAPIServerOps }
import from jaclang.scale.admin.podenv { JacAPIServerPodEnv }
import from jaclang.scale.admin.traces { JacAPIServerTraces }
import from jaclang.scale.admin.workloads { JacAPIServerWorkloads }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.emailer.emailer { Emailer }
import from jaclang.scale.observability.metrics { MetricsCollector }
import from jaclang.scale.state.factory { get_state_backend }
import from jaclang.scale.state.state_backend { StateBackend }
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
        collector: MetricsCollector = UtilityFactory.create_metrics('prometheus', cfg);
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
}


obj RecoveryMailExtension(ServerExtension) {
    has emailer: (Emailer | None) = None,
        state: (StateBackend | None) = None;

    def _limiter(
        kind: str, rate_per_hour: float, burst: float
    ) -> Callable[[str], tuple[bool, float]] {
        backend = self.state;
        window = 3600;
        allowance = max(1, int(burst));

        def consume(key: str) -> tuple[bool, float] {
            if backend is None or rate_per_hour <= 0 {
                return (True, 0.0);
            }
            count = backend.increment(
                f"ratelimit:{kind}:{key}", 1.0, ttl_seconds=window
            );
            if count <= allowance {
                return (True, 0.0);
            }
            return (False, float(window));
        }
        return consume;
    }

    def register(server: JacAPIServer) {
        import from jaclang.scale.emailer.factory { create as create_emailer }
        emailer_cfg = get_scale_config().get_emailer_config();
        self.emailer = create_emailer(emailer_cfg);
        server.emailer = self.emailer;
        settings = server.resolved_settings();
        self.state = get_state_backend(shared=settings.workers.multi_process());
        auth_cfg = get_scale_config().get_auth_config();
        verify_limit = self._limiter(
            'send_verification',
            float(auth_cfg.get('send_verification_rate_per_hour', 5)),
            float(auth_cfg.get('send_verification_burst', 5))
        );
        forgot_limit = self._limiter(
            'forgot_password',
            float(auth_cfg.get('forgot_password_rate_per_hour', 3)),
            float(auth_cfg.get('forgot_password_burst', 3))
        );
        users = server.user_manager;
        ext = self;

        def _fail(
            code: str, message: str, status: int, extra: (dict | None) = None
        ) -> TransportResponse {
            meta_extra: dict[str, any] = {'http_status': status};
            if extra {
                meta_extra.update(extra);
            }
            return TransportResponse.fail(
                code=code, message=message, meta=Meta(extra=meta_extra)
            );
        }
        def _ok(data: dict[str, any], status: int = 200) -> TransportResponse {
            return TransportResponse.success(
                data=data, meta=Meta(extra={'http_status': status})
            );
        }
        def _link_token(
            user_id: str, purpose: str, identity_value: str, ttl: int, template: str
        ) -> str {
            store = AuthTokenStore.instance();
            store.revoke_user_tokens(user_id, purpose);
            token = store.create_token(
                user_id=user_id,
                purpose=purpose,
                ttl_seconds=ttl,
                identity_value=identity_value
            );
            return template.replace('{token}', token) if template else token;
        }
        def _mail_body(action: str, link: str, ttl: int, footer: str = '') -> str {
            return (
                f"Hello,\n\nUse the link below to {action}:\n\n{link}\n\n"
                f"This link expires in {ttl // 60} minutes.\n\n"
                f"If you did not request this, you can ignore this message{footer}."
            );
        }

        async def send_verification(
            request: Request, body_data: SendVerificationRequest
        ) -> TransportResponse {
            (user_id, auth_err) = require_user(request);
            if auth_err is not None {
                return auth_err;
            }
            identity: dict[str, any] = body_data.identity.model_dump(mode='json');
            raw_value: str = str(identity.get('value', '') or '');
            normalized: str = raw_value.lower().strip();
            if not normalized {
                return _fail('VALIDATION_ERROR', 'Identity value is required', 400);
            }
            if identity.get('type') != 'email' {
                return _fail(
                    'VALIDATION_ERROR', 'Only email identities can be verified', 400
                );
            }
            user = users.get_user(str(user_id));
            if user is None {
                return _fail('NOT_FOUND', 'User not found', 404);
            }
            target: (dict | None) = None;
            for ident in user.get('identities', []) {
                if ident.get('type') == 'email'
                    and (ident.get('value_normalized') or '') == normalized {
                    target = ident;
                    break;
                }
            }
            if target is None {
                return _fail('NOT_FOUND', 'Identity not found on this user', 404);
            }
            if target.get('verified') {
                return _ok({'status': 'already_verified'});
            }
            (allowed, retry_after) = verify_limit(str(user_id));
            if not allowed {
                audit(
                    'identity_verification.rate_limited',
                    user_id=user_id,
                    identity_value=normalized,
                    source_ip=client_ip(request),
                    retry_after_seconds=int(retry_after) + 1
                );
                return _fail(
                    'RATE_LIMITED',
                    'Too many verification requests, please try again later',
                    429,
                    extra={'retry_after_seconds': int(retry_after) + 1}
                );
            }
            emailer = ext.emailer;
            if emailer is None or not emailer.is_ready() {
                return _fail(
                    'EMAIL_DISABLED',
                    'Email features are not configured on this server',
                    503
                );
            }
            ttl = int(auth_cfg.get('verify_token_ttl_seconds', 86400));
            link = _link_token(
                str(user_id),
                'verify',
                normalized,
                ttl,
                str(auth_cfg.get('verify_url_template', ''))
            );
            sent = emailer.send_email(
                to_addr=target.get('value_raw') or raw_value,
                subject='Verify your email address',
                body_text=_mail_body('verify your email address', link, ttl)
            );
            return _ok(
                {'status': 'pending_verification', 'email_sent': bool(sent)}, status=202
            );
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path='/user/send-verification',
                callback=send_verification,
                request_model=SendVerificationRequest,
                tags=['User APIs'],
                summary='Send a verification email for an unverified identity',
                description='Issues a verification token for an email identity on the authenticated user and mails it. Idempotent for verified identities.',
                requires_auth=True
            )
        );

        async def forgot_password(
            request: Request, body_data: ForgotPasswordRequest
        ) -> TransportResponse {
            ok_response = _ok(
                {
                    'status': 'ok',
                    'message': 'If that account exists, a reset link has been sent.'
                }
            );
            identity: dict[str, any] = body_data.identity.model_dump(mode='json');
            normalized: str = str(identity.get('value', '') or '').lower().strip();
            if not normalized {
                return ok_response;
            }
            emailer = ext.emailer;
            if emailer is None or not emailer.is_ready() {
                logger.warning(
                    '/user/forgot-password called but no emailer is configured'
                );
                return ok_response;
            }
            user = users.find_user_by_identity(normalized);
            if user is None {
                return ok_response;
            }
            recipient_raw: (str | None) = None;
            recipient_normalized: (str | None) = None;
            for ident in user.get('identities', []) {
                if ident.get('type') != 'email' or not ident.get('verified') {
                    continue;
                }
                if ident.get('is_recovery') {
                    recipient_raw = ident.get('value_raw');
                    recipient_normalized = ident.get('value_normalized');
                    break;
                }
                if recipient_raw is None {
                    recipient_raw = ident.get('value_raw');
                    recipient_normalized = ident.get('value_normalized');
                }
            }
            if not recipient_raw {
                return ok_response;
            }
            (allowed, retry_after) = forgot_limit(recipient_normalized or '');
            if not allowed {
                audit(
                    'password_reset.rate_limited',
                    user_id=user.get('user_id', ''),
                    identity_value=recipient_normalized,
                    source_ip=client_ip(request),
                    retry_after_seconds=int(retry_after) + 1
                );
                return ok_response;
            }
            ttl = int(auth_cfg.get('reset_token_ttl_seconds', 1800));
            link = _link_token(
                str(user.get('user_id', '')),
                'reset',
                recipient_normalized or '',
                ttl,
                str(auth_cfg.get('reset_url_template', ''))
            );
            sent = emailer.send_email(
                to_addr=recipient_raw,
                subject='Reset your password',
                body_text=_mail_body(
                    'reset your password',
                    link,
                    ttl,
                    footer=', your password will remain unchanged'
                )
            );
            audit(
                'password_reset.requested',
                user_id=user.get('user_id', ''),
                identity_value=recipient_normalized,
                source_ip=client_ip(request),
                email_sent=bool(sent)
            );
            return ok_response;
        }
        server.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path='/user/forgot-password',
                callback=forgot_password,
                request_model=ForgotPasswordRequest,
                tags=['User APIs'],
                summary='Start a password reset flow',
                description="Mails a reset link to the account's recovery email when the account exists. Always answers 200."
            )
        );
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
        RecoveryMailExtension(),
        SSOExtension(),
        ApiKeyExtension(),
        WebhookExtension(),
        WebSocketExtension(),
        JobsExtension(),
        EventsExtension(),
        AdminExtension()
    ];
}
