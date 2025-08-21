"""Websocket Handler."""

from dataclasses import MISSING
from os import getenv
from traceback import format_exception
from typing import Any, Iterable
from uuid import uuid4

from anyio import to_thread
from anyio.abc import TaskGroup

from asyncer import syncify

from broadcaster import Broadcast

from fastapi import APIRouter, WebSocket

from jaclang.runtimelib.machine import JacMachineInterface as Jac

from orjson import dumps, loads

from pydantic import ValidationError

from starlette.websockets import WebSocketDisconnect, WebSocketState

from ...core.archetype import AccessLevel, NodeAnchor, NodeArchetype, Root, WalkerAnchor
from ...core.context import JaseciContext, PUBLIC_ROOT, PUBLIC_ROOT_ID
from ...jaseci.dtos import (
    ChangeUserEvent,
    ChannelEvent,
    ClientEvent,
    ConnectionEvent,
    UserEvent,
    WalkerEvent,
    WebSocketEvent,
)
from ...jaseci.security import authenticate_websocket
from ...jaseci.utils import utc_timestamp

websocket_router = APIRouter(prefix="/websocket", tags=["walker"])
websocket_events: dict[str, dict[str, Any]] = {}


async def send_json(
    self: WebSocket, data: Any, mode: str = "text"  # noqa: ANN401
) -> None:
    """Overide Websocket send_json."""
    if mode not in {"text", "binary"}:
        raise RuntimeError('The "mode" argument should be "text" or "binary".')
    text = dumps(data)
    if mode == "text":
        await self.send({"type": "websocket.send", "text": text.decode()})
    else:
        await self.send({"type": "websocket.send", "bytes": text})


WebSocket.send_json = send_json


class WalkerExecutionError(Exception):
    """Walker Execution Error."""


