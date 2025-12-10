"""\nJFastApiServer: A FastAPI Implementation of JServer\n\nThis module provides a FastAPI-specific implementation of the JServer abstract base class.\nIt handles endpoint registration with FastAPI applications and provides all the FastAPI-specific\nfunctionality like parameter injection, response model generation, and route creation.\n\nKey Components:\n- JFastApiServer: FastAPI implementation of JServer\n- create_app(): Creates a basic FastAPI application for demonstration\n\nAdvanced Features:\n- Parameter injection with type conversion\n- Response model generation from JSON schema\n- Support for async/sync callback functions\n- Automatic OpenAPI documentation generation\n- Integration with JAC pass execution patterns\n"""
import inspect;
import from collections.abc { Callable }
import from typing { Any, Optional, TypeAlias, get_type_hints }
import uvicorn;
import from fastapi { Body, FastAPI, Header, HTTPException, Path, Query, Request }
import from fastapi.responses { Response }
import from pydantic { BaseModel, Field, create_model }
import from .jserver { APIParameter, HTTPMethod, JEndPoint, JServer, ParameterType }
with entry {
    EndpointResponse: TypeAlias = Response | BaseModel | <>dict[(str, object)] | <>list[
        object
    ] | str | <>bytes | None;
}

"""\n    A FastAPI implementation of JServer for programmatic endpoint creation.\n\n    JFastApiServer provides FastAPI-specific implementation of the JServer interface,\n    handling endpoint registration with FastAPI applications.\n\n    This class implements the JServer interface by:\n    - Storing registered endpoints internally\n    - Implementing HTTP method handlers (_get, _post, _put, _patch, _delete)\n    - Providing FastAPI app instance for server execution\n\n    Example:\n        >>> # Create server with endpoints\n        >>> endpoints = [\n        ...     JEndPoint(HTTPMethod.GET, "/users", get_users_callback),\n        ...     JEndPoint(HTTPMethod.POST, "/users", create_user_callback)\n        ... ]\n        >>> server = JFastApiServer(endpoints)\n        >>>\n        >>> # Execute to create FastAPI routes\n        >>> server.execute()\n        >>> app = server.create_server()\n\n    Attributes:\n        app (FastAPI): The underlying FastAPI application instance\n    """
class JFastApiServer(JServer[FastAPI]) {
    def __init__(
        self: JFastApiServer,
        endpoints: (list[JEndPoint] | None) = None,
        app: (FastAPI | None) = None
    ) -> None {
        super.init((endpoints or []));
        self.app = app or FastAPI();
        self._models: dict[(str, type[BaseModel])] = {};
        self.__server_created = False;
    }

    """\n        Handle execution of a GET endpoint by registering it with FastAPI.\n\n        Args:\n            endpoint (JEndPoint): The GET endpoint to execute\n\n        Returns:\n            JFastApiServer: Self for method chaining\n        """
    def _get(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
        self._create_fastapi_route(HTTPMethod.GET, endpoint);
        return self;
    }

    """\n        Handle execution of a POST endpoint by registering it with FastAPI.\n\n        Args:\n            endpoint (JEndPoint): The POST endpoint to execute\n\n        Returns:\n            JFastApiServer: Self for method chaining\n        """
    def _post(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
        self._create_fastapi_route(HTTPMethod.POST, endpoint);
        return self;
    }

    """\n        Handle execution of a PUT endpoint by registering it with FastAPI.\n\n        Args:\n            endpoint (JEndPoint): The PUT endpoint to execute\n\n        Returns:\n            JFastApiServer: Self for method chaining\n        """
    def _put(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
        self._create_fastapi_route(HTTPMethod.PUT, endpoint);
        return self;
    }

    """\n        Handle execution of a PATCH endpoint by registering it with FastAPI.\n\n        Args:\n            endpoint (JEndPoint): The PATCH endpoint to execute\n\n        Returns:\n            JFastApiServer: Self for method chaining\n        """
    def _patch(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
        self._create_fastapi_route(HTTPMethod.PATCH, endpoint);
        return self;
    }

