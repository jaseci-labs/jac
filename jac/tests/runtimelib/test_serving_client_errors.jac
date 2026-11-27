"""Tests for the serving client's phase-typed exception taxonomy (#7902).

The client classifies transport failures by request lifecycle phase:
ClientRequestNotSent (provably never left the process, safe to retry) vs
ClientRequestSent / ClientReadTimeout (the peer may have executed the
request, never safe to retry). These tests run against real loopback
sockets so the classification is exercised end to end.
"""

import asyncio;
import socket;
import struct;
import threading;
import time;
import from jaclang.server.serving.client {
    ClientConnectionError,
    ClientRequestNotSent,
    ClientRequestSent,
    ClientReadTimeout,
    arequest,
    request_sync,
    post_stream_aware_sync
}
import from jaclang.server.serving.client {
    IDLE_TIMEOUT,
    MAX_CONNECTION_AGE,
    MAX_IDLE_PER_ORIGIN,
    _PooledConn,
    _idle_pool,
    _release,
    _take_idle
}
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.serving.server { ServingServer }


def _closed_port -> int {
    probe = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    probe.bind(("127.0.0.1", 0));
    port = probe.getsockname()[1];
    probe.close();
    return port;
}


def _start_server(handler: any) -> tuple[any, ...] {
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    srv.bind(("127.0.0.1", 0));
    srv.listen(4);
    port = srv.getsockname()[1];
    held: list[any] = [];

    def serve {
        while True {
            try {
                (conn, _addr) = srv.accept();
            } except OSError {
                return;
            }
            held.append(conn);
            try {
                handler(conn);
            } except OSError {}
        }
    }
    t = threading.Thread(target=serve, daemon=True);
    t.start();
    return (srv, held, port);
}


def _stop_server(srv: any, held: list[any]) {
    try {
        srv.close();
    } except OSError {}
    for conn in held {
        try {
            conn.close();
        } except OSError {}
    }
}


def _deaf(conn: any) {
    conn.recv(65536);
}


def _partial_body_then_reset(conn: any) {
    conn.recv(65536);
    conn.sendall(b"HTTP/1.1 200 OK\r\nContent-Length: 100\r\n\r\npartial");
    conn.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0));
    conn.close();
}


def _http_500(conn: any) {
    conn.recv(65536);
    conn.sendall(
        b"HTTP/1.1 500 Internal Server Error\r\n"
            + b"Content-Type: text/plain\r\n"
            + b"Content-Length: 4\r\n"
            + b"Connection: close\r\n\r\nboom"
    );
    conn.close();
}


def _interim_then_created(conn: any) {
    conn.recv(65536);
    conn.sendall(
        b"HTTP/1.1 100 Continue\r\n\r\n"
            + b"HTTP/1.1 201 Created\r\n"
            + b"Content-Length: 2\r\n\r\nok"
    );
    conn.close();
}


def _multiple_interim_then_created(conn: any) {
    conn.recv(65536);
    conn.sendall(
        b"HTTP/1.1 103 Early Hints\r\nLink: </style.css>; rel=preload\r\n\r\n"
            + b"HTTP/1.1 100 Continue\r\n\r\n"
            + b"HTTP/1.1 201 Created\r\n"
            + b"Content-Length: 2\r\n\r\nok"
    );
    conn.close();
}


def _created(conn: any) {
    conn.recv(65536);
    conn.sendall(b"HTTP/1.1 201 Created\r\n" + b"Content-Length: 2\r\n\r\nok");
    conn.close();
}


def _interim_then_eof(conn: any) {
    conn.recv(65536);
    conn.sendall(b"HTTP/1.1 100 Continue\r\n\r\n");
    conn.close();
}


def _switching_protocols(conn: any) {
    conn.recv(65536);
    conn.sendall(
        b"HTTP/1.1 101 Switching Protocols\r\n"
            + b"Upgrade: websocket\r\n"
            + b"Connection: Upgrade\r\n\r\n"
    );
    conn.close();
}


glob _sse_reset_gate: any = threading.Event();


