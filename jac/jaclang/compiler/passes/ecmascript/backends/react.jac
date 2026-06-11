"""React backend — lowers reactive-intent records to React hook ESTree."""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.framework_backend { FrameworkBackend }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

obj ReactBackend(FrameworkBackend) {
    def name -> str;
    def runtime_module -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    def jsx_factory_name -> str;
    def import_source(symbol: str) -> str;
    def required_globals -> list[str];
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;
    # Helpers reused across lower_* methods
    def _get_setter_name(var_name: str) -> str;
    def _jsx_fragment(children: list[es.Expression]) -> es.CallExpression;
}
