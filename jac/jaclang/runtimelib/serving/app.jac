import asyncio;
import inspect;
import logging;
import traceback;
import from jaclang.runtimelib.serving.coerce {
    RequestValidationError,
    bind_parameters,
    body_param_name,
    coerce_value,
    get_callback_spec,
    filter_kwargs_for_callback
}
import from jaclang.runtimelib.serving.datatypes {
    HTTPError,
    JSONResponse,
    RedirectResponse,
    Request,
    Response,
    StreamingResponse,
    parse_query_string
}
import from jaclang.runtimelib.serving.endpoint { JEndPoint, WSEndPoint }
import from jaclang.runtimelib.serving.multipart {
    parse_multipart,
    parse_urlencoded_form
}
import from jaclang.runtimelib.serving.router { Router }
import from jaclang.runtimelib.serving.sse { sse_frame_stream }
import from jaclang.runtimelib.transport { TransportResponse }


glob _logger: logging.Logger = logging.getLogger("jaclang.runtimelib.serving.app");


def transport_to_response(tr: TransportResponse) -> JSONResponse {
    status = 200 if tr.ok else 500;
    if tr.meta and tr.meta.extra {
        status = tr.meta.extra.get('http_status', status);
    }
    body: dict[str, any] = {
        'ok': tr.ok,
        'type': tr.type,
        'data': tr.data,
        'error': None
    };
    if not tr.ok and tr.error {
        error_obj: dict[str, any] = {};
        if tr.error.code {
            error_obj['code'] = tr.error.code;
        }
        if tr.error.message {
            error_obj['message'] = tr.error.message;
        }
        if tr.error.details is not None {
            error_obj['details'] = tr.error.details;
        }
        body['error'] = error_obj;
    }
    if tr.meta {
        meta_dict: dict[str, any] = {};
        if tr.meta.request_id {
            meta_dict['request_id'] = tr.meta.request_id;
        }
        if tr.meta.trace_id {
            meta_dict['trace_id'] = tr.meta.trace_id;
        }
        if tr.meta.timestamp {
            meta_dict['timestamp'] = tr.meta.timestamp;
        }
        if tr.meta.extra {
            meta_dict['extra'] = {
                k: v
                for (k, v) in tr.meta.extra.items()
                if k != 'http_status'
            };
            if not meta_dict['extra'] {
                meta_dict.pop('extra');
            }
        }
        if meta_dict {
            body['meta'] = meta_dict;
        }
    }
    return JSONResponse(content=body, status_code=status);
}

def _slash_alternate(path: str) -> (str | None) {
    if path.endswith('/') and len(path) > 1 {
        return path.rstrip('/') or '/';
    }
    if path and not path.endswith('/') {
        return path + '/';
    }
    return None;
}


def _declares_body(ep: JEndPoint) -> bool {
    for param in (ep.parameters or []) {
        kind_name = str(param.kind.value) if param.kind?.value else str(param.kind);
        if kind_name in ('body', 'file') {
            return True;
        }
    }
    return False;
}

def _parse_request_body(request: Request, ep: JEndPoint) -> any {
    content_type = (request.headers.get('Content-Type') or '').lower();
    if not request.body {
        return None;
    }
    if 'multipart/form-data' in content_type {
        parse_multipart(request);
        return None;
    }
    if 'application/x-www-form-urlencoded' in content_type {
        parse_urlencoded_form(request);
        return None;
    }
    if 'application/json' in content_type or content_type == '' {
        try {
            return request.json_sync();
        } except Exception {
            if _declares_body(ep) {
                raise RequestValidationError(
                    errors=[
                        {
                            'type': 'json_invalid',
                            'loc': ['body'],
                            'msg': 'Invalid JSON body'
                        }
                    ]
                );
            }
            return None;
        }
    }
    return None;
}

