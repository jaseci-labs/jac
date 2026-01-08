"""Route handlers for the API server."""
import from typing { Any }
import from jaclang.runtimelib.server.types { Response }
import from jaclang.runtimelib.server.introspector { ModuleIntrospector }
import from jaclang.runtimelib.server.execution_manager { ExecutionManager }
import from jaclang.runtimelib.server.user_manager { UserManager }

"""Base route handler."""
obj RouteHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;
}

"""Handle authentication routes."""
obj AuthHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    def create_user(username: str, password: str) -> Response;
    def login(username: str, password: str) -> Response;
}

"""Handle introspection routes."""
obj IntrospectionHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    def list_functions -> Response;
    def list_walkers -> Response;
    def get_function_info(name: str) -> Response;
    def get_walker_info(name: str) -> Response;
}

"""Handle execution routes."""
obj ExecutionHandler {
    has introspector: ModuleIntrospector,
        execution_manager: ExecutionManager,
        user_manager: UserManager;

    def call_function(name: str, args: dict[(str, Any)], username: str) -> Response;
    def spawn_walker(name: str, fields: dict[(str, Any)], username: str) -> Response;
}

