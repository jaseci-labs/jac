"""Client-disconnect errors must not escape the request handler.

When a client reloads, navigates away, or closes the tab mid-response, the
socket drops while the base `BaseHTTPRequestHandler.handle_one_request` is still
reading or writing -- raising BrokenPipeError/ConnectionResetError/
ConnectionAbortedError. The base handler only swallows TimeoutError, so those
disconnect errors otherwise escape into socketserver, which prints an alarming
traceback for what is a routine disconnect. `JacRequestHandler` overrides
`handle_one_request` to end the connection quietly instead.

This drives the override directly: an `rfile` whose `readline` raises the
disconnect error (the first thing the base handler does) stands in for a peer
that hung up. Without the override the call re-raises and this test errors out;
with it, the error is swallowed and the connection is marked for closing.
"""

import io;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.testing { JacTestClient }

"""Stand-in socket reader that hangs up the moment it is read."""
class BrokenReader {
    def init(rself: BrokenReader, err: type) {
        rself.err = err;
    }

    def readline(rself: BrokenReader, *args: any) -> bytes {
        raise rself.err("peer disconnected");
    }

    def close(rself: BrokenReader) {
        ;
    }
}

test "handle_one_request swallows client-disconnect errors" {
    with TemporaryDirectory() as tmp {
        app = Path(tmp) / "disconnect_app.jac";
        app.write_text('def:pub ping -> dict { return {"ok": True}; }\n');
        client = JacTestClient.from_file(str(app), base_path=tmp);
        try {
            # The real handler class produced by the server under test.
            handler_class = client.server.create_handler();

            class DisconnectHandler(handler_class) {
                def init(hself: DisconnectHandler, err: type) {
                    # Stand up the handler without the socket-bound parent
                    # __init__; only what handle_one_request touches is needed.
                    hself.rfile = BrokenReader(err);
                    hself.wfile = io.BytesIO();
                    hself.client_address = ("127.0.0.1", 0);
                    hself.server = type(
                        "MockServer", (), {"server_address": ("localhost", 0)}
                    )();
                    hself.request_version = "HTTP/1.1";
                    hself.close_connection = False;
                }

                def log_message(hself: DisconnectHandler, format: str, *args: any) {
                    ;
                }
            }

            # Every flavor of mid-request hang-up must be absorbed, not raised.
            for err_type in [
                BrokenPipeError,
                ConnectionResetError,
                ConnectionAbortedError
            ] {
                handler = DisconnectHandler(err_type);
                # No exception escapes (a bare base handler would re-raise here)...
                handler.handle_one_request();
                # ...and the connection is marked done so the keep-alive loop ends.
                assert handler.close_connection == True , f"{err_type.__name__} was not absorbed by handle_one_request";
            }
        } finally {
            client.close();
        }
    }
}
