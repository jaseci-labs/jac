"""Tests for the `jac browse` engine (`jaclang.cli.browser_engine`).

The transport tests drive a real `CDP.call()` through the actual RFC 6455
framing code against an in-process loopback server, so they need no Chrome:
client-side masking, the extended-length encodings, fragmentation, control
frames, and the `Sec-WebSocket-Accept` handshake check all run for real. The
remaining tests cover the Chrome-free engine logic directly: accessibility-tree
ref assignment, key-code mapping, and cookie projection.
"""

import base64;
import hashlib;
import json;
import os;
import socket;
import struct;
import tempfile;
import threading;
import from jaclang.cli.browser_engine {
    CDP,
    connect,
    _walk_ax,
    _key_code,
    _cookie_param
}


# ---------------------------------------------------------------------------
# Loopback WebSocket/CDP server (stands in for Chrome's DevTools endpoint)
# ---------------------------------------------------------------------------
def _recv_exact(conn: any, n: int) -> bytes {
    buf = bytearray();
    while len(buf) < n {
        chunk = conn.recv(n - len(buf));
        if not chunk {
            raise ConnectionError("client closed mid-frame");
        }
        buf.extend(chunk);
    }
    return bytes(buf);
}


"""Read one (masked) client frame and return its unmasked payload bytes."""
def _read_client_frame(conn: any) -> bytes {
    (b0, b1) = _recv_exact(conn, 2);
    masked = (b1 & 0x80) != 0;
    ln = b1 & 0x7F;
    if ln == 126 {
        ln = struct.unpack("!H", _recv_exact(conn, 2))[0];
    } elif ln == 127 {
        ln = struct.unpack("!Q", _recv_exact(conn, 8))[0];
    }
    mask = _recv_exact(conn, 4) if masked else bytes();
    payload = _recv_exact(conn, ln);
    if masked {
        payload = bytes([payload[i] ^ mask[i % 4] for i in range(ln)]);
    }
    return payload;
}


"""Send one server frame (server-to-client frames are never masked)."""
def _send_server_frame(conn: any, payload: bytes, opcode: int = 0x1, fin: bool = True) {
    header = bytearray([(0x80 if fin else 0x00) | opcode]);
    ln = len(payload);
    if ln < 126 {
        header.append(ln);
    } elif ln < 65536 {
        header.append(126);
        header.extend(struct.pack("!H", ln));
    } else {
        header.append(127);
        header.extend(struct.pack("!Q", ln));
    }
    conn.sendall(bytes(header) + payload);
}


"""Accept one connection and complete the WebSocket handshake."""
def _accept_ws(srv: socket.socket) -> socket.socket {
    conn = srv.accept()[0];
    conn.settimeout(10);
    req = bytearray();
    while "\r\n\r\n".encode() not in req {
        chunk = conn.recv(4096);
        if not chunk {
            return conn;
        }
        req.extend(chunk);
    }
    key = "";
    for line in bytes(req).decode().split("\r\n") {
        if line.lower().startswith("sec-websocket-key:") {
            key = line.split(":", 1)[1].strip();
        }
    }
    guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    accept = base64.b64encode(hashlib.sha1((key + guid).encode()).digest()).decode();
    conn.sendall(
        (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept}\r\n\r\n"
        ).encode()
    );
    return conn;
}


"""Answer one call in a single text frame."""
def _serve_one(srv: socket.socket, make_reply: any) {
    conn = _accept_ws(srv);
    request = json.loads(_read_client_frame(conn).decode());
    _send_server_frame(conn, json.dumps(make_reply(request)).encode());
}


"""Answer one call split across two frames (start + continuation)."""
def _serve_fragmented(srv: socket.socket, make_reply: any) {
    conn = _accept_ws(srv);
    request = json.loads(_read_client_frame(conn).decode());
    body = json.dumps(make_reply(request)).encode();
    mid = len(body) // 2;
    _send_server_frame(conn, body[:mid], opcode=0x1, fin=False);
    _send_server_frame(conn, body[mid:], opcode=0x0, fin=True);
}


