"""Implementation of MicroserviceGateway."""

"""Resolve a service URL from sv_client registry for a given module name."""
impl MicroserviceGateway.resolve_service_url
(module_name: str) -> str | None {
    try {
        import from jaclang.runtimelib { sv_client }
        registry: dict = getattr(sv_client, "_registry", {});
        if module_name in registry {
            url: str = str(registry[module_name]);
            return url;
        }
    } except ImportError {
        logger.debug("sv_client not available");
    }
    return None;
}

"""Build the target URL by stripping the API prefix."""
impl MicroserviceGateway.build_target_url
(service_url: str, prefix: str, path: str, query: str) -> str {
    remaining: str = path[len(prefix):];
    if not remaining {
        remaining = "/";
    }
    target: str = f"{service_url}{remaining}";
    if query {
        target = f"{target}?{query}";
    }
    return target;
}

"""Serve a static file from client dist. Returns None if not found."""
impl MicroserviceGateway.serve_static
(file_path: str) -> Response | None {
    dist = Path(self.client_dist_dir);
    target = dist / file_path;

    try {
        resolved = target.resolve();
        dist_resolved = dist.resolve();
        if not str(resolved).startswith(str(dist_resolved)) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }

    if content_type.startswith("text/") or content_type in ("application/javascript", "application/json") {
        return Response(content=target.read_text(encoding="utf-8"), media_type=content_type);
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}

"""Serve index.html for SPA fallback. Returns None if not found."""
impl MicroserviceGateway.serve_spa_fallback
-> Response | None {
    index = Path(self.client_dist_dir) / "index.html";
    if index.is_file() {
        return HTMLResponse(content=index.read_text(encoding="utf-8"));
    }
    return None;
}

"""Bootstrap admin UI from pre-built bundle if needed."""
impl MicroserviceGateway.bootstrap_admin
-> None {
    admin_dist = Path(self.admin_dist_dir);
    if (admin_dist / "index.html").exists() {
        return;
    }
    try {
        import from jac_scale.admin { admin_portal }
        admin_file: str = admin_portal.__file__ or "";
        if not admin_file {
            logger.debug("No admin module file path, skipping admin UI bootstrap");
            return;
        }
        bundled = Path(admin_file).parent / "_dist";
        if bundled.exists() and (bundled / "index.html").exists() {
            logger.info("Deploying pre-built admin UI to gateway");
            admin_dist.mkdir(parents=True, exist_ok=True);
            for item in bundled.iterdir() {
                dest = admin_dist / item.name;
                if item.is_dir() {
                    if dest.exists() {
                        shutil.rmtree(dest);
                    }
                    shutil.copytree(item, dest);
                } else {
                    shutil.copy2(item, dest);
                }
            }
        }
    } except (ImportError, ModuleNotFoundError) {
        logger.debug("Admin module not available");
    }
}

"""Serve an admin asset. Returns None if not found."""
impl MicroserviceGateway.serve_admin_asset
(asset_path: str) -> Response | None {
    admin_dist = Path(self.admin_dist_dir);
    target = admin_dist / (asset_path if asset_path and asset_path != "/" else "index.html");

    try {
        if not str(target.resolve()).startswith(str(admin_dist.resolve())) {
            return None;
        }
    } except OSError {
        return None;
    }

    if not target.is_file() {
        index = admin_dist / "index.html";
        if index.is_file() {
            return HTMLResponse(content=index.read_text(encoding="utf-8"));
        }
        return None;
    }

    (content_type, _) = mimetypes.guess_type(str(target));
    if content_type is None {
        content_type = "application/octet-stream";
    }
    if content_type.startswith("text/") or content_type in ("application/javascript", "application/json") {
        return Response(content=target.read_text(encoding="utf-8"), media_type=content_type);
    }
    return Response(content=target.read_bytes(), media_type=content_type);
}

"""Create the FastAPI app and register the middleware."""
impl MicroserviceGateway.setup -> FastAPI {
    self.app = FastAPI(title="Jac Microservice Gateway");
    gw = self;

    self.bootstrap_admin();

    @self.app.middleware("http")
    async def proxy_middleware(request: Request, call_next: object) -> Response {
        path: str = request.url.path;

        # Health — aggregate service status
        if path == "/health" {
            service_status: dict[str, str] = {};
            for (module_name, prefix) in gw.routes.items() {
                url = gw.resolve_service_url(module_name);
                service_status[module_name] = url if url else "not registered";
            }
            return JSONResponse(status_code=200, content={
                "status": "healthy",
                "gateway": f"{gw.host}:{gw.port}",
                "services": service_status
            });
        }

        # Admin UI
        if path == "/admin" {
            import from fastapi.responses { RedirectResponse }
            return RedirectResponse(url="/admin/", status_code=302);
        }
        if path.startswith("/admin/") {
            admin_resp = gw.serve_admin_asset(path[7:]);
            if admin_resp {
                return admin_resp;
            }
        }

        # Built-in jac-scale routes — passthrough to any registered service
        is_builtin = path.startswith(("/user/", "/cl/", "/walker/", "/function/",
            "/sso/", "/api-key/", "/webhook/", "/ws/", "/jobs/")) or
            path in ("/user", "/healthz", "/graph", "/graph/data",
            "/metrics", "/docs", "/openapi.json");

        if is_builtin {
            fwd_headers: dict[str, str] = {};
            for (key, value) in request.headers.items() {
                if key.lower() not in HOP_BY_HOP_HEADERS {
                    fwd_headers[key] = value;
                }
            }
            body: bytes = await request.body();
            query = str(request.url.query);

            # Try each registered service until one responds with non-404
            for (module_name, prefix) in gw.routes.items() {
                svc_url = gw.resolve_service_url(module_name);
                if svc_url {
                    target = f"{svc_url}{path}";
                    if query {
                        target = f"{target}?{query}";
                    }
                    result = await raw_forward(request.method, target, fwd_headers, body);
                    if result is not None {
                        (sc, rh, rb) = result;
                        if sc != 404 {
                            return Response(status_code=sc, headers=rh, content=rb);
                        }
                    }
                }
            }
            return JSONResponse(status_code=404, content={"error": "Not found", "path": path});
        }

        # API proxy — match /api/{prefix}/* to service
        for (module_name, prefix) in gw.routes.items() {
            if path == prefix or path.startswith(prefix + "/") {
                svc_url = gw.resolve_service_url(module_name);
                if not svc_url {
                    return JSONResponse(status_code=503, content={
                        "error": f"Service '{module_name}' not registered"
                    });
                }

                target_url = gw.build_target_url(svc_url, prefix, path, str(request.url.query));
                logger.info(f"Proxy: {request.method} {path} -> {target_url}");

                fwd_headers: dict[str, str] = {};
                for (key, value) in request.headers.items() {
                    if key.lower() not in HOP_BY_HOP_HEADERS {
                        fwd_headers[key] = value;
                    }
                }
                client_addr: str = getattr(getattr(request, "client", None), "host", "unknown");
                fwd_headers["X-Forwarded-For"] = client_addr;

                body: bytes = await request.body();
                result = await raw_forward(request.method, target_url, fwd_headers, body);
                if result is None {
                    return JSONResponse(status_code=502, content={
                        "error": f"Failed to reach service '{module_name}'"
                    });
                }
                (sc, rh, rb) = result;
                return Response(status_code=sc, headers=rh, content=rb);
            }
        }

        # Static files (GET only)
        if request.method == "GET" {
            file_path: str = path.lstrip("/");
            if file_path {
                static_resp = gw.serve_static(file_path);
                if static_resp {
                    return static_resp;
                }
            }
            accept: str = request.headers.get("accept", "");
            if "text/html" in accept {
                fallback = gw.serve_spa_fallback();
                if fallback {
                    return fallback;
                }
            }
        }

        return JSONResponse(status_code=404, content={"error": "Not found", "path": path});
    }

    return self.app;
}

"""Start the gateway server (blocking)."""
impl MicroserviceGateway.start -> None {
    if self.app is None {
        self.setup();
    }

    # Startup banner
    print("");
    print("  ╔══════════════════════════════════════════════════╗");
    print("  ║           JAC MICROSERVICE GATEWAY               ║");
    print("  ╚══════════════════════════════════════════════════╝");
    print("");
    print(f"  Gateway:  http://{self.host}:{self.port}");
    print("");

    if self.routes {
        print("  Routes:");
        for (module_name, prefix) in self.routes.items() {
            svc_url = self.resolve_service_url(module_name);
            status_icon = "●" if svc_url else "○";
            url_str = svc_url if svc_url else "not registered";
            print(f"    {status_icon} {prefix:24s} → {module_name:20s} ({url_str})");
        }
    } else {
        print("  No routes configured.");
    }

    print("");

    import os;
    has_client = os.path.isfile(os.path.join(self.client_dist_dir, "index.html"));
    has_admin = os.path.isfile(os.path.join(self.admin_dist_dir, "index.html"));
    if has_client or has_admin {
        print("  Serving:");
        if has_client {
            print(f"    ● Client UI     → {self.client_dist_dir}");
        }
        if has_admin {
            print("    ● Admin         → /admin/");
        }
        print("");
    }

    print("  Endpoints:");
    print("    /health          Gateway + service status");
    print("    /admin/          Admin dashboard");
    print("    /api/<svc>/*     Proxy to service");
    print("    /user/*          Auth passthrough");
    print("    /*               Static files + SPA fallback");
    print("");
    print("  ─────────────────────────────────────────────────");
    print("");

    uvicorn.run(getattr(self, "app"), host=self.host, port=self.port);
}
