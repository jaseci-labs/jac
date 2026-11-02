def _literal_names(value: (Expr | None)) -> (list[str] | None);

obj CallableKey {
    has owner: (UniScopeNode | None) = None,
        key: str = "";
}

def callable_key(sym: Symbol) -> CallableKey;

def _summary_strings(value: object) -> list[str];

walker EndpointEffectPass(TreePass) {
    static has contract: PassContract = PassContract();
    has _is_writer: bool = False,
        _unknown: bool = False,
        _declared_reads: set[str] = set(),
        _declared_writes: set[str] = set(),
        _assumptions: set[str] = set(),
        _touches: set[str] = set(),
        _visited: set[int] = set(),
        _recording: bool = False,
        _summaries: dict[int, dict[str, any]] = {},
        _summarizing: set[int] = set();

    can prepare with entry;
    can enter_ability with Ability entry;
    can enter_archetype with Archetype entry;
    can record_callables with Module exit;
    def _summary(ability: Ability) -> (dict[str, any] | None);
    def _served_effects(call: FuncCall) -> (dict[str, any] | None);
    def _apply(summary: dict[str, any], call: FuncCall);
    def _classify(
        body_nodes: list[UniNode],
        kind: str,
        name: str,
        declaration: Ability | None = None
    ) -> dict[str, any];

    def _scan(nd: (UniNode | None)) -> None;
    def _call_target_symbol(call: FuncCall) -> (Symbol | None);
    def _declared_effects(call: FuncCall) -> dict[str, list[str]] | None;
    def _declaration_effects(decl: Ability) -> dict[str, list[str]] | None;
    def _callee_ability(call: FuncCall) -> (Ability | None);
    def _callee_body(call: FuncCall) -> list[UniNode];
    def _resolved_body(owner: UniNode) -> list[UniNode];
}
