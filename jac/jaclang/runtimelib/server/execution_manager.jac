"""Manages execution contexts for user operations."""
import from collections.abc { Callable }
import from typing { TYPE_CHECKING, Any }
import from jaclang.runtimelib.server.types { JsonValue }
import from jaclang.runtimelib.server.user_manager { UserManager }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { WalkerArchetype }
    }
}

"""Manages execution contexts for user operations."""
obj ExecutionManager {
    has session_path: str,
        user_manager: UserManager;

    def execute_function(
        func: Callable[(..., Any)], args: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue];

    def spawn_walker(
        walker_cls: type[WalkerArchetype], fields: dict[(str, Any)], username: str
    ) -> dict[str, JsonValue];
}

