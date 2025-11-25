from typing import Callable, Optional

from fastapi.middleware.cors import CORSMiddleware

from jac_scale.jserver.jfastApi import JFastApiServer
from jac_scale.jserver.jserver import APIParameter, HTTPMethod, JEndPoint, ParameterType

from jaclang.runtimelib.server import JacAPIServer as JServer
from jaclang.runtimelib.server import JsonValue


class JacAPIServer(JServer):

    def __init__(
        self,
        module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: str | None = None,
    ) -> None:
        super().__init__(module_name, session_path, port, base_path)
        self.server_impl = JFastApiServer([])

        # Configure CORS
        self.server_impl.app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],  # Allows all origins
            allow_credentials=True,
            allow_methods=["*"],  # Allows all methods
            allow_headers=["*"],  # Allows all headers
        )

    def login(self, username: str, password: str) -> tuple[int, JsonValue]:
        res = self.auth_handler.login(username, password)
        return res.status, res.body

    def register_login_endpoint(self) -> None:
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path="/user/login",
                callback=self.login,
                parameters=[
                    APIParameter(
                        name="username",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Username for login",
                        type=ParameterType.BODY,
                    ),
                    APIParameter(
                        name="password",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Password for login",
                        type=ParameterType.BODY,
                    ),
                ],
                response_model=None,
                tags=["User APIs"],
                summary="User login",
                description="Endpoint for user authentication and token generation",
            )
        )

    def create_user(self, username: str, password: str) -> tuple[int, JsonValue]:
        res = self.auth_handler.create_user(username, password)
        return res.status, res.body

    def register_create_user_endpoint(self) -> None:
        self.server_impl.add_endpoint(
            JEndPoint(
                method=HTTPMethod.POST,
                path="/user/create",
                callback=self.create_user,
                parameters=[
                    APIParameter(
                        name="username",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Username for new user",
                        type=ParameterType.BODY,
                    ),
                    APIParameter(
                        name="password",
                        data_type="string",
                        required=True,
                        default=None,
                        description="Password for new user",
                        type=ParameterType.BODY,
                    ),
                ],
                response_model=None,
                tags=["User APIs"],
                summary="Register user API.",
                description="Endpoint for creating a new user account",
            )
        )

    def create_walker_callback(
        self, walker_name: str, has_node_param: bool = False
    ) -> Callable[..., dict[str, JsonValue]]:

        def callback(
            node: Optional[str] = None, **kwargs: JsonValue
        ) -> dict[str, JsonValue]:
            if node:
                kwargs["_jac_spawn_node"] = node
            return self.execution_manager.spawn_walker(
                self.get_walkers()[walker_name], kwargs, "__guest__"
            )

        return callback

    def create_function_callback(
        self, func_name: str
    ) -> Callable[..., dict[str, JsonValue]]:
        def callback(**kwargs: JsonValue) -> dict[str, JsonValue]:
            print(f"Executing function '{func_name}' with params: {kwargs}")
            return self.execution_manager.execute_function(
                self.get_functions()[func_name], kwargs, "__guest__"
            )

        return callback

    def create_walker_parameters(
        self, walker_name: str, invoke_on_root: bool
    ) -> list[APIParameter]:
        parameters: list[APIParameter] = []
        walker_fields = self.introspector.introspect_walker(
            self.get_walkers()[walker_name]
        )["fields"]

        for field_name in walker_fields:

            if field_name == "_jac_spawn_node" and invoke_on_root:
                continue

            parameters.append(
                APIParameter(
                    name="node" if field_name == "_jac_spawn_node" else field_name,
                    data_type=walker_fields[field_name]["type"],
                    required=walker_fields[field_name]["required"],
                    default=walker_fields[field_name]["default"],
                    description=f"Field {field_name} for walker {walker_name}",
                    type=(
                        ParameterType.BODY
                        if field_name != "_jac_spawn_node"
                        else ParameterType.PATH
                    ),
                )
            )
        return parameters

    def create_function_parameters(self, func_name: str) -> list[APIParameter]:
        parameters: list[APIParameter] = []
        func_fields = self.introspector.introspect_callable(
            self.get_functions()[func_name]
        )["parameters"]
        for field_name in func_fields:
            parameters.append(
                APIParameter(
                    name=field_name,
                    data_type=func_fields[field_name]["type"],
                    required=func_fields[field_name]["required"],
                    default=func_fields[field_name]["default"],
                    description=f"Field {field_name} for function {func_name}",
                )
            )
        return parameters

    def start(self) -> None:

        self.register_create_user_endpoint()
        self.register_login_endpoint()

        # Register endpoints for each walker
        for walker_name in self.get_walkers():
            self.server_impl.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path=f"/walker/{walker_name}/{{node}}",
                    callback=self.create_walker_callback(
                        walker_name, has_node_param=True
                    ),
                    parameters=self.create_walker_parameters(
                        walker_name, invoke_on_root=False
                    ),
                    response_model=None,
                    tags=["Walkers"],
                    summary="API Entry",
                    description="API Entry",
                )
            )
            self.server_impl.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.POST,
                    path=f"/walker/{walker_name}",
                    callback=self.create_walker_callback(
                        walker_name, has_node_param=False
                    ),
                    parameters=self.create_walker_parameters(
                        walker_name, invoke_on_root=True
                    ),
                    response_model=None,
                    tags=["Walkers"],
                    summary="API Root",
                    description="API Root",
                )
            )

        # Register endpoints for each function
        for func_name in self.get_functions():
            self.server_impl.add_endpoint(
                JEndPoint(
                    method=HTTPMethod.GET,
                    path=f"/function/{func_name}",
                    callback=self.create_function_callback(func_name),
                    parameters=self.create_function_parameters(func_name),
                    response_model=None,
                    tags=["Functions"],
                    summary="This is a summary",
                    description="This is a description",
                )
            )

        if "__guest__" not in self.user_manager._users:
            self.user_manager.create_user("__guest__", "__no_password__")
        self.server_impl.run_server()
