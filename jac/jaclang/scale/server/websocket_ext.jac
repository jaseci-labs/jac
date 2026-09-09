import asyncio;
import logging;
import time;
import from inspect { isgenerator }
import from typing { AsyncGenerator }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.runtime.builtin { APIProtocol }
import from jaclang.server.server { JacAPIServer, ServerExtension }
import from jaclang.server.serving.datatypes { WebSocketDisconnect }
import from jaclang.server.serving.ws { WebSocket }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.websocket.backplane { MemoryBackplane, build_backplane }
import from jaclang.scale.websocket.protocol {
    AUTH_HANDSHAKE_TIMEOUT_SECONDS,
    HEARTBEAT_MISSED_ALLOWED,
    HEARTBEAT_SECONDS,
    SEND_TIMEOUT_SECONDS,
    ws_authenticate,
    ws_error_frame,
    ws_execute_target,
    ws_handle_control,
    ws_heartbeat_loop,
    ws_pre_accept_auth,
    ws_receive_frame,
    ws_reject_auth,
    ws_reject_pre_accept,
    ws_reject_registration
}
import from jaclang.scale.websocket.websocket {
    ConnectionContext,
    WebSocketConnectionManager,
    _ws_stream_result
}

glob logger: logging.Logger = logging.getLogger(__name__);


async def serve_ws_connection(
    websocket: WebSocket,
    ws_manager: WebSocketConnectionManager,
    user_manager: any,
    requires_auth: bool,
    target_kind: str,
    target_name: str,
    is_broadcast: bool,
    label: str,
    max_bytes: int,
    target_timeout: float,
    msgs_per_sec: float,
    make_awaitable: any
) {
    rate_capacity = max(msgs_per_sec, 1.0);
    user_id: (str | None) = None;
    token_exp: (float | None) = None;
    first_data: (dict | None) = None;
    pre_auth: (dict | None) = None;
    if requires_auth {
        pre_auth = ws_pre_accept_auth(websocket, user_manager);
        if pre_auth is not None and pre_auth['status'] != 'ok' {
            await ws_reject_pre_accept(websocket, pre_auth);
            return;
        }
    }
    await websocket.accept();
    if requires_auth {
        if pre_auth is not None {
            user_id = pre_auth.get('user_id');
            token_exp = pre_auth.get('exp');
        } else {
            (auth_detail, first_data) = await ws_authenticate(
                websocket, user_manager, AUTH_HANDSHAKE_TIMEOUT_SECONDS, max_bytes
            );
            if auth_detail['status'] != 'ok' {
                await ws_reject_auth(websocket, auth_detail);
                return;
            }
            user_id = auth_detail.get('user_id');
            token_exp = auth_detail.get('exp');
        }
    }
    ctx = ConnectionContext(
        websocket=websocket,
        target_kind=target_kind,
        target_name=target_name,
        user_id=user_id,
        exp=token_exp,
        rate_tokens=rate_capacity
    );
    rejection = await ws_manager.register(ctx);
    if rejection {
        await ws_reject_registration(websocket, rejection);
        return;
    }
    heartbeat_task = asyncio.create_task(
        ws_heartbeat_loop(ctx, HEARTBEAT_SECONDS, HEARTBEAT_MISSED_ALLOWED)
    );
    async def send_result(payload: dict) {
        if is_broadcast {
            await ws_manager.broadcast_target(target_kind, target_name, payload);
        } else {
            await websocket.send_json(payload);
        }
    }
    try {
        while True {
            if first_data {
                data = first_data;
                first_data = None;
            } else {
                (status, data) = await ws_receive_frame(websocket, max_bytes);
                if status == 'close' {
                    break;
                }
                if status == 'skip' {
                    continue;
                }
            }
            ctx.last_seen = time.monotonic();
            control = await ws_handle_control(
                websocket,
                ctx,
                data,
                user_manager,
                requires_auth,
                msgs_per_sec,
                rate_capacity
            );
            if control == 'break' {
                break;
            }
            if control == 'continue' {
                continue;
            }
            data.pop('token', None);
            (ok, result) = await ws_execute_target(
                websocket,
                label,
                target_name,
                make_awaitable(data, (ctx.user_id or Con.GUEST.value)),
                target_timeout
            );
            if not ok {
                continue;
            }
            if isgenerator(result) or isinstance(result, AsyncGenerator) {
                await _ws_stream_result(send_result, result);
            } elif isinstance(result, dict) and 'error' in result {
                await websocket.send_json(
                    ws_error_frame(
                        'EXECUTION_ERROR',
                        result.get('error', f"{label} execution failed")
                    )
                );
            } else {
                await send_result({'ok': True, 'data': result});
            }
        }
    } except WebSocketDisconnect {
        logger.debug(f"WS client disconnected conn_id={ctx.conn_id}");
    } except Exception as e {
        logger.error(
            f"WS error {label.lower()}='{target_name}' conn_id={ctx.conn_id}: {e}"
        );
    } finally {
        heartbeat_task.cancel();
        try {
            await heartbeat_task;
        } except Exception as e {
            logger.debug(f"WS heartbeat cleanup exception: {e}");
        }
        await ws_manager.unregister(ctx);
    }
}


