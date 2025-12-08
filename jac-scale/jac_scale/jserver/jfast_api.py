"""
JFastApiServer: A FastAPI Implementation of JServer

This module provides a FastAPI-specific implementation of the JServer abstract base class.
It handles endpoint registration with FastAPI applications and provides all the FastAPI-specific
functionality like parameter injection, response model generation, and route creation.

Key Components:
- JFastApiServer: FastAPI implementation of JServer
- create_app(): Creates a basic FastAPI application for demonstration

Advanced Features:
- Parameter injection with type conversion
- Response model generation from JSON schema
- Support for async/sync callback functions
- Automatic OpenAPI documentation generation
- Integration with JAC pass execution patterns
"""

import inspect
from collections.abc import Callable
from typing import Any, Optional, TypeAlias, get_type_hints

import uvicorn
from fastapi import Body, FastAPI, Header, HTTPException, Path, Query, Request
from fastapi.responses import Response
from pydantic import BaseModel, Field, create_model

# Import from the separated jserver module
from .jserver import APIParameter, HTTPMethod, JEndPoint, JServer, ParameterType

# Type alias for FastAPI endpoint return values
EndpointResponse: TypeAlias = (
    Response | BaseModel | dict[str, object] | list[object] | str | bytes | None
)


class JFastApiServer(JServer[FastAPI]):
    """
    A FastAPI implementation of JServer for programmatic endpoint creation.

    JFastApiServer provides FastAPI-specific implementation of the JServer interface,
    handling endpoint registration with FastAPI applications.

    This class implements the JServer interface by:
    - Storing registered endpoints internally
    - Implementing HTTP method handlers (_get, _post, _put, _patch, _delete)
    - Providing FastAPI app instance for server execution

    Example:
        >>> # Create server with endpoints
        >>> endpoints = [
        ...     JEndPoint(HTTPMethod.GET, "/users", get_users_callback),
        ...     JEndPoint(HTTPMethod.POST, "/users", create_user_callback)
        ... ]
        >>> server = JFastApiServer(endpoints)
        >>>
        >>> # Execute to create FastAPI routes
        >>> server.execute()
        >>> app = server.create_server()

    Attributes:
        app (FastAPI): The underlying FastAPI application instance
    """

    def __init__(
        self, endpoints: list[JEndPoint] | None = None, app: FastAPI | None = None
    ) -> None:
        # Initialize with endpoints (empty list if none provided)
        super().__init__(endpoints or [])
        self.app = app or FastAPI()
        self._models: dict[str, type[BaseModel]] = {}
        self.__server_created = False

    def _get(self, endpoint: JEndPoint) -> "JFastApiServer":
        """
        Handle execution of a GET endpoint by registering it with FastAPI.

        Args:
            endpoint (JEndPoint): The GET endpoint to execute

        Returns:
            JFastApiServer: Self for method chaining
        """
        self._create_fastapi_route(HTTPMethod.GET, endpoint)
        return self

    def _post(self, endpoint: JEndPoint) -> "JFastApiServer":
        """
        Handle execution of a POST endpoint by registering it with FastAPI.

        Args:
            endpoint (JEndPoint): The POST endpoint to execute

        Returns:
            JFastApiServer: Self for method chaining
        """
        self._create_fastapi_route(HTTPMethod.POST, endpoint)
        return self

    def _put(self, endpoint: JEndPoint) -> "JFastApiServer":
        """
        Handle execution of a PUT endpoint by registering it with FastAPI.

        Args:
            endpoint (JEndPoint): The PUT endpoint to execute

        Returns:
            JFastApiServer: Self for method chaining
        """
        self._create_fastapi_route(HTTPMethod.PUT, endpoint)
        return self

    def _patch(self, endpoint: JEndPoint) -> "JFastApiServer":
        """
        Handle execution of a PATCH endpoint by registering it with FastAPI.

        Args:
            endpoint (JEndPoint): The PATCH endpoint to execute

        Returns:
            JFastApiServer: Self for method chaining
        """
        self._create_fastapi_route(HTTPMethod.PATCH, endpoint)
        return self

    def _delete(self, endpoint: JEndPoint) -> "JFastApiServer":
        """
        Handle execution of a DELETE endpoint by registering it with FastAPI.

        Args:
            endpoint (JEndPoint): The DELETE endpoint to execute

        Returns:
            JFastApiServer: Self for method chaining
        """
        self._create_fastapi_route(HTTPMethod.DELETE, endpoint)
        return self

    def _route_priority(self, endpoint: JEndPoint) -> tuple[int, int, str]:
        """
        Calculate route priority for sorting. More specific routes get higher priority (lower number).

        Priority rules:
        1. Static paths (no parameters) come first
        2. Paths with fewer parameters come before paths with more parameters
        3. Longer paths come before shorter paths
        4. Alphabetical order for tie-breaking
        """
        path = endpoint.path

        # Count path parameters (segments with {})
        param_count = path.count("{")

        # Count total path segments
        segment_count = len([seg for seg in path.split("/") if seg])

        # Static paths get priority 0, parameterized paths get priority based on param count
        priority = param_count

        # Secondary sort by negative segment count (longer paths first)
        # Tertiary sort by path string for consistency
        return (priority, -segment_count, path)

    def execute(self) -> None:
        """
        Execute all endpoints by processing them through their respective HTTP method handlers.

        Routes are sorted to ensure more specific paths are registered before generic ones
        to avoid path matching conflicts.
        """
        # Sort endpoints to prioritize specific paths over parameterized ones
        self._endpoints = sorted(self._endpoints, key=self._route_priority)
        super().execute()

    def create_server(self) -> FastAPI:
        """
        Create a complete FastAPI server with all endpoints registered.

        This method executes all registered endpoints to create FastAPI routes
        and returns the configured FastAPI application.

        Returns:
            FastAPI: The configured FastAPI application instance
        """
        if not self.__server_created:
            self.execute()
            self.__server_created = True
        return self.app

    def _create_fastapi_route(self, method: HTTPMethod, endpoint: JEndPoint) -> None:
        """
        Create and register a FastAPI route for the given endpoint.

        Args:
            method (HTTPMethod): The HTTP method for the route
            endpoint (JEndPoint): The endpoint configuration
        """
        # Create wrapper function with proper parameter handling
        endpoint_func = self._create_endpoint_function(
            endpoint.callback,
            endpoint.parameters or [],
            [],  # dependencies not yet implemented in JEndPoint
        )

        # Set up route options with proper typing
        route_kwargs: dict[str, Any] = {
            "response_model": endpoint.response_model,
            "status_code": self._get_default_status_code(method),
            "summary": endpoint.summary or f"{method.value} {endpoint.path}",
            "description": endpoint.description
            or (endpoint.callback.__doc__ if endpoint.callback.__doc__ else ""),
            "tags": endpoint.tags or [],
        }

        # Auto-detect response_class from callback return type annotation
        try:
            hints = get_type_hints(endpoint.callback)
            return_type = hints.get("return")
            # Check if return type is a Response subclass
            if (
                return_type
                and isinstance(return_type, type)
                and issubclass(return_type, Response)
            ):
                route_kwargs["response_class"] = return_type
        except Exception:
            # If we can't get type hints, that's okay - just skip auto-detection
            pass

        # Register the route with FastAPI
        if method == HTTPMethod.GET:
            self.app.get(endpoint.path, **route_kwargs)(endpoint_func)
        elif method == HTTPMethod.POST:
            self.app.post(endpoint.path, **route_kwargs)(endpoint_func)
        elif method == HTTPMethod.PUT:
            self.app.put(endpoint.path, **route_kwargs)(endpoint_func)
        elif method == HTTPMethod.PATCH:
            self.app.patch(endpoint.path, **route_kwargs)(endpoint_func)
        elif method == HTTPMethod.DELETE:
            self.app.delete(endpoint.path, **route_kwargs)(endpoint_func)

    def _get_default_status_code(self, method: HTTPMethod) -> int:
        """Get the default status code for an HTTP method."""
        status_codes = {
            HTTPMethod.GET: 200,
            HTTPMethod.POST: 201,
            HTTPMethod.PUT: 200,
            HTTPMethod.PATCH: 200,
            HTTPMethod.DELETE: 204,
        }
        return status_codes.get(method, 200)

    def _create_endpoint_function(
        self,
        callback: Callable[..., Any],
        parameters: list[APIParameter],
        dependencies: list[Any],
    ) -> Callable[..., Any]:
        """Create the actual endpoint function with parameter injection."""

        # Check if callback accepts **kwargs
        sig = inspect.signature(callback)
        accepts_kwargs = any(
            p.kind == inspect.Parameter.VAR_KEYWORD for p in sig.parameters.values()
        )

        # If no parameters, check if we should inject Request for query params
        if not parameters:
            if accepts_kwargs:
                # Callback accepts **kwargs, so inject Request to capture query params
                if inspect.iscoroutinefunction(callback):

                    async def async_endpoint_wrapper(
                        request: Request,
                    ) -> EndpointResponse:
                        try:
                            # Extract all query parameters and pass as kwargs
                            query_params = dict(request.query_params)
                            return await callback(**query_params)
                        except Exception as e:
                            raise HTTPException(status_code=500, detail=str(e)) from e

                    return async_endpoint_wrapper
                else:

                    def sync_endpoint_wrapper(request: Request) -> EndpointResponse:
                        try:
                            # Extract all query parameters and pass as kwargs
                            query_params = dict(request.query_params)
                            return callback(**query_params)
                        except Exception as e:
                            raise HTTPException(status_code=500, detail=str(e)) from e

                    return sync_endpoint_wrapper
            else:
                # No parameters and doesn't accept kwargs, simple wrapper
                if inspect.iscoroutinefunction(callback):

                    async def async_endpoint_wrapper__1() -> EndpointResponse:
                        try:
                            return await callback()
                        except Exception as e:
                            raise HTTPException(status_code=500, detail=str(e)) from e

                    return async_endpoint_wrapper__1
                else:

                    def sync_endpoint_wrapper__1() -> EndpointResponse:
                        try:
                            return callback()
                        except Exception as e:
                            raise HTTPException(status_code=500, detail=str(e)) from e

                    return sync_endpoint_wrapper__1

        # Group parameters by location
        body_params: list[APIParameter] = []
        path_params: list[APIParameter] = []
        query_params: list[APIParameter] = []
        header_params: list[APIParameter] = []

        for param in parameters:
            param_location = param.type
            if param_location == ParameterType.BODY:
                body_params.append(param)
            elif param_location == ParameterType.PATH:
                path_params.append(param)
            elif param_location == ParameterType.QUERY:
                query_params.append(param)
            elif param_location == ParameterType.HEADER:
                header_params.append(param)

        # Build parameter strings and their FastAPI annotations
        param_strs: list[str] = []
        param_mapping: dict[str, str] = {}

        # If callback accepts **kwargs, add Request parameter first (before any optional params)
        if accepts_kwargs:
            param_strs.append("request: Request")
            param_mapping["__request__"] = "request"

        # Handle body parameters - if multiple, create a single Body model
        body_model: type[BaseModel] | None = None

        if len(body_params) >= 1:
            # Always create a dynamic Pydantic model for body parameters
            model_fields: dict[str, Any] = {}
            for param in body_params:
                param_name = param.name
                if not param_name:
                    continue
                param_type = self._get_python_type(param.data_type)
                required = param.required
                description = param.description

                if required:
                    model_fields[param_name] = (
                        param_type,
                        Field(..., description=description),
                    )
                else:
                    default_value = param.default
                    # Don't use None as default, treat as optional without default
                    if default_value is None:
                        model_fields[param_name] = (
                            param_type | None,
                            Field(description=description),
                        )
                    else:
                        model_fields[param_name] = (
                            param_type | None,
                            Field(default_value, description=description),
                        )

            # Create the model
            if model_fields:
                body_model = create_model("RequestBody", **model_fields)  # type: ignore[misc]
                param_strs.append("body_data: RequestBody")
                param_mapping["body_data"] = "body_data"

        # Handle other parameter types (path, query, header)
        param_type_mapping = [
            (path_params, ParameterType.PATH),
            (query_params, ParameterType.QUERY),
            (header_params, ParameterType.HEADER),
        ]

        for param_list, param_type_enum in param_type_mapping:
            for param in param_list:
                param_name = param.name
                if not param_name:
                    continue

                param_type_str = param.data_type
                required = param.required
                default_value = param.default
                description = param.description

                # Convert string type to actual type
                actual_type = self._get_python_type(param_type_str)
                type_name = actual_type.__name__

                # Create parameter definition
                if param_type_enum == ParameterType.PATH:
                    # Path parameters cannot have defaults, so always required
                    param_str = f"{param_name}: {type_name} = Path(..., description='{description}')"
                elif param_type_enum == ParameterType.QUERY:
                    if required:
                        param_str = f"{param_name}: {type_name} = Query(..., description='{description}')"
                    else:
                        # Don't use None as default, treat as optional without default
                        if default_value is None:
                            param_str = f"{param_name}: Optional[{type_name}] = Query(description='{description}')"
                        else:
                            param_str = (
                                f"{param_name}: Optional[{type_name}] = "
                                f"Query({repr(default_value)}, description='{description}')"
                            )
                elif param_type_enum == ParameterType.HEADER:
                    if required:
                        param_str = f"{param_name}: {type_name} = Header(..., description='{description}')"
                    else:
                        # Don't use None as default, treat as optional without default
                        if default_value is None:
                            param_str = f"{param_name}: Optional[{type_name}] = Header(description='{description}')"
                        else:
                            param_str = (
                                f"{param_name}: Optional[{type_name}] = "
                                f"Header({repr(default_value)}, description='{description}')"
                            )
                else:
                    continue

                param_strs.append(param_str)
                param_mapping[param_name] = param_name

        # Create function signature
        params = ", ".join(param_strs)

        # Build callback arguments assignment
        callback_args_lines: list[str] = []
        if body_model:
            # Handle body model case
            for param in body_params:
                param_name = param.name
                if param_name:
                    callback_args_lines.append(
                        f"        callback_args['{param_name}'] = body_data.{param_name}"
                    )

            # Add other parameters (except __request__ which is used for query extraction)
            for name in param_mapping:
                if name not in ("body_data", "__request__"):
                    callback_args_lines.append(
                        f"        callback_args['{name}'] = {name}"
                    )
        else:
            # Handle normal case (except __request__ which is used for query extraction)
            callback_args_lines = [
                f"        callback_args['{name}'] = {name}"
                for name in param_mapping
                if name != "__request__"
            ]

        callback_args_str = "\n".join(callback_args_lines)

        # If callback accepts kwargs, add code to extract and merge query params
        extra_query_params_code = ""
        if accepts_kwargs:
            # Get the list of explicitly declared parameter names
            declared_params = [p.name for p in parameters if p.name]
            declared_params_str = repr(declared_params)
            extra_query_params_code = f"""
        # Extract additional query parameters not explicitly declared
        declared_params = set({declared_params_str})
        for key, value in request.query_params.items():
            if key not in declared_params:
                callback_args[key] = value
"""

        # Create function code
        if inspect.iscoroutinefunction(callback):
            func_code = f"""
async def endpoint_wrapper({params}):
    try:
        callback_args: Dict[str, Any] = {{}}
{callback_args_str}{extra_query_params_code}
        result = await callback(**callback_args)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
"""
        else:
            func_code = f"""
def endpoint_wrapper({params}):
    try:
        callback_args: Dict[str, Any] = {{}}
{callback_args_str}{extra_query_params_code}
        result = callback(**callback_args)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
"""

        # Prepare execution context
        exec_globals: dict[str, Any] = {
            "callback": callback,
            "HTTPException": HTTPException,
            "Query": Query,
            "Path": Path,
            "Body": Body,
            "Header": Header,
            "Request": Request,
            "Optional": Optional,
            "Field": Field,
            "create_model": create_model,
            "Dict": dict,
            "Any": Any,
            "int": int,
            "str": str,
            "float": float,
            "bool": bool,
            "list": list,
            "dict": dict,
        }

        # Add body model if created
        if body_model:
            exec_globals["RequestBody"] = body_model

        # Execute the function definition
        exec(func_code, exec_globals)

        return exec_globals["endpoint_wrapper"]

    def _get_python_type(self, type_string: str) -> type[Any]:
        """Convert string type to Python type."""
        # Handle actual type objects that were converted to strings like "<class 'int'>"
        if type_string.startswith("<class '") and type_string.endswith("'>"):
            # Extract the type name from "<class 'int'>" format
            type_string = type_string[8:-2]  # Remove "<class '" and "'>"
        type_mapping: dict[str, type[Any]] = {
            "str": str,
            "string": str,
            "int": int,
            "integer": int,
            "float": float,
            "number": float,
            "bool": bool,
            "boolean": bool,
            "list": list,
            "dict": dict,
            "object": dict,
        }
        return type_mapping.get(type_string.lower(), str)

    def _create_response_model(
        self, response_config: dict[str, Any] | None = None
    ) -> type[BaseModel] | None:
        """Create a Pydantic response model from configuration."""
        if not response_config:
            return None

        model_name = response_config.get("name", "ResponseModel")
        fields = response_config.get("fields", {})

        if not fields:
            return None

        # Convert field definitions to Pydantic field format
        pydantic_fields: dict[str, Any] = {}
        for field_name, field_config in fields.items():
            field_type = self._get_python_type(field_config.get("type", "str"))
            required = field_config.get("required", True)
            description = field_config.get("description", "")

            if required:
                pydantic_fields[field_name] = (
                    field_type,
                    Field(..., description=description),
                )
            else:
                default_value = field_config.get("default")
                pydantic_fields[field_name] = (
                    field_type | None,
                    Field(default_value, description=description),
                )

        # Create and cache the model
        model = create_model(model_name, **pydantic_fields)  # type: ignore[misc]
        self._models[model_name] = model
        return model

    def get_app(self) -> FastAPI:
        """
        Get the underlying FastAPI application instance.
        """
        return self.app

    def run_server(self, host: str = "0.0.0.0", port: int = 8000) -> None:
        """Run the FastAPI server using Uvicorn."""
        app = self.create_server()
        uvicorn.run(app, host=host, port=port)
