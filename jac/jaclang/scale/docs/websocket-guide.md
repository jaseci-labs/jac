# WebSocket Guide

Jac Scale provides built-in support for WebSocket endpoints, enabling real-time bidirectional communication between clients and your walkers or functions. This guide explains how to create WebSocket targets, connect from clients, authenticate, and handle the message protocol.

## Overview

WebSockets allow persistent, full-duplex connections between a client and your Jac application. Unlike REST endpoints (single request-response), a WebSocket connection stays open, allowing multiple messages to be exchanged in both directions. Jac Scale provides:

- **Dedicated `/ws/` endpoints** for WebSocket walkers and functions
- **Persistent connections** with a message loop
- **JSON message protocol** for sending target fields and receiving results
- **JWT authentication** via a query parameter or the first message frame
- **Connection limits**, per-message size caps, and per-connection rate limiting
- **Heartbeat** with idle close, and a `refresh` control message for long-lived sessions
- **Streaming** responses for generator targets
- **Broadcast** fan-out across workers via an in-process or Redis backplane
- **HMR support** in dev mode for live reloading

## 1. Creating WebSocket Targets

Use the `@restspec(protocol=APIProtocol.WEBSOCKET)` decorator on an `async walker` or a `def`.

### Basic WebSocket Walker (Public)

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
async walker : pub EchoMessage {
    has message: str;
    has client_id: str = "anonymous";

    async can echo with Root entry {
        report {
            "echo": self.message,
            "client_id": self.client_id
        };
    }
}
```

This walker is accessible at `ws://localhost:8000/ws/walker/EchoMessage`.

### WebSocket Function

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
def:pub ws_echo(message: str, client_id: str = "anonymous") -> dict {
    return {"echo": message, "client_id": client_id};
}
```

This function is accessible at `ws://localhost:8000/ws/function/ws_echo`. Omit `:pub` to require JWT authentication.

### Authenticated WebSocket Walker

Omit `: pub` to require JWT authentication:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
async walker SecureChat {
    has message: str;

    async can respond with Root entry {
        report {"echo": self.message, "authenticated": True};
    }
}
```

### Broadcasting WebSocket Walker

Use `broadcast=True` to send each result to ALL connected clients of that target:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET, broadcast=True)
async walker : pub ChatRoom {
    has message: str;
    has sender: str = "anonymous";

    async can handle with Root entry {
        report {
            "type": "message",
            "sender": self.sender,
            "content": self.message
        };
    }
}
```

Broadcasts are delivered through a backplane, so with the Redis backplane they reach clients connected to *any* worker, not just the one that handled the message.

### Streaming WebSocket Target

A generator target streams its results as `chunk` frames followed by a terminating `done` frame:

```jac
@restspec(protocol=APIProtocol.WEBSOCKET)
def:pub ws_stream(count: int = 3) -> Generator {
    def stream -> Generator {
        for i in range(count) {
            yield {"index": i, "label": f"chunk-{i}"};
        }
    }
    return stream();
}
```

The client receives one `chunk` frame per yielded item, then a single `done` frame.

## 2. Routes

| Target | Canonical route | Legacy route |
|--------|-----------------|--------------|
| walker | `ws://host/ws/walker/{walker_name}` | `ws://host/ws/{walker_name}` |
| function | `ws://host/ws/function/{func_name}` | none |

The legacy `/ws/{walker_name}` route is still registered for backwards compatibility.

WebSocket targets are **not** reachable over their HTTP route and are **not** included in the OpenAPI schema.

## 3. Authentication

Public targets (`: pub`) need no token. For authenticated targets, send the JWT one of two ways.

**Query parameter** (simplest for browsers, which cannot set headers on an upgrade):

```
ws://localhost:8000/ws/walker/SecureChat?token=<JWT>
```

An invalid token is rejected during the handshake, before the socket is accepted, so the client sees a refused upgrade.

> **Tradeoff:** a token in the URL is recorded verbatim in uvicorn/nginx access logs. If you treat access logs as sensitive, prefer first-frame auth and suppress WS upgrade lines from your access logs.

**First message frame** (no token in the URL):

```json
{"token": "<JWT>"}
```

Send this as the very first frame. Any other keys in that frame are treated as the first request payload. A bad token gets an `UNAUTHORIZED` error frame followed by close code `4401`.

The connection is authenticated **once**, at the handshake. A `token` key on later frames is ignored (and stripped before the target runs), so clients written against the older per-message auth keep working.

### Keeping a session alive past token expiry

When the token expires, the connection is closed with `4401` / `expired`, within one heartbeat interval even if the client is idle. To stay connected, send a `refresh` control frame with a new token *before* the old one expires:

