glob GRAPH_WRITING_RUNTIME_CALLS: set[str] = {
         "connect",
         "destroy",
         "disconnect",
         "grant",
         "revoke",
         "save",
         "spawn"
     };

glob MUTATING_METHODS: set[str] = {
         "add",
         "append",
         "clear",
         "discard",
         "extend",
         "insert",
         "pop",
         "popitem",
         "remove",
         "reverse",
         "setdefault",
         "sort",
         "update"
     };

obj GraphEffectScan {
    has evaluator: any = None,
        _memo: dict[int, bool] = {},
        _active: set[int] = set(),
        _aliasing: set[int] = set();

    def writes(owner: UniNode) -> bool;
    def _node_writes(nd: UniNode) -> bool;
    def _call_writes(call: FuncCall) -> bool;
    def _spawn_writes(operands: list[Expr]) -> bool;
    def _in_graph(expr: Expr) -> bool;
    def _type_of(expr: Expr) -> (TypeBase | None);
}

def graph_typed(t: (TypeBase | None)) -> bool;
def endpoint_effects(module: Module, evaluator: any) -> dict[str, dict[str, any]];
