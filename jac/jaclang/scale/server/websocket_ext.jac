import asyncio;
import logging;
import time;
import from inspect { isgenerator }
import from typing { AsyncGenerator }

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
    make_awaitable: any,
    open_scope: Callable[[], RequestScope]
);


obj WebSocketExtension(ServerExtension) {
    has manager: (WebSocketConnectionManager | None) = None;

    def validate(server: JacAPIServer) -> list[str];
    def ws_manager(server: JacAPIServer) -> WebSocketConnectionManager;
    def target_handler(
        server: JacAPIServer,
        target_kind: str,
        target_name: str,
        requires_auth: bool,
        execute: Callable
    ) -> Callable;

    def websocket_targets(server: JacAPIServer) -> list[tuple[str, str]];
    def register(server: JacAPIServer);
}