    """\n        Handle execution of a DELETE endpoint by registering it with FastAPI.\n\n        Args:\n            endpoint (JEndPoint): The DELETE endpoint to execute\n\n        Returns:\n            JFastApiServer: Self for method chaining\n        """
    def _delete(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer' {
        self._create_fastapi_route(HTTPMethod.DELETE, endpoint);
        return self;
    }

    """\n        Calculate route priority for sorting. More specific routes get higher priority (lower number).\n\n        Priority rules:\n        1. Static paths (no parameters) come first\n        2. Paths with fewer parameters come before paths with more parameters\n        3. Longer paths come before shorter paths\n        4. Alphabetical order for tie-breaking\n        """
    def _route_priority(
        self: JFastApiServer, endpoint: JEndPoint
    ) -> tuple[int, int, str] {
        path = endpoint.path;
        param_count = path.count('{');
        segment_count = len(
            [
                seg
                for seg in path.split('/')
                if seg
            ]
        );
        priority = param_count;
        return (priority, -segment_count, path);
    }

    """\n        Execute all endpoints by processing them through their respective HTTP method handlers.\n\n        Routes are sorted to ensure more specific paths are registered before generic ones\n        to avoid path matching conflicts.\n        """
    def execute(self: JFastApiServer) -> None {
        self._endpoints = sorted(self._endpoints, key=self._route_priority);
        super.execute();
    }

    """\n        Create a complete FastAPI server with all endpoints registered.\n\n        This method executes all registered endpoints to create FastAPI routes\n        and returns the configured FastAPI application.\n\n        Returns:\n            FastAPI: The configured FastAPI application instance\n        """
    def create_server(self: JFastApiServer) -> FastAPI {
        if not self.__server_created {
            self.execute();
            self.__server_created = True;
        }
        return self.app;
    }