class WebSocketManager:
    """WebSocket Manager."""

    channel = "replicas"

    def __init__(self) -> None:
        """Initialize."""
        self.instance_id = f"{utc_timestamp()}:{uuid4().hex}"
        self.broadcaster: Broadcast | None = None
        self.user_websockets: dict[NodeAnchor, set[WebSocket]] = {}
        self.channel_websockets: dict[str, set[WebSocket]] = {}
        self.websocket_clients: dict[str, WebSocket] = {}

    async def open_broadcaster(self, task_group: TaskGroup) -> None:
        """Open Broadcaster."""
        if socket_redis_host := getenv("SOCKET_REDIS_HOST"):
            broadcaster = self.broadcaster = Broadcast(socket_redis_host)
            await broadcaster.connect()

            async def run_broadcast_reciever() -> None:
                async with broadcaster.subscribe(channel=self.channel) as sub:
                    while True:
                        try:
                            bc_event = await sub.get()
                            wse = WebSocketEvent(**loads(bc_event.message))

                            if wse.instance_id != self.instance_id:
                                event = wse.event
                                match event:
                                    case UserEvent():
                                        await user_execution(event)
                                    case ChannelEvent():
                                        await channel_execution(event)
                                    case ClientEvent():
                                        await client_execution(event)
                                    case _:
                                        pass
                        except Exception as e:
                            print(format_exception(e))

                await broadcaster.disconnect()
                task_group.cancel_scope.cancel()

            task_group.start_soon(run_broadcast_reciever)

    async def close_broadcaster(self, task_group: TaskGroup) -> None:
        """Close Broadcaster."""
        if self.broadcaster:
            await self.broadcaster.disconnect()

        task_group.cancel_scope.cancel()

    async def broadcast(self, event: WebSocketEvent) -> None:
        """Broadcast to all replicas."""
        if self.broadcaster:
            event.instance_id = self.instance_id
            await self.broadcaster.publish(self.channel, event.model_dump_json())

    async def connect(self, websocket: WebSocket, channel_id: str | None) -> None:
        """Connect Websocket."""
        await websocket.accept()

        root: NodeAnchor = websocket._root  # type: ignore[attr-defined]
        client_id = websocket._client_id = f"{utc_timestamp()}:{uuid4().hex}"  # type: ignore[attr-defined]
        channel_id = websocket._channel_id = (  # type: ignore[attr-defined]
            channel_id or f"{utc_timestamp()}:{uuid4().hex}"
        )

        if root not in self.user_websockets:
            self.user_websockets[root] = set()

        if channel_id not in self.channel_websockets:
            self.channel_websockets[channel_id] = set()

        self.user_websockets[root].add(websocket)
        self.channel_websockets[channel_id].add(websocket)
        self.websocket_clients[client_id] = websocket

        await connection_execution(websocket)

    async def disconnect(self, websocket: WebSocket) -> None:
        """Disconnect Websocket."""
        if websocket.client_state is WebSocketState.CONNECTED:
            await websocket.close()

        root: NodeAnchor = websocket._root  # type: ignore[attr-defined]
        client_id: str = websocket._client_id  # type: ignore[attr-defined]
        channel_id: str = websocket._channel_id  # type: ignore[attr-defined]

        self.websocket_clients.pop(client_id, None)
        self.user_websockets[root].remove(websocket)
        self.channel_websockets[channel_id].remove(websocket)

    async def change_user(self, websocket: WebSocket, token: str | None) -> None:
        """Change User Websocket."""
        root: NodeAnchor = websocket._root  # type: ignore[attr-defined]

        self.user_websockets[root].remove(websocket)

        if not authenticate_websocket(websocket, token):
            websocket._user = None  # type: ignore[attr-defined]
            websocket._root = PUBLIC_ROOT  # type: ignore[attr-defined]

        root = websocket._root  # type: ignore[attr-defined]

        if root not in self.user_websockets:
            self.user_websockets[root] = set()

        self.user_websockets[root].add(websocket)

    def notify_self(self, data: dict) -> None:
        """Notify self client."""
        if isinstance(socket := JaseciContext.get().connection, WebSocket):
            syncify(socket.send_json)(data)

    def notify_clients(self, client_ids: Iterable[str], data: dict) -> None:
        """Notify clients associated with target root."""
        if client_ids:
            for client_id in client_ids:
                if websocket := self.websocket_clients.get(client_id):
                    syncify(websocket.send_json)(data)

            if self.broadcaster:
                syncify(self.broadcaster.publish)(
                    self.channel,
                    WebSocketEvent(
                        instance_id=self.instance_id,
                        event=ClientEvent(client_ids=list(client_ids), data=data),
                    ).model_dump_json(),
                )

    def notify_users(self, roots: Iterable[NodeArchetype], data: dict) -> None:
        """Notify clients associated with target root."""
        if roots:
            root_ids: list[str] = []
            for root in roots:
                root_ids.append((anch := root.__jac__).ref_id)
                if websockets := self.user_websockets.get(anch):
                    for websocket in websockets:
                        syncify(websocket.send_json)(data)
            if self.broadcaster:
                syncify(self.broadcaster.publish)(
                    self.channel,
                    WebSocketEvent(
                        instance_id=self.instance_id,
                        event=UserEvent(root_ids=root_ids, data=data),
                    ).model_dump_json(),
                )

    def notify_channels(self, channel_ids: Iterable[str], data: dict) -> None:
        """Notify clients associated with target root."""
        if channel_ids:
            for channel_id in channel_ids:
                if websockets := self.channel_websockets.get(channel_id):
                    for websocket in websockets:
                        syncify(websocket.send_json)(data)
            if self.broadcaster:
                syncify(self.broadcaster.publish)(
                    self.channel,
                    WebSocketEvent(
                        instance_id=self.instance_id,
                        event=ChannelEvent(channel_ids=list(channel_ids), data=data),
                    ).model_dump_json(),
                )


def walker_execution(websocket: WebSocket, event: WalkerEvent) -> dict:
    """Websocket event sychronizer."""
    if walker_event := websocket_events.get(even_walker := event.walker):
        if walker_event["auth"] and websocket._root == PUBLIC_ROOT:  # type: ignore[attr-defined]
            raise WalkerExecutionError(
                f"Event {even_walker} requires to be authenticated!"
            )
        elif not walker_event["auth"] and websocket._root != PUBLIC_ROOT:  # type: ignore[attr-defined]
            raise WalkerExecutionError(
                f"Event {even_walker} requires to be unauthenticated!"
            )

        walker: type = walker_event["type"]
        try:
            payload = walker_event["model"](**event.context).__dict__
        except ValidationError:
            raise

        jctx = JaseciContext.create(
            websocket, NodeAnchor.ref(event.node) if event.node else None
        )

        wlk: WalkerAnchor = walker(**payload).__jac__
        if Jac.check_read_access(jctx.entry_node):
            Jac.spawn(wlk.archetype, jctx.entry_node.archetype)
            jctx.close()

            if jctx.custom is not MISSING:
                return jctx.custom

            return jctx.response()
        else:
            jctx.close()
            raise WalkerExecutionError(
                f"You don't have access on target entry {jctx.entry_node.ref_id}!"
            )
    else:
        raise WalkerExecutionError("Invalid request! Please use valid walker event!")


