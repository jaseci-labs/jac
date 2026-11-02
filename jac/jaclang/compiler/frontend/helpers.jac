def _is_version_info_access(expr: Expr) -> bool;

def _is_type_checking_ref(expr: Expr) -> bool;

def _extract_version_tuple(expr: Expr) -> tuple[int, int] | None;

def evaluate_version_condition(condition: Expr) -> bool | None;