obj ServingApp {
    has title: str = 'Jac API',
        version: str = '0.1.0',
        router: Router = Router(),
        middlewares: list[any] = [],
        on_shutdown: list[any] = [],
        docs_url: (str | None) = '/docs',
        openapi_url: (str | None) = '/openapi.json',
        openapi_security: dict[str, any] = {},
        openapi_cache: (dict | None) = None,
        state: dict[str, any] = {};

    def add_endpoint(ep: JEndPoint) {
        self.router.add(ep);
        self.openapi_cache = None;
    }

    def add_ws_endpoint(ep: WSEndPoint) {
        self.router.add_ws(ep);
    }

    def add_middleware(fn: Callable[..., any]) {
        self.middlewares.append(fn);
    }

    def add_shutdown_hook(fn: Callable[..., any]) {
        self.on_shutdown.append(fn);
    }

    def clear_routes {
        self.router.clear();
        self.openapi_cache = None;
    }

    def openapi -> dict[str, any] {
        import from jaclang.runtimelib.serving.openapi { build_openapi }
        return build_openapi(self);
    }

    async def shutdown {
        for hook in list(self.on_shutdown) {
            try {
                hook_fn: any = hook;
                result = hook_fn();
                if inspect.isawaitable(result) {
                    await result;
                }
            } except Exception {
                _logger.exception("shutdown hook failed");
            }
        }
    }

    async def dispatch(request: Request) -> Response {
        handler: any = self._route_and_call;
        for mw in self.middlewares {
            handler = self._wrap_middleware(mw, handler);
        }
        try {
            return await handler(request);
        } except RequestValidationError as ve {
            return JSONResponse(content={'detail': ve.errors}, status_code=422);
        } except HTTPError as he {
            return JSONResponse(
                content={'detail': he.detail}, status_code=he.status_code
            );
        } except Exception as exc {
            _logger.error(
                f"Unhandled error for {request.method} {request.url.path}\n"
                    + traceback.format_exc()
            );
            return JSONResponse(
                content={'error': f"{type(exc).__name__}: {exc}"}, status_code=500
            );
        }
    }

    def _wrap_middleware(
        mw: Callable[..., any], next_handler: Callable[..., any]
    ) -> Callable[..., any] {
        mw_fn: any = mw;
        next_fn: any = next_handler;

        async def _invoke(request: Request) -> Response {
            return await mw_fn(request, next_fn);
        }
        return _invoke;
    }

    async def _route_and_call(request: Request) -> Response {
        (ep, path_params, allowed) = self.router.resolve(
            request.method, request.url.path
        );
        if ep is None {
            if allowed {
                resp = JSONResponse(
                    content={'detail': 'Method Not Allowed'}, status_code=405
                );
                resp.headers.set('Allow', ', '.join(sorted(allowed)));
                return resp;
            }
            alt = _slash_alternate(request.url.path);
            if alt is not None
                and self.router.resolve(request.method, alt)[0] is not None {
                query = request.url.query;
                return RedirectResponse(
                    url=alt + (f"?{query}" if query else ''), status_code=307
                );
            }
            return JSONResponse(content={'detail': 'Not Found'}, status_code=404);
        }
        request.path_params = path_params;
        spec = get_callback_spec(ep);
        body_json = _parse_request_body(request, ep);
        kwargs = bind_parameters(ep, request, body_json);
        if ep.request_model is not None {
            body_name = body_param_name(spec, kwargs);
            if body_name is not None {
                try {
                    kwargs[body_name] = coerce_value(
                        body_json if body_json is not None else {}, ep.request_model
                    );
                } except RequestValidationError {
                    raise;
                } except Exception as e {
                    raise RequestValidationError(
                        errors=[{'type': 'invalid', 'loc': ['body'], 'msg': str(e)}]
                    );
                }
            }
        }
        kwargs = filter_kwargs_for_callback(spec, kwargs, request);
        callback_fn: any = ep.callback;
        if spec.is_async {
            result = await callback_fn(**kwargs);
        } else {
            def _call_sync -> any {
                return callback_fn(**kwargs);
            }
            result = await asyncio.to_thread(_call_sync);
            if inspect.isawaitable(result) {
                result = await result;
            }
        }
        return self._to_response(result, ep);
    }

    def _to_response(result: any, ep: JEndPoint) -> Response {
        if isinstance(result, Response) {
            return result;
        }
        if isinstance(result, TransportResponse) {
            if inspect.isgenerator(result.data) or inspect.isasyncgen(result.data) {
                return StreamingResponse(
                    content=sse_frame_stream(result.data),
                    media_type='text/event-stream',
                    headers={'Cache-Control': 'no-cache', 'X-Accel-Buffering': 'no'}
                );
            }
            resp = transport_to_response(result);
            if ep.status_code is not None and resp.status_code == 200 {
                resp.status_code = ep.status_code;
            }
            return resp;
        }
        if inspect.isgenerator(result) or inspect.isasyncgen(result) {
            return StreamingResponse(
                content=sse_frame_stream(result),
                media_type='text/event-stream',
                headers={'Cache-Control': 'no-cache', 'X-Accel-Buffering': 'no'}
            );
        }
        status = ep.status_code if ep.status_code is not None else 200;
        if ep.media_type {
            return Response(
                content=result, status_code=status, media_type=ep.media_type
            );
        }
        return JSONResponse(content=result, status_code=status);
    }
}
