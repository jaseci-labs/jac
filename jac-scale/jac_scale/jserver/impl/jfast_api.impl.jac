import logging;

"""Helper function to convert TransportResponse to JSONResponse (similar to HTTPTransport.send)."""
def _convert_transport_response_to_json_response(
    transport_response: TransportResponse
) -> JSONResponse {
    import json;
    import from fastapi.responses { JSONResponse }
    import from jaclang.runtimelib.transport { TransportResponse }
    # Extract HTTP status from meta.extra or use defaults (same logic as HTTPTransport.send)
    status = 200 if transport_response.ok else 500;
    if transport_response.meta and transport_response.meta.extra {
        status = transport_response.meta.extra.get('http_status', status);
    }
    # Build response body following TransportResponse envelope pattern (same as HTTPTransport.send)
    response_body = {
        'ok': transport_response.ok,
        'type': transport_response.type,
        'data': transport_response.data,
        'error': None
    };
    # Serialize error if present
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
    # Include metadata if present
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

"""Custom logging handler that routes logs to jac-super console."""
class ConsoleLogHandler(logging.Handler) {
    """A logging handler that forwards log messages to jac-super's console."""
    def emit(self: ConsoleLogHandler, record: logging.LogRecord) {
        import from jaclang.cli.console { console }
        message = self.format(record);
        console.print(f"  {message}");
    }
}

"""Run the FastAPI server using Uvicorn.

If the specified port is in use, tries subsequent ports up to max_retries times.
"""
impl JFastApiServer.run_server(
    self: JFastApiServer, host: str = '0.0.0.0', port: int = 8000, max_retries: int = 10
) -> None {
    import from jaclang.cli.console { console }
    app = self.create_server();
    # Create custom handler for console logging
    console_handler = ConsoleLogHandler();
    console_handler.setFormatter(logging.Formatter("%(message)s"));
    # Suppress startup logs but route access logs through jac-super console
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
    current_port = port;
    for _ in range(max_retries) {
        try {
            if current_port != port {
                console.print(
                    f"  Port {port} is in use, using port {current_port} instead",
                    style="warning"
                );
            }
            uvicorn.run(app, host=host, port=current_port, log_config=log_config);
            return;
        } except SystemExit as e {
            # uvicorn raises SystemExit when port is in use
            # errno 98 = EADDRINUSE (Linux), errno 10048 = WSAEADDRINUSE (Windows)
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

"""Get the underlying FastAPI application instance."""
impl JFastApiServer.get_app(self: JFastApiServer) -> FastAPI {
    return self.app;
}

"""Create a Pydantic response model from configuration."""
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

"""Convert string type to Python type."""
impl JFastApiServer._get_python_type(
    self: JFastApiServer, type_string: str
) -> type[Any] {
    if (type_string.startswith("<class '") and type_string.endswith("'>")) {
        type_string = type_string[8:-2];
    }
    type_mapping: dict[(str, type[Any])] = {
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

"""Check whether a type is a user-defined Jac archetype (obj/node/edge)."""
def _is_jac_archetype(cls: Any) -> bool {
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

"""Recursively convert a validated Pydantic/dict payload into Jac obj instances."""
def _pydantic_to_jac(data: Any, jac_cls: Any) -> Any {
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
        # Union / Optional: pick the first non-None archetype arg if data is dict-like
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
        kwargs: dict[str, Any] = {};
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

"""Resolve a parameter type to a Pydantic-compatible Python type.

Uses the actual type object (type_obj) when available to handle custom Jac
obj types, generics (list[Obj], dict[str, Obj]), and Optional/Union. Falls
back to the primitive string mapping when type_obj is None.
"""
impl JFastApiServer._resolve_type(
    self: JFastApiServer, type_string: str, type_obj: Any = None
) -> Any {
    import from typing { get_origin, get_args, Union }
    import types;
    # Fast path: primitive string mapping
    primitive = self._get_python_type(type_string);
    if (type_obj is None) {
        return primitive;
    }
    # Direct Jac archetype -> dynamic Pydantic model
    if _is_jac_archetype(type_obj) {
        return self._build_pydantic_model(type_obj);
    }
    # Generic types: list[X], dict[K, V], Optional[X], Union[...]
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
    # Plain Python type (int, str, BaseModel subclass, Enum, etc.)
    if isinstance(type_obj, type) {
        return type_obj;
    }
    return primitive;
}

"""Build (and cache) a Pydantic model mirroring a Jac archetype's `has` fields.

Registers a `ForwardRef` in the cache before recursing so self-referential
types (e.g. `TreeNode` with `children: list[TreeNode]`) terminate; the
forward refs are resolved via `model_rebuild` once the real model exists.
"""
impl JFastApiServer._build_pydantic_model(
    self: JFastApiServer, jac_cls: Any
) -> type[BaseModel] {
    import from typing { get_type_hints, ForwardRef }
    model_name = jac_cls.__name__;
    cached = self._models.get(model_name);
    if cached is not None {
        return cached;
    }
    # Register a ForwardRef before recursing. Self-references inside this
    # archetype's fields will resolve to this ForwardRef and be resolved
    # by `model_rebuild` once the real model is registered.
    self._models[model_name] = ForwardRef(model_name);
    sig = inspect.signature(jac_cls.init);
    try {
        hints = get_type_hints(jac_cls.init);
    } except Exception {
        hints = {};
    }
    import dataclasses;
    dc_fields: dict[(str, Any)] = getattr(jac_cls, '__dataclass_fields__', {});
    fields: dict[str, Any] = {};
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
    # Resolve any ForwardRefs now that every referenced model is built.
    # Only pass fully-built models to the namespace (ForwardRef values in
    # the cache belong to models still in the middle of building).
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

"""Implementation of PATH parameter handler."""
impl PathParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    return f"{param.name}: {type_name} = Path(..., description='{description}')";
}

"""Implementation of QUERY parameter handler."""
impl QueryParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    if param.required {
        return f"{param.name}: {type_name} = Query(..., description='{description}')";
    } elif (param.default is None) {
        return f"{param.name}: Optional[{type_name}] = Query(description='{description}')";
    } else {
        return f"{param.name}: Optional[{type_name}] = Query({repr(
            param.default
        )}, description='{description}')";
    }
}

"""Implementation of HEADER parameter handler."""
impl HeaderParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    if param.required {
        return f"{param.name}: {type_name} = Header(..., description='{description}')";
    } elif (param.default is None) {
        return f"{param.name}: Optional[{type_name}] = Header(default=None, description='{description}')";
    } else {
        return f"{param.name}: Optional[{type_name}] = Header({repr(
            param.default
        )}, description='{description}')";
    }
}

