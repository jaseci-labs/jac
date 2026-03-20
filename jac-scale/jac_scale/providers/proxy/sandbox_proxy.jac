import os;
import asyncio;
import logging;
import aiohttp;
import from aiohttp { WSMsgType, web }

def _setup_logging -> logging.Logger {
    logging.basicConfig(
        level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s"
    );
    return logging.getLogger("sandbox-proxy");
}

glob log = _setup_logging(),
     SANDBOX_NAMESPACE = os.environ.get("SANDBOX_NAMESPACE", "jac-sandboxes"),
     SANDBOX_LABEL = os.environ.get("SANDBOX_LABEL", "jac-sandbox=true"),
     INTERNAL_PORT = int(os.environ.get("INTERNAL_PORT", "8000")),
     PROXY_PORT = int(os.environ.get("PROXY_PORT", "8080")),
     routes: dict[str, dict] = {},
     _session: aiohttp.ClientSession | None = None,
     _ws_session: aiohttp.ClientSession | None = None;


async def watch_pods -> None {
    import from kubernetes_asyncio { client, config, watch }

    try {
        config.load_incluster_config();
    } except Exception {
        await config.load_kube_config();
    }

    v1 = client.CoreV1Api();
    w = watch.Watch();

    while True {
        try {
            log.info(f"Starting pod watch on {SANDBOX_NAMESPACE} ({SANDBOX_LABEL})");
            async for event in w.stream(
                v1.list_namespaced_pod,
                namespace=SANDBOX_NAMESPACE,
                label_selector=SANDBOX_LABEL,
                timeout_seconds=300
            ) {
                etype = event["type"];
                pod = event["object"];
                pod_ip = pod.status.pod_ip if pod.status else None;
                labels = pod.metadata.labels or {};
                sandbox_id = labels.get("jac-sandbox-id", pod.metadata.name);

                if etype == "DELETED" {
                    if routes.pop(sandbox_id, None) {
                        log.info(f"Removed route: {sandbox_id}");
                    }
                } elif pod_ip {
                    phase = pod.status.phase or "Unknown";
                    ready = False;
                    if pod.status.container_statuses {
                        for cs in pod.status.container_statuses {
                            if cs.name == "sandbox" and cs.ready {
                                ready = True;
                            }
                        }
                    }
                    old = routes.get(sandbox_id);
                    routes[sandbox_id] = {"ip": pod_ip, "phase": phase, "ready": ready};
                    if not old {
                        log.info(f"New route: {sandbox_id} -> {pod_ip} ({phase})");
                    }
                }
            }
        } except asyncio.CancelledError {
            raise;
        } except Exception as e {
            log.warning(f"Watch error: {e}, reconnecting in 3s...");
            await asyncio.sleep(3);
        }
    }
}

glob LOADING_HTML = '<!DOCTYPE html>\n<html><head>\n<meta charset="utf-8">\n<meta http-equiv="refresh" content="2">\n<style>\nbody { background: #0d0e11; color: #a1a1b0; font-family: system-ui;\n       display: flex; align-items: center; justify-content: center;\n       height: 100vh; margin: 0; }\n.loader { text-align: center; }\n.spinner { width: 32px; height: 32px; border: 3px solid #22232d;\n           border-top: 3px solid #f97316; border-radius: 50%;\n           animation: spin 1s linear infinite; margin: 0 auto 16px; }\n@keyframes spin { to { transform: rotate(360deg); } }\n</style>\n</head><body>\n<div class="loader">\n<div class="spinner"></div>\n<p>Starting preview server...</p>\n<p style="font-size:12px;color:#5c5c6e">This page will auto-refresh</p>\n</div>\n</body></html>';


def _get_sandbox_id(request: web.Request) -> str {
    host = request.host.split(":")[0];
    return host.split(".")[0];
}

async def _get_session -> aiohttp.ClientSession {
    global _session;
    if _session is None or _session.closed {
        _session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=30));
    }
    return _session;
}

async def _get_ws_session -> aiohttp.ClientSession {
    global _ws_session;
    if _ws_session is None or _ws_session.closed {
        _ws_session = aiohttp.ClientSession(timeout=aiohttp.ClientTimeout(total=None));
    }
    return _ws_session;
}

async def health(request: web.Request) -> web.Response {
    return web.Response(text=f"ok ({len(routes)} routes)");
}

def _wants_html(request: web.Request) -> bool {
    accept = request.headers.get("Accept", "");
    return "text/html" in accept;
}

