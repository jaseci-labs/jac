"""Bundled native `ssl` cross-backend equivalence fixture (#6978 Phase 1).

`import ssl` binds the bundled `na_stdlib/ssl.na.jac` Mechanism-F module (a
verifying TLS-client surface over the libssl/libcrypto FFI floor) on the na
backend; the sv reference is CPython's real `ssl`. The owning
`test_ssl_equivalence` suite stands up a loopback HTTPS server with a
test-generated self-signed cert for `localhost`, publishes the port in
`JAC_SSL_TEST_PORT` and the cert (used as the trust anchor) in
`JAC_SSL_TEST_CAFILE`, and exercises the three cases that matter for a
fail-closed TLS client:

  - **positive**: trusting the cert + the right hostname -> the handshake
    verifies and a GET returns the HTTP status.
  - **untrusted chain**: the default system trust store does NOT contain the
    self-signed cert -> `wrap_socket` must raise `SSLError` (fail closed).
  - **hostname mismatch**: trusting the cert but asking for the wrong hostname
    -> the in-handshake identity check must raise `SSLError` (fail closed).

The native functions return plain `int`s, driven directly through the JIT
(`get_func`) -- 1 means "the expected `SSLError` was raised and caught" -- so the
suite asserts on the scalar the native pathway marshals reliably (mirroring
`test_socket_equivalence`/`test_urllib_equivalence`). ES/JS opts out.
"""

import os;
import ssl;
import socket;


"""CPython reference: a verifying TLS GET against the loopback server, trusting
the test cert. Pins the server + the positive path (na must match this status)."""
def ssl_py -> dict {
    port = int(os.getenv("JAC_SSL_TEST_PORT"));
    cafile = os.getenv("JAC_SSL_TEST_CAFILE");
    ctx = ssl.create_default_context(cafile=cafile);
    sock = socket.create_connection(("127.0.0.1", port));
    ss = ctx.wrap_socket(sock, server_hostname="localhost");
    ss.sendall(b"GET /hello HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n");
    data = ss.recv(4096);
    ss.close();
    return {"status": int(data[9:12])};
}


na {
    import from socket { create_connection }
    import from ssl { create_default_context, SSLError }

    # Trust the test cert + the correct hostname: the handshake verifies and the
    # GET returns the server's HTTP status.
    def ssl_status_na -> int {
        port = int(os.getenv("JAC_SSL_TEST_PORT"));
        cafile = os.getenv("JAC_SSL_TEST_CAFILE");
        ctx = create_default_context(cafile=cafile);
        sock = create_connection(("127.0.0.1", port));
        ss = ctx.wrap_socket(sock, server_hostname="localhost");
        ss.sendall(
            "GET /hello HTTP/1.0\r\nHost: localhost\r\nConnection: close\r\n\r\n".encode()
        );
        first = ss.recv(4096);
        ss.close();
        if len(first) < 12 {
            return -1;
        }
        return (first[9] - 48) * 100 + (first[10] - 48) * 10 + (first[11] - 48);
    }

    # Default trust store does NOT contain the self-signed cert -> fail closed.
    # 1 == the expected SSLError was raised and caught.
    def ssl_untrusted_caught_na -> int {
        port = int(os.getenv("JAC_SSL_TEST_PORT"));
        sock = create_connection(("127.0.0.1", port));
        ctx = create_default_context();
        try {
            ss = ctx.wrap_socket(sock, server_hostname="localhost");
            ss.close();
            return 0;
        } except SSLError as e {
            sock.close();
            return 1;
        }
    }

    # Trust the cert but ask for the wrong hostname -> in-handshake identity
    # check rejects it -> fail closed. 1 == expected SSLError caught.
    def ssl_hostname_caught_na -> int {
        port = int(os.getenv("JAC_SSL_TEST_PORT"));
        cafile = os.getenv("JAC_SSL_TEST_CAFILE");
        sock = create_connection(("127.0.0.1", port));
        ctx = create_default_context(cafile=cafile);
        try {
            ss = ctx.wrap_socket(sock, server_hostname="wrong.invalid");
            ss.close();
            return 0;
        } except SSLError as e {
            sock.close();
            return 1;
        }
    }
}
