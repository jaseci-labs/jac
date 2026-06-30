"""Cross-backend `ssl` equivalence over the libssl/libcrypto TLS floor
(issue #6978 Phase 1, the security-critical leg of the network tier).

`import ssl` binds the bundled `na_stdlib/ssl.na.jac` Mechanism-F module (a
verifying TLS-client surface over OpenSSL's `libssl`/`libcrypto`) on the na
backend; the sv reference is CPython's real `ssl`. A loopback HTTPS server is
stood up with a test-generated self-signed cert for `localhost`; the cert path
(the trust anchor) is published in `JAC_SSL_TEST_CAFILE` and the port in
`JAC_SSL_TEST_PORT`.

This is the executable **fail-closed** guard:

  - trusting the cert + the right hostname -> the handshake verifies and the GET
    returns 200 (congruent with CPython, pinned via `ssl_py`);
  - the default trust store does NOT contain the self-signed cert -> the native
    `wrap_socket` raises a catchable `SSLError` (untrusted chain rejected);
  - trusting the cert but the WRONG hostname -> the in-handshake identity check
    raises a catchable `SSLError` (hostname mismatch rejected).

The native functions return plain `int`s driven through the JIT (`get_func`),
1 == "the expected `SSLError` was raised", mirroring `test_socket_equivalence`.
The cert is generated with the `openssl` CLI; the test skips cleanly where
`openssl` is unavailable (no committed private key).
"""

import os;
import shutil;
import subprocess;
import tempfile;
import threading;
import ssl as pyssl;
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from jaclang.compiler.tests.xbackend_equiv {
    run_py_fixture,
    compile_native,
    get_func
}

glob _BODY: bytes = b"hello world";


"""Loopback handler: `/hello` -> 200 + fixed body. `log_message` silenced."""
class _Handler(BaseHTTPRequestHandler) {
    def do_GET(self: _Handler) {
        self.send_response(200);
        self.send_header("Content-Type", "text/plain");
        self.send_header("Content-Length", str(len(_BODY)));
        self.end_headers();
        self.wfile.write(_BODY);
    }

    def log_message(self: _Handler, fmt: str, *args: any) -> None {
        return;
    }
}


"""Generate a self-signed cert+key for `localhost` (SAN DNS:localhost,
IP:127.0.0.1) into `d` via the `openssl` CLI. Returns (cert, key, ok)."""
def _gen_cert(d: str) -> tuple {
    cert = os.path.join(d, "cert.pem");
    key = os.path.join(d, "key.pem");
    r = subprocess.run(
        [
            "openssl",
            "req",
            "-x509",
            "-newkey",
            "rsa:2048",
            "-sha256",
            "-keyout",
            key,
            "-out",
            cert,
            "-days",
            "3650",
            "-nodes",
            "-subj",
            "/CN=localhost",
            "-addext",
            "subjectAltName=DNS:localhost,IP:127.0.0.1"
        ],
        capture_output=True,
        timeout=60
    );
    return (cert, key, r.returncode == 0);
}


"""Start a loopback HTTPS server (TLS via `cert`/`key`) on an ephemeral port in a
daemon thread; return (server, port). The caller shuts it down."""
def _start_tls_server(cert: str, key: str) -> tuple {
    sctx = pyssl.SSLContext(pyssl.PROTOCOL_TLS_SERVER);
    sctx.load_cert_chain(cert, key);
    httpd = HTTPServer(("127.0.0.1", 0), _Handler);
    httpd.socket = sctx.wrap_socket(httpd.socket, server_side=True);
    port = httpd.server_address[1];
    t = threading.Thread(target=httpd.serve_forever);
    t.daemon = True;
    t.start();
    return (httpd, port);
}


"""Call a no-arg native `int`-returning fixture function through the JIT."""
def _call_na_int(eng: object, name: str) -> int {
    import ctypes;
    fn = get_func(eng, name, ctypes.c_int64);
    return int(fn());
}


test "ssl verifying TLS client over libssl floor (fail-closed cert + hostname)" {
    if shutil.which("openssl") is None {
        return;  # no cert toolchain available -> skip cleanly
    }
    d = tempfile.mkdtemp();
    (cert, key, ok) = _gen_cert(d);
    if not ok {
        return;  # cert generation failed -> skip
    }
    (httpd, port) = _start_tls_server(cert, key);
    os.environ["JAC_SSL_TEST_PORT"] = str(port);
    os.environ["JAC_SSL_TEST_CAFILE"] = cert;
    try {
        # Pin the canonical sv (CPython ssl) result: a verified 200.
        py = run_py_fixture("prim_ssl", "ssl_py");
        assert py["status"] == 200 , py;

        (eng, _) = compile_native("prim_ssl.jac");
        # Positive: verified handshake -> same status as CPython.
        assert _call_na_int(eng, "ssl_status_na") == py["status"] , "verified GET status";
        # Fail-closed: an untrusted self-signed chain must raise SSLError.
        assert _call_na_int(eng, "ssl_untrusted_caught_na") == 1 , (
            "untrusted certificate must fail closed (SSLError)"
        );
        # Fail-closed: a hostname mismatch must raise SSLError.
        assert _call_na_int(eng, "ssl_hostname_caught_na") == 1 , (
            "hostname mismatch must fail closed (SSLError)"
        );
    } finally {
        httpd.shutdown();
        os.environ.pop("JAC_SSL_TEST_PORT", None);
        os.environ.pop("JAC_SSL_TEST_CAFILE", None);
    }
}