async def handle_request(request: web.Request) -> web.Response {
    sandbox_id = _get_sandbox_id(request);
    route = routes.get(sandbox_id);
    is_nav = _wants_html(request);

    if not route {
        if is_nav {
            return web.Response(
                status=200, text=LOADING_HTML, content_type="text/html"
            );
        }
        return web.Response(status=502, text="Sandbox not found");
    }

    if not route["ready"] {
        if is_nav {
            return web.Response(
                status=200, text=LOADING_HTML, content_type="text/html"
            );
        }
        return web.Response(status=503, text="Sandbox starting");
    }

    if request.headers.get("Upgrade", "").lower() == "websocket" {
        return await handle_websocket(request, route["ip"]);
    }

    target = f"http://{route['ip']}:{INTERNAL_PORT}{request.path_qs}";
    try {
        session = await _get_session();
        headers = {
            k: v
            for (k, v) in request.headers.items()
            if k.lower() not in ("host", "transfer-encoding")
        };
        body = await request.read();
        async with session.request(
            request.method, target, headers=headers, data=body, allow_redirects=False
        ) as resp {
            if resp.status in (502, 503) and is_nav {
                return web.Response(
                    status=200, text=LOADING_HTML, content_type="text/html"
                );
            }
            resp_headers = {
                k: v
                for (k, v) in resp.headers.items()
                if k.lower() not in ("transfer-encoding", "connection")
            };
            return web.Response(
                status=resp.status, headers=resp_headers, body=await resp.read()
            );
        }
    } except Exception as e {
        log.warning(f"Proxy error for {sandbox_id}: {e}");
        if is_nav {
            return web.Response(
                status=200, text=LOADING_HTML, content_type="text/html"
            );
        }
        return web.Response(status=502, text=f"Proxy error: {e}");
    }
}

async def handle_websocket(request: web.Request, pod_ip: str) -> web.WebSocketResponse {
    protocols = [p for p in request.headers.getall("Sec-WebSocket-Protocol", [])];
    ws_client = web.WebSocketResponse(protocols=protocols);
    await ws_client.prepare(request);

    target = f"ws://{pod_ip}:{INTERNAL_PORT}{request.path_qs}";
    try {
        ws_session = await _get_ws_session();
        ws_headers = {};
        origin = request.headers.get("Origin");
        if origin {
            ws_headers["Origin"] = origin;
        }
        async with ws_session.ws_connect(
            target, protocols=protocols, headers=ws_headers
        ) as ws_backend {
            async def client_to_backend -> None {
                async for msg in ws_client {
                    if msg.type == WSMsgType.TEXT {
                        await ws_backend.send_str(msg.data);
                    } elif msg.type == WSMsgType.BINARY {
                        await ws_backend.send_bytes(msg.data);
                    } elif msg.type in (WSMsgType.CLOSE, WSMsgType.ERROR) {
                        await ws_backend.close();
                        break;
                    }
                }
            }
            async def backend_to_client -> None {
                async for msg in ws_backend {
                    if msg.type == WSMsgType.TEXT {
                        await ws_client.send_str(msg.data);
                    } elif msg.type == WSMsgType.BINARY {
                        await ws_client.send_bytes(msg.data);
                    } elif msg.type in (WSMsgType.CLOSE, WSMsgType.ERROR) {
                        await ws_client.close();
                        break;
                    }
                }
            }
            await asyncio.gather(
                client_to_backend(), backend_to_client(), return_exceptions=True
            );
        }
    } except Exception as e {
        log.warning(f"WS proxy error: {e}");
    }

    return ws_client;
}

async def on_startup(app: web.Application) -> None {
    app["watcher"] = asyncio.create_task(watch_pods());
    log.info(f"Sandbox proxy started on :{PROXY_PORT}");
}

async def on_cleanup(app: web.Application) -> None {
    app["watcher"].cancel();
    if _session and not _session.closed {
        await _session.close();
    }
    if _ws_session and not _ws_session.closed {
        await _ws_session.close();
    }
}

def create_app -> web.Application {
    app = web.Application();
    app.on_startup.append(on_startup);
    app.on_cleanup.append(on_cleanup);
    app.router.add_route("*", "/_proxy/health", health);
    app.router.add_route("*", "/{path_info:.*}", handle_request);
    return app;
}

glob app = create_app();

with entry {
    web.run_app(app, host="0.0.0.0", port=PROXY_PORT);
}