obj WebSocketExtension(ServerExtension) {
    has manager: (WebSocketConnectionManager | None) = None;

    def validate(server: JacAPIServer) -> list[str] {
        settings = server.resolved_settings();
        if not settings.workers.multi_process() {
            return [];
        }
        has_ws = any(
            server.introspector.walker_protocol(n) == APIProtocol.WEBSOCKET
            for n in server.get_walkers()
        )
            or any(
                server.introspector.function_protocol(n) == APIProtocol.WEBSOCKET
                for n in server.get_functions()
            );
        if not has_ws {
            return [];
        }
        try {
            backplane = build_backplane(get_scale_config().get_websocket_config());
        } except ValueError as e {
            return [str(e)];
        }
        if isinstance(backplane, MemoryBackplane) {
            return [
                f"[scale.websocket] backplane resolves to 'memory', which keeps "
                f"broadcasts inside one process; with {settings.workers.count} workers "
                "a client only sees what its own worker publishes. Set backplane = "
                "'pg' (and a database URL), or run with workers = 1."
            ];
        }
        return [];
    }

    def ws_manager(server: JacAPIServer) -> WebSocketConnectionManager {
        if self.manager is None {
            ws_cfg = get_scale_config().get_websocket_config();
            manager = WebSocketConnectionManager(
                max_per_target=int(ws_cfg['max_connections_per_target']),
                max_per_user=int(ws_cfg['max_connections_per_user']),
                max_anonymous_per_target=int(ws_cfg['max_anonymous_per_target']),
                send_timeout=SEND_TIMEOUT_SECONDS,
                backplane=build_backplane(ws_cfg),
                metrics=server.metrics
            );
            self.manager = manager;
            async def _shutdown {
                await manager.shutdown();
            }
            server.add_shutdown_hook(_shutdown);
        }
        return self.manager;
    }

    def target_handler(
        server: JacAPIServer,
        target_kind: str,
        target_name: str,
        target: any,
        requires_auth: bool,
        execute: Callable
    ) -> Callable {
        ws_manager = self.ws_manager(server);
        ws_cfg = get_scale_config().get_websocket_config();
        restspec: any = target.restspec if target?.restspec else None;
        is_broadcast: bool = bool(restspec.broadcast) if restspec?.broadcast else False;
        user_manager = server.user_manager;
        settings = server.resolved_settings();
        max_bytes = settings.websocket.max_message_bytes
            or int(ws_cfg['max_message_bytes']);

        async def websocket_handler(websocket: WebSocket) {
            def make_awaitable(data: dict, user: str) -> any {
                return execute(target, data, user);
            }
            await serve_ws_connection(
                websocket,
                ws_manager,
                user_manager,
                requires_auth,
                target_kind,
                target_name,
                is_broadcast,
                target_kind.capitalize(),
                max_bytes,
                float(ws_cfg['target_timeout_seconds']),
                float(ws_cfg['messages_per_second']),
                make_awaitable
            );
        }
        return websocket_handler;
    }

    def register(server: JacAPIServer) {
        for walker_name in list(server.get_walkers()) {
            if server.introspector.walker_protocol(walker_name)
                != APIProtocol.WEBSOCKET {
                continue;
            }
            handler = self.target_handler(
                server,
                'walker',
                walker_name,
                server.get_walkers()[walker_name],
                server.introspector.is_auth_required_for_walker(walker_name),
                server.execution_manager.spawn_walker
            );
            server.add_ws_endpoint(f"/ws/walker/{walker_name}", handler);
            server.add_ws_endpoint(f"/ws/{walker_name}", handler);
        }
        for func_name in list(server.get_functions()) {
            if server.introspector.function_protocol(func_name)
                != APIProtocol.WEBSOCKET {
                continue;
            }
            handler = self.target_handler(
                server,
                'function',
                func_name,
                server.get_functions()[func_name],
                server.introspector.is_auth_required_for_function(func_name),
                server.execution_manager.execute_function
            );
            server.add_ws_endpoint(f"/ws/function/{func_name}", handler);
        }
    }
}