    """\n        Create and register a FastAPI route for the given endpoint.\n\n        Args:\n            method (HTTPMethod): The HTTP method for the route\n            endpoint (JEndPoint): The endpoint configuration\n        """
    def _create_fastapi_route(
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

    """Get the default status code for an HTTP method."""
    def _get_default_status_code(self: JFastApiServer, method: HTTPMethod) -> int {
        status_codes = {
            HTTPMethod.GET: 200,
            HTTPMethod.POST: 201,
            HTTPMethod.PUT: 200,
            HTTPMethod.PATCH: 200,
            HTTPMethod.DELETE: 204
        };
        return status_codes.get(method, 200);
    }

    """Create the actual endpoint function with parameter injection."""
    def _create_endpoint_function(
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
                    async def async_endpoint_wrapper(
                        request: Request
                    ) -> EndpointResponse {
                        try {
                            query_params = <>dict(request.query_params);
                            return await callback(**query_params);
                        } except Exception as e {
                            raise e from HTTPException(status_code=500, detail=str(e)) ;
                        }
                    }
                    return async_endpoint_wrapper;
                } else {
                    def sync_endpoint_wrapper(request: Request) -> EndpointResponse {
                        try {
                            query_params = <>dict(request.query_params);
                            return callback(**query_params);
                        } except Exception as e {
                            raise e from HTTPException(status_code=500, detail=str(e)) ;
                        }
                    }
                    return sync_endpoint_wrapper;
                }
            } elif inspect.iscoroutinefunction(callback) {
                async def async_endpoint_wrapper__1()  -> EndpointResponse {
                    try {
                        return await callback();
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e)) ;
                    }
                }
                return async_endpoint_wrapper__1;
            } else {
                def sync_endpoint_wrapper__1()  -> EndpointResponse {
                    try {
                        return callback();
                    } except Exception as e {
                        raise e from HTTPException(status_code=500, detail=str(e)) ;
                    }
                }
                return sync_endpoint_wrapper__1;
            }
        }
        body_params: list[APIParameter] = [];
        path_params: list[APIParameter] = [];
        query_params: list[APIParameter] = [];
        header_params: list[APIParameter] = [];
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
            }
        }
        param_strs: list[str] = [];
        param_mapping: dict[(str, str)] = {};
        if accepts_kwargs {
            param_strs.append('request: Request');
            param_mapping['__request__'] = 'request';
        }
        body_model: (type[BaseModel] | None) = None;
        if (len(body_params) >= 1) {
            model_fields: dict[(str, Any)] = {};
            for param in body_params {
                param_name = param.name;
                if not param_name {
                    continue;
                }
                param_type = self._get_python_type(param.data_type);
                required = param.required;
                description = param.description;
                if required {
                    model_fields[param_name] = (
                        param_type,
                        Field(..., description=description)
                    );
                } else {
                    default_value = param.default;
                    if (default_value is None) {
                        model_fields[param_name] = (
                            (param_type | None),
                            Field(description=description)
                        );
                    } else {
                        model_fields[param_name] = (
                            (param_type | None),
                            Field(default_value, description=description)
                        );
                    }
                }
            }
            if model_fields {
                body_model = create_model('RequestBody', **model_fields);
                param_strs.append('body_data: RequestBody');
                param_mapping['body_data'] = 'body_data';
            }
        }
        param_type_mapping = [
            (path_params, ParameterType.PATH),
            (query_params, ParameterType.QUERY),
            (header_params, ParameterType.HEADER)
        ];
        for (param_list, param_type_enum) in param_type_mapping {
            for param in param_list {
                param_name = param.name;
                if not param_name {
                    continue;
                }
                param_type_str = param.data_type;
                required = param.required;
                default_value = param.default;
                description = param.description;
                actual_type = self._get_python_type(param_type_str);
                type_name = actual_type.__name__;
                if (param_type_enum == ParameterType.PATH) {
                    param_str = f"{param_name}: {type_name} = Path(..., description='{description}')";
                } elif (param_type_enum == ParameterType.QUERY) {
                    if required {
                        param_str = f"{param_name}: {type_name} = Query(..., description='{description}')";
                    } elif (default_value is None) {
                        param_str = f"{param_name}: Optional[{type_name}] = Query(description='{description}')";
                    } else {
                        param_str = f"{param_name}: Optional[{type_name}] = Query({repr(
                            default_value
                        )}, description='{description}')";
                    }
                } elif (param_type_enum == ParameterType.HEADER) {
                    if required {
                        param_str = f"{param_name}: {type_name} = Header(..., description='{description}')";
                    } elif (default_value is None) {
                        param_str = f"{param_name}: Optional[{type_name}] = Header(description='{description}')";
                    } else {
                        param_str = f"{param_name}: Optional[{type_name}] = Header({repr(
                            default_value
                        )}, description='{description}')";
                    }
                } else {
                    continue;
                }
                param_strs.append(param_str);
                param_mapping[param_name] = param_name;
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
                    callback_args_lines.append(
                        f"        callback_args['{name}'] = {name}"
                    );
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
            'Request': Request,
            'Optional': Optional,
            'Field': Field,
            'create_model': create_model,
            'Dict': <>dict,
            'Any': Any,
            'int': int,
            'str': str,
            'float': float,
            'bool': bool,
            'list': <>list,
            'dict': <>dict
        };
        if body_model {
            exec_globals['RequestBody'] = body_model;
        }
        exec(func_code, exec_globals);
        return exec_globals['endpoint_wrapper'];
    }

    """Convert string type to Python type."""
    def _get_python_type(self: JFastApiServer, type_string: str) -> type[Any] {
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

    """Create a Pydantic response model from configuration."""
    def _create_response_model(
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

    """\n        Get the underlying FastAPI application instance.\n        """
    def get_app(self: JFastApiServer) -> FastAPI {
        return self.app;
    }

    """Run the FastAPI server using Uvicorn."""
    def run_server(
        self: JFastApiServer, host: str = '0.0.0.0', port: int = 8000
    ) -> None {
        app = self.create_server();
        uvicorn.run(app, host=host, port=port);
    }
}
