"""Ssl: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import os;
import ssl;
import socket;


"""CPython reference: a verifying TLS GET against the loopback server, trusting
the test cert. Pins the server + the positive path (na must match this status)."""
def ssl_py -> dict[any, any] {
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
