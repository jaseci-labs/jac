def erased_import_binds(
    nd: UniNode, name: str, imported_name: str | None = None
) -> bool;

def erased_identity_call_arg(nd: FuncCall) -> (Expr | None);

def is_contextmanager_decorator(
    expr: UniNode, anchor: (UniNode | None) = None
) -> bool;

def contextmanager_ability(ab: (UniNode | None)) -> bool;
