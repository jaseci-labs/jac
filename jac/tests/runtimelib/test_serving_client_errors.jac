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
import from jaclang.server.serving.client {
    ClientConnectionError,
    ClientRequestNotSent,
    ClientRequestSent,
    ClientReadTimeout,
    arequest,
    request_sync,
    post_stream_aware_sync
}


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


def _recv_request(conn: any, pending: bytearray) -> (str | None) {
    while b"\r\n\r\n" not in pending {
        data = conn.recv(65536);
        if not data {
            return None;
        }
        pending.extend(data);
    }
    (head, _, rest) = bytes(pending).partition(b"\r\n\r\n");
    text = head.decode("latin-1").lower();
    length = 0;
    for line in text.split("\r\n")[1:] {
        (name, _, value) = line.partition(":");
        if name.strip() == "content-length" {
            length = int(value.strip());
        }
    }
    while len(rest) < length {
        data = conn.recv(65536);
        if not data {
            return None;
        }
        rest += data;
    }
    pending.clear();
    pending.extend(rest[length:]);
    return text;
}


def _keep_alive(reply: bytes, drop_reused: bool = False) -> any {
    def handle(conn: any) {
        pending = bytearray();
        served = 0;
        while True {
            head = _recv_request(conn, pending);
            if head is None or (drop_reused and served == 1) {
                conn.close();
                return;
            }
            conn.sendall(reply);
            served += 1;
        }
    }
    return handle;
}


async def _send_each(port: int, methods: list[str], mode: str) -> list[any] {
    outcomes: list[any] = [];
    headers = {"Connection": "close"} if mode == "close" else None;
    for method in methods {
        try {
            resp = await arequest(
                method,
                f"http://127.0.0.1:{port}/x",
                headers=headers,
                data=b"{}",
                timeout=2.0,
                stream=mode in ("stream", "partial")
            );
            if mode == "stream" {
                blocks: list[bytes] = [];
                async for block in resp.aiter_raw() {
                    blocks.append(block);
                }
                await resp.aclose();
                outcomes.append(b"".join(blocks));
            } elif mode == "partial" {
                async for _ in resp.aiter_raw() {
                    break;
                }
                await resp.aclose();
                outcomes.append("partial");
            } else {
                outcomes.append(resp.body);
            }
        } except ClientConnectionError as e {
            outcomes.append(type(e));
        }
    }
    return outcomes;
}


glob _OK: bytes = b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nok";


test "connection reuse follows the response framing" {
    cases: list[tuple[str, bytes, bool, list[str], str, list[any], int]] = [
        ("content-length", _OK, False, ["GET", "GET", "GET"], "body", [b"ok"] * 3, 1),
        (
            "chunked",
            b"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nok\r\n0\r\n\r\n",
            False,
            ["GET", "GET", "GET"],
            "body",
            [b"ok"] * 3,
            1
        ),
        (
            "bodiless 204",
            b"HTTP/1.1 204 No Content\r\n\r\n",
            False,
            ["GET", "GET", "GET"],
            "body",
            [b""] * 3,
            1
        ),
        (
            "interim 100 continue",
            b"HTTP/1.1 100 Continue\r\n\r\n" + _OK,
            False,
            ["GET", "GET", "GET"],
            "body",
            [b"ok"] * 3,
            1
        ),
        (
            "streamed to the end",
            _OK,
            False,
            ["GET", "GET", "GET"],
            "stream",
            [b"ok"] * 3,
            1
        ),
        (
            "stream closed after one block",
            b"HTTP/1.1 200 OK\r\nContent-Length: 100000\r\n\r\n" + b"x" * 100000,
            False,
            ["GET", "GET"],
            "partial",
            ["partial"] * 2,
            2
        ),
        (
            "connection close",
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok",
            False,
            ["GET", "GET"],
            "body",
            [b"ok"] * 2,
            2
        ),
        (
            "connection close after keep-alive",
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n"
                + b"Connection: keep-alive\r\nConnection: close\r\n\r\nok",
            False,
            ["GET", "GET"],
            "body",
            [b"ok"] * 2,
            2
        ),
        ("request asked to close", _OK, False, ["GET", "GET"], "close", [b"ok"] * 2, 2),
        (
            "content-length overrun",
            b"HTTP/1.1 200 OK\r\nContent-Length: 2\r\n\r\nokEXTRA",
            False,
            ["GET", "GET"],
            "body",
            [b"ok"] * 2,
            2
        ),
        (
            "dead pooled GET is retried",
            _OK,
            True,
            ["GET", "GET"],
            "body",
            [b"ok"] * 2,
            2
        ),
        (
            "dead pooled POST is not replayed",
            _OK,
            True,
            ["GET", "POST"],
            "body",
            [b"ok", ClientRequestSent],
            1
        ),
        (
            "dead pooled PUT is not replayed",
            _OK,
            True,
            ["GET", "PUT"],
            "body",
            [b"ok", ClientRequestSent],
            1
        ),
        (
            "dead pooled DELETE is not replayed",
            _OK,
            True,
            ["GET", "DELETE"],
            "body",
            [b"ok", ClientRequestSent],
            1
        )
    ];
    failures: list[str] = [];
    for (name, reply, drop_reused, methods, mode, expected, connections) in cases {
        (srv, held, port) = _start_server(_keep_alive(reply, drop_reused));
        try {
            outcomes = asyncio.run(_send_each(port, methods, mode));
            if outcomes != expected or len(held) != connections {
                failures.append(
                    f"{name}: outcomes={outcomes!r} connections={len(held)}, "
                    f"expected {expected!r} over {connections}"
                );
            }
        } finally {
            _stop_server(srv, held);
        }
    }
    assert not failures , "\n".join(failures);
}


test "retry-unsafe types are not OSErrors" {
    assert not issubclass(ClientRequestSent, OSError);
    assert not issubclass(ClientRequestNotSent, OSError);
    assert issubclass(ClientReadTimeout, ClientRequestSent);
    assert issubclass(ClientRequestSent, ClientConnectionError);
    assert issubclass(ClientRequestNotSent, ClientConnectionError);
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
