obj AssignVerdict {
    has ok: bool,
        diagnosed: bool = False;
}

glob I64_TOP: int = 9223372036854775807,
     I64_BOTTOM: int = -9223372036854775807 - 1;

def value_in_range(value: int, t_lo: int, t_hi: int, wide: bool) -> bool;

def unbounded_interval_in_range(
    op: str,
    left: tuple[int, int],
    right: tuple[int, int],
    t_lo: int,
    t_hi: int,
    wide: bool
) -> bool;

def corner_in_range(op: str, x: int, y: int, t_lo: int, t_hi: int, wide: bool) -> bool;

def unsigned_top_in_range(
    op: str, top_left: bool, o_lo: int, o_hi: int, wide: bool, signed_wide: bool
) -> bool;

def interval_of_op(
    op: str,
    left: (tuple[int, int] | None),
    right: (tuple[int, int] | None),
    target: str
) -> bool;

def interval_of_expr(expr: (Expr | None)) -> (tuple[int, int] | None);

def numeric_name_of(t: TypeBase | None) -> str | None;

def folded_number(expr: UniNode | None) -> int | float | None;

def _numeric_dest(evaluator: TypeEvaluator, dest: TypeBase) -> ClassType | None;

def annotate_coercion(expr: Expr | None, target: ClassType);

def adopt_literal(
    evaluator: TypeEvaluator,
    expr: Expr,
    value: int | float,
    target: ClassType,
    probe: bool = False
) -> AssignVerdict;

def is_brand(t: TypeBase | None) -> bool;

def assign_numeric_expr(
    evaluator: TypeEvaluator,
    expr: Expr | None,
    src: TypeBase,
    dest: TypeBase,
    probe: bool = False
) -> AssignVerdict | None;

def unify_numeric_operands(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    left_node: Expr | None,
    right_node: Expr | None,
    diag_node: UniNode | None,
    op: str
) -> TypeBase | None;

def arithmetic_result_type(evaluator: TypeEvaluator, t: TypeBase) -> TypeBase;

def both_numeric(left_type: TypeBase, right_type: TypeBase) -> bool;

def is_unsigned_type(t: TypeBase | None) -> bool;

glob WRAPPING_BINARY_BUILTINS: list[str] = [
         "wrapping_add",
         "wrapping_sub",
         "wrapping_mul",
         "wrapping_shl"
     ],
     WRAPPING_UNARY_BUILTINS: list[str] = ["wrapping_neg"];

def _is_jac_builtin_fn(evaluator: TypeEvaluator, callee: Expr, name: str) -> bool;

def fixed_width_call_type(
    evaluator: TypeEvaluator, call: FuncCall, callee_type: TypeBase
) -> TypeBase | None;

def shift_result_type(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    left_node: Expr | None,
    right_node: Expr | None
) -> TypeBase | None;
