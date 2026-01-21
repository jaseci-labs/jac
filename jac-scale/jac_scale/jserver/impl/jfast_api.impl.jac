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
        if getattr(transport_response.error, "code", None) {
            error_obj['code'] = transport_response.error.code;
        }
        if getattr(transport_response.error, "message", None) {
            error_obj['message'] = transport_response.error.message;
        }
        if getattr(transport_response.error, "details", None) is not None {
            error_obj['details'] = transport_response.error.details;
        }
        response_body['error'] = error_obj;
    }
    # Include metadata if present
    if transport_response.meta {
        meta_dict = {};
        if getattr(transport_response.meta, "request_id", None) {
            meta_dict['request_id'] = transport_response.meta.request_id;
        }
        if getattr(transport_response.meta, "trace_id", None) {
            meta_dict['trace_id'] = transport_response.meta.trace_id;
        }
        if getattr(transport_response.meta, "timestamp", None) {
            meta_dict['timestamp'] = transport_response.meta.timestamp;
        }
        if getattr(transport_response.meta, "extra", None) {
            meta_dict['extra'] = transport_response.meta.extra;
        }
        if meta_dict {
            response_body['meta'] = meta_dict;
        }
    }
    return JSONResponse(status_code=status, content=response_body);
}

"""Run the FastAPI server using Uvicorn."""
impl JFastApiServer.run_server(
    self: JFastApiServer, host: str = '0.0.0.0', port: int = 8000
) -> None {
    app = self.create_server();
    # Suppress INFO logs to avoid duplicate server messages (we show our own JAC DEV SERVER banner)
    uvicorn.run(app, host=host, port=port, log_level="warning");
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
        'list': <>list,
        'dict': <>dict,
        'object': <>dict
    };
    return type_mapping.get(type_string.lower(), str);
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
        return f"{param.name}: Optional[{type_name}] = Query({repr(param.default)}, description='{description}')";
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
        return f"{param.name}: Optional[{type_name}] = Header({repr(param.default)}, description='{description}')";
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
        param_type = self.type_converter._get_python_type(param.data_type);
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
    dependencies: list[Any]
) -> Callable[..., Any] {
    sig = inspect.signature(callback);
    accepts_kwargs = <>any(
        (p.kind == inspect.Parameter.VAR_KEYWORD) for p in sig.parameters.values()
    );
    if not parameters {
        if accepts_kwargs {
            if inspect.iscoroutinefunction(callback) {
                async def async_endpoint_wrapper(request: Request) -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        query_params = <>dict(request.query_params);
                        result = await callback(**query_params);
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e)) ;
                    }
                }
                return async_endpoint_wrapper;
            } else {
                def sync_endpoint_wrapper(request: Request) -> EndpointResponse {
                    import from jaclang.runtimelib.transport { TransportResponse }
                    try {
                        query_params = <>dict(request.query_params);
                        result = callback(**query_params);
                        # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                        if isinstance(result, TransportResponse) {
                            return _convert_transport_response_to_json_response(result);
                        }
                        return result;
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e)) ;
                    }
                }
                return sync_endpoint_wrapper;
            }
        } elif inspect.iscoroutinefunction(callback) {
            async def async_endpoint_wrapper__1 -> EndpointResponse {
                import from jaclang.runtimelib.transport { TransportResponse }
                try {
                    result = await callback();
                    # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                    if isinstance(result, TransportResponse) {
                        return _convert_transport_response_to_json_response(result);
                    }
                    return result;
                } except Exception as e {
                    raise e from HTTPException(status_code=500, detail=str(e)) ;
                }
            }
            return async_endpoint_wrapper__1;
        } else {
            def sync_endpoint_wrapper__1 -> EndpointResponse {
                import from jaclang.runtimelib.transport { TransportResponse }
                try {
                    result = callback();
                    # Automatically convert TransportResponse to JSONResponse (like HTTPTransport.send)
                    if isinstance(result, TransportResponse) {
                        return _convert_transport_response_to_json_response(result);
                    }
                    return result;
                } except Exception as e {
                    raise e from HTTPException(status_code=500, detail=str(e)) ;
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
        param_strs.append('request: Request');
        param_mapping['__request__'] = 'request';
    } elif needs_request {
        param_strs.append('request: Request');
        param_mapping['request'] = 'request';
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
    if (len(body_params) >= 1) {
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
    callback_args_lines: list[str] = [];
    if body_model {
        for param in body_params {
            param_name = param.name;
            if param_name {
                callback_args_lines.append(
                    f"        callback_args['{param_name}'] = body_data.{param_name}"
                );
            }
        }
        for name in param_mapping {
            if (name not in ('body_data', '__request__')) {
                callback_args_lines.append(f"        callback_args['{name}'] = {name}");
            }
        }
    } else {
        callback_args_lines = [
            f"        callback_args['{name}'] = {name}"
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
        for key, value in request.query_params.items():
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
        'Dict': <>dict,
        'List': <>list,
        'Any': Any,
        'int': int,
        'str': str,
        'float': float,
        'bool': bool,
        'list': <>list,
        'dict': <>dict,
        'TransportResponse': TransportResponse,
        '_convert_transport_response_to_json_response': _convert_transport_response_to_json_response,
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
        endpoint.callback, (endpoint.parameters or []), []
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
            and isinstance(return_type, <>type)
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
impl JFastApiServer._put(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
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
impl JFastApiServer._get(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
    self._create_fastapi_route(HTTPMethod.GET, endpoint);
    return self;
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
}
