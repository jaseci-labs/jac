import logging;

def _convert_transport_response_to_json_response(
    transport_response: TransportResponse
) -> JSONResponse {
    import json;
    import from fastapi.responses { JSONResponse }
    import from jaclang.runtimelib.transport { TransportResponse }

    status = 200 if transport_response.ok else 500;
    if transport_response.meta and transport_response.meta.extra {
        status = transport_response.meta.extra.get('http_status', status);
    }

    response_body = {
        'ok': transport_response.ok,
        'type': transport_response.type,
        'data': transport_response.data,
        'error': None
    };

    if not transport_response.ok and transport_response.error {
        error_obj = {};
        if transport_response.error.code {
            error_obj['code'] = transport_response.error.code;
        }
        if transport_response.error.message {
            error_obj['message'] = transport_response.error.message;
        }
        if transport_response.error.details is not None {
            error_obj['details'] = transport_response.error.details;
        }
        response_body['error'] = error_obj;
    }

    if transport_response.meta {
        meta_dict = {};
        if transport_response.meta.request_id {
            meta_dict['request_id'] = transport_response.meta.request_id;
        }
        if transport_response.meta.trace_id {
            meta_dict['trace_id'] = transport_response.meta.trace_id;
        }
        if transport_response.meta.timestamp {
            meta_dict['timestamp'] = transport_response.meta.timestamp;
        }
        if transport_response.meta.extra {
            meta_dict['extra'] = transport_response.meta.extra;
        }
        if meta_dict {
            response_body['meta'] = meta_dict;
        }
    }
    return JSONResponse(status_code=status, content=response_body);
}

class ConsoleLogHandler(logging.Handler) {
    def emit(self: ConsoleLogHandler, record: logging.LogRecord) {
        import from jaclang.cli.console { console }
        message = self.format(record);
        console.print(f"  {message}");
    }
}

class HealthCheckFilter(logging.Filter) {
    _SUPPRESSED = {
        '"GET /docs HTTP',
        '"GET / HTTP',
        '"GET /openapi.json HTTP',
        '"GET /health HTTP',
        '"GET /healthz'
    };

    def filter(self: HealthCheckFilter, record: logging.LogRecord) -> bool {
        msg = record.getMessage();
        for pat in self._SUPPRESSED {
            if pat in msg {
                return False;
            }
        }
        return True;
    }
}

impl JFastApiServer.run_server(
    self: JFastApiServer, host: str = '0.0.0.0', port: int = 8000, max_retries: int = 10
) -> None {
    import from jaclang.cli.console { console }
    app = self.create_server();
    import from jaclang.scale.config.config_loader { get_scale_config }

    console_handler = ConsoleLogHandler();
    console_handler.setFormatter(logging.Formatter("%(message)s"));
    server_cfg = get_scale_config().get_server_config();
    if server_cfg.get('suppress_health_check_logs', False) {
        console_handler.addFilter(HealthCheckFilter());
    }

    log_config = {
        "version": 1,
        "disable_existing_loggers": False,
        "formatters": {
            "default": {"format": "%(message)s"},
            "access": {"format": "%(message)s"},

        },
        "handlers": {
            "default": {
                "formatter": "default",
                "class": "logging.StreamHandler",
                "stream": "ext://sys.stderr"
            },
            "access": {"()": lambda : console_handler },

        },
        "loggers": {
            "uvicorn": {
                "handlers": ["default"],
                "level": "WARNING",
                "propagate": False
            },
            "uvicorn.error": {"level": "WARNING", "propagate": False},
            "uvicorn.access": {
                "handlers": ["access"],
                "level": "INFO",
                "propagate": False
            },

        },

    };

    import from jaclang.scale.runtime.lifecycle.drain { install_signal_drain }
    ms_cfg = get_scale_config().get_microservices_config();
    drain_timeout: float = float(ms_cfg.get("drain_timeout_seconds", 10));

    prebound = self?._prebound_listen_socket;
    if prebound is not None {
        config = uvicorn.Config(
            app,
            host=host,
            port=port,
            log_config=log_config,
            timeout_graceful_shutdown=int(drain_timeout)
        );
        server = uvicorn.Server(config);
        install_signal_drain(server, timeout_s=drain_timeout);
        server.run(sockets=[prebound]);
        return;
    }
    current_port = port;
    for _ in range(max_retries) {
        try {
            if current_port != port {
                console.print(
                    f"  Port {port} is in use, using port {current_port} instead",
                    style="warning"
                );
            }
            config = uvicorn.Config(
                app,
                host=host,
                port=current_port,
                log_config=log_config,
                timeout_graceful_shutdown=int(drain_timeout)
            );
            server = uvicorn.Server(config);
            install_signal_drain(server, timeout_s=drain_timeout);
            server.run();
            return;
        } except SystemExit as e {
            if "Address already in use" in str(e)
            or "address already in use" in str(e) {
                current_port += 1;
            } else {
                raise;
            }
        } except OSError as e {
            if e.errno in (98, 10048) or "Address already in use" in str(e) {
                current_port += 1;
            } else {
                raise;
            }
        }
    }
    raise OSError(
        f"Could not find an available port after trying {port}-{current_port}"
    );
}

