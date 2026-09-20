"""Socket: compare native Python-object calls with the Python backend.

Both pathways use the bundled interpreter standard library. Native execution
must preserve its values, exceptions, signatures, and default arguments.
"""

import os;
import socket;


"""The fixed request both clients send (HTTP/1.0 + close so the server drains
and shuts the connection, ending the recv loop deterministically)."""
def _request -> str {
    return "GET /hello HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n";
}


"""Parse the HTTP status code from the start of a raw response (`HTTP/1.x SSS`).
The 3 status digits sit at byte offsets 9..11 of the status line."""
def _status_of(resp: bytes) -> int {
    if len(resp) < 12 {
        return -1;
    }
    return (resp[9] - 48) * 100 + (resp[10] - 48) * 10 + (resp[11] - 48);
}


def socket_py -> dict[any, any] {
    port = int(os.getenv("JAC_SOCKET_TEST_PORT"));
    s = socket.create_connection(("127.0.0.1", port));
    s.sendall(_request().encode());
    total = 0;
    first = b"";
    chunk = s.recv(4096);
    while len(chunk) > 0 {
        if len(first) == 0 {
            first = chunk;
        }
        total += len(chunk);
        chunk = s.recv(4096);
    }
    s.close();
    return {"status": _status_of(first), "total": total};
}


def socket_cl -> dict[any, any] {
    return {};
}


import from socket { create_connection }

# `_request`/`_status_of` are sv module-level helpers; native code can only
# reach them through the JIT interop bridge, so the request string and status
# parse are inlined here (the `test_urllib_equivalence` convention) to keep
# these functions fully native.
def socket_status_na -> int {
    port = int(os.getenv("JAC_SOCKET_TEST_PORT"));
    s = create_connection(("127.0.0.1", port));
    s.sendall(
        "GET /hello HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n".encode()
    );
    first = s.recv(4096);
    s.close();
    if len(first) < 12 {
        return -1;
    }
    return (first[9] - 48) * 100 + (first[10] - 48) * 10 + (first[11] - 48);
}

def socket_total_na -> int {
    port = int(os.getenv("JAC_SOCKET_TEST_PORT"));
    s = create_connection(("127.0.0.1", port));
    s.sendall(
        "GET /hello HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n".encode()
    );
    total = 0;
    chunk = s.recv(4096);
    while len(chunk) > 0 {
        total += len(chunk);
        chunk = s.recv(4096);
    }
    s.close();
    return total;
}

# Connecting to a closed port must raise a *catchable* `OSError` -- proving
# the surface's error path unwinds to a handler one module up (native
# cross-module exceptions, #7013/#7021), not aborts. Returns 1 if caught.
def socket_refused_caught_na -> int {
    try {
        # Port 1 on loopback has no listener -> connect() ECONNREFUSED.
        s = create_connection(("127.0.0.1", 1));
        s.close();
        return 0;
    } except OSError as e {
        return 1;
    }
}
