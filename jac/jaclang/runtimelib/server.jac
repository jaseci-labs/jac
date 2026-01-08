"""REST API Server for Jac Programs."""
import json;
import from collections.abc { Callable }
import from http.server { BaseHTTPRequestHandler, HTTPServer }
import from pathlib { Path }
import from typing { TYPE_CHECKING, Any }
import from urllib.parse { parse_qs, urlparse }
import from jaclang.runtimelib.server.types { Response }
import from jaclang.runtimelib.server.serializer { JacSerializer }
import from jaclang.runtimelib.server.user_manager { UserManager }
import from jaclang.runtimelib.server.execution_manager { ExecutionManager }
import from jaclang.runtimelib.server.introspector { ModuleIntrospector }
import from jaclang.runtimelib.server.response_builder { ResponseBuilder }
import from jaclang.runtimelib.server.handlers {
    AuthHandler,
    IntrospectionHandler,
    ExecutionHandler
}
import from jaclang { JacRuntime as Jac }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { WalkerArchetype }
    }
}

"""REST API Server for Jac programs."""
obj JacAPIServer {
    has module_name: str,
        session_path: str,
        port: int = 8000,
        base_path: (str | None) = None;

    def postinit -> None;
    def create_handler -> type[BaseHTTPRequestHandler];
    def load_module(force_reload: bool = False) -> None;
    @property
    def module -> object;

    def get_functions -> dict[str, Callable[(..., Any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def introspect_callable(func: Callable[(..., Any)]) -> dict[str, Any];
    def introspect_walker(walker_cls: type[WalkerArchetype]) -> dict[str, Any];
    def render_client_page(
        function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, Any];

    def get_client_bundle_code -> str;
    def print_endpoint_docs -> None;
    def start -> None;
}

"""Print comprehensive documentation for all endpoints that would be generated."""
def print_endpoint_docs(server: JacAPIServer) -> None;
