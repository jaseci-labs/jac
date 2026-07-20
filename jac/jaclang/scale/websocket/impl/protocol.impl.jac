impl ws_error_frame(code: str, message: any, reason: any = None) -> dict {
    err: dict = {'code': code, 'message': message};
    if reason {
        err['reason'] = reason;
    }
    return {'ok': False, 'error': err};
}

impl _auth_fail(status: str, reason: str) -> dict {
    return {'status': status, 'user_id': None, 'exp': None, 'reason': reason};
}

impl _ws_send_then_close(
    websocket: WebSocket, frame: dict, close_code: int, close_reason: str
) -> None {
    try {
        await websocket.send_json(frame);
    } except Exception as e {
        logger.debug(f"WS reject send ignored: {e}");
    }
    try {
        await websocket.close(code=close_code, reason=close_reason);
    } except Exception as e {
        logger.debug(f"WS close after reject failed: {e}");
    }
}

impl ws_pre_accept_auth(websocket: WebSocket, user_manager: Any) -> any {
    query_token = websocket.query_params.get('token');
    if not query_token {
        return None;
    }
    return user_manager.validate_jwt_token_detail(query_token);
}

impl ws_reject_pre_accept(websocket: WebSocket, auth_detail: dict) {
    status = auth_detail.get('status', 'invalid');
    try {
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED, reason=str(status));
    } except Exception as e {
        logger.debug(f"WS pre-accept close failed: {e}");
    }
}

impl ws_authenticate(
    websocket: WebSocket, user_manager: Any, handshake_timeout: float, max_bytes: int
) -> (dict, dict | None) {
    try {
        raw = await asyncio.wait_for(
            websocket.receive_text(), timeout=handshake_timeout
        );
    } except asyncio.TimeoutError {
        return (_auth_fail('missing', 'Auth handshake timed out'), None);
    }
    if len(str(raw).encode()) > max_bytes {
        return (_auth_fail('invalid', 'Handshake payload too large'), None);
    }
    try {
        first_data = json.loads(raw);
    } except Exception {
        return (_auth_fail('invalid', 'Handshake payload is not valid JSON'), None);
    }
    if not isinstance(first_data, dict) {
        return (_auth_fail('invalid', 'Handshake payload must be a JSON object'), None);
    }
    token = first_data.pop('token', None);
    return (user_manager.validate_jwt_token_detail(token), first_data);
}

impl ws_heartbeat_loop(
    ctx: ConnectionContext, heartbeat_seconds: float, missed_allowed: int
) -> None {
    try {
        while not ctx.closed {
            await asyncio.sleep(heartbeat_seconds);
            if ctx.closed {
                break;
            }
            if ctx.exp is not None and time.time() >= float(ctx.exp) {
                logger.info(f"WS expiry close conn_id={ctx.conn_id}; token expired");
                try {
                    await ctx.websocket.close(
                        code=WS_CLOSE_UNAUTHORIZED, reason='expired'
                    );
                } except Exception as e {
                    logger.debug(f"WS expiry close failed: {e}");
                }
                ctx.closed = True;
                break;
            }
            now = time.monotonic();
            max_idle = heartbeat_seconds * float(missed_allowed + 1);
            if now - ctx.last_seen > max_idle {
                logger.info(
                    f"WS idle close conn_id={ctx.conn_id}; "
                    f"no message for {now - ctx.last_seen:.1f}s"
                );
                try {
                    await ctx.websocket.close(
                        code=WS_CLOSE_IDLE, reason='idle_timeout'
                    );
                } except Exception as e {
                    logger.debug(f"WS idle close failed: {e}");
                }
                ctx.closed = True;
                break;
            }
            try {
                await asyncio.wait_for(
                    ctx.websocket.send_json({'type': 'ping', 'ts': time.time()}),
                    timeout=SEND_TIMEOUT_SECONDS
                );
            } except asyncio.TimeoutError {
                logger.info(
                    f"WS ping send timed out conn_id={ctx.conn_id}; closing connection"
                );
                try {
                    await ctx.websocket.close(
                        code=WS_CLOSE_IDLE, reason='send_timeout'
                    );
                } except Exception as close_err {
                    logger.debug(f"WS close after ping timeout failed: {close_err}");
                }
                ctx.closed = True;
                break;
            } except Exception as e {
                logger.debug(f"WS ping send failed conn_id={ctx.conn_id}: {e}");
                break;
            }
        }
    } except asyncio.CancelledError {
        return;
    }
}

impl ws_reject_auth(websocket: WebSocket, auth_detail: dict) {
    status = auth_detail.get('status', 'invalid');
    message_map = {
        'missing': 'Invalid or missing token',
        'expired': 'Token expired',
        'invalid': 'Invalid or missing token',
        'unknown_user': 'User associated with token no longer exists'
    };
    msg = message_map.get(str(status), 'Invalid or missing token');
    reason = auth_detail.get('reason') or msg;
    await _ws_send_then_close(
        websocket,
        ws_error_frame('UNAUTHORIZED', msg, reason),
        WS_CLOSE_UNAUTHORIZED,
        str(status)
    );
}

