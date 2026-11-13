obj FieldInitialization {
    has default_expr: Expr | None,
        factory_expr: Expr | None = None,
        participates_in_init: bool = True,
        keyword_only: bool = False;
}

def is_field_marker(nd: FuncCall) -> bool;

def field_marker_argument(nd: FuncCall, name: str) -> (Expr | None);

def field_initialization(var: HasVar) -> FieldInitialization;

def positional_field_names(fields: list[HasVar]) -> list[str];
