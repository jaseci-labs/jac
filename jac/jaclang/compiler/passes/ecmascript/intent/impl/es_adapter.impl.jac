import jaclang.compiler.passes.ecmascript.estree as es;
import jaclang.jac0core.unitree as uni;
import type from jaclang.compiler.passes.ecmascript.framework_backend {
    FrameworkBackend
}
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

impl EsIntentAdapter.backend -> FrameworkBackend {
    self.pass_ref._ensure_backend();
    backend = self.pass_ref.backend;
    if backend is None {
        raise RuntimeError("EsastGenPass backend not initialized");
    }
    return backend;
}

impl EsIntentAdapter.lower_state_read(name: str) -> es.Expression {
    return self.backend().lower_state_read(name);
}

impl EsIntentAdapter.lower_state_field(
    nd: uni.UniNode, s: StateField
) -> list[es.Statement] {
    self.collector.record_state_field(s);
    b = self.backend();
    for sym in b.runtime_symbols(s) {
        self.pass_ref._inject_runtime_import(sym, nd);
    }
    return b.lower_state_field(s);
}

impl EsIntentAdapter.lower_ref_field(
    nd: uni.UniNode, r: RefField
) -> list[es.Statement] {
    self.collector.record_ref_field(r);
    b = self.backend();
    for sym in b.runtime_symbols(r) {
        self.pass_ref._inject_runtime_import(sym, nd);
    }
    return b.lower_ref_field(r);
}

impl EsIntentAdapter.lower_state_update(
    nd: uni.UniNode, u: StateUpdate
) -> es.Expression {
    self.collector.record_state_update(u);
    return self.backend().lower_state_update(u);
}

impl EsIntentAdapter.lower_effect(nd: uni.UniNode, e: Effect) -> list[es.Statement] {
    self.collector.record_effect(e);
    b = self.backend();
    for sym in b.runtime_symbols(e) {
        self.pass_ref._inject_runtime_import(sym, nd);
    }
    return b.lower_effect(e);
}

impl EsIntentAdapter.lower_async_boundary(
    nd: uni.UniNode, a: AsyncBoundary
) -> es.Expression {
    self.collector.record_async_boundary(a);
    b = self.backend();
    for sym in b.runtime_symbols(a) {
        self.pass_ref._inject_runtime_import(sym, nd);
    }
    return b.lower_async_boundary(a);
}

impl EsIntentAdapter.lower_view_symbols(nd: uni.UniNode, view: ViewElement) -> None {
    b = self.backend();
    for sym in b.runtime_symbols(view) {
        self.pass_ref._inject_runtime_import(sym, nd);
    }
}

impl EsIntentAdapter.lower_view(view: ViewElement, sync_loc: any) -> es.Expression {
    self.collector.record_view(view);
    return self.backend().lower_view(view, sync_loc);
}

impl EsIntentAdapter.apply_arch_has_scan(
    nd: uni.UniNode, scan: ArchHasScanResult
) -> list[es.Statement] {
    stmts: list[es.Statement] = [];
    for r in scan.ref_fields {
        stmts.extend(self.lower_ref_field(nd, r));
    }
    for s in scan.state_fields {
        stmts.extend(self.lower_state_field(nd, s));
    }
    return stmts;
}
