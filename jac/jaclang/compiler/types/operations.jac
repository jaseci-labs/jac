glob BINARY_OPERATOR_MAP: dict[str, tuple[str, str]] = {
         Tok.PLUS: ('__add__', '__radd__'),
         Tok.MINUS: ('__sub__', '__rsub__'),
         Tok.STAR_MUL: ('__mul__', '__rmul__'),
         Tok.FLOOR_DIV: ('__floordiv__', '__rfloordiv__'),
         Tok.DIV: ('__truediv__', '__rtruediv__'),
         Tok.MOD: ('__mod__', '__rmod__'),
         Tok.STAR_POW: ('__pow__', '__rpow__'),
         Tok.DECOR_OP: ('__matmul__', '__rmatmul__'),
         Tok.BW_AND: ('__and__', '__rand__'),
         Tok.BW_OR: ('__or__', '__ror__'),
         Tok.BW_XOR: ('__xor__', '__rxor__'),
         Tok.LSHIFT: ('__lshift__', '__rlshift__'),
         Tok.RSHIFT: ('__rshift__', '__rrshift__'),
         Tok.EE: ('__eq__', '__eq__'),
         Tok.NE: ('__ne__', '__ne__'),
         Tok.LT: ('__lt__', '__gt__'),
         Tok.LTE: ('__le__', '__ge__'),
         Tok.GT: ('__gt__', '__lt__'),
         Tok.GTE: ('__ge__', '__le__')
     },
     ARITHMETIC_OPERATORS: set[str] = {
         Tok.PLUS,
         Tok.MINUS,
         Tok.STAR_MUL,
         Tok.DIV,
         Tok.FLOOR_DIV,
         Tok.MOD,
         Tok.STAR_POW
     },
     AUG_OPERATOR_MAP: dict[str, str] = {
         Tok.ADD_EQ: '__iadd__',
         Tok.SUB_EQ: '__isub__',
         Tok.MUL_EQ: '__imul__',
         Tok.DIV_EQ: '__itruediv__',
         Tok.FLOOR_DIV_EQ: '__ifloordiv__',
         Tok.MOD_EQ: '__imod__',
         Tok.STAR_POW_EQ: '__ipow__',
         Tok.LSHIFT_EQ: '__ilshift__',
         Tok.RSHIFT_EQ: '__irshift__',
         Tok.BW_AND_EQ: '__iand__',
         Tok.BW_OR_EQ: '__ior__',
         Tok.BW_XOR_EQ: '__ixor__',
         Tok.MATMUL_EQ: '__imatmul__'
     },
     AUG_TO_BINARY_MAP: dict[str, str] = {
         Tok.ADD_EQ: Tok.PLUS,
         Tok.SUB_EQ: Tok.MINUS,
         Tok.MUL_EQ: Tok.STAR_MUL,
         Tok.DIV_EQ: Tok.DIV,
         Tok.FLOOR_DIV_EQ: Tok.FLOOR_DIV,
         Tok.MOD_EQ: Tok.MOD,
         Tok.STAR_POW_EQ: Tok.STAR_POW,
         Tok.LSHIFT_EQ: Tok.LSHIFT,
         Tok.RSHIFT_EQ: Tok.RSHIFT,
         Tok.BW_AND_EQ: Tok.BW_AND,
         Tok.BW_OR_EQ: Tok.BW_OR,
         Tok.BW_XOR_EQ: Tok.BW_XOR,
         Tok.MATMUL_EQ: Tok.DECOR_OP
     };

def _is_runtime_archetype_instance(t: TypeBase, base_name: str) -> bool;

def _has_gradual_type_args(t: TypeBase) -> bool;

glob COMPLEX_ARITH_OPS: set[str] = {
         Tok.PLUS,
         Tok.MINUS,
         Tok.STAR_MUL,
         Tok.DIV,
         Tok.STAR_POW
     },
     BITWISE_OPERATORS: set[str] = {Tok.BW_AND, Tok.BW_OR, Tok.BW_XOR},
     SHIFT_OPERATORS: set[str] = {Tok.LSHIFT, Tok.RSHIFT};

def get_numeric_promotion_type(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    op: str,
    left_node: Expr | None = None,
    right_node: Expr | None = None,
    diag_node: UniNode | None = None
) -> TypeBase | None;

def is_int_kind_type(t: TypeBase) -> bool;

def _is_builtin_instance_named(t: TypeBase, name: str) -> bool;

def get_complex_arith_result_type(
    left_type: TypeBase, right_type: TypeBase
) -> TypeBase | None;

def get_pow_result_type(
    evaluator: TypeEvaluator,
    left_type: TypeBase,
    right_type: TypeBase,
    right_node: (Expr | None),
    left_node: Expr | None = None,
    diag_node: UniNode | None = None
) -> (TypeBase | None);

def is_annotation_type(evaluator: TypeEvaluator, ty: TypeBase) -> bool;

def _is_literal_form(operand: Expr) -> bool;

def get_type_of_binary_operation(
    evaluator: TypeEvaluator, expr: BinaryExpr
) -> TypeBase;
