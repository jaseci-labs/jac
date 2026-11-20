glob PURE_BUILTINS: set[str] = {
         "abs",
         "all",
         "any",
         "bool",
         "dict",
         "enumerate",
         "float",
         "format",
         "frozenset",
         "getattr",
         "hasattr",
         "int",
         "isinstance",
         "len",
         "list",
         "max",
         "min",
         "print",
         "range",
         "repr",
         "reversed",
         "round",
         "set",
         "sorted",
         "str",
         "sum",
         "tuple",
         "type",
         "zip"
     };

glob READ_ONLY_METHODS: set[str] = {"copy", "count", "get", "index", "items", "keys", "values"};

glob IMMUTABLE_TYPES: list[str] = [
         "bool",
         "bytes",
         "complex",
         "float",
         "frozenset",
         "int",
         "NoneType",
         "str",
         "tuple"
     ];

glob FRESH_VALUES: tuple[type, ...] = (
         DictCompr,
         DictVal,
         FString,
         ListCompr,
         ListVal,
         Literal,
         MultiString,
         SetVal,
         TupleVal
     );

obj GraphEffectScan {
    has evaluator: any = None,
        modules: list[Module] = [],
        _memo: dict[int, bool] = {},
        _active: set[int] = set(),
        _reactions: (list[tuple[Ability, (set[str] | None)]] | None) = None;

    def writes(owner: UniNode) -> bool;
    def _scan(roots: list[UniNode]) -> bool;
    def _walker_writes(walker: Archetype) -> bool;
    def _spawn_writes(operands: list[Expr]) -> bool;
    def _node_writes(nd: UniNode) -> bool;
    def _store_writes(target: Expr) -> bool;
    def _call_writes(call: FuncCall) -> bool;
    def _library_call_writes(call: FuncCall, origin: str, name: str) -> bool;
    def _safe_to_share(expr: Expr) -> bool;
    def _fresh_local(expr: Expr) -> bool;
    def _type_of(expr: Expr) -> (TypeBase | None);
}

def graph_typed(t: (TypeBase | None)) -> bool;
def immutable_type(t: (TypeBase | None)) -> bool;
def endpoint_effects(module: Module, program: any) -> dict[str, dict[str, any]];
