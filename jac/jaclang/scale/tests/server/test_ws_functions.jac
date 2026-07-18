"""In-process WebSocket tests for function endpoints and canonical walker paths.

Uses the Starlette TestClient transport (no subprocess / uvicorn / dev server),
so it exercises the FastAPI WebSocket routes directly.
"""
import from jaclang.scale.tests.scale_test_client { make_client }


"""Build a test client and register WebSocket routes on its app.

The "test" endpoint profile does not register WebSocket routes, so opt in
explicitly against the already-built app.
"""
def _ws_client -> any {
    client = make_client("test_api.jac");
    client.server.register_websocket_endpoints();
    return client;
}


test "ws function echo returns the function result envelope" {
    client = _ws_client();
    try {
        tc = client.raw_client;
        with tc.websocket_connect("/ws/function/ws_echo") as ws {
            ws.send_json({"message": "hi", "client_id": "c1"});
            resp = ws.receive_json();
            assert resp["ok"] == True , f"expected ok, got {resp}";
            data = resp["data"];
            body = data["result"]
                if isinstance(data, dict) and "result" in data
                else data;
            assert body["echo"] == "hi" , f"got {body}";
            assert body["client_id"] == "c1" , f"got {body}";
            assert body["protocol"] == "websocket" , f"got {body}";
        }
    } finally {
        client.close();
    }
}


test "ws function streaming yields chunk frames then a done frame" {
    client = _ws_client();
    try {
        tc = client.raw_client;
        with tc.websocket_connect("/ws/function/ws_stream") as ws {
            ws.send_json({"count": 3});
            frames = [];
            for _ in range(20) {
                frame = ws.receive_json();
                frames.append(frame);
                if frame.get("type") == "done" {
                    break;
                }
            }
            chunks = [
                f
                for f in frames
                if f.get("type") == "chunk"
            ];
            assert len(chunks) == 3 , f"expected 3 chunks, got {frames}";
            assert frames[-1] == {"ok": True, "type": "done"} , f"got {frames}";
        }
    } finally {
        client.close();
    }
}


test "ws walker canonical path /ws/walker/{name} works" {
    client = _ws_client();
    try {
        tc = client.raw_client;
        with tc.websocket_connect("/ws/walker/EchoMessage") as ws {
            ws.send_json({"message": "cw", "client_id": "c2"});
            resp = ws.receive_json();
            assert resp["ok"] == True , f"expected ok, got {resp}";
        }
    } finally {
        client.close();
    }
}


test "ws private function rejects a message with no token" {
    client = _ws_client();
    try {
        tc = client.raw_client;
        with tc.websocket_connect("/ws/function/ws_private_echo") as ws {
            ws.send_json({"message": "secret"});
            resp = ws.receive_json();
            assert resp["ok"] == False , f"expected rejection, got {resp}";
            assert resp["error"]["code"] == "UNAUTHORIZED" , f"got {resp}";
        }
    } finally {
        client.close();
    }
}


test "ws walker legacy path /ws/{name} still works" {
    client = _ws_client();
    try {
        tc = client.raw_client;
        with tc.websocket_connect("/ws/EchoMessage") as ws {
            ws.send_json({"message": "lw", "client_id": "c3"});
            resp = ws.receive_json();
            assert resp["ok"] == True , f"expected ok, got {resp}";
        }
    } finally {
        client.close();
    }
}
