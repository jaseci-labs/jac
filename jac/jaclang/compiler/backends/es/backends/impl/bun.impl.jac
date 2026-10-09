import jaclang.compiler.backends.es.estree as es;
import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

import type from jaclang.compiler.backends.es.view_ir { ViewElement }
import from jaclang.compiler.frontend.diagnostics { E5017 }

def _unsupported(view: ViewElement, sync_loc: any) -> es.Expression {
    raise RuntimeError(f"[{E5017.code}] {E5017.format_message()}");
}

impl BunBackend.name -> str {
    return "bun";
}

impl BunBackend.runtime_module -> str {
    return "./server_runtime.js";
}

impl BunBackend.jsx_factory_name -> str {
    return "";
}

impl BunBackend.lowers_fragments_natively -> bool {
    return False;
}

impl BunBackend.import_source(symbol: str) -> str {
    return "./server_runtime.js";
}

impl BunBackend.required_globals -> list[str] {
    return [];
}

impl BunBackend.runtime_source_basename -> str {
    return "server_runtime.jac";
}

impl BunBackend.vite_aliases -> dict[str, str] {
    return {};
}

impl BunBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return None;
}

impl BunBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    return (
        'import { startBunServer } from "./server_runtime.js";\n'
        + '// Bun service bootstrap is emitted as server.mjs by the server builder.\n'
    );
}

impl BunBackend.build_pages_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    return self.build_entry_script(entry_module);
}

impl BunBackend.lower_state_field(s: StateField) -> list[es.Statement] {
    return [];
}

impl BunBackend.lower_ref_field(r: RefField) -> list[es.Statement] {
    return [];
}

impl BunBackend.lower_state_update(u: StateUpdate) -> es.Expression {
    return u.value;
}

impl BunBackend.lower_effect(e: Effect) -> list[es.Statement] {
    return [];
}

impl BunBackend.lower_async_boundary(a: AsyncBoundary) -> es.Expression {
    return a.try_expr;
}

impl BunBackend.lower_state_read(name: str) -> es.Expression {
    return es.Identifier(name=name);
}

impl BunBackend.lower_view_expr(expr: es.Expression) -> es.Expression {
    return expr;
}

impl BunBackend.lower_view(view: ViewElement, sync_loc: any) -> es.Expression {
    return _unsupported(view, sync_loc);
}

impl BunBackend.state_field_symbols(s: StateField) -> list[str] {
    return [];
}

impl BunBackend.ref_field_symbols(r: RefField) -> list[str] {
    return [];
}

impl BunBackend.effect_symbols(e: Effect) -> list[str] {
    return [];
}

impl BunBackend.async_boundary_symbols(a: AsyncBoundary) -> list[str] {
    return [];
}

impl BunBackend.view_runtime_symbols(view: ViewElement) -> list[str] {
    return [];
}