"""Implementation of FILE parameter handler."""
impl FileParameterHandler.generate_param_string(param: APIParameter) -> str {
    description = param.description or '';
    is_multiple = 'list' in param.data_type.lower();
    if is_multiple {
        if param.required {
            return f"{param.name}: List[UploadFile] = File(..., description='{description}')";
        } else {
            return f"{param.name}: Optional[List[UploadFile]] = File(default=None, description='{description}')";
        }
    } else {
        if param.required {
            return f"{param.name}: UploadFile = File(..., description='{description}')";
        } else {
            return f"{param.name}: Optional[UploadFile] = File(default=None, description='{description}')";
        }
    }
}

"""Implementation of Form BODY parameter handler."""
impl FormBodyParameterHandler.generate_param_string(param: APIParameter) -> str {
    type_name = self.get_type_name(param);
    description = param.description or '';
    if param.required {
        return f"{param.name}: {type_name} = Form(..., description='{description}')";
    } elif (param.default is None) {
        return f"{param.name}: Optional[{type_name}] = Form(default=None, description='{description}')";
    } else {
        return f"{param.name}: Optional[{type_name}] = Form(default={repr(
            param.default
        )}, description='{description}')";
    }
}

"""Implementation of JSON BODY parameter handler - generate Pydantic model."""
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

