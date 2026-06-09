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

"""Capability flags advertised by a backend."""
obj BackendCaps {
    has memo: bool = False,
        cleanup: bool = True,
        async_boundary: bool = True;
}

"""Abstract base for per-framework lowering strategies."""
obj FrameworkBackend {
    def name -> str;
    def runtime_module -> str;
    def capabilities -> BackendCaps;

    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;

    # JSX factory name for shared EsJsxProcessor (v1: all backends use __jacJsx)
    def jsx_factory_name -> str;

    def import_source(symbol: str) -> str;
    def required_globals -> list[str];
}
