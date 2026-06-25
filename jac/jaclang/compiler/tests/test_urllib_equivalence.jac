"""Cross-backend `urllib.request` equivalence over the libcurl floor
(issues #6404 / #6940, Phase 3: transport + HTTP).

`import from urllib.request { urlopen }` binds the bundled
`na_stdlib/urllib/request.na.jac` Mechanism-F module (libcurl floor + pure-Jac
surface) on the na backend; the sv reference is CPython's real `urllib.request`.
There is no live network: a loopback `http.server` is stood up on an ephemeral
port, its port published in `JAC_URLLIB_TEST_PORT`, and the two `urlopen`
implementations are pinned congruent on HTTP status and received body length --
for a direct GET and for a 301 redirect both follow.

This is the executable Phase-3 guard: it exercises DNS/connect (loopback), the
HTTP/1.1 GET, libcurl header+body capture to temp files, the native variadic
`curl_easy_setopt` FFI, status-line parsing, and redirect following. The native
functions return plain `int`s, driven directly through the JIT (`get_func`),
because the native pathway does not yet box object-derived values into a
`dict[str, any]` reliably -- so this suite compares ints rather than going
through `run_with_both`. The sv reference is pinned with concrete asserts, so a
regression in either backend is a hard failure. ES/JS opts out (no libcurl floor).
"""

import ctypes;
import os;
import threading;
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from jaclang.compiler.tests.xbackend_equiv {
    run_py_fixture,
    compile_native,
    get_func
}

glob _BODY: bytes = b"hello world";


"""Loopback handler serving the two fixed routes the fixture requests:
`/hello` (200 text/plain) and `/redirect` (301 -> /hello). Everything else 404s.
`log_message` is silenced so the test output stays clean."""
class _LoopbackHandler(BaseHTTPRequestHandler) {
    def do_GET(self: _LoopbackHandler) {
        if self.path == "/hello" {
            self.send_response(200);
            self.send_header("Content-Type", "text/plain; charset=utf-8");
            self.send_header("Content-Length", str(len(_BODY)));
            self.end_headers();
            self.wfile.write(_BODY);
        } elif self.path == "/redirect" {
            self.send_response(301);
            self.send_header("Location", "/hello");
            self.send_header("Content-Length", "0");
            self.end_headers();
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
    fn = get_func(eng, name, ctypes.c_int64);
    return int(fn());
}


test "urllib.request.urlopen GET over the libcurl floor (sv<->na congruent)" {
    (srv, port) = _start_server();
    os.environ["JAC_URLLIB_TEST_PORT"] = str(port);
    try {
        # Pin the canonical sv (CPython urllib) semantics as a hard guard.
        py = run_py_fixture("prim_urllib", "urllib_py");
        assert py["status"] == 200 , py;
        assert py["body"] == "hello world" , py;
        assert py["body_length"] == 11 , py;
        assert py["content_type"] == "text/plain; charset=utf-8" , py;

        # Native libcurl floor: same status and body length, parsed from the
        # real HTTP exchange against the loopback server.
        (eng, _) = compile_native("prim_urllib.jac");
        assert _call_na_int(eng, "urlopen_status_na") == py["status"] , "status";
        assert _call_na_int(eng, "urlopen_body_length_na") == py["body_length"] , (
            "body_length"
        );
    } finally {
        srv.shutdown();
        os.environ.pop("JAC_URLLIB_TEST_PORT", None);
    }
}


test "urllib.request.urlopen follows redirects over the libcurl floor (sv<->na)" {
    (srv, port) = _start_server();
    os.environ["JAC_URLLIB_TEST_PORT"] = str(port);
    try {
        py = run_py_fixture("prim_urllib", "urllib_redirect_py");
        assert py["status"] == 200 , py;
        assert py["body"] == "hello world" , py;
        assert py["body_length"] == 11 , py;

        (eng, _) = compile_native("prim_urllib.jac");
        assert _call_na_int(eng, "urlopen_redirect_status_na") == py["status"] , (
            "redirect status"
        );
        assert _call_na_int(eng, "urlopen_redirect_body_length_na") == (
            py["body_length"]
        ) , "redirect body_length";
    } finally {
        srv.shutdown();
        os.environ.pop("JAC_URLLIB_TEST_PORT", None);
    }
}