"""Create the actual endpoint function with parameter injection."""
impl JFastApiServer._create_endpoint_function(
    self: JFastApiServer,
    callback: Callable[(..., Any)],
    parameters: list[APIParameter],
    dependencies: list[Any],
    request_model: (type[BaseModel] | None) = None
) -> Callable[..., Any] {
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
                        query_params = dict(__jac_request__.query_params);
                        if needs_request_no_params {
                            result = await callback(
                                **{'request': __jac_request__, ** query_params}
                            );
                        } else {
                            result = await callback(**query_params);
                        }
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(
                                result
                            );
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
                        query_params = dict(__jac_request__.query_params);
                        if needs_request_no_params {
                            result = callback(
                                **{'request': __jac_request__, ** query_params}
                            );
                        } else {
                            result = callback(**query_params);
                        }
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(
                                result
                            );
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
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(
                                result
                            );
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
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(
                                result
                            );
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
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(
                                result
                            );
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
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(
                                result
                            );
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
    # Group parameters by type
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
    # Initialize parameter strings and mapping
    param_strs: list[str] = [];
    param_mapping: dict[(str, str)] = {};
    needs_request = 'request' in sig.parameters;
    if accepts_kwargs {
        param_strs.append('__jac_request__: Request');
        param_mapping['__request__'] = '__jac_request__';
        # If the callback also explicitly accepts a request parameter, map it
        if needs_request {
            param_mapping['request'] = '__jac_request__';
        }
    } elif needs_request {
        param_strs.append('__jac_request__: Request');
        param_mapping['request'] = '__jac_request__';
    }
    # Create handler map
    has_file_params = len(file_params) > 0;
    handler_map: dict[(ParameterType, ParameterHandler)] = {
        ParameterType.PATH: PathParameterHandler(type_converter=self),
        ParameterType.QUERY: QueryParameterHandler(type_converter=self),
        ParameterType.HEADER: HeaderParameterHandler(type_converter=self),
        ParameterType.FILE: FileParameterHandler(type_converter=self)
    };
    # Handle body parameters using appropriate handler
    body_model: (type[BaseModel] | None) = None;
    use_request_model = request_model is not None;
    if use_request_model {
        # Use the provided Pydantic model directly as the request body
        body_model = request_model;
        param_strs.append('body_data: RequestBody');
        param_mapping['body_data'] = 'body_data';
    } elif (len(body_params) >= 1) {
        if has_file_params {
            # Use Form handler when files are present (multipart/form-data)
            form_handler = FormBodyParameterHandler(type_converter=self);
            for param in body_params {
                if param.name {
                    param_str = form_handler.generate_param_string(param);
                    param_strs.append(param_str);
                    param_mapping[param.name] = param.name;
                }
            }
        } else {
            # Use JSON body handler (Pydantic model)
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
    # Process other parameter types using their handlers
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
    # Map body-param names to their Jac type objects so the wrapper can
    # reconstruct archetype instances from validated Pydantic data.
    body_type_map: dict[str, Any] = {};
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
            # Pass the whole Pydantic model to the callback as body_data
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
    if accepts_kwargs {
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
        'Any': Any,
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

"""Get the default status code for an HTTP method."""
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

"""
Create and register a FastAPI route for the given endpoint.
Args:method (HTTPMethod): The HTTP method for the route
method (HTTPMethod): The HTTP method for the route
endpoint (JEndPoint): The endpoint configuration
"""
impl JFastApiServer._create_fastapi_route(
    self: JFastApiServer, method: HTTPMethod, endpoint: JEndPoint
) -> None {
    endpoint_func = self._create_endpoint_function(
        endpoint.callback,
        (endpoint.parameters or []),
        [],
        request_model=endpoint.request_model
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

"""
Create a complete FastAPI server with all endpoints registered.
This method executes all registered endpoints to create FastAPI routes
and returns the configured FastAPI application.

Returns:
FastAPI: The configured FastAPI application instance
"""
impl JFastApiServer.create_server(self: JFastApiServer) -> FastAPI {
    if not self.__server_created {
        self.execute();
        self.__server_created = True;
    }
    return self.app;
}

"""
Execute all endpoints by processing them through their respective HTTP method handlers.
Routes are sorted to ensure more specific paths are registered before generic ones
to avoid path matching conflicts.
"""
impl JFastApiServer.execute(self: JFastApiServer) -> None {
    self._endpoints = sorted(self._endpoints, key=self._route_priority);
    super.execute();
}


"""
Calculate route priority for sorting. More specific routes get higher priority (lower number).
Priority rules:
1. Static paths (no parameters) come first
2. Paths with fewer parameters come before paths with more parameters
3. Longer paths come before shorter paths
4. Alphabetical order for tie-breaking
"""
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

"""
Handle execution of a DELETE endpoint by registering it with FastAPI.
Args:
endpoint (JEndPoint): The DELETE endpoint to execute
Returns:
JFastApiServer: Self for method chaining
"""
impl JFastApiServer._delete(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.DELETE, endpoint);
    return self;
}

"""
Handle execution of a PATCH endpoint by registering it with FastAPI.
Args:
endpoint (JEndPoint): The PATCH endpoint to execute
Returns:
JFastApiServer: Self for method chaining
"""
impl JFastApiServer._patch(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.PATCH, endpoint);
    return self;
}

"""
Handle execution of a PUT endpoint by registering it with FastAPI.
Args:
endpoint (JEndPoint): The PUT endpoint to execute
Returns:
JFastApiServer: Self for method chaining
"""
impl JFastApiServer._put(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.PUT, endpoint);
    return self;
}

"""
Handle execution of a POST endpoint by registering it with FastAPI.
Args:
endpoint (JEndPoint): The POST endpoint to execute
Returns:
JFastApiServer: Self for method chaining
"""
impl JFastApiServer._post(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.POST, endpoint);
    return self;
}

"""
Handle execution of a GET endpoint by registering it with FastAPI.
Args:
endpoint (JEndPoint): The GET endpoint to execute
Returns:
JFastApiServer: Self for method chaining
"""
impl JFastApiServer._get(
    self: JFastApiServer, endpoint: JEndPoint
) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.GET, endpoint);
    return self;
}

