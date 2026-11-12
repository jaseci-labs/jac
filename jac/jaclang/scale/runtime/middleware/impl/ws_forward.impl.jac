impl _to_ws_scheme(url: str) -> str {
    if url.startswith("http://") {
        return "ws://" + url[7:];
    }
    if url.startswith("https://") {
        return "wss://" + url[8:];
    }
    return url;
}

impl _select_handshake_headers(
    client_headers: dict[str, str], peer: str
) -> dict[str, str] {
    out: dict[str, str] = {};
    xff: list[str] = [];
    for (k, v) in client_headers.items() {
        lk = k.lower();
        if lk in _WS_HOP_BY_HOP {
            continue;
        }
        if lk == "x-forwarded-for" {
            xff.append(v);
            continue;
        }
        if lk in ("authorization", "x-trace-id") {
            out[k] = v;
        }
    }
    offered: str = client_headers.get("sec-websocket-protocol", "")
        or client_headers.get("Sec-WebSocket-Protocol", "");
    if offered {
        out["Sec-WebSocket-Protocol"] = offered;
    }
    out["X-Forwarded-For"] = ", ".join(xff + [peer]);
    return out;
}

impl _pump_client_to_upstream(
    client_ws: any, upstream_ws: any, session_guard: any = None
) {
    try {
        while True {
            frame = await client_ws.receive();
            if frame.get("type", "") == "websocket.disconnect" {
                break;
            }
            if not await _forward_session_current(client_ws, session_guard, frame) {
                break;
            }
            if "text" in frame and frame["text"] is not None {
                await upstream_ws.send_text(frame["text"]);
            } elif "bytes" in frame and frame["bytes"] is not None {
                await upstream_ws.send_bytes(frame["bytes"]);
            }
        }
    } except Exception as e {
        _logger.debug(f"ws: client->upstream pump ended: {e}");
    }
}

impl _pump_upstream_to_client(
    upstream_ws: any, client_ws: any, session_guard: any = None
) {
    try {
        while True {
            frame = await upstream_ws.receive();
            if frame.get("type", "") == "websocket.disconnect" {
                break;
            }
            if not await _forward_session_current(client_ws, session_guard) {
                break;
            }
            if "text" in frame and frame["text"] is not None {
                await client_ws.send_text(frame["text"]);
            } elif "bytes" in frame and frame["bytes"] is not None {
                await client_ws.send_bytes(frame["bytes"]);
            }
        }
    } except Exception as e {
        _logger.debug(f"ws: upstream->client pump ended: {e}");
    }
}

impl websocket_forward(
    client_ws: any,
    upstream_url: str,
    request_headers: dict[str, str],
    timeout: int = 30,
    on_upstream: any = None,
    session_guard: any = None
) -> None {
    if not await _forward_session_current(client_ws, session_guard) {
        return;
    }
    ws_url: str = _to_ws_scheme(upstream_url);
    peer: str = client_ws.client_host or "unknown";
    hs_headers: dict[str, str] = _select_handshake_headers(request_headers, peer);
    try {
        upstream_ws = await aws_connect(
            ws_url, headers=hs_headers, timeout=float(timeout)
        );
    } except (ClientConnectionError, OSError) as e {
        _logger.error(f"ws: upstream handshake failed: {e}");
        try {
            await client_ws.close(code=1011);
        } except Exception {}
        return;
    }
    try {
        if on_upstream is not None {
            ready: any = on_upstream;
            await ready(upstream_ws.subprotocol);
        }
        if session_guard is None {
            await asyncio.gather(
                _pump_client_to_upstream(client_ws, upstream_ws),
                _pump_upstream_to_client(upstream_ws, client_ws),
                return_exceptions=True
            );
        } else {
            tasks = [
                asyncio.create_task(
                    _pump_client_to_upstream(client_ws, upstream_ws, session_guard)
                ),
                asyncio.create_task(
                    _pump_upstream_to_client(upstream_ws, client_ws, session_guard)
                ),
                asyncio.create_task(_watch_forward_session(client_ws, session_guard))
            ];
            try {
                await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED);
            } finally {
                for task in tasks {
                    task.cancel();
                }
                await asyncio.gather(*tasks, return_exceptions=True);
            }
        }
    } finally {
        try {
            await upstream_ws.close();
        } except Exception {}
        try {
            await client_ws.close();
        } except Exception {}
    }
}


impl _forward_session_current(
    client_ws: any,
    session_guard: any,
    frame: (dict[str, any] | None) = None,
    force: bool = False
) -> bool {
    if session_guard is None {
        return True;
    }
    try {
        if await session_guard(frame, force=force) {
            return True;
        }
    } except Exception as e {
        _logger.warning(f"ws: forwarded session check failed: {e}");
    }
    try {
        await client_ws.close(code=WS_CLOSE_UNAUTHORIZED, reason='revoked');
    } except Exception {}
    return False;
}

impl _watch_forward_session(client_ws: any, session_guard: any) {
    while True {
        await asyncio.sleep(SESSION_RECHECK_SECONDS);
        if not await _forward_session_current(client_ws, session_guard, force=True) {
            return;
        }
    }
}
