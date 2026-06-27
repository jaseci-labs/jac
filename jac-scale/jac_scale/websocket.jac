import logging;
import from fastapi { WebSocket }

glob logger = logging.getLogger(__name__);

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
            await ws.send_json(message);
        }
    }
}
