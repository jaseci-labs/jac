"""Preview reverse proxy — subdomain-based routing for preview servers.

Routes {user_id}-p{port}.jaseci.org requests to localhost:{port} inside
the pod. Each preview gets its own origin, so Vite root-absolute imports
and HMR WebSockets work natively without any request rewriting.
"""

import re;
import asyncio;
import httpx;
import websockets;
import from typing { Any }
import from jaclang.jac0core.runtime { hookimpl, plugin_manager }
import from jac_scale.serve { JacAPIServer }
import from services.preview_manager { PREVIEW_BASE_PORT, PREVIEW_PORT_COUNT }

glob PREVIEW_MIN_PORT: int = PREVIEW_BASE_PORT;
glob PREVIEW_MAX_PORT: int = PREVIEW_BASE_PORT + PREVIEW_PORT_COUNT * 2;

# Regex to extract port from subdomain: {user_id}-p{port}.jaseci.org → port
# Matches both "abc123-p5180.jaseci.org" and "p5180.jaseci.org" (no user_id)
glob _SUBDOMAIN_RE = re.compile(r'(?:^|-)p(\d+)\.');

"""Only allow even ports allocated to preview Vite servers (not odd API ports)."""
def _validate_port(port: int) -> bool {
    return PREVIEW_MIN_PORT <= port < PREVIEW_MAX_PORT and port % 2 == 0;
}

"""ASGI middleware that intercepts subdomain-based preview requests.

When Host header matches p{port}.jaseci.org, proxies the entire request
(HTTP or WebSocket) to localhost:{port}. Since each preview gets its own
origin, Vite root-absolute imports and HMR WebSockets work natively.
"""
class _SubdomainProxyMiddleware {
    def init(self: _SubdomainProxyMiddleware, app: Any) -> None {
        self.app = app;
        self._http_client = httpx.AsyncClient(timeout=30.0);
    }

    async def __call__(self: _SubdomainProxyMiddleware, scope: dict, receive: Any, send: Any) -> None {
        if scope.get("type") not in ["http", "websocket"] {
            await self.app(scope, receive, send);
            return;
        }
        host_val = "";
        for header_pair in scope.get("headers", []) {
            if header_pair[0] == b"host" {
                host_val = header_pair[1].decode("utf-8", errors="replace");
                break;
            }
        }
        subdomain_match = _SUBDOMAIN_RE.search(host_val);
        if not subdomain_match {
            await self.app(scope, receive, send);
            return;
        }
        port_num = int(subdomain_match.group(1));
        if not _validate_port(port_num) {
            await self.app(scope, receive, send);
            return;
        }
        if scope.get("type") == "websocket" {
            await self._proxy_ws(scope, receive, send, port_num);
        } else {
            await self._proxy_http(scope, receive, send, port_num);
        }
    }

    async def _proxy_http(self: _SubdomainProxyMiddleware, scope: dict, receive: Any, send: Any, port: int) -> None {
        path = scope.get("path", "/");
        qs = scope.get("query_string", b"").decode("utf-8");
        target = f"http://localhost:{port}{path}";
        if qs {
            target += f"?{qs}";
        }
        req_headers: dict = {};
        for header_pair in scope.get("headers", []) {
            name = header_pair[0].decode("utf-8", errors="replace").lower();
            if name not in ["host", "transfer-encoding", "connection", "keep-alive"] {
                req_headers[name] = header_pair[1].decode("utf-8", errors="replace");
            }
        }
        body = b"";
        while True {
            message = await receive();
            chunk = message.get("body", b"");
            if chunk {
                body += chunk;
            }
            if not message.get("more_body", False) {
                break;
            }
        }
        method = scope.get("method", "GET");
        try {
            resp = await self._http_client.request(
                method=method,
                url=target,
                headers=req_headers,
                content=body,
                follow_redirects=False
            );
        } except httpx.ConnectError {
            await send({"type": "http.response.start", "status": 502, "headers": [[b"content-type", b"text/plain"]]});
            await send({"type": "http.response.body", "body": b"Preview server not running on this port"});
            return;
        }
        hop_headers = ["transfer-encoding", "connection", "keep-alive", "content-encoding", "content-length"];
        resp_headers: list = [];
        for item in resp.headers.items() {
            if item[0].lower() not in hop_headers {
                resp_headers.append([item[0].encode("utf-8"), item[1].encode("utf-8")]);
            }
        }
        await send({"type": "http.response.start", "status": resp.status_code, "headers": resp_headers});
        await send({"type": "http.response.body", "body": resp.content});
    }