def _sse_one_event_then_reset(conn: any) {
    conn.recv(65536);
    conn.sendall(
        b"HTTP/1.1 200 OK\r\n"
            + b"Content-Type: text/event-stream\r\n"
            + b"Connection: close\r\n\r\n"
            + b"data: {\"n\": 1}\n\n"
    );
    _sse_reset_gate.`wait(5.0);
    conn.setsockopt(socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0));
    conn.close();
}


def _reply_and_hold(reply: bytes) -> any {
    def handle(conn: any) {
        conn.recv(65536);
        conn.sendall(reply);
    }
    return handle;
}


test "retry-unsafe types are not OSErrors" {
    assert not issubclass(ClientRequestSent, OSError);
    assert not issubclass(ClientRequestNotSent, OSError);
    assert issubclass(ClientReadTimeout, ClientRequestSent);
    assert issubclass(ClientRequestSent, ClientConnectionError);
    assert issubclass(ClientRequestNotSent, ClientConnectionError);
}


async def _pooled_pair(origin: tuple[str, str, int]) -> tuple[any, any] {
    (ours, peer) = socket.socketpair();
    (reader, writer) = await asyncio.open_connection(sock=ours);
    conn = _PooledConn(
        origin=origin, reader=reader, writer=writer, opened=time.monotonic()
    );
    return (conn, peer);
}


async def _pool_outcome(scenario: str) -> tuple[bool, bool] {
    origin = ("http", "svc", 80);
    peers: list[any] = [];
    if scenario == "pool full" {
        for _ in range(MAX_IDLE_PER_ORIGIN) {
            (other, other_peer) = await _pooled_pair(origin);
            peers.append(other_peer);
            _release(other);
        }
    }
    (conn, peer) = await _pooled_pair(origin);
    peers.append(peer);
    if scenario == "too old" {
        conn.opened -= MAX_CONNECTION_AGE;
    }
    _release(conn);
    if scenario == "idle too long" {
        conn.idle_since -= IDLE_TIMEOUT;
    } elif scenario == "unread bytes" {
        peer.sendall(b"x");
    } elif scenario == "peer closed" {
        peer.close();
    }
    await asyncio.sleep(0.05);
    taken = _take_idle(("http", "other", 80) if scenario == "other origin" else origin);
    closed = conn.writer.is_closing();
    leftovers = [conn] + [c for bucket in _idle_pool().values() for c in bucket];
    if taken is not None {
        leftovers.append(taken);
    }
    for c in leftovers {
        c.writer.close();
    }
    for p in peers {
        p.close();
    }
    return (taken is conn, closed);
}


test "the idle pool hands back only clean, recent connections" {
    cases: dict[str, tuple[bool, bool]] = {
        "fresh": (True, False),
        "idle too long": (False, True),
        "too old": (False, True),
        "unread bytes": (False, True),
        "peer closed": (False, True),
        "other origin": (False, False),
        "pool full": (False, True)
    };
    outcomes = {scenario: asyncio.run(_pool_outcome(scenario)) for scenario in cases};
    assert outcomes == cases , outcomes;
}


test "connect refused classifies as ClientRequestNotSent" {
    port = _closed_port();
    caught: any = None;
    try {
        request_sync('POST', f"http://127.0.0.1:{port}/x", json_body={}, timeout=2.0);
    } except ClientRequestNotSent as e {
        caught = e;
    }
    assert caught is not None;
    assert str(caught) != "";
}


test "response-head timeout classifies as ClientReadTimeout with a message" {
    (srv, held, port) = _start_server(_deaf);
    try {
        caught: any = None;
        try {
            request_sync(
                'POST', f"http://127.0.0.1:{port}/x", json_body={}, timeout=1.0
            );
        } except ClientReadTimeout as e {
            caught = e;
        }
        assert caught is not None;
        assert not isinstance(caught, OSError);
        assert "no response head within" in str(caught);
    } finally {
        _stop_server(srv, held);
    }
}


test "connection loss after send classifies as ClientRequestSent" {
    (srv, held, port) = _start_server(_partial_body_then_reset);
    try {
        caught: any = None;
        try {
            request_sync(
                'POST', f"http://127.0.0.1:{port}/x", json_body={}, timeout=2.0
            );
        } except ClientRequestSent as e {
            caught = e;
        }
        assert caught is not None;
        assert not isinstance(caught, ClientRequestNotSent);
        assert str(caught) != "";
    } finally {
        _stop_server(srv, held);
    }
}


test "post_stream_aware_sync preserves ClientReadTimeout across its thread" {
    (srv, held, port) = _start_server(_deaf);
    try {
        caught: any = None;
        try {
            post_stream_aware_sync(
                f"http://127.0.0.1:{port}/x", json_body={}, timeout=1.0
            );
        } except ClientReadTimeout as e {
            caught = e;
        }
        assert caught is not None;
        assert "no response head within" in str(caught);
    } finally {
        _stop_server(srv, held);
    }
}


test "post_stream_aware_sync preserves ClientRequestNotSent on connect failure" {
    port = _closed_port();
    caught: any = None;
    try {
        post_stream_aware_sync(f"http://127.0.0.1:{port}/x", json_body={}, timeout=2.0);
    } except ClientRequestNotSent as e {
        caught = e;
    }
    assert caught is not None;
}


test "post_stream_aware_sync classifies HTTP 500 as ClientRequestSent" {
    (srv, held, port) = _start_server(_http_500);
    try {
        caught: any = None;
        try {
            post_stream_aware_sync(
                f"http://127.0.0.1:{port}/x", json_body={}, timeout=2.0
            );
        } except ClientRequestSent as e {
            caught = e;
        }
        assert caught is not None;
        assert not isinstance(caught, ClientRequestNotSent);
        assert "HTTP 500" in str(caught);
        assert caught.status_code == 500;
    } finally {
        _stop_server(srv, held);
    }
}


test "client skips 100 Continue before a final response" {
    (srv, held, port) = _start_server(_interim_then_created);
    try {
        response = request_sync(
            'POST', f"http://127.0.0.1:{port}/x", data=b"body", timeout=2.0
        );
        assert response.status_code == 201;
        assert response.text() == "ok";
    } finally {
        _stop_server(srv, held);
    }
}


test "client skips multiple informational responses before a final response" {
    (srv, held, port) = _start_server(_multiple_interim_then_created);
    try {
        response = request_sync(
            'POST', f"http://127.0.0.1:{port}/x", data=b"body", timeout=2.0
        );
        assert response.status_code == 201;
        assert response.text() == "ok";
    } finally {
        _stop_server(srv, held);
    }
}


test "client preserves a final response without informational responses" {
    (srv, held, port) = _start_server(_created);
    try {
        response = request_sync(
            'POST', f"http://127.0.0.1:{port}/x", data=b"body", timeout=2.0
        );
        assert response.status_code == 201;
        assert response.text() == "ok";
    } finally {
        _stop_server(srv, held);
    }
}


test "client reports EOF after an informational response" {
    (srv, held, port) = _start_server(_interim_then_eof);
    try {
        caught: any = None;
        try {
            request_sync(
                'POST', f"http://127.0.0.1:{port}/x", data=b"body", timeout=2.0
            );
        } except ClientRequestSent as e {
            caught = e;
        }
        assert caught is not None;
        assert "bad status line" in str(caught);
    } finally {
        _stop_server(srv, held);
    }
}


test "client treats 101 Switching Protocols as terminal" {
    (srv, held, port) = _start_server(_switching_protocols);
    try {
        response = request_sync('GET', f"http://127.0.0.1:{port}/x", timeout=2.0);
        assert response.status_code == 101;
    } finally {
        _stop_server(srv, held);
    }
}


test "mid-stream connection loss raises from the consumer's iterator" {
    _sse_reset_gate.clear();
    (srv, held, port) = _start_server(_sse_one_event_then_reset);
    try {
        (kind, gen) = post_stream_aware_sync(
            f"http://127.0.0.1:{port}/x", json_body={}, timeout=2.0
        );
        assert kind == 'sse';
        it = iter(gen);
        got: list[any] = [next(it)];
        _sse_reset_gate.set();
        raised: any = None;
        try {
            for item in it {
                got.append(item);
            }
        } except RuntimeError as e {
            raised = e;
        }
        assert raised is not None , got;
        assert "raised" in str(raised) , str(raised);
        assert got == [{"n": 1}] , got;
    } finally {
        _sse_reset_gate.set();
        _stop_server(srv, held);
    }
}


test "bodiless responses end at the head" {
    cases: list[tuple[str, str, bytes, int]] = [
        (
            "HEAD with a length",
            "HEAD",
            b"HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\n",
            200
        ),
        (
            "304 with a length",
            "GET",
            b"HTTP/1.1 304 Not Modified\r\nContent-Length: 5\r\n\r\n",
            304
        ),
        ("204 without framing", "GET", b"HTTP/1.1 204 No Content\r\n\r\n", 204)
    ];
    failures: list[str] = [];
    for (name, method, reply, status) in cases {
        (srv, held, port) = _start_server(_reply_and_hold(reply));
        try {
            resp: any = asyncio.run(
                asyncio.wait_for(
                    arequest(method, f"http://127.0.0.1:{port}/x", timeout=2.0),
                    timeout=3.0
                )
            );
            if resp.status_code != status or resp.body != b"" {
                failures.append(f"{name}: {resp.status_code} {resp.body!r}");
            }
        } except asyncio.TimeoutError {
            failures.append(f"{name}: client kept waiting for a body");
        } finally {
            _stop_server(srv, held);
        }
    }
    assert not failures , "\n".join(failures);
}


def _pong -> dict[str, any] {
    return {"ok": True};
}


def _large -> str {
    return "x" * 100000;
}


def _app -> ServingApp {
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path="/ping", callback=_pong));
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path="/large", callback=_large));
    return app;
}


async def _shelves_after(
    port: int, method: str, path: str, mode: str
) -> tuple[list[int], list[list[int]]] {
    statuses: list[int] = [];
    seen: list[any] = [];
    shelves: list[list[int]] = [];
    for i in range(2) {
        resp: any = await arequest(
            method,
            f"http://127.0.0.1:{port}{path}",
            headers={"Connection": "close"} if mode == "close" and i == 1 else None,
            timeout=5.0,
            stream=mode in ("stream", "partial"),
            keep_alive=mode != "off"
        );
        if mode in ("stream", "partial") {
            async for _ in resp.aiter_raw() {
                if mode == "partial" {
                    break;
                }
            }
            await resp.aclose();
        }
        statuses.append(resp.status_code);
        bucket = _idle_pool().get(("http", "127.0.0.1", port), []);
        seen.extend(
            conn
            for conn in bucket
            if all(conn is not s for s in seen)
        );
        shelves.append([[s is conn for s in seen].index(True) for conn in bucket]);
    }
    for conn in seen {
        conn.writer.close();
    }
    return (statuses, shelves);
}


test "the client reuses a connection only after a complete keep-alive reply" {
    cases: list[tuple[str, str, str, str, int, list[list[int]]]] = [
        ("body read in full", "GET", "/ping", "body", 0, [[0], [0]]),
        ("HEAD reply", "HEAD", "/ping", "body", 0, [[0], [0]]),
        ("stream read to the end", "GET", "/ping", "stream", 0, [[0], [0]]),
        ("stream closed early", "GET", "/large", "partial", 0, [[], []]),
        ("server closes at its budget", "GET", "/ping", "body", 2, [[0], []]),
        ("caller asks to close", "GET", "/ping", "close", 0, [[0], [0]]),
        ("keep-alive not requested", "GET", "/ping", "off", 0, [[], []])
    ];
    failures: list[str] = [];
    for (name, method, path, mode, budget, shelves) in cases {
        server = ServingServer(
            app=_app(), host="127.0.0.1", port=0, request_budget=budget
        );
        stop = server.serve_background();
        try {
            outcome: any = asyncio.run(
                _shelves_after(server.bound_port, method, path, mode)
            );
            if outcome != ([200, 200], shelves) {
                failures.append(f"{name}: got {outcome!r}, expected {shelves!r}");
            }
        } finally {
            try {
                stop();
            } except RuntimeError {}
        }
    }
    assert not failures , "\n".join(failures);
}
