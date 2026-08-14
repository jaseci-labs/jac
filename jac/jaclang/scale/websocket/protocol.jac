import asyncio;
import json;
import logging;
import time;
import from typing { Any }
import from jaclang.runtimelib.serving.ws { WebSocket }
import from jaclang.scale.websocket.websocket { ConnectionContext, consume_rate_token }

glob logger = logging.getLogger(__name__),
     WS_CLOSE_UNAUTHORIZED: int = 4401,
     WS_CLOSE_FORBIDDEN: int = 4403,
     WS_CLOSE_IDLE: int = 4408,
     WS_CLOSE_TOO_LARGE: int = 4413,
     WS_CLOSE_UNAVAILABLE: int = 4503,
     HEARTBEAT_SECONDS: float = 30.0,
     HEARTBEAT_MISSED_ALLOWED: int = 2,
     SEND_TIMEOUT_SECONDS: float = 5.0,
     AUTH_HANDSHAKE_TIMEOUT_SECONDS: float = 10.0;

def ws_error_frame(code: str, message: any, reason: any = None) -> dict[str, any];

def _auth_fail(status: str, reason: str) -> dict[str, any];

async def _ws_send_then_close(
    websocket: WebSocket, frame: dict[str, any], close_code: int, close_reason: str
) -> None;

def ws_pre_accept_auth(websocket: WebSocket, user_manager: Any) -> any;

async def ws_reject_pre_accept(websocket: WebSocket, auth_detail: dict[str, any]);

async def ws_authenticate(
    websocket: WebSocket, user_manager: Any, handshake_timeout: float, max_bytes: int
) -> (dict[str, any], dict[str, any] | None);

async def ws_heartbeat_loop(
    ctx: ConnectionContext, heartbeat_seconds: float, missed_allowed: int
) -> None;

async def ws_reject_auth(websocket: WebSocket, auth_detail: dict[str, any]);

async def ws_reject_registration(websocket: WebSocket, rejection: str);

async def ws_receive_frame(
    websocket: WebSocket, max_bytes: int
) -> (str, dict[str, any] | None);

async def ws_handle_control(
    websocket: WebSocket,
    ctx: ConnectionContext,
    data: dict[str, any],
    user_manager: Any,
    requires_auth: bool,
    msgs_per_sec: float,
    rate_capacity: float
) -> str;

async def ws_execute_target(
    websocket: WebSocket, label: str, name: str, awaitable: Any, target_timeout: float
) -> (bool, Any);
