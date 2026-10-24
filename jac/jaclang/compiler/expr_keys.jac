def int_subscript_suffix(right: IndexSlice) -> str | None;

def reference_key_deps(expr: Expr) -> set[str];

def get_expr_key(expr: Expr) -> str | None;

def _extract_first_arg_key(arg: Expr) -> str | None;

def _extract_compare_left_key(left: Expr) -> str | None;

def classify_condition_key(condition: Expr) -> str | None;

def _predicate_call_keys(condition: FuncCall) -> set[str];

def collect_narrowing_symbols(condition: Expr) -> set[str];

def find_destructure_index_path(target: UniNode, key: str) -> list[int] | None;

def collect_assignment_target_keys(target: UniNode) -> set[str];

def collect_assigned_symbols(nd: UniNode) -> set[str];

def type_tag_borrows(expr: (UniNode | None)) -> bool;