```json
{"type": "refresh", "token": "<new JWT>"}
```

The server replies `{"type": "refreshed", "ok": true}`. The refreshed token must belong to the same user, or the connection is closed with `identity_mismatch`.

## 4. Message Protocol

### Client to server

| Frame | Meaning |
|-------|---------|
| `{...target fields}` | Run the target once with these fields |
| `{"type": "ping"}` | Liveness check; server replies with `pong` |
| `{"type": "pong"}` | Reply to a server `ping` |
| `{"type": "refresh", "token": "..."}` | Replace the connection's token |

Every frame, including control frames, is charged against the connection's rate limit.

### Server to client

| Frame | Meaning |
|-------|---------|
| `{"ok": true, "data": {...}}` | Successful single result |
| `{"ok": true, "type": "chunk", "data": {...}}` | One item of a streamed result |
| `{"ok": true, "type": "done"}` | Stream finished successfully |
| `{"ok": false, "type": "done", "error": {...}}` | Stream failed partway |
| `{"ok": false, "error": {"code": ..., "message": ..., "reason": ...}}` | Error |
| `{"type": "ping", "ts": ...}` | Heartbeat |
| `{"type": "pong", "ts": ...}` | Reply to a client `ping` |
| `{"type": "refreshed", "ok": true}` | Token refresh accepted |

A streamed response always ends with a `done` frame, carrying the error if one occurred, so a client that reads until `done` never hangs.

### Error codes

| Code | Meaning |
|------|---------|
| `UNAUTHORIZED` | Missing, invalid, expired, or unknown-user token |
| `CAPACITY` | A connection limit was reached |
| `SERVICE_UNAVAILABLE` | The broadcast backplane could not be subscribed |
| `RATE_LIMITED` | Too many messages per second |
| `MESSAGE_TOO_LARGE` | Frame exceeded `max_message_bytes` |
| `INVALID_PAYLOAD` | Frame was not a JSON object |
| `EXECUTION_TIMEOUT` | Target exceeded `target_timeout_seconds` |
| `EXECUTION_ERROR` | Target returned an error |
| `STREAM_ERROR` | Generator target raised partway through streaming |
| `INTERNAL_ERROR` | Unhandled server error |

### Close codes

| Code | Meaning |
|------|---------|
| `4401` | Unauthorized: bad token, expired token, or failed refresh |
| `4403` | Forbidden: a connection cap was reached |
| `4408` | Idle timeout, or the server could not deliver within the send timeout |
| `4413` | Message exceeded the size limit |
| `4503` | Broadcast backplane unavailable; retry later |

## 5. Configuration

Tune limits and the broadcast backplane under `[scale.websocket]` in `jac.toml`:

```toml
[scale.websocket]
max_connections_per_target = 5000   # live connections allowed per target
max_connections_per_user = 10       # live connections allowed per authenticated user
max_anonymous_per_target = 100      # live connections allowed per target, unauthenticated
max_message_bytes = 65536           # per-frame size cap, in wire bytes
messages_per_second = 20            # per-connection token-bucket rate limit
target_timeout_seconds = 30         # per-message execution timeout
backplane = "redis"                 # "memory" (default) or "redis"
redis_url = "redis://localhost:6379"
```

`backplane` selects broadcast fan-out:

- **`memory`** (default) keeps broadcasts inside one worker. Correct for a single-process deployment; with multiple workers, a client only sees broadcasts produced by the worker it happens to be connected to.
- **`redis`** publishes broadcasts over Redis pub/sub so every worker delivers them to its own clients. Required for any multi-worker deployment that uses `broadcast=True`.

`messages_per_second` and `target_timeout_seconds` accept fractional values (`0.5`, `1.5`). Every limit must be **greater than zero**; none of them treat `0` as "unlimited", and a zero would wedge the connection rather than loosen it (a `messages_per_second` of `0` leaves the token bucket with nothing to refill it, so the socket is rate-limited forever after its first message). A non-positive or non-numeric value is rejected at startup. To effectively disable a limit, set it high.

If `backplane` is unset but a `redis_url` is configured (here or under `[scale.database]`), Redis is selected automatically.

## 6. Important Notes

- WebSocket walkers **must** be declared as `async walker`
- Use `: pub` for public access, or omit it to require JWT auth
- `broadcast=True` is only valid with the `WEBSOCKET` protocol
- Each incoming JSON frame triggers one target execution
- Frames must be JSON **objects**; anything else draws `INVALID_PAYLOAD`
- The connection stays open until the client disconnects, the token expires, the idle timeout fires, or a limit is breached
- The server pings every 30s and closes a connection idle for more than 90s
