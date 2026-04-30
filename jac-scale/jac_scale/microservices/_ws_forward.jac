"""WebSocket bidirectional proxy for the gateway (ROADMAP P15).

Upstream handshake forwards Authorization + X-Trace-Id + X-Forwarded-For
only; aiohttp manages its own WS handshake headers (Upgrade, Sec-*).
"""

import logging;
import aiohttp;
import asyncio;
import from typing { Any }

glob _logger = logging.getLogger(__name__),
     _WS_HOP_BY_HOP: set[str] = {"host","connection","upgrade","sec-websocket-key","sec-websocket-version","sec-websocket-extensions","sec-websocket-protocol","sec-websocket-accept","transfer-encoding","keep-alive"};


def _to_ws_scheme(url: str) -> str {
    if url.startswith("http://") {
        return "ws://" + url[7:];
    }
    if url.startswith("https://") {
        return "wss://" + url[8:];
    }
    return url;
}


"""Only forward auth + trace + XFF; drop cookies and hop-by-hops so
we don't leak client-hop state into the service."""
def _select_handshake_headers(client_headers: dict[str, str]) -> dict[str, str] {
    out: dict[str, str] = {};
    for (k, v) in client_headers.items() {
        lk = k.lower();
        if lk in _WS_HOP_BY_HOP {
            continue;
        }
        if lk in ("authorization", "x-trace-id", "x-forwarded-for") {
            out[k] = v;
        }
    }
    return out;
}


async def _pump_client_to_upstream(client_ws: Any, upstream_ws: Any) {
    try {
        while True {
            frame = await client_ws.receive();
            if frame.get("type", "") == "websocket.disconnect" {
                break;
            }
            if "text" in frame and frame["text"] is not None {
                await upstream_ws.send_str(frame["text"]);
            } elif "bytes" in frame and frame["bytes"] is not None {
                await upstream_ws.send_bytes(frame["bytes"]);
            }
        }
    } except Exception as e {
        _logger.debug(f"ws: client->upstream pump ended: {e}");
    }
}


async def _pump_upstream_to_client(upstream_ws: Any, client_ws: Any) {
    try {
        async for msg in upstream_ws {
            if msg.type == aiohttp.WSMsgType.TEXT {
                await client_ws.send_text(msg.data);
            } elif msg.type == aiohttp.WSMsgType.BINARY {
                await client_ws.send_bytes(msg.data);
            } elif msg.type in (
                aiohttp.WSMsgType.CLOSE,
                aiohttp.WSMsgType.CLOSED,
                aiohttp.WSMsgType.CLOSING
            ) {
                break;
            } elif msg.type == aiohttp.WSMsgType.ERROR {
                _logger.warning(f"ws: upstream error: {upstream_ws.exception()}");
                break;
            }
        }
    } except Exception as e {
        _logger.debug(f"ws: upstream->client pump ended: {e}");
    }
}


"""Caller must have called `client_ws.accept()` already. Closes both
sockets when either side ends."""
async def websocket_forward(
    client_ws: Any,
    upstream_url: str,
    request_headers: dict[str, str],
    timeout: int = 30
) -> None {
    ws_url: str = _to_ws_scheme(upstream_url);
    hs_headers: dict[str, str] = _select_handshake_headers(request_headers);
    session = aiohttp.ClientSession(
        timeout=aiohttp.ClientTimeout(total=None, sock_connect=timeout)
    );
    try {
        try {
            upstream_ws = await session.ws_connect(ws_url, headers=hs_headers);
        } except (aiohttp.ClientError, aiohttp.WSServerHandshakeError, OSError) as e {
            _logger.error(f"ws: upstream handshake failed: {e}");
            try {
                await client_ws.close(code=1011);
            } except Exception {
                ;
            }
            return;
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
            } except Exception {
                ;
            }
            try {
                await client_ws.close();
            } except Exception {
                ;
            }
        }
    } finally {
        try {
            await session.close();
        } except Exception {
            ;
        }
    }
}
