glob PURE_BUILTINS: set[str] = {
         "abs",
         "all",
         "any",
         "bool",
         "dict",
         "enumerate",
         "float",
         "int",
         "isinstance",
         "len",
         "list",
         "max",
         "min",
         "print",
         "range",
         "round",
         "set",
         "sorted",
         "str",
         "sum",
         "tuple",
         "zip"
     },
     READ_ONLY_METHODS: set[str] = {
         "copy",
         "count",
         "get",
         "index",
         "items",
         "keys",
         "values"
     },
     FRESH_VALUES: tuple = (
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
        _memo: dict[int, bool] = {},
        _active: set[int] = set();

    def writes(owner: UniNode) -> bool;
    def _scan(roots: list[UniNode]) -> bool;
    def _node_writes(nd: UniNode) -> bool;
    def _store_writes(target: Expr) -> bool;
    def _call_writes(call: FuncCall) -> bool;
    def _fresh_local(expr: Expr) -> bool;
    def _type_of(expr: Expr) -> (TypeBase | None);
}

def endpoint_effects(module: Module, program: any) -> dict[str, dict[str, any]];
