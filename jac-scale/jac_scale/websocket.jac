"""WebSocket support for Jac Scale.

This module provides WebSocket connection management for walkers
configured with @restspec(protocol=APIProtocol.WEBSOCKET).
"""
import logging;
import from fastapi { WebSocket }

glob logger = logging.getLogger(__name__);

"""Manages active WebSocket connections, keyed by walker name."""
obj WebSocketConnectionManager {
    has _active_connections: dict[str, list[WebSocket]] = {};

    """Accept and track a new WebSocket connection for a walker."""
    async def connect(websocket: WebSocket, walker_name: str) -> None {
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

    """Remove a WebSocket connection for a walker."""
    def disconnect(websocket: WebSocket, walker_name: str) -> None {
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

    """Get all active connections for a walker."""
    def get_connections(walker_name: str) -> list[WebSocket] {
        return self._active_connections.get(walker_name, []);
    }

    """Broadcast a message to all connections for a walker."""
    async def broadcast(walker_name: str, message: dict) -> None {
        for ws in self.get_connections(walker_name) {
            await ws.send_json(message);
        }
    }
}