"""Send a PING before the reply, then read the client's PONG."""
def _serve_with_ping(srv: socket.socket, make_reply: any) {
    conn = _accept_ws(srv);
    request = json.loads(_read_client_frame(conn).decode());
    _send_server_frame(conn, "ping".encode(), opcode=0x9, fin=True);
    _send_server_frame(conn, json.dumps(make_reply(request)).encode());
    _read_client_frame(conn);  # consume the PONG so the socket stays open for it
}


def _reply_small(req: dict) -> dict {
    return {"id": req["id"], "result": {"value": 42}};
}


def _reply_large(req: dict) -> dict {
    return {"id": req["id"], "result": {"value": "x" * 300, "echo": req["params"]}};
}


def _reply_error(req: dict) -> dict {
    return {"id": req["id"], "error": {"code": -32000, "message": "boom"}};
}


def _serve_in_thread(
    make_reply: any, serve_fn: any = _serve_one
) -> tuple[socket.socket, int, threading.Thread] {
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1);
    srv.bind(("127.0.0.1", 0));
    srv.listen(1);
    port = srv.getsockname()[1];
    t = threading.Thread(target=serve_fn, args=(srv, make_reply));
    t.start();
    return (srv, port, t);
}


def _connect_cdp(port: int) -> CDP {
    return CDP(ws_url=f"ws://127.0.0.1:{port}/devtools/page/X");
}


# ---------------------------------------------------------------------------
# Transport: WebSocket framing + CDP.call
# ---------------------------------------------------------------------------
test "CDP round-trips a JSON-RPC call over the hand-rolled WebSocket" {
    (srv, port, t) = _serve_in_thread(_reply_small);
    cdp = _connect_cdp(port);
    res = cdp.call("Runtime.evaluate", {"expression": "21+21"});
    assert res == {"value": 42};
    cdp.close();
    t.join(timeout=5);
    srv.close();
}


test "CDP handles extended-length frames in both directions" {
    (srv, port, t) = _serve_in_thread(_reply_large);
    cdp = _connect_cdp(port);
    # A >=126-byte expression forces the client's two-byte length send path;
    # the 300-byte reply forces the matching two-byte length recv path.
    big_expr = "y" * 200;
    res = cdp.call("Runtime.evaluate", {"expression": big_expr});
    assert len(res["value"]) == 300;
    assert res["echo"]["expression"] == big_expr;
    cdp.close();
    t.join(timeout=5);
    srv.close();
}


test "CDP reassembles a fragmented WebSocket message" {
    (srv, port, t) = _serve_in_thread(_reply_small, _serve_fragmented);
    cdp = _connect_cdp(port);
    res = cdp.call("Runtime.evaluate", {"expression": "1"});
    assert res == {"value": 42};
    cdp.close();
    t.join(timeout=5);
    srv.close();
}


test "CDP answers a server PING and still returns the reply" {
    (srv, port, t) = _serve_in_thread(_reply_small, _serve_with_ping);
    cdp = _connect_cdp(port);
    res = cdp.call("Runtime.evaluate", {"expression": "1"});
    assert res == {"value": 42};
    cdp.close();
    t.join(timeout=5);
    srv.close();
}


test "CDP surfaces a protocol error response as RuntimeError" {
    (srv, port, t) = _serve_in_thread(_reply_error);
    cdp = _connect_cdp(port);
    raised = False;
    try {
        cdp.call("Runtime.evaluate", {"expression": "boom"});
    } except RuntimeError as e {
        raised = True;
        assert "boom" in str(e);
    }
    assert raised , "a CDP error field must raise RuntimeError";
    cdp.close();
    t.join(timeout=5);
    srv.close();
}