impl JFastApiServer.get_app(self: JFastApiServer) -> FastAPI {
    return self.app;
}

impl JFastApiServer._create_response_model(
    self: JFastApiServer, response_config: (dict[(str, Any)] | None) = None
) -> (type[BaseModel] | None) {
    if not response_config {
        return None;
    }
    model_name = response_config.get('name', 'ResponseModel');
    fields = response_config.get('fields', {});
    if not fields {
        return None;
    }
    pydantic_fields: dict[(str, Any)] = {};
    for (field_name, field_config) in fields.items() {
        field_type = self._get_python_type(field_config.get('type', 'str'));
        required = field_config.get('required', True);
        description = field_config.get('description', '');
        if required {
            pydantic_fields[field_name] = (
                field_type,
                Field(..., description=description)
            );
        } else {
            default_value = field_config.get('default');
            pydantic_fields[field_name] = (
                (field_type | None),
                Field(default_value, description=description)
            );
        }
    }
    model = create_model(model_name, **pydantic_fields);
    self._models[model_name] = model;
    return model;
}

impl JFastApiServer._get_python_type(
    self: JFastApiServer, type_string: str
) -> type[any] {
    if (type_string.startswith("<class '") and type_string.endswith("'>")) {
        type_string = type_string[8:-2];
    }
    type_mapping: dict[(str, type[any])] = {
        'str': str,
        'string': str,
        'int': int,
        'integer': int,
        'float': float,
        'number': float,
        'bool': bool,
        'boolean': bool,
        'list': `list,
        'dict': `dict,
        'object': `dict
    };
    return type_mapping.get(type_string.lower(), str);
}

def _is_jac_archetype(cls: any) -> bool {
    import from jaclang.jac0core.archetype { Archetype }
    try {
        return (
            isinstance(cls, type)
            and issubclass(cls, Archetype)
            and (not cls.__dict__.get('__jac_base__', False))
        );
    } except TypeError {
        return False;
    }
}

def _pydantic_to_jac(data: any, jac_cls: any) -> any {
    import from typing { get_type_hints, get_origin, get_args }
    import inspect;
    import from pydantic { BaseModel }
    if data is None {
        return None;
    }
    if isinstance(data, BaseModel) {
        data = data.model_dump();
    }
    origin = get_origin(jac_cls);
    if origin in (`list, list) {
        args = get_args(jac_cls);
        inner = args[0] if args else None;
        return [_pydantic_to_jac(item, inner) for item in data];
    }
    if origin in (`dict, dict) {
        args = get_args(jac_cls);
        v_type = args[1] if (len(args) > 1) else None;
        return {k: _pydantic_to_jac(v, v_type) for (k, v) in data.items()};
    }
    if origin is not None {
        for arg in get_args(jac_cls) {
            if (arg is type(None)) {
                continue;
            }
            if _is_jac_archetype(arg) and isinstance(data, dict) {
                return _pydantic_to_jac(data, arg);
            }
        }
        return data;
    }
    if _is_jac_archetype(jac_cls) and isinstance(data, dict) {
        hints = get_type_hints(jac_cls.init);
        sig = inspect.signature(jac_cls.init);
        kwargs: dict[str, any] = {};
        for (key, value) in data.items() {
            if (key not in sig.parameters) {
                continue;
            }
            field_type = hints.get(key);
            kwargs[key] = _pydantic_to_jac(value, field_type);
        }
        return jac_cls(**kwargs);
    }
    return data;
}

impl JFastApiServer._resolve_type(
    self: JFastApiServer, type_string: str, type_obj: any = None
) -> any {
    import from typing { get_origin, get_args, Union }
    import types;

    primitive = self._get_python_type(type_string);
    if (type_obj is None) {
        return primitive;
    }

    if _is_jac_archetype(type_obj) {
        return self._build_pydantic_model(type_obj);
    }

    origin = get_origin(type_obj);
    args = get_args(type_obj);
    if origin in (`list, list) {
        inner = args[0] if args else Any;
        resolved = self._resolve_type(getattr(inner, '__name__', str(inner)), inner);
        return (`list[resolved]);
    }
    if origin in (`dict, dict) {
        k = args[0] if args else str;
        v = args[1] if (len(args) > 1) else Any;
        resolved_k = self._resolve_type(getattr(k, '__name__', str(k)), k);
        resolved_v = self._resolve_type(getattr(v, '__name__', str(v)), v);
        return (`dict[resolved_k, resolved_v]);
    }
    if (origin is Union)
    or (types?.UnionType and isinstance(type_obj, types.UnionType)) {
        resolved_args = tuple(
            self._resolve_type(getattr(a, '__name__', str(a)), a) for a in args
        );
        return Union[resolved_args];
    }

    if isinstance(type_obj, type) {
        return type_obj;
    }
    return primitive;
}

impl JFastApiServer._build_pydantic_model(
    self: JFastApiServer, jac_cls: any
) -> type[BaseModel] {
    import from typing { get_type_hints, ForwardRef }
    model_name = jac_cls.__name__;
    cached = self._models.get(model_name);
    if cached is not None {
        return cached;
    }

    self._models[model_name] = ForwardRef(model_name);
    sig = inspect.signature(jac_cls.init);
    try {
        hints = get_type_hints(jac_cls.init);
    } except Exception {
        hints = {};
    }
    import dataclasses;
    dc_fields: dict[(str, Any)] = getattr(jac_cls, '__dataclass_fields__', {});
    fields: dict[str, any] = {};
    for (name, param) in sig.parameters.items() {
        if (name in ('self', 'args', 'kwargs')) {
            continue;
        }
        field_type_obj = hints.get(name, str);
        resolved = self._resolve_type(
            getattr(field_type_obj, '__name__', str(field_type_obj)), field_type_obj
        );
        if (param.default == inspect.Parameter.empty) {
            fields[name] = (resolved, Field(...));
        } else {
            dc_field = dc_fields.get(name);
            if (
                dc_field is not None
                and dc_field.default_factory is not dataclasses.MISSING
            ) {
                fields[name] = (
                    resolved,
                    Field(default_factory=dc_field.default_factory)
                );
            } else {
                fields[name] = (resolved, Field(default=param.default));
            }
        }
    }
    model = create_model(model_name, **fields);
    self._models[model_name] = model;

    namespace = {
        k: v
        for (k, v) in self._models.items()
        if isinstance(v, type)
    };
    try {
        model.model_rebuild(force=True, _types_namespace=namespace);
    } except Exception {
        ;
    }
    return model;
}

impl PathParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    return f"{param.name}: {type_name} = Path(..., description={repr(description)})";
}

impl QueryParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    if param.required {
        return f"{param.name}: {type_name} = Query(..., description={repr(
            description
        )})";
    } elif (param.default is None) {
        return f"{param.name}: Optional[{type_name}] = Query(description={repr(
            description
        )})";
    } else {
        return f"{param.name}: Optional[{type_name}] = Query({repr(
            param.default
        )}, description={repr(description)})";
    }
}

impl HeaderParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    if param.required {
        return f"{param.name}: {type_name} = Header(..., description={repr(
            description
        )})";
    } elif (param.default is None) {
        return f"{param.name}: Optional[{type_name}] = Header(default=None, description={repr(
            description
        )})";
    } else {
        return f"{param.name}: Optional[{type_name}] = Header({repr(
            param.default
        )}, description={repr(description)})";
    }
}

impl FileParameterHandler.generate_param_string(param: APIParameter) -> str {
    description = param.description or '';
    is_multiple = 'list' in param.data_type.lower();
    if is_multiple {
        if param.required {
            return f"{param.name}: List[UploadFile] = File(..., description={repr(
                description
            )})";
        } else {
            return f"{param.name}: Optional[List[UploadFile]] = File(default=None, description={repr(
                description
            )})";
        }
    } else {
        if param.required {
            return f"{param.name}: UploadFile = File(..., description={repr(
                description
            )})";
        } else {
            return f"{param.name}: Optional[UploadFile] = File(default=None, description={repr(
                description
            )})";
        }
    }
}

impl FormBodyParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    if param.required {
        return f"{param.name}: {type_name} = Form(..., description={repr(
            description
        )})";
    } elif (param.default is None) {
        return f"{param.name}: Optional[{type_name}] = Form(default=None, description={repr(
            description
        )})";
    } else {
        return f"{param.name}: Optional[{type_name}] = Form(default={repr(
            param.default
        )}, description={repr(description)})";
    }
}

impl JSONBodyParameterHandler.generate_body_model -> (type[BaseModel] | None) {
    model_fields: dict[(str, Any)] = {};
    for param in self.body_params {
        if not param.name {
            continue;
        }
        param_type = self.type_converter._resolve_type(param.data_type, param.type_obj);
        description = param.description or '';
        if param.required {
            model_fields[param.name] = (
                param_type,
                Field(..., description=description)
            );
        } else {
            if (param.default is None) {
                model_fields[param.name] = (
                    (param_type | None),
                    Field(description=description)
                );
            } else {
                model_fields[param.name] = (
                    (param_type | None),
                    Field(param.default, description=description)
                );
            }
        }
    }
    if model_fields {
        return create_model('RequestBody', **model_fields);
    }
    return None;
}

impl JFastApiServer._create_endpoint_function(
    self: JFastApiServer,
    callback: Callable[(..., Any)],
    parameters: list[APIParameter],
    dependencies: list[any],
    request_model: (type[BaseModel] | None) = None,
    forward_undeclared_query_params: bool = True
) -> Callable[..., any] {
    sig = inspect.signature(callback);
    accepts_kwargs = any(
        (p.kind == inspect.Parameter.VAR_KEYWORD) for p in sig.parameters.values()
    );
    needs_request_no_params = 'request' in sig.parameters;
    if not parameters and not request_model {
        if accepts_kwargs {
            if inspect.iscoroutinefunction(callback) {
                async def async_endpoint_wrapper(
                    __jac_request__: Request
                ) -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        query_params = dict(__jac_request__.query_params)
                            if forward_undeclared_query_params
                            else {};
                        if needs_request_no_params {
                            result = await callback(
                                **{'request': __jac_request__, ** query_params}
                            );
                        } else {
                            result = await callback(**query_params);
                        }

                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e));
                    }
                }
                return async_endpoint_wrapper;
            } else {
                def sync_endpoint_wrapper(
                    __jac_request__: Request
                ) -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        query_params = dict(__jac_request__.query_params)
                            if forward_undeclared_query_params
                            else {};
                        if needs_request_no_params {
                            result = callback(
                                **{'request': __jac_request__, ** query_params}
                            );
                        } else {
                            result = callback(**query_params);
                        }

                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e));
                    }
                }
                return sync_endpoint_wrapper;
            }
        } elif inspect.iscoroutinefunction(callback) {
            if needs_request_no_params {
                async def async_endpoint_wrapper__1(
                    __jac_request__: Request
                ) -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        result = await callback(**{'request': __jac_request__});

                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e));
                    }
                }
            } else {
                async def async_endpoint_wrapper__1 -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        result = await callback();

                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e));
                    }
                }
            }
            return async_endpoint_wrapper__1;
        } else {
            if needs_request_no_params {
                def sync_endpoint_wrapper__1(
                    __jac_request__: Request
                ) -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        result = callback(**{'request': __jac_request__});

                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e));
                    }
                }
            } else {
                def sync_endpoint_wrapper__1 -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        result = callback();

                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e));
                    }
                }
            }
            return sync_endpoint_wrapper__1;
        }
    }

    body_params: list[APIParameter] = [];
    path_params: list[APIParameter] = [];
    query_params: list[APIParameter] = [];
    header_params: list[APIParameter] = [];
    file_params: list[APIParameter] = [];
    for param in parameters {
        param_location = param.type;
        if (param_location == ParameterType.BODY) {
            body_params.append(param);
        } elif (param_location == ParameterType.PATH) {
            path_params.append(param);
        } elif (param_location == ParameterType.QUERY) {
            query_params.append(param);
        } elif (param_location == ParameterType.HEADER) {
            header_params.append(param);
        } elif (param_location == ParameterType.FILE) {
            file_params.append(param);
        }
    }

    param_strs: list[str] = [];
    param_mapping: dict[(str, str)] = {};
    needs_request = 'request' in sig.parameters;
    if accepts_kwargs {
        param_strs.append('__jac_request__: Request');
        param_mapping['__request__'] = '__jac_request__';

        if needs_request {
            param_mapping['request'] = '__jac_request__';
        }
    } elif needs_request {
        param_strs.append('__jac_request__: Request');
        param_mapping['request'] = '__jac_request__';
    }

    has_file_params = len(file_params) > 0;
    handler_map: dict[(ParameterType, ParameterHandler)] = {
        ParameterType.PATH: PathParameterHandler(type_converter=self),
        ParameterType.QUERY: QueryParameterHandler(type_converter=self),
        ParameterType.HEADER: HeaderParameterHandler(type_converter=self),
        ParameterType.FILE: FileParameterHandler(type_converter=self)
    };

    body_model: (type[BaseModel] | None) = None;
    use_request_model = request_model is not None;
    if use_request_model {
        body_model = request_model;
        param_strs.append('body_data: RequestBody');
        param_mapping['body_data'] = 'body_data';
    } elif (len(body_params) >= 1) {
        if has_file_params {
            form_handler = FormBodyParameterHandler(type_converter=self);
            for param in body_params {
                if param.name {
                    param_str = form_handler.generate_param_string(param);
                    param_strs.append(param_str);
                    param_mapping[param.name] = param.name;
                }
            }
        } else {
            json_handler = JSONBodyParameterHandler(
                type_converter=self, body_params=body_params
            );
            body_model = json_handler.generate_body_model();
            if body_model {
                param_strs.append('body_data: RequestBody');
                param_mapping['body_data'] = 'body_data';
            }
        }
    }

    param_groups = [
        (path_params, ParameterType.PATH),
        (query_params, ParameterType.QUERY),
        (header_params, ParameterType.HEADER),
        (file_params, ParameterType.FILE)
    ];
    for (param_list, param_type) in param_groups {
        handler = handler_map.get(param_type);
        if handler {
            for param in param_list {
                if param.name {
                    param_str = handler.generate_param_string(param);
                    param_strs.append(param_str);
                    param_mapping[param.name] = param.name;
                }
            }
        }
    }
    params = ', '.join(param_strs);

    body_type_map: dict[str, any] = {};
    for param in body_params {
        if param.name
        and (param.type_obj is not None)
        and (param.type_obj is not Any) {
            body_type_map[param.name] = param.type_obj;
        }
    }
    callback_args_lines: list[str] = [];
    if body_model {
        if use_request_model {
            callback_args_lines.append(
                "        callback_args['body_data'] = body_data"
            );
        } else {
            for param in body_params {
                param_name = param.name;
                if param_name {
                    if (param_name in body_type_map) {
                        callback_args_lines.append(
                            f"        callback_args['{param_name}'] = _pydantic_to_jac(body_data.{param_name}, _body_types['{param_name}'])"
                        );
                    } else {
                        callback_args_lines.append(
                            f"        callback_args['{param_name}'] = body_data.{param_name}"
                        );
                    }
                }
            }
        }
        for name in param_mapping {
            if (name not in ('body_data', '__request__')) {
                callback_args_lines.append(
                    f"        callback_args['{name}'] = {param_mapping[name]}"
                );
            }
        }
    } else {
        callback_args_lines = [
            f"        callback_args['{name}'] = {param_mapping[name]}"
            for name in param_mapping
            if (name != '__request__')
        ];
    }
    callback_args_str = '\n'.join(callback_args_lines);
    extra_query_params_code = '';
    if accepts_kwargs and forward_undeclared_query_params {
        declared_params = [
            p.name
            for p in parameters
            if p.name
        ];
        declared_params_str = repr(declared_params);
        extra_query_params_code = f"""
        # Extract additional query parameters not explicitly declared
        declared_params = set({declared_params_str})
        for key, value in __jac_request__.query_params.items():
            if key not in declared_params:
                callback_args[key] = value
""";
    }
    if inspect.iscoroutinefunction(callback) {
        func_code = f"""
async def endpoint_wrapper({params}):
    try:
        callback_args: Dict[str, Any] = {{}}
{callback_args_str}{extra_query_params_code}
        result = await callback(**callback_args)
        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
        if isinstance(result, TransportResponse):
            return _convert_transport_response_to_json_response(result)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
""";
    } else {
        func_code = f"""
def endpoint_wrapper({params}):
    try:
        callback_args: Dict[str, Any] = {{}}
{callback_args_str}{extra_query_params_code}
        result = callback(**callback_args)
        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
        if isinstance(result, TransportResponse):
            return _convert_transport_response_to_json_response(result)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
""";
    }
    exec_globals: dict[(str, Any)] = {
        'callback': callback,
        'HTTPException': HTTPException,
        'Query': Query,
        'Path': Path,
        'Body': Body,
        'Header': Header,
        'File': File,
        'Form': Form,
        'UploadFile': UploadFile,
        'Request': Request,
        'Optional': Optional,
        'Field': Field,
        'create_model': create_model,
        'Dict': `dict,
        'List': `list,
        'Any': any,
        'int': int,
        'str': str,
        'float': float,
        'bool': bool,
        'list': `list,
        'dict': `dict,
        'TransportResponse': TransportResponse,
        '_convert_transport_response_to_json_response': _convert_transport_response_to_json_response,
        '_pydantic_to_jac': _pydantic_to_jac,
        '_body_types': body_type_map,
        'isinstance': isinstance
    };
    if body_model {
        exec_globals['RequestBody'] = body_model;
    }
    exec(func_code, exec_globals);
    return exec_globals['endpoint_wrapper'];
}

impl JFastApiServer._get_default_status_code(
    self: JFastApiServer, method: HTTPMethod
) -> int {
    status_codes = {
        HTTPMethod.GET: 200,
        HTTPMethod.POST: 200,
        HTTPMethod.PUT: 200,
        HTTPMethod.PATCH: 200,
        HTTPMethod.DELETE: 204
    };
    return status_codes.get(method, 200);
}

impl JFastApiServer._create_fastapi_route(
    self: JFastApiServer, method: HTTPMethod, endpoint: JEndPoint
) -> None {
    endpoint_func = self._create_endpoint_function(
        endpoint.callback,
        (endpoint.parameters or []),
        [],
        request_model=endpoint.request_model,
        forward_undeclared_query_params=endpoint.forward_undeclared_query_params
    );
    route_kwargs: dict[(str, Any)] = {
        'response_model': endpoint.response_model,
        'status_code': self._get_default_status_code(method),
        'summary': (endpoint.summary or f"{method.value} {endpoint.path}"),
        'description': (
            endpoint.description or endpoint.callback.__doc__
                if endpoint.callback.__doc__
                else ''
        ),
        'tags': (endpoint.tags or [])
    };
    try {
        hints = get_type_hints(endpoint.callback);
        return_type = hints.get('return');
        if (
            return_type
            and isinstance(return_type, type)
            and issubclass(return_type, Response)
        ) {
            route_kwargs['response_class'] = return_type;
        }
    } except Exception {
        ;
    }
    if (method == HTTPMethod.GET) {
        self.app.get(endpoint.path, **route_kwargs)(endpoint_func);
    } elif (method == HTTPMethod.POST) {
        self.app.post(endpoint.path, **route_kwargs)(endpoint_func);
    } elif (method == HTTPMethod.PUT) {
        self.app.put(endpoint.path, **route_kwargs)(endpoint_func);
    } elif (method == HTTPMethod.PATCH) {
        self.app.patch(endpoint.path, **route_kwargs)(endpoint_func);
    } elif (method == HTTPMethod.DELETE) {
        self.app.delete(endpoint.path, **route_kwargs)(endpoint_func);
    }
}

impl JFastApiServer.create_server(self: JFastApiServer) -> FastAPI {
    if not self.__server_created {
        self.execute();
        self.__server_created = True;
    }
    return self.app;
}

impl JFastApiServer.execute(self: JFastApiServer) -> None {
    self._endpoints = sorted(self._endpoints, key=self._route_priority);
    super.execute();
}


impl JFastApiServer._route_priority(
    self: JFastApiServer, endpoint: JEndPoint
) -> tuple[int, int, int, str] {
    path = endpoint.path;
    is_catchall = ':path}' in path;
    param_count = path.count('{');
    segment_count = len(
        [
            seg
            for seg in path.split('/')
            if seg
        ]
    );
    catchall_priority = 1 if is_catchall else 0;
    priority = param_count;
    return (catchall_priority, priority, -segment_count, path);
}

impl JFastApiServer._delete(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.DELETE, endpoint);
    return self;
}

impl JFastApiServer._patch(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.PATCH, endpoint);
    return self;
}

impl JFastApiServer._put(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.PUT, endpoint);
    return self;
}

impl JFastApiServer._post(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.POST, endpoint);
    return self;
}

impl JFastApiServer._get(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.GET, endpoint);
    return self;
}

impl JFastApiServer.set_user_manager(self: JFastApiServer, user_manager: any) -> None {
    if user_manager is None {
        raise RuntimeError(
            "set_user_manager() called with None - jwt_validation_middleware will be "
            "non-functional and all authenticated requests will run as the guest user."
        );
    }
    self._user_manager = user_manager;
}

impl JFastApiServer.init(
    self: JFastApiServer,
    endpoints: (list[JEndPoint] | None) = None,
    app: (FastAPI | None) = None
) -> None {
    super.init((endpoints or []));
    self.app = app or FastAPI();
    self._models: dict[(str, type[BaseModel])] = {};
    self.__server_created = False;

    async def jwt_validation_middleware(request: Request, call_next: Callable) {
        authorization = request.headers.get('Authorization');
        username: (str | None) = None;
        user_root_id: (str | None) = None;

        if authorization
        and isinstance(authorization, str)
        and authorization.startswith('Bearer ') {
            token = authorization[7:];

            if self._user_manager {
                username = self._user_manager.validate_jwt_token(token);

                if username {
                    user_root_id = self._user_manager.get_root_id(username);
                }
            }
        }

        setattr(request.state, 'user_root_id', user_root_id);
        setattr(request.state, 'username', username);

        response = await call_next(request);
        return response;
    }

    async def request_context_middleware(request: Request, call_next: Callable) {
        import from jaclang.scale.memory.context { JScaleExecutionContext }
        ctx = JScaleExecutionContext();
        req_token = JacRuntime.push_request_context(ctx);

        import from jaclang.scale.runtime.context.auth_ctx {
            set_current_auth,
            reset_current_auth
        }
        auth_token = set_current_auth(request.headers.get('Authorization'));

        import from jaclang.scale.runtime.context.trace_ctx {
            set_current_trace,
            reset_current_trace,
            ensure_trace_id
        }
        import from jaclang.scale.runtime.context.log_emit {
            install_structured_logging
        }
        install_structured_logging();

        import from jaclang.scale.runtime.context.tracing {
            install_tracing,
            tracing_installed,
            start_server_span,
            end_span
        }
        if not tracing_installed() {
            import from jaclang.scale.config.config_loader { get_scale_config }
            _trc_cfg = get_scale_config().get_microservices_config().get("tracing", {});
            install_tracing(
                enabled=_trc_cfg.get("enabled", False),
                endpoint=_trc_cfg.get("endpoint"),
                sample_ratio=float(_trc_cfg.get("sample_ratio", 1.0))
            );
        }

        trace_id = ensure_trace_id(request.headers.get('X-Trace-Id'));
        trace_token = set_current_trace(trace_id);
        trace_span = start_server_span(
            f"{request.method} {request.url.path}",
            trace_id,
            request.headers.get("traceparent"),
            {"http.method": request.method, "http.target": request.url.path}
        );

        user_id = request.state?.user_root_id if request?.state else None;

        if user_id {
            try {
                await ctx.aset_user_root(user_id);
            } except ValueError {
                logger.warning(f"Invalid user_root_id: {user_id}, using system root");
            }
        }

        try {
            response = await call_next(request);

            if trace_id {
                response.headers["X-Trace-Id"] = trace_id;
            }

            if trace_span is not None {
                trace_span.set_attribute("http.status_code", response.status_code);
            }

            return response;
        } finally {
            try {
                JacRuntime.reset_request_context(req_token);
                ctx.close();
            } except Exception as e {
                logger.warning(f"Failed to clear request context: {e}", exc_info=True);
            }
            try {
                reset_current_auth(auth_token);
            } except Exception as e {
                logger.warning(f"Failed to reset auth context: {e}", exc_info=True);
            }
            try {
                end_span(trace_span);
            } except Exception as e {
                logger.warning(f"Failed to end trace span: {e}", exc_info=True);
            }
            try {
                reset_current_trace(trace_token);
            } except Exception as e {
                logger.warning(f"Failed to reset trace context: {e}", exc_info=True);
            }
        }
    }

    self.app.middleware('http')(request_context_middleware);
    self.app.middleware('http')(jwt_validation_middleware);

    import from jaclang.scale.runtime.lifecycle.drain { build_drain_middleware }
    self.app.middleware('http')(build_drain_middleware("service"));
}
