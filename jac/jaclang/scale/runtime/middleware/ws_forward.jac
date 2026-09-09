import asyncio;
import logging;
import from jaclang.server.serving.client { ClientConnectionError, aws_connect }

glob _logger = logging.getLogger(__name__),
     _WS_HOP_BY_HOP: set[str] = {
         "host",
         "connection",
         "upgrade",
         "sec-websocket-key",
         "sec-websocket-version",
         "sec-websocket-extensions",
         "sec-websocket-protocol",
         "sec-websocket-accept",
         "transfer-encoding",
         "keep-alive"
     };


def _to_ws_scheme(url: str) -> str {
    if url.startswith("http://") {
        return "ws://" + url[7:];
    }
    if url.startswith("https://") {
        return "wss://" + url[8:];
    }
    return url;
}


def _select_handshake_headers(
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


async def _pump_client_to_upstream(client_ws: any, upstream_ws: any) {
    try {
        while True {
            frame = await client_ws.receive();
            if frame.get("type", "") == "websocket.disconnect" {
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


async def _pump_upstream_to_client(upstream_ws: any, client_ws: any) {
    try {
        while True {
            frame = await upstream_ws.receive();
            if frame.get("type", "") == "websocket.disconnect" {
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


async def websocket_forward(
    client_ws: any,
    upstream_url: str,
    request_headers: dict[str, str],
    timeout: int = 30,
    on_upstream: any = None
) -> None {
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
    if on_upstream is not None {
        ready: any = on_upstream;
        await ready(upstream_ws.subprotocol);
    }
    try {
        await asyncio.gather(
            _pump_client_to_upstream(client_ws, upstream_ws),
            _pump_upstream_to_client(upstream_ws, client_ws),
            return_exceptions=True
        );
    } finally {
        try {
            await upstream_ws.close();
        } except Exception {}
        try {
            await client_ws.close();
        } except Exception {}
    }
}
