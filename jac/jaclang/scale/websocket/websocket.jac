import asyncio;
import logging;
import time;
import uuid;
import from asyncio { Lock }
import from fastapi { WebSocket, WebSocketDisconnect }
import from inspect { isgenerator }
import from jaclang.scale.websocket.backplane { BaseBackplane, MemoryBackplane }

glob logger = logging.getLogger(__name__),
     _WS_STREAM_STOP: any = object();

obj ConnectionContext {
    has websocket: WebSocket,
        target_kind: str,
        target_name: str,
        conn_id: str = uuid.uuid4().hex,
        user_id: (str | None) = None,
        exp: (float | None) = None,
        rate_tokens: float = 0.0,
        rate_last_refill: float = time.monotonic(),
        last_seen: float = time.monotonic(),
        closed: bool = False;
}

obj WebSocketConnectionManager {
    has _by_target: dict[str, dict[str, ConnectionContext]] = {},
        _by_user: dict[str, int] = {},
        _anon_by_target: dict[str, int] = {},
        _lock: (Lock | None) = None,
        _sub_lock: (Lock | None) = None,
        max_per_target: int = 5000,
        max_per_user: int = 10,
        max_anonymous_per_target: int = 100,
        send_timeout: float = 5.0,
        backplane: (BaseBackplane | None) = None,
        metrics: any = None,
        _subscribed: set[str] = set(),
        _backplane_started: bool = False;

    def _get_lock -> Lock;
    def _get_sub_lock -> Lock;
    def _target_has_connections(target_key: str) -> bool;
    def _get_backplane -> BaseBackplane;
    async def ensure_backplane_started -> None;
    async def shutdown -> None;
    async def ensure_subscribed(target_key: str) -> None;
    async def maybe_unsubscribe(target_key: str) -> None;
    async def _on_backplane_message(channel: str, message: dict) -> None;
    async def _local_fanout(target_key: str, message: dict) -> None;
    async def _release_slot(ctx: ConnectionContext) -> None;
    async def register(ctx: ConnectionContext) -> (str | None);
    async def unregister(ctx: ConnectionContext) -> None;
    async def broadcast_target(
        target_kind: str, target_name: str, message: dict
    ) -> None;

    async def send_to(ctx: ConnectionContext, message: dict) -> bool;
}

def consume_rate_token(
    ctx: ConnectionContext, capacity: float, refill_per_sec: float
) -> bool;

def _ws_stream_next(gen: any) -> any;

async def _ws_stream_result(send_result: any, result: any);