impl ws_reject_registration(websocket: WebSocket, rejection: str) {
    if rejection == 'subscribe_unavailable' {
        await _ws_send_then_close(
            websocket,
            ws_error_frame(
                'SERVICE_UNAVAILABLE', 'Broadcast backplane unavailable', rejection
            ),
            WS_CLOSE_UNAVAILABLE,
            rejection
        );
        return;
    }
    await _ws_send_then_close(
        websocket,
        ws_error_frame('CAPACITY', 'Connection limit reached', rejection),
        WS_CLOSE_FORBIDDEN,
        rejection
    );
}

impl ws_receive_frame(websocket: WebSocket, max_bytes: int) -> (str, dict | None) {
    raw = await websocket.receive_text();
    if len(raw.encode()) > max_bytes {
        await websocket.send_json(
            ws_error_frame('MESSAGE_TOO_LARGE', f'Message exceeds {max_bytes} bytes')
        );
        await websocket.close(code=WS_CLOSE_TOO_LARGE, reason='message_too_large');
        return ('close', None);
    }
    try {
        data = json.loads(raw);
    } except Exception as parse_err {
        await websocket.send_json(
            ws_error_frame(
                'INVALID_PAYLOAD', 'Payload is not valid JSON', str(parse_err)
            )
        );
        return ('skip', None);
    }
    if not isinstance(data, dict) {
        await websocket.send_json(
            ws_error_frame('INVALID_PAYLOAD', 'Payload must be a JSON object')
        );
        return ('skip', None);
    }
    return ('ok', data);
}

impl ws_handle_control(
    websocket: WebSocket,
    ctx: ConnectionContext,
    data: dict,
    user_manager: Any,
    requires_auth: bool,
    msgs_per_sec: float,
    rate_capacity: float
) -> str {
    if not consume_rate_token(ctx, rate_capacity, msgs_per_sec) {
        await websocket.send_json(
            ws_error_frame(
                'RATE_LIMITED', f'Rate limit exceeded ({msgs_per_sec:g} msg/s)'
            )
        );
        return 'continue';
    }
    ctrl_type = data.get('type');
    if ctrl_type == 'pong' {
        return 'continue';
    }
    if ctrl_type == 'ping' {
        await websocket.send_json({'type': 'pong', 'ts': time.time()});
        return 'continue';
    }
    if ctrl_type == 'refresh' {
        if not requires_auth {
            return 'continue';
        }
        detail = user_manager.validate_jwt_token_detail(data.get('token'));
        if detail['status'] != 'ok' {
            await websocket.send_json(
                ws_error_frame(
                    'UNAUTHORIZED', 'Token refresh failed', detail.get('reason')
                )
            );
            await websocket.close(
                code=WS_CLOSE_UNAUTHORIZED, reason=str(detail['status'])
            );
            return 'break';
        }
        if detail.get('user_id') != ctx.user_id {
            await websocket.send_json(
                ws_error_frame(
                    'UNAUTHORIZED', 'Token refresh failed', 'identity_mismatch'
                )
            );
            await websocket.close(
                code=WS_CLOSE_UNAUTHORIZED, reason='identity_mismatch'
            );
            return 'break';
        }
        refreshed_uid = detail.get('user_id');
        refreshed_exp = detail.get('exp');
        ctx.user_id = str(refreshed_uid) if refreshed_uid is not None else None;
        ctx.exp = (
            float(refreshed_exp) if isinstance(refreshed_exp, (int, float)) else None
        );
        await websocket.send_json({'type': 'refreshed', 'ok': True});
        return 'continue';
    }
    if requires_auth and ctx.exp is not None and time.time() >= float(ctx.exp) {
        await websocket.send_json(
            ws_error_frame(
                'UNAUTHORIZED', 'Token expired; send a refresh message', 'expired'
            )
        );
        await websocket.close(code=WS_CLOSE_UNAUTHORIZED, reason='expired');
        return 'break';
    }
    return 'proceed';
}

impl ws_execute_target(
    websocket: WebSocket, label: str, name: str, awaitable: Any, target_timeout: float
) -> (bool, Any) {
    try {
        result = await asyncio.wait_for(awaitable, timeout=target_timeout);
        return (True, result);
    } except asyncio.TimeoutError {
        await websocket.send_json(
            ws_error_frame(
                'EXECUTION_TIMEOUT',
                f"{label} '{name}' timed out after {target_timeout:g}s"
            )
        );
        return (False, None);
    } except Exception as e {
        logger.error(f"WS {label.lower()} execution error '{name}': {e}");
        await websocket.send_json(ws_error_frame('INTERNAL_ERROR', str(e)));
        return (False, None);
    }
}