test "connect raises when no live browser session exists" {
    tmp = tempfile.mkdtemp();
    old = os.environ.get("JACBROWSER_CACHE");
    os.environ["JACBROWSER_CACHE"] = tmp;
    try {
        raised = False;
        try {
            connect("nope");
        } except RuntimeError as e {
            raised = True;
            assert "no live browser" in str(e);
        }
        assert raised , "connect must reject a session with no state file";
    } finally {
        if old is None {
            del os.environ["JACBROWSER_CACHE"];
        } else {
            os.environ["JACBROWSER_CACHE"] = old;
        }
    }
}


# ---------------------------------------------------------------------------
# Engine logic (no Chrome, no socket)
# ---------------------------------------------------------------------------
test "_walk_ax assigns @e refs to interactive and named nodes only" {
    # WebArea
    #   button "Send"     -> interactive + backend            -> @e1
    #   heading "Welcome" -> named (non-interactive) + backend -> @e2
    #   generic           -> non-interactive, unnamed          -> no ref
    #   (ignored wrapper) -> emits nothing, child still walked
    #     link "Home"     -> interactive + backend             -> @e3
    #   textbox "Search"  -> interactive but no backend id     -> no ref
    nodes = {
        "1": {
            "nodeId": "1",
            "role": {"value": "WebArea"},
            "name": {"value": ""},
            "childIds": ["2", "3", "4", "5", "7"]
        },
        "2": {
            "nodeId": "2",
            "role": {"value": "button"},
            "name": {"value": "Send"},
            "backendDOMNodeId": 100,
            "childIds": []
        },
        "3": {
            "nodeId": "3",
            "role": {"value": "heading"},
            "name": {"value": "Welcome"},
            "backendDOMNodeId": 200,
            "childIds": []
        },
        "4": {
            "nodeId": "4",
            "role": {"value": "generic"},
            "name": {"value": ""},
            "backendDOMNodeId": 300,
            "childIds": []
        },
        "5": {
            "nodeId": "5",
            "ignored": True,
            "role": {"value": "presentation"},
            "childIds": ["6"]
        },
        "6": {
            "nodeId": "6",
            "role": {"value": "link"},
            "name": {"value": "Home"},
            "backendDOMNodeId": 400,
            "childIds": []
        },
        "7": {
            "nodeId": "7",
            "role": {"value": "textbox"},
            "name": {"value": "Search"},
            "childIds": []
        }
    };
    lines = [];
    refs = {};
    _walk_ax(nodes["1"], nodes, 0, lines, refs);

    assert refs == {"e1": 100, "e2": 200, "e3": 400};
    assert lines == [
        'WebArea',
        '  @e1 button "Send"',
        '  @e2 heading "Welcome"',
        '  generic',
        '  @e3 link "Home"',
        '  textbox "Search"'
    ];
}


test "_key_code maps letters and digits to DOM codes, passes through the rest" {
    assert _key_code("a") == "KeyA";
    assert _key_code("Z") == "KeyZ";
    assert _key_code("7") == "Digit7";
    assert _key_code("-") == "-";
    assert _key_code(".") == ".";
}


test "_cookie_param projects a CDP cookie to Network.setCookies shape" {
    full = _cookie_param(
        {
            "name": "sid",
            "value": "abc",
            "domain": "example.com",
            "path": "/app",
            "httpOnly": True,
            "secure": True,
            "expires": 1893456000.0,
            "sameSite": "Lax",
            "size": 99,
            "session": False
        }
    );
    assert full == {
        "name": "sid",
        "value": "abc",
        "domain": "example.com",
        "path": "/app",
        "httpOnly": True,
        "secure": True,
        "expires": 1893456000.0,
        "sameSite": "Lax"
    };

    # Session cookie: negative `expires` and missing `sameSite` are dropped,
    # and the domain/path/flag defaults are filled in.
    minimal = _cookie_param({"name": "t", "value": "1", "expires": -1});
    assert minimal == {
        "name": "t",
        "value": "1",
        "domain": "",
        "path": "/",
        "httpOnly": False,
        "secure": False
    };
}
