glob GRAPH_WRITING_RUNTIME_CALLS: set[str] = {
         "assign_all",
         "build_edge",
         "clear_edges",
         "commit",
         "connect",
         "destroy",
         "disconnect",
         "grant",
         "perm_grant",
         "perm_revoke",
         "revoke",
         "save",
         "spawn"
     };

glob MUTATING_METHODS: set[str] = {
         "__delitem__",
         "__iadd__",
         "__setitem__",
         "add",
         "append",
         "clear",
         "difference_update",
         "discard",
         "extend",
         "insert",
         "intersection_update",
         "pop",
         "popitem",
         "remove",
         "reverse",
         "setdefault",
         "sort",
         "symmetric_difference_update",
         "update"
     };

glob ATTRIBUTE_WRITING_BUILTINS: set[str] = {"delattr", "setattr"};

enum GraphEffect {
    PURE = "pure",
    WRITES = "writes",
    UNKNOWN = "unknown"
}

obj GraphEffectScan {
    has evaluator: any = None,
        _memo: dict[int, GraphEffect] = {},
        _active: set[int] = set(),
        _aliasing: set[int] = set(),
        _cycle_hits: int = 0;

    def of_owner(owner: UniNode) -> GraphEffect;
    def _of_nodes(roots: list[UniNode]) -> GraphEffect;
    def _node_effect(nd: UniNode) -> GraphEffect;
    def _call_effect(call: FuncCall) -> GraphEffect;
    def _foreign_call_effect(call: FuncCall, origin: str) -> GraphEffect;
    def _spawn_effect(operands: list[Expr]) -> GraphEffect;
    def _delete_effect(stmt: DeleteStmt) -> GraphEffect;
    def _store_effect(target: Expr) -> GraphEffect;
    def _rooted(expr: Expr) -> GraphEffect;
    def _type_of(expr: Expr) -> (TypeBase | None);
}

def graph_type_effect(t: (TypeBase | None)) -> GraphEffect;
def owner_body(owner: UniNode) -> list[UniNode];
def call_symbol(call: FuncCall) -> (Symbol | None);
def effect_record(
    module: Module, kind: str, name: str, effect: GraphEffect
) -> dict[str, any];

def endpoint_effects(module: Module, evaluator: any) -> dict[str, dict[str, any]];
