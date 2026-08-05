import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.detection { ArchHasScanResult }
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    StateUpdate,
    Effect,
    IntentLeaf
}

impl ComposeIntentAdapter.apply_arch_has_scan(
    nd: uni.UniNode, scan: ArchHasScanResult
) -> list[IntentLeaf] {
    for r in scan.ref_fields {
        self.collector.record_ref_field(r);
    }
    for s in scan.state_fields {
        self.collector.record_state_field(s);
    }
    return [];
}

impl ComposeIntentAdapter.lower_state_update(
    nd: uni.UniNode, u: StateUpdate
) -> (IntentLeaf | None) {
    self.collector.record_state_update(u);
    return None;
}

impl ComposeIntentAdapter.lower_effect(nd: uni.UniNode, e: Effect) -> list[IntentLeaf] {
    self.collector.record_effect(e);
    return [];
}
