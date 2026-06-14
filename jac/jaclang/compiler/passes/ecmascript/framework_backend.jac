"""Pluggable backend interface for framework-specific lowering.

Each supported client framework (React, Preact, Solid, ...) implements
FrameworkBackend.  EsastGenPass emits framework-neutral reactive-intent records
and then calls the active backend to lower them to ESTree.
"""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

"""Abstract base for per-framework lowering strategies."""
obj FrameworkBackend {
    def name -> str;
    def runtime_module -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    # Runtime symbols required by each lower_* (for import injection)
    def state_field_symbols(s: StateField) -> list[str];
    def ref_field_symbols(r: RefField) -> list[str];
    def effect_symbols(e: Effect) -> list[str];
    def async_boundary_symbols(a: AsyncBoundary) -> list[str];
    # JSX factory name for shared EsJsxProcessor (v1: all backends use __jacJsx)
    def jsx_factory_name -> str;
    def import_source(symbol: str) -> str;
    def required_globals -> list[str];
    # Runtime source basename — selects framework-specific .cl.jac runtime
    def runtime_source_basename -> str;
    # Vite resolve aliases — framework-specific module remapping for the bundler
    def vite_aliases -> dict[str, str];
    # Vite plugin — returns (import_line, plugin_call) or None to skip plugin
    def vite_plugin_lines -> (tuple[str, str] | None);
    # Entry-point script — builds the JS bootstrap that mounts the app
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;
}
