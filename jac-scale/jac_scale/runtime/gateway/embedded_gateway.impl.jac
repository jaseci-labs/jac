import uvicorn;


impl EmbeddedGateway._service_prefixes -> list[str] {
    return [e.prefix for e in self.registry.entries.values()];
}


impl EmbeddedGateway._service_for_prefix(prefix: str) -> str {
    for (_name, entry) in self.registry.entries.items() {
        if entry.prefix == prefix {
            return entry.name;
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


impl EmbeddedGateway._serve_static(path: str, accept: str) -> Response {
    dist = Path(self.client_dist_dir);
    rel: str = path.lstrip("/");
    if rel {
        candidate = dist / rel;
        try {
            resolved = candidate.resolve();

            if resolved.is_relative_to(dist.resolve()) and resolved.is_file() {
                ctype: str = mimetypes.guess_type(str(resolved))[0]
                or "application/octet-stream";
                return Response(content=resolved.read_bytes(), media_type=ctype);
            }
        } except OSError {
            ;
        }
    }

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
            body: bytes = await request.body();
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
    accept: str = request.headers.get("accept", "");
    return self._serve_static(path, accept);
}


impl EmbeddedGateway.setup -> None {
    app = FastAPI(title="Jac Embedded Gateway");
    gw = self;

    @app.middleware("http")
    async def dispatcher(request: Request, call_next: object) -> Response {
        return await gw.dispatch(request);
    }

    self.middleware.install(app);

    self.app = app;
}


impl EmbeddedGateway.serve -> None {
    if self.app is None {
        self.setup();
    }
    _logger.info(f"Embedded gateway serving in-process on {self.host}:{self.port}");
    config = uvicorn.Config(getattr(self, "app"), host=self.host, port=self.port);
    server = uvicorn.Server(config);
    server.run();
}
