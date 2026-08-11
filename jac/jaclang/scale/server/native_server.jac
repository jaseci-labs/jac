import logging;
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.endpoint { JEndPoint, WSEndPoint }
import from jaclang.runtimelib.serving.server { ACCESS_LOGGER_NAME, ServingServer }


glob logger: logging.Logger = logging.getLogger(__name__);


class ConsoleLogHandler(logging.Handler) {
    def emit(self: ConsoleLogHandler, record: logging.LogRecord) {
        import from jaclang.cli.console { console }
        message = self.format(record);
        console.print(f"  {message}");
    }
}

class HealthCheckFilter(logging.Filter) {
    _SUPPRESSED = {
        '"GET /docs HTTP',
        '"GET / HTTP',
        '"GET /openapi.json HTTP',
        '"GET /health HTTP',
        '"GET /healthz'
    };

    def filter(self: HealthCheckFilter, record: logging.LogRecord) -> bool {
        msg = record.getMessage();
        for pat in self._SUPPRESSED {
            if pat in msg {
                return False;
            }
        }
        return True;
    }
}

def configure_access_logging(suppress_health_checks: bool = False) {
    console_handler = ConsoleLogHandler();
    console_handler.setFormatter(logging.Formatter("%(message)s"));
    if suppress_health_checks {
        console_handler.addFilter(HealthCheckFilter());
    }
    access_logger = logging.getLogger(ACCESS_LOGGER_NAME);
    access_logger.handlers = [console_handler];
    access_logger.setLevel(int(logging.INFO));
    access_logger.propagate = False;
}

obj NativeJServer {
    has app: ServingApp = ServingApp(title='Jac API', version='1.0.0'),
        user_manager: any = None,
        serving: any = None,
        install_drain: bool = True,
        _endpoints: list[JEndPoint] = [],
        _prebound_listen_socket: any = None;

    def postinit {
        import from jaclang.jac0core.runtime { JacRuntime }
        import from jaclang.scale.runtime.lifecycle.drain { build_drain_middleware }
        server = self;

        async def jwt_validation_middleware(request: any, call_next: any) -> any {
            authorization = request.headers.get('Authorization');
            username: (str | None) = None;
            user_root_id: (str | None) = None;
            if authorization
                and isinstance(authorization, str)
                and authorization.startswith('Bearer ') {
                token = authorization[7:];
                if server.user_manager {
                    username = server.user_manager.validate_jwt_token(token);
                    if username {
                        user_root_id = server.user_manager.get_root_id(username);
                    }
                }
            }
            setattr(request.state, 'user_root_id', user_root_id);
            setattr(request.state, 'username', username);
            next_fn: any = call_next;
            return await next_fn(request);
        }

        async def request_context_middleware(request: any, call_next: any) -> any {
            import from jaclang.scale.memory.context { JScaleExecutionContext }
            ctx = JScaleExecutionContext();
            req_token = JacRuntime.push_request_context(ctx);
            import from jaclang.scale.runtime.context.auth_ctx {
                set_current_auth,
                reset_current_auth
            }
            auth_token = set_current_auth(request.headers.get('Authorization'));
            import from jaclang.scale.runtime.context.trace_ctx {
                set_current_trace,
                reset_current_trace,
                ensure_trace_id
            }
            import from jaclang.scale.runtime.context.log_emit {
                install_structured_logging
            }
            install_structured_logging();
            import from jaclang.scale.runtime.context.tracing {
                install_tracing,
                tracing_installed,
                start_server_span,
                end_span
            }
            if not tracing_installed() {
                import from jaclang.scale.config.config_loader { get_scale_config }
                _trc_cfg = get_scale_config().get_microservices_config().get(
                    "tracing", {}
                );
                install_tracing(
                    enabled=_trc_cfg.get("enabled", False),
                    endpoint=_trc_cfg.get("endpoint"),
                    sample_ratio=float(_trc_cfg.get("sample_ratio", 1.0))
                );
            }
            trace_id = ensure_trace_id(request.headers.get('X-Trace-Id'));
            trace_token = set_current_trace(trace_id);
            trace_span = start_server_span(
                f"{request.method} {request.url.path}",
                trace_id,
                request.headers.get("traceparent"),
                {"http.method": request.method, "http.target": request.url.path}
            );
            user_id = request.state?.user_root_id if request?.state else None;
            if user_id {
                root_ref: any = user_id;
                try {
                    await ctx.aset_user_root(root_ref);
                } except ValueError {
                    logger.warning(
                        f"Invalid user_root_id: {user_id}, using system root"
                    );
                }
            }
            try {
                next_fn: any = call_next;
                response = await next_fn(request);
                if trace_id {
                    response.headers["X-Trace-Id"] = trace_id;
                }
                if trace_span is not None {
                    trace_span.set_attribute("http.status_code", response.status_code);
                }
                return response;
            } finally {
                try {
                    JacRuntime.reset_request_context(req_token);
                    ctx.close();
                } except Exception as e {
                    logger.warning(
                        f"Failed to clear request context: {e}", exc_info=True
                    );
                }
                try {
                    reset_current_auth(auth_token);
                } except Exception as e {
                    logger.warning(f"Failed to reset auth context: {e}", exc_info=True);
                }
                try {
                    end_span(trace_span);
                } except Exception as e {
                    logger.warning(f"Failed to end trace span: {e}", exc_info=True);
                }
                try {
                    reset_current_trace(trace_token);
                } except Exception as e {
                    logger.warning(
                        f"Failed to reset trace context: {e}", exc_info=True
                    );
                }
            }
        }
        self.app.add_middleware(request_context_middleware);
        self.app.add_middleware(jwt_validation_middleware);
        if self.install_drain {
            self.app.add_middleware(build_drain_middleware("service"));
        }
    }

    def set_user_manager(user_manager: any) {
        self.user_manager = user_manager;
    }

    def add_endpoint(endpoint: JEndPoint) {
        self._endpoints.append(endpoint);
        self.app.add_endpoint(endpoint);
    }

    def add_ws_endpoint(path: str, handler: any) {
        self.app.add_ws_endpoint(WSEndPoint(path=path, handler=handler));
    }

    def execute { }
    def create_server { }
    def run_server(
        host: str = '0.0.0.0',
        port: int = 8000,
        max_retries: int = 10,
        on_ready: any = None
    ) {
        import from jaclang.scale.config.config_loader { get_scale_config }
        import from jaclang.scale.runtime.lifecycle.drain { install_signal_drain }
        server_cfg = get_scale_config().get_server_config();
        configure_access_logging(
            suppress_health_checks=bool(
                server_cfg.get('suppress_health_check_logs', False)
            )
        );
        ms_cfg = get_scale_config().get_microservices_config();
        drain_timeout = float(ms_cfg.get("drain_timeout_seconds", 10));
        ws_cfg = get_scale_config().get_websocket_config();
        self.serving = ServingServer(
            app=self.app,
            host=host,
            port=port,
            drain_timeout=drain_timeout,
            ws_allowed_origins=[str(o) for o in (ws_cfg.get('allowed_origins') or [])],
            ws_max_message_bytes=int(ws_cfg.get('max_message_bytes') or 0)
        );
        install_signal_drain(self.serving, timeout_s=drain_timeout);
        self.serving.run(on_ready=on_ready, port_retries=max_retries);
    }

    def request_stop {
        if self.serving is not None {
            self.serving.request_stop();
        }
    }
}
