import os;

walker ImportWiringPass(CompilerPass) {
    static has contract: PassContract = PassContract(requires=(AnalysisFact.SYM_OF, ));

    can run_walk with Module entry;
    def _check_arch_module(mod: Module) -> None;
    def _check_scope(spec: WiringSpec, block: GraphImport, seen: set[int]) -> None;
    def _check_wire(spec: WiringSpec, wire: ImportWire) -> None;
    def _check_target(
        spec: WiringSpec, provider: str, provider_ok: bool, target: WireTarget
    ) -> None;

    def _check_rule_patterns(spec: WiringSpec, rule: ImportRule) -> None;
    def _check_edge(
        spec: WiringSpec,
        provider: str,
        consumer: str,
        names: (list[tuple[str, UniNode]] | None),
        at: UniNode,
        local: bool
    ) -> None;

    def _check_module(mod: Module, spec: WiringSpec) -> None;
    def _check_import(
        spec: WiringSpec,
        imp: Import,
        consumer: str,
        scope: (list[str] | None),
        declared: set[tuple[str, tuple[str, str, str, str]]]
    ) -> None;

    static def _written_import_fix(
        spec: WiringSpec,
        binding: WireBinding,
        consumer: str,
        held: (WireRec | None),
        positional: bool
    ) -> str;

    static def _rule_names(rules: list[RuleRec]) -> str;
}

obj UnusedBinding {
    has consumer: str,
        wire: WireRec,
        binding: WireBinding,
        at: UniNode;
}

obj ScopeReads {
    has mod: Module,
        owners: (dict[str, list[(Ability | ImplDef)]] | None) = None,
        read: dict[str, set[str]] = {};

    def names(scope: str) -> set[str];
}

def is_effect_binding(binding: WireBinding) -> bool;
def report_unused_wires(reporter: CompilerPass, mod: Module) -> None;
def unused_wire_bindings(mod: Module) -> list[UnusedBinding];
def names_read_in(body: UniNode, mod: Module) -> set[str];
