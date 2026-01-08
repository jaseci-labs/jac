"""Introspects and caches module metadata."""
import from collections.abc { Callable }
import from typing { TYPE_CHECKING, Any }
import from jaclang.runtimelib.server.types { JsonValue }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.constructs { WalkerArchetype }
    }
}

"""Introspects and caches module metadata."""
obj ModuleIntrospector {
    has module_name: str,
        base_path: (str | None),
        _module: Any = None,
        _functions: dict[(str, Callable[(..., Any)])] = {},
        _walkers: dict[(str, type[WalkerArchetype])] = {},
        _client_functions: dict[(str, Callable[(..., Any)])] = {},
        _client_manifest: dict[(str, Any)] = {},
        _bundle: Any = None,
        _bundle_error: (str | None) = None,
        _bundle_builder: Any = None,
        _function_access: dict[(str, bool)] = {},
        _walker_access: dict[(str, bool)] = {};

    def postinit -> None;
    def load(force_reload: bool = False) -> None;
    def _load_manifest -> None;
    def _extract_access_levels -> None;
    def _collect_functions -> dict[str, Callable[(..., Any)]];
    def _collect_walkers -> dict[str, type[WalkerArchetype]];
    def get_functions -> dict[str, Callable[(..., Any)]];
    def get_walkers -> dict[str, type[WalkerArchetype]];
    def get_client_functions -> dict[str, Callable[(..., Any)]];
    def introspect_callable(func: Callable[(..., Any)]) -> dict[str, Any];
    def introspect_walker(walker_cls: type[WalkerArchetype]) -> dict[str, Any];
    def ensure_bundle -> str;
    def render_page(
        function_name: str, args: dict[(str, Any)], username: str
    ) -> dict[str, Any];

    def is_auth_required_for_function(func_name: str) -> bool;
    def is_auth_required_for_walker(walker_name: str) -> bool;
    def _collect_client_globals -> dict[str, Any];
}

