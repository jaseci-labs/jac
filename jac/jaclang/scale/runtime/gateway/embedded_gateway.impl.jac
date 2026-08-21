impl EmbeddedGateway._service_prefixes -> list[str] {
    return [e.prefix for e in self.registry.entries.values()];
}


impl EmbeddedGateway._service_for_prefix(prefix: str) -> str {
    for (_name, `entry) in self.registry.entries.items() {
        if `entry.prefix == prefix {
            return `entry.name;
        }
    }
    return "";
}


impl EmbeddedGateway._call_member(
    service: str, remainder: str, payload: dict[str, any]
) -> Response | None {
    parts: list[str] = remainder.strip("/").split("/");
    if len(parts) < 2 {
        return None;
    }
    kind: str = parts[0];
    name: str = parts[1];
    try {
        if kind == "function" {
            result = self.transport.call_function(service, name, payload);
        } elif kind == "walker" {
            result = self.transport.call_walker(service, name, payload);
        } else {
            return None;
        }
    } except KeyError as e {
        return JSONResponse(
            status_code=404,
            content={
                "ok": False,
                "type": "error",
                "data": None,
                "error": {"code": "NOT_FOUND", "message": str(e)}
            }
        );
    } except Exception as e {
        _logger.error(f"in-process {kind} call {service}.{name} failed: {e}");
        return JSONResponse(
            status_code=500,
            content={
                "ok": False,
                "type": "error",
                "data": None,
                "error": {"code": "INTERNAL", "message": str(e)}
            }
        );
    }
    return JSONResponse(
        content={"ok": True, "type": "response", "data": {"result": result}}
    );
}


impl EmbeddedGateway._get_asset_table -> list[AssetRoot] {
    if self._asset_table is None {
        import from jaclang.runtimelib.serving.static_assets { asset_root_table }
        self._asset_table = asset_root_table(
            Path(self.base_path), Path(self.client_dist_dir), self.static_mounts
        );
    }
    return self._asset_table;
}

impl EmbeddedGateway._serve_static(path: str, accept: str) -> Response {
    import from jaclang.runtimelib.serving.static_assets {
        resolve_asset,
        asset_response
    }
    hit = resolve_asset(self._get_asset_table(), path);
    if hit is not None {
        (target, _) = hit;
        return asset_response(target);
    }

    dist = Path(self.client_dist_dir);
    rel: str = path.lstrip("/");
    index_file = dist / "index.html";
    if (rel == "" or "text/html" in accept) and index_file.is_file() {
        return Response(
            content=index_file.read_text(encoding="utf-8"), media_type="text/html"
        );
    }
    return JSONResponse(
        status_code=404,
        content={
            "ok": False,
            "type": "error",
            "data": None,
            "error": {"code": "NOT_FOUND", "message": f"Not found: {path}"}
        }
    );
}


impl EmbeddedGateway.dispatch(request: Request) -> Response {
    path: str = request.url.path;
    decision = classify_route(path, self._service_prefixes());
    if decision.kind == ROUTE_PROXY {
        service: str = self._service_for_prefix(decision.service);
        remainder: str = path[len(decision.service):];
        payload: dict[str, any] = {};
        try {
            body: bytes = request.body;
            if body {
                import json;
                payload = json.loads(body.decode("utf-8"));
            }
        } except Exception {
            payload = {};
        }
        resp = await self._call_member(service, remainder, payload);
        if resp is not None {
            return resp;
        }
    }
    accept: str = str(request.headers.get("accept") or "");
    return self._serve_static(path, accept);
}


impl EmbeddedGateway.setup -> None {
    app = ServingApp(title="Jac Embedded Gateway");
    gw = self;

    async def dispatcher(request: Request, call_next: object) -> Response {
        return await gw.dispatch(request);
    }

    app.add_middleware(dispatcher);
    self.middleware.install(app);

    self._get_asset_table();
    self.app = app;
}


impl EmbeddedGateway.serve -> None {
    if self.app is None {
        self.setup();
    }
    _logger.info(f"Embedded gateway serving in-process on {self.host}:{self.port}");
    import from jaclang.runtimelib.serving.server { ServingServer }
    serving = ServingServer(app=self.app, host=self.host, port=self.port);
    serving.run();
}
