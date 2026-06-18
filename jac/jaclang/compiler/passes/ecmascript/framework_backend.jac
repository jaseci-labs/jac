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
# Type-only: `ViewElement` is used solely in the `lower_view` signature. A
# runtime import would re-enter `get_compiler()` during the compiler bootstrap
# (this module is imported early by `esast_gen_pass`); backends import the View
# IR records lazily where they actually construct/inspect them.
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

"""Abstract base for per-framework lowering strategies."""
obj FrameworkBackend {
    def name -> str;
    def runtime_module -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    # Read seam (#6677) — lower a reactive value read at a value position.
    # No-op on hooks backends (bare identifier); signals backends wrap (`x()`).
    def lower_state_read(name: str) -> es.Expression;
    # View seam — lower a dynamic JSX position (expression child / dynamic
    # attribute value). No-op on hooks backends; signals backends thunk (`() => expr`).
    # Consumed *inside* `lower_view` (no longer pre-applied by the producer).
    def lower_view_expr(expr: es.Expression) -> es.Expression;
    # View IR seam ① — lower a neutral `ViewElement` tree to this backend's view
    # form. JS-family backends (React/Preact/Solid) build a `__jacJsx(...)` factory
    # call; a future Svelte backend builds template text. `sync_loc` is the pass's
    # location-stamper `(es_node, jac_node=...) -> es_node`, handed in so the
    # backend can carry each View IR node's provenance onto the ESTree it emits.
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression;
    # Runtime symbols required by each lower_* (for import injection)
    def state_field_symbols(s: StateField) -> list[str];
    def ref_field_symbols(r: RefField) -> list[str];
    def effect_symbols(e: Effect) -> list[str];
    def async_boundary_symbols(a: AsyncBoundary) -> list[str];
    # Framework view components a lowered tree references (control-flow nodes →
    # `<For>`/`<Show>` on Solid); empty on JS-family backends that render the
    # carried `js_fallback`. The pass injects these after `lower_view` runs.
    def view_runtime_symbols(view: ViewElement) -> list[str];
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
    # File-based-routing entry — assembles the router tree from the generated
    # `_routes.js` manifest and mounts it. `auth_redirect` is the login path an
    # unauthenticated `auth: true` visit bounces to; `has_app_wrapper` wraps the
    # router in the entry module's top-level `app` export when present.
    def build_pages_entry_script(
        entry_module: str, auth_redirect: str, has_app_wrapper: bool
    ) -> str;
}