    async def _proxy_ws(self: _SubdomainProxyMiddleware, scope: dict, receive: Any, send: Any, port: int) -> None {
        path = scope.get("path", "/");
        qs = scope.get("query_string", b"").decode("utf-8");
        target = f"ws://localhost:{port}{path}";
        if qs {
            target += f"?{qs}";
        }
        # ASGI requires receiving websocket.connect before accepting
        connect_event = await receive();
        if connect_event.get("type") != "websocket.connect" {
            return;
        }
        # Forward subprotocols from client (Vite requires "vite-hmr")
        subprotocols = scope.get("subprotocols", []);
        # Connect to backend with matching subprotocols
        try {
            backend = await websockets.connect(
                target,
                subprotocols=subprotocols,
                open_timeout=10
            );
        } except Exception as e {
            print(f"[WS-PROXY] backend unreachable: {e}");
            await send({"type": "websocket.close", "code": 1011});
            return;
        }
        # Accept client with the negotiated subprotocol
        accept_msg: dict = {"type": "websocket.accept"};
        if backend.subprotocol {
            accept_msg["subprotocol"] = backend.subprotocol;
        }
        await send(accept_msg);
        print(f"[WS-PROXY] connected port={port} path={path} subprotocol={backend.subprotocol}");
        try {
            async def client_to_backend() -> None {
                try {
                    while True {
                        message = await receive();
                        msg_type = message.get("type", "");
                        if msg_type == "websocket.receive" {
                            text = message.get("text");
                            if text is not None {
                                await backend.send(text);
                            } else {
                                data = message.get("bytes", b"");
                                if data {
                                    await backend.send(data);
                                }
                            }
                        } elif msg_type == "websocket.disconnect" {
                            break;
                        }
                    }
                } except Exception {
                    ;
                }
            }
            async def backend_to_client() -> None {
                try {
                    async for msg in backend {
                        if isinstance(msg, str) {
                            await send({"type": "websocket.send", "text": msg});
                        } else {
                            await send({"type": "websocket.send", "bytes": msg});
                        }
                    }
                } except Exception {
                    ;
                }
            }
            tasks = [asyncio.create_task(client_to_backend()),
                     asyncio.create_task(backend_to_client())];
            done_tasks = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED);
            for task in done_tasks[1] {
                task.cancel();
            }
        } except Exception as e {
            print(f"[WS-PROXY] error: {e}");
        } finally {
            try {
                await backend.close();
            } except Exception {
                ;
            }
            try {
                await send({"type": "websocket.close", "code": 1000});
            } except Exception {
                ;
            }
        }
    }
}

"""Register subdomain proxy middleware on the FastAPI app."""
def _register_preview_proxy(server: Any) -> None {
    app = server.server.app;
    app.add_middleware(_SubdomainProxyMiddleware);
    print("INFO - Registered subdomain preview proxy middleware");
}

"""JacAPIServer subclass that adds the subdomain preview proxy."""
obj JacBuilderAPIServer(JacAPIServer) {
    override def postinit -> None {
        super.postinit();
        _register_preview_proxy(self);
    }
}

"""Plugin that overrides get_api_server_class to return our subclass."""
obj JacBuilderPlugin {
    @hookimpl
    static def get_api_server_class -> type {
        return JacBuilderAPIServer;
    }
}

"""Register our plugin so it takes precedence (last registered wins with firstresult=True)."""
def _register_plugin() -> bool {
    plugin_manager.register(JacBuilderPlugin());
    return True;
}

glob _registered: bool = _register_plugin();
