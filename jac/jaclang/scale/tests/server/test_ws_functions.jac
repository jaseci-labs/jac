"""In-process WebSocket tests for function endpoints and canonical walker paths.

Uses the in-process ServingTestClient transport (no subprocess / dev server),
so it exercises the jac-native serving WebSocket routes directly.
"""

import asyncio;
import socket;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

"""A test client whose app carries the WebSocket routes (the scale
extensions register them as part of the one assembly)."""
def _ws_client -> any {
    return make_client("test_api.jac");
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


test "websocket retry renews its PG backplane while hot reload keeps live connections" {
    fixture = Path(__file__).parents[1] / "fixtures" / "test_api.jac";
    with TemporaryDirectory(prefix="ws_retry_") as tmp {
        base = Path(tmp);
        app_file = base / "test_api.jac";
        app_file.write_text(fixture.read_text());
        (base / "jac.toml").write_text(
            '[project]\nname = "ws-retry"\n\n[scale.websocket]\nbackplane = "pg"\n'
        );
        reset_scale_config();
        get_scale_config(base);
        extension = WebSocketExtension();
        runtime = prepare_inprocess_runtime(
            str(app_file),
            tmp,
            endpoint_profile="desktop",
            setup_background_services=False,
            transport_kind="listener",
            overrides={"host": "127.0.0.1", "port": 0}
        );
        stop: any = None;
        try {
            server = runtime.server;
            server.extensions = [MetricsExtension(), extension];
            with socket.socket() as occupied {
                occupied.bind(("127.0.0.1", 0));
                occupied.listen();
                server.settings.port = occupied.getsockname()[1];
                try {
                    stop = server.serve_background(port_retries=0);
                    assert False , "occupied port unexpectedly started";
                } except PortInUseError {}
                failed_manager = extension.manager;
                assert failed_manager is not None;
                failed_app = server.require_app();
                failed_backplane = failed_manager.backplane;
                assert isinstance(failed_backplane, PgBackplane);
                assert failed_backplane._closed;
            }
            stop = server.serve_background(port_retries=0);
            manager = extension.manager;
            assert manager is not None;
            retry_app = server.require_app();
            backplane = manager.backplane;
            assert isinstance(backplane, PgBackplane);
            fresh = manager is not failed_manager and backplane is not failed_backplane;
            metrics_current = manager.metrics is server.metrics;
            hooks = len(retry_app.on_shutdown);
            asyncio.run(failed_app.shutdown());

            async def broadcast -> tuple[any, ...] {
                peer = PgBackplane();
                ws = await aws_connect(
                    f"ws://127.0.0.1:{server.port}/ws/walker/BroadcastChat"
                );
                try {
                    deadline = asyncio.get_running_loop().time() + 2;
                    while "walker:BroadcastChat" not in manager._subscribed
                        and asyncio.get_running_loop().time() < deadline {
                        await asyncio.sleep(0.01);
                    }
                    assert "walker:BroadcastChat" in manager._subscribed;
                    server._refresh_dev_endpoints();
                    retained = extension.manager is manager and server.app is retry_app;
                    await peer.publish(
                        "ws:walker:BroadcastChat", {"source": "pg-retry"}
                    );
                    received: any = None;
                    try {
                        received = await asyncio.wait_for(ws.receive_json(), timeout=2);
                    } except asyncio.TimeoutError {}
                    return (retained, received);
                } finally {
                    await ws.close();
                    await peer.close();
                }
            }
            (retained, received) = asyncio.run(broadcast());
            stop();
            stop = None;
            assert (fresh, metrics_current, retained, received)
                == (True, True, True, {"source": "pg-retry"}) , (
                fresh,
                metrics_current,
                retained,
                received
            );
            assert len(retry_app.on_shutdown) == hooks == 1;
            assert backplane._closed and backplane._handlers == {};
        } finally {
            if stop is not None {
                stop();
            }
            runtime.close();
            reset_scale_config();
        }
    }
}
