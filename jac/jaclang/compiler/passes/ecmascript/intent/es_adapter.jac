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
import type from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
import from jaclang.compiler.passes.ecmascript.intent.collector { IntentCollector }
import from jaclang.compiler.passes.ecmascript.intent.detection { ArchHasScanResult }

obj EsIntentAdapter {
    has pass_ref: EsastGenPass,
        collector: IntentCollector;

    def backend -> FrameworkBackend;
    def lower_state_read(name: str) -> es.Expression;
    def lower_state_field(nd: uni.UniNode, s: StateField) -> list[es.Statement];
    def lower_ref_field(nd: uni.UniNode, r: RefField) -> list[es.Statement];
    def lower_state_update(nd: uni.UniNode, u: StateUpdate) -> es.Expression;
    def lower_effect(nd: uni.UniNode, e: Effect) -> list[es.Statement];
    def lower_async_boundary(nd: uni.UniNode, a: AsyncBoundary) -> es.Expression;
    def lower_view_symbols(nd: uni.UniNode, view: ViewElement) -> None;
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression;
    def apply_arch_has_scan(
        nd: uni.UniNode, scan: ArchHasScanResult
    ) -> list[es.Statement];
}
