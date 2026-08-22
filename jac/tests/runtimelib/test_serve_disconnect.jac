"""Client-disconnect errors must not escape the connection handler.

When a client reloads, navigates away, or closes the tab mid-response, the
socket drops while the server is still reading or writing. The serving core's
connection handler absorbs ConnectionError/IncompleteReadError quietly; a
routine disconnect must never take down the server or poison the accept loop.

This drives the real asyncio server: a peer connects, sends a partial request,
and hangs up abruptly (RST via SO_LINGER 0). The server must keep answering
subsequent requests as if nothing happened.
"""

import json;
import socket;
import struct;
import urllib.request;
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.runtimelib.serving.server { ServingServer }

def _ping -> dict {
    return {"ok": True};
}

test "abrupt client disconnects are absorbed by the connection handler" {
    app = ServingApp();
    app.add_endpoint(JEndPoint(method=HTTPMethod.GET, path='/ping', callback=_ping));
    server = ServingServer(app=app, host='127.0.0.1', port=0);
    stop = server.serve_background();
    try {
        for _ in range(3) {
            sock = socket.create_connection(
                ('127.0.0.1', server.bound_port), timeout=5
            );
            sock.setsockopt(
                socket.SOL_SOCKET, socket.SO_LINGER, struct.pack('ii', 1, 0)
            );
            sock.sendall(b"GET /ping HTTP/1.1\r\nHost: x\r\nConte");
            sock.close();
        }
        resp = urllib.request.urlopen(
            f"http://127.0.0.1:{server.bound_port}/ping", timeout=5
        );
        body = json.loads(resp.read());
        assert resp.status == 200;
        assert body == {"ok": True} , "server stopped serving after client disconnects";
    } finally {
        stop();
    }
}