async def user_execution(event: UserEvent) -> None:
    """User event execution."""
    for root_id in event.root_ids:
        if websockets := WEBSOCKET_MANAGER.user_websockets.get(NodeAnchor.ref(root_id)):
            for websocket in websockets:
                await websocket.send_json(event.data)


async def channel_execution(event: ChannelEvent) -> None:
    """Channel event execution."""
    for channel_id in event.channel_ids:
        if websockets := WEBSOCKET_MANAGER.channel_websockets.get(channel_id):
            for websocket in websockets:
                await websocket.send_json(event.data)


async def client_execution(event: ClientEvent) -> None:
    """Channel event execution."""
    for client_id in event.client_ids:
        if weboscket := WEBSOCKET_MANAGER.websocket_clients.get(client_id):
            await weboscket.send_json(event.data)


async def connection_execution(websocket: WebSocket) -> None:
    """Websocket connection info."""
    await websocket.send_json(
        {
            "type": "connection",
            "data": {
                "client_id": websocket._client_id,  # type: ignore[attr-defined]
                "root_id": websocket._root.ref_id,  # type: ignore[attr-defined]
                "channel_id": websocket._channel_id,  # type: ignore[attr-defined]
            },
        }
    )


@websocket_router.websocket("")
async def websocket_endpoint(
    websocket: WebSocket, channel_id: str | None = None, auth: str | None = None
) -> None:
    """Websocket Endpoint."""
    if not authenticate_websocket(websocket, auth):
        if not isinstance(
            public_root := NodeAnchor.Collection.find_by_id(PUBLIC_ROOT_ID), NodeAnchor
        ):
            public_root = Root().__jac__
            public_root.id = PUBLIC_ROOT_ID
            public_root.access.all = AccessLevel.WRITE
            public_root.persistent = True
        websocket._root = public_root  # type: ignore[attr-defined]

    await WEBSOCKET_MANAGER.connect(websocket, channel_id)
    while True:
        try:
            wse = WebSocketEvent(event=await websocket.receive_json())
            event = wse.event

            match event:
                case WalkerEvent():
                    resp = await to_thread.run_sync(walker_execution, websocket, event)
                    if event.response:
                        await websocket.send_json(resp)
                case UserEvent():
                    await user_execution(event)
                    await WEBSOCKET_MANAGER.broadcast(wse)
                case ChannelEvent():
                    await channel_execution(event)
                    await WEBSOCKET_MANAGER.broadcast(wse)
                case ClientEvent():
                    await client_execution(event)
                    await WEBSOCKET_MANAGER.broadcast(wse)
                case ConnectionEvent():
                    await connection_execution(websocket)
                case ChangeUserEvent():
                    await WEBSOCKET_MANAGER.change_user(websocket, event.token)
                    await connection_execution(websocket)
                case _:
                    await websocket.send_json({"error": "Not a valid event!"})
        except ValidationError as e:
            await websocket.send_json({"error": e.errors()})
        except WalkerExecutionError as e:
            await websocket.send_json({"type": "walker", "error": str(e)})
        except WebSocketDisconnect:
            await WEBSOCKET_MANAGER.disconnect(websocket)
            break
        except Exception as e:
            match websocket.client_state:
                case WebSocketState.CONNECTED:
                    await websocket.send_json({"error": format_exception(e)})
                case WebSocketState.DISCONNECTED:
                    await WEBSOCKET_MANAGER.disconnect(websocket)
                    break
                case _:
                    pass


WEBSOCKET_MANAGER = WebSocketManager()