impl JFastApiServer.set_user_manager(self: JFastApiServer, user_manager: Any) -> None {
    if user_manager is None {
        raise RuntimeError(
            "set_user_manager() called with None — jwt_validation_middleware will be "
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
        import from fastapi.responses { JSONResponse }
        authorization = request.headers.get('Authorization');
        token: (str | None) = None;
        username: (str | None) = None;
        user_root_id: (str | None) = None;
        token_attempted: bool = False;

        if authorization
        and isinstance(authorization, str)
        and authorization.startswith('Bearer ') {
            token = authorization[7:];
            token_attempted = True;

            if self._user_manager {
                username = self._user_manager.validate_jwt_token(token);

                if username {
                    user_root_id = self._user_manager.get_root_id(username);
                }
            }
        }

        if token_attempted and not username {
            return JSONResponse(
                status_code=401,
                content={
                    'ok': False,
                    'error': {'code': 'UNAUTHORIZED', 'message': 'Unauthorized'}
                }
            );
        }

        setattr(request.state, 'user_root_id', user_root_id);
        setattr(request.state, 'username', username);

        response = await call_next(request);
        return response;
    }

    async def request_context_middleware(request: Request, call_next: Callable) {
        ctx = JacRuntimeInterface.create_j_context(user_root=None);
        JacRuntime.set_request_context(ctx);

        user_id = getattr(request.state, 'user_root_id', None)
            if request?.state
            else None;

        if user_id {
            try {
                ctx.set_user_root(user_id);
            } except ValueError {
                logger.warning(f"Invalid user_root_id: {user_id}, using system root");
            }
        }

        try {
            response = await call_next(request);
            try {
                ctx.mem.commit();
            } except Exception as e {
                logger.error(
                    f"CRITICAL: Failed to commit request data: {e}. Request will fail.",
                    exc_info=True
                );
                raise;
            }

            return response;
        } finally {
            try {
                JacRuntime.clear_request_context();
            } except Exception as e {
                logger.warning(f"Failed to clear request context: {e}", exc_info=True);
            }
        }
    }

    # Starlette insert(0,...): last registered = index 0 = outermost = runs FIRST.
    # Register context first so JWT ends up at index 0 and runs before context.
    self.app.middleware('http')(request_context_middleware);
    self.app.middleware('http')(jwt_validation_middleware);
}
