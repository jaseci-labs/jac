"""Malformed request lines must receive 400 responses without handler errors."""

import io;
import logging;
import socket;
import from jaclang.server.serving.app { ServingApp }
import from jaclang.server.serving.datatypes { Request, Response }
import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.server.serving.server { ServingServer }


def _echo(request: Request) -> Response {
    return Response(content=request.body, media_type="application/octet-stream");
}


def _raw_request(port: int, payload: bytes) -> bytes {
    sock = socket.create_connection(('127.0.0.1', port), timeout=5);
    sock.settimeout(2);
    try {
        sock.sendall(payload);
        sock.shutdown(socket.SHUT_WR);
        chunks: list[bytes] = [];
        while True {
            piece = sock.recv(4096);
            if not piece {
                break;
            }
            chunks.append(piece);
        }
        return b"".join(chunks);
    } except TimeoutError {
        return b"";
    } finally {
        sock.close();
    }
}


test "malformed request parser inputs return 400 without handler traceback" {
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path='/ping', callback=_echo));
    server = ServingServer(app=app, host='127.0.0.1', port=0);
    stop = server.serve_background();
    logger = logging.getLogger("jaclang.server.serving.server");
    captured = io.StringIO();
    handler = logging.StreamHandler(captured);
    old_level = logger.level;
    logger.addHandler(handler);
    logger.setLevel(logging.ERROR);
    failures: list[str] = [];
    try {
        malformed = [
            (
                "negative chunk size",
                b"GET /ping HTTP/1.1\r\nHost: x\r\n"
                b"Transfer-Encoding: chunked\r\n\r\n-5\r\n"
            ),
            (
                "signed chunk size",
                b"GET /ping HTTP/1.1\r\nHost: x\r\n"
                b"Transfer-Encoding: chunked\r\n\r\n+5\r\nabcde\r\n0\r\n\r\n"
            ),
            (
                "underscored chunk size",
                b"GET /ping HTTP/1.1\r\nHost: x\r\n"
                b"Transfer-Encoding: chunked\r\n\r\n1_0\r\n"
                b"0123456789abcdef\r\n0\r\n\r\n"
            ),
            (
                "prefixed chunk size",
                b"GET /ping HTTP/1.1\r\nHost: x\r\n"
                b"Transfer-Encoding: chunked\r\n\r\n0x5\r\nabcde\r\n0\r\n\r\n"
            ),
            (
                "non-ASCII content length",
                b"GET /ping HTTP/1.1\r\nHost: x\r\nContent-Length: \xb2\r\n\r\n"
            ),
            (
                "oversized ASCII content length",
                b"GET /ping HTTP/1.1\r\nHost: x\r\nContent-Length: "
                    + b"9" * 4301
                    + b"\r\n\r\n"
            ),
            ("malformed IPv6 target", b"GET //[x/ HTTP/1.1\r\nHost: x\r\n\r\n"),
            (
                "duplicate content length",
                b"GET /ping HTTP/1.1\r\nHost: x\r\n"
                b"Content-Length: 1\r\nContent-Length: 2\r\n\r\n"
            ),
            (
                "transfer encoding with content length",
                b"GET /ping HTTP/1.1\r\nHost: x\r\n"
                b"Transfer-Encoding: chunked\r\nContent-Length: 0\r\n\r\n"
            )
        ];
        for (label, payload) in malformed {
            response = _raw_request(server.bound_port, payload);
            if not response.startswith(b"HTTP/1.1 400 ") {
                failures.append(f"{label}: {response[:80]}");
            }
        }
        if server.requests_served != 0 {
            failures.append(
                f"malformed requests reached the app: {server.requests_served}"
            );
        }

        oversized = _raw_request(
            server.bound_port,
            b"GET /ping HTTP/1.1\r\nHost: x\r\n" b"Content-Length: 104857601\r\n\r\n"
        );
        if not oversized.startswith(b"HTTP/1.1 413 ") {
            failures.append(f"oversized body: {oversized[:80]}");
        }
        valid_length = _raw_request(
            server.bound_port,
            b"GET /ping HTTP/1.1\r\nHost: x\r\nContent-Length: 3\r\n\r\nabc"
        );
        if (
            not valid_length.startswith(b"HTTP/1.1 200 ")
            or not valid_length.endswith(b"abc")
        ) {
            failures.append(f"valid ASCII content length: {valid_length[:80]}");
        }
        valid_chunked = _raw_request(
            server.bound_port,
            b"GET /ping HTTP/1.1\r\nHost: x\r\n"
            b"Transfer-Encoding: ChUnKeD\r\n\r\na ; foo=bar\r\n"
            b"0123456789\r\n0\r\n\r\n"
        );
        if (
            not valid_chunked.startswith(b"HTTP/1.1 200 ")
            or not valid_chunked.endswith(b"0123456789")
        ) {
            failures.append(f"mixed-case chunk extension: {valid_chunked[:80]}");
        }
    } finally {
        logger.removeHandler(handler);
        logger.setLevel(old_level);
        handler.close();
        stop();
    }
    assert failures == [] , f"unexpected parser responses: {failures}";
    logs = captured.getvalue();
    assert "connection handler failed" not in logs , logs;
    assert "Traceback" not in logs , logs;
}
