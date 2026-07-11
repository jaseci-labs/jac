import logging;
import asyncio;
import from fastapi { WebSocket, WebSocketDisconnect }
import from inspect { isgenerator }

glob logger = logging.getLogger(__name__),
     _WS_STREAM_STOP: any = object();

obj WebSocketConnectionManager {
    has _active_connections: dict[str, list[WebSocket]] = {};

    async def connect(websocket: WebSocket, walker_name: str) {
        await websocket.accept();
        if walker_name not in self._active_connections {
            self._active_connections[walker_name] = [];
        }
        self._active_connections[walker_name].append(websocket);
        logger.info(
            f"WebSocket connected for walker '{walker_name}'. "
            f"Active: {len(self._active_connections[walker_name])}"
        );
    }

    def disconnect(websocket: WebSocket, walker_name: str) {
        if walker_name in self._active_connections {
            self._active_connections[walker_name] = [
                ws
                for ws in self._active_connections[walker_name]
                if ws != websocket
            ];
            logger.info(
                f"WebSocket disconnected for walker '{walker_name}'. "
                f"Active: {len(self._active_connections[walker_name])}"
            );
        }
    }

    def get_connections(walker_name: str) -> list[WebSocket] {
        return self._active_connections.get(walker_name, []);
    }

    async def broadcast(walker_name: str, message: dict) {
        for ws in self.get_connections(walker_name) {
            try {
                await ws.send_json(message);
            } except Exception as e {
                logger.debug(
                    f"WS broadcast send failed for '{walker_name}'; dropping socket: {e}"
                );
                self.disconnect(ws, walker_name);
            }
        }
    }
}

"""Advance a synchronous generator one step off the event-loop thread, returning
the `_WS_STREAM_STOP` sentinel on exhaustion (StopIteration cannot cross an
executor boundary, so it is converted to a sentinel)."""
def _ws_stream_next(gen: any) -> any {
    try {
        return gen.__next__();
    } except StopIteration {
        return _WS_STREAM_STOP;
    }
}

"""Stream a generator target result over the socket as `chunk` frames followed by
a terminating `done` frame. Mirrors the HTTP SSE frame semantics: synchronous
generators are advanced in a worker thread so a slow step does not block the
event loop, and the `done` frame is always sent (carrying the error on failure)
so a client that reads until `done` never hangs."""
async def _ws_stream_result(
    websocket: WebSocket,
    ws_manager: WebSocketConnectionManager,
    target_name: str,
    is_broadcast: bool,
    result: any
) {
    async def emit(frame: dict) {
        if is_broadcast {
            await ws_manager.broadcast(target_name, frame);
        } else {
            await websocket.send_json(frame);
        }
    }
    stream_error: (str | None) = None;
    try {
        if isgenerator(result) {
            loop = asyncio.get_running_loop();
            while True {
                item = await loop.run_in_executor(None, _ws_stream_next, result);
                if item is _WS_STREAM_STOP {
                    break;
                }
                await emit({'ok': True, 'type': 'chunk', 'data': item});
            }
        } else {
            async for item in result {
                await emit({'ok': True, 'type': 'chunk', 'data': item});
            }
        }
    } except WebSocketDisconnect {
        raise;
    } except Exception as e {
        logger.error(f"WS stream error for '{target_name}': {e}");
        stream_error = str(e);
    }
    if stream_error is None {
        await emit({'ok': True, 'type': 'done'});
    } else {
        await emit(
            {
                'ok': False,
                'type': 'done',
                'error': {'code': 'STREAM_ERROR', 'message': stream_error}
            }
        );
    }
}
