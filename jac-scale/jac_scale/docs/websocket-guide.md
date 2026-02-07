# WebSocket Guide

Jac Scale provides built-in support for WebSocket endpoints, enabling real-time bidirectional communication between clients and walkers. This guide explains how to create WebSocket walkers, connect from clients, and handle the message protocol.

## Overview

WebSockets allow persistent, full-duplex connections between a client and your Jac application. Unlike REST endpoints (single request-response), a WebSocket connection stays open, allowing multiple messages to be exchanged in both directions. Jac Scale provides:

- **Dedicated `/ws/` endpoints** for WebSocket walkers
- **Persistent connections** with a message loop
- **JSON message protocol** for sending walker fields and receiving results
- **JWT authentication** via query parameter or message payload
- **Connection management** with automatic cleanup on disconnect
- **HMR support** in dev mode for live reloading

## 1. Creating WebSocket Walkers

To create a WebSocket endpoint, use the `@restspec(protocol=APIProtocol.WEBSOCKET)` decorator on an `async walker` definition.

### Basic WebSocket Walker (Public)

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
async walker : pub EchoMessage {
    has message: str;
    has client_id: str = "anonymous";

    async can echo with `root entry {
        report {
            "echo": self.message,
            "client_id": self.client_id
        };
    }
}
```

This walker will be accessible at `ws://localhost:8000/ws/EchoMessage`.

### Minimal WebSocket Walker

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
async walker : pub PingPong {
    async can pong with `root entry {
        report {"status": "pong"};
    }
}
```

### Authenticated WebSocket Walker

Omit `: pub` to require JWT authentication:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
async walker SecureChat {
    has message: str;

    async can respond with `root entry {
        report {"echo": self.message, "authenticated": True};
    }
}
```

### Broadcasting WebSocket Walker

Use `broadcast=True` to send messages to ALL connected clients of this walker:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET, broadcast=True)
async walker : pub ChatRoom {
    has message: str;
    has sender: str = "anonymous";

    async can handle with `root entry {
        report {
            "type": "message",
            "sender": self.sender,
            "content": self.message
        };
    }
}
```

When a client sends a message, **all connected clients** receive the response, making it ideal for:

- Chat rooms
- Live notifications
- Real-time collaboration
- Game state synchronization

### Private Broadcasting Walker

Combine authentication with broadcasting for secure group communication:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET, broadcast=True)
async walker TeamChat {
    has message: str;
    has room: str = "general";

    async can handle with `root entry {
        report {
            "room": self.room,
            "content": self.message,
            "authenticated": True
        };
    }
}
```

Only authenticated users can connect and send messages, and all authenticated users receive broadcasts.

### Important Notes

- WebSocket walkers **must** be declared as `async walker`
- Use `: pub` for public access (no authentication required) or omit it to require JWT auth
- Use `broadcast=True` to send responses to ALL connected clients (only valid with WEBSOCKET protocol)
- WebSocket walkers are **only** accessible via `ws://host/ws/{walker_name}`
- They are **not** accessible via the standard `/walker/{walker_name}` HTTP endpoint
- They are **not** included in the OpenAPI schema
- Each incoming JSON message triggers a new walker execution
- The connection stays open until the client disconnects
