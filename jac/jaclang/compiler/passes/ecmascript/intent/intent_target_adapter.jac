import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.detection { ArchHasScanResult }
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    IntentLeaf,
    StateUpdate,
    Effect
}

obj IntentTargetAdapter {
    def apply_arch_has_scan(
        nd: uni.UniNode, scan: ArchHasScanResult
    ) -> list[IntentLeaf];

    def lower_state_update(nd: uni.UniNode, u: StateUpdate) -> (IntentLeaf | None);
    def lower_effect(nd: uni.UniNode, e: Effect) -> list[IntentLeaf];
}
