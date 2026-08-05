import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.collector { IntentCollector }
import from jaclang.compiler.passes.ecmascript.intent.detection { ArchHasScanResult }
import from jaclang.compiler.passes.ecmascript.intent.intent_target_adapter {
    IntentTargetAdapter
}
import from jaclang.compiler.passes.ecmascript.intent.leaf_converter { LeafConverter }
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    IntentLeaf,
    StateUpdate
}

enum SkipExistingPolicy { NONE = "none", MODULE = "module" }

obj IntentSession {
    has collector: IntentCollector,
        adapter: IntentTargetAdapter,
        converter: LeafConverter,
        pass_ref: any = None,
        component_types: Sequence[str] = (),
        strict_arch_has: bool = False,
        use_arch_has_dedup: bool = True,
        skip_existing_policy: SkipExistingPolicy = SkipExistingPolicy.NONE,
        reactive_vars: set[str] = set(),
        reactive_vars_stack: list[set[str]] = [],
        _recorded_arch_has: set[int] = set();

    def enter_ability(nd: uni.Ability) -> None;
    def pop_ability_scope -> None;
    def arch_has_skip_existing -> set[str];
    def scan_arch_has(nd: uni.ArchHas) -> (ArchHasScanResult | None);
    def scan_state_update(nd: uni.Assignment) -> (StateUpdate | None);
    def lower_state_update(
        nd: uni.Assignment, update: StateUpdate
    ) -> (IntentLeaf | None);

    def record_and_lower_effect(nd: uni.Ability) -> list[IntentLeaf];
    def _sync_converter_reactive_vars -> None;
}
