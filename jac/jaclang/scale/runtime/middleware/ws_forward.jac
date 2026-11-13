import asyncio;
import logging;

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


def _to_ws_scheme(url: str) -> str;


def _select_handshake_headers(
    client_headers: dict[str, str], peer: str
) -> dict[str, str];


async def _pump_client_to_upstream(client_ws: any, upstream_ws: any);


async def _pump_upstream_to_client(upstream_ws: any, client_ws: any);


async def websocket_forward(
    client_ws: any,
    upstream_url: str,
    request_headers: dict[str, str],
    timeout: int = 30,
    on_upstream: any = None
) -> None;
