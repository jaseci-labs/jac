"""Cross-backend `socket` equivalence over the libc BSD-sockets floor
(issue #6978 Phase 1, the network tier `ssl` + `http`/`urllib` build on).

`import socket` binds the bundled `na_stdlib/socket.na.jac` Mechanism-A/F module
(a pure-Jac TCP-client surface over the libc socket FFI floor) on the na
backend; the sv reference is CPython's real `socket`. There is no live network:
a loopback HTTP server is stood up on an ephemeral port, its port published in
`JAC_SOCKET_TEST_PORT`, and the two client implementations are pinned congruent
on a raw GET against the same server -- the HTTP status and the exact total
response byte count (deterministic, hence byte-equal across backends).

This is the executable Phase-1 socket guard: it exercises loopback DNS
(`getaddrinfo`), `create_connection`/`connect`, `sendall`, and a `recv` drain to
end-of-stream. The native functions return plain `int`s, driven directly through
the JIT (`get_func`) -- the scalar shape the native pathway marshals across a
module boundary reliably -- so this suite compares ints rather than going
through `run_with_both`, exactly like `test_urllib_equivalence`. The sv
reference is pinned with concrete asserts, so a regression in either backend is a
hard failure. ES/JS opts out (no socket floor).
"""

import os;
import threading;
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from jaclang.compiler.tests.xbackend_equiv {
    run_py_fixture,
    compile_native,
    get_func
}

glob _BODY: bytes = b"hello world";


"""Loopback handler serving `/hello` (200 text/plain, fixed body); 404 elsewhere.
`log_message` is silenced so the test output stays clean."""
class _LoopbackHandler(BaseHTTPRequestHandler) {
    def do_GET(self: _LoopbackHandler) {
        if self.path == "/hello" {
            self.send_response(200);
            self.send_header("Content-Type", "text/plain; charset=utf-8");
            self.send_header("Content-Length", str(len(_BODY)));
            self.end_headers();
            self.wfile.write(_BODY);
        } else {
            self.send_response(404);
            self.send_header("Content-Length", "0");
            self.end_headers();
        }
    }

    def log_message(self: _LoopbackHandler, fmt: str, *args: any) -> None {
        return;
    }
}


"""Start the loopback server on an ephemeral port in a daemon thread; return
(server, port). The caller shuts it down in a `finally`."""
def _start_server -> tuple {
    srv = HTTPServer(("127.0.0.1", 0), _LoopbackHandler);
    port = srv.server_address[1];
    t = threading.Thread(target=srv.serve_forever);
    t.daemon = True;
    t.start();
    return (srv, port);
}


"""Call a no-arg native `int`-returning fixture function through the JIT."""
def _call_na_int(eng: object, name: str) -> int {
    import ctypes;
    fn = get_func(eng, name, ctypes.c_int64);
    return int(fn());
}


test "socket TCP client over the libc floor (sv<->na congruent)" {
    (srv, port) = _start_server();
    os.environ["JAC_SOCKET_TEST_PORT"] = str(port);
    try {
        # Pin canonical sv (CPython socket) semantics as a hard guard: a 200 and
        # a non-empty total-byte count for the fixed server reply.
        py = run_py_fixture("prim_socket", "socket_py");
        assert py["status"] == 200 , py;
        assert py["total"] > 0 , py;

        # Native libc socket floor: same status, and the SAME exact total bytes
        # (identical server reply read by a hand-rolled recv drain).
        (eng, _) = compile_native("prim_socket.jac");
        assert _call_na_int(eng, "socket_status_na") == py["status"] , "status";
        assert _call_na_int(eng, "socket_total_na") == py["total"] , "total bytes";

        # Error path: connecting to a closed port raises a CATCHABLE `OSError`
        # that unwinds across the module boundary (native cross-module
        # exceptions, #7013/#7021) rather than aborting -- 1 == caught.
        assert _call_na_int(eng, "socket_refused_caught_na") == 1 , (
            "connection-refused OSError must be catchable, not abort"
        );
    } finally {
        srv.shutdown();
        os.environ.pop("JAC_SOCKET_TEST_PORT", None);
    }
}
