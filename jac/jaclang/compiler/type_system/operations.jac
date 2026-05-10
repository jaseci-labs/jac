"""
Provides type evaluation logic for unary, binary, augmented assignment and ternary operators.

PyrightReference: packages/pyright-internal/src/analyzer/operations.ts
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from . { types as jtypes }
import from jaclang.jac0core.diagnostics {
    E1010,
    E1033,
    E1035,
    E1055,
    E1096,
    E1097,
    E1098,
    E1114,
    E1115,
    E1118
}
import type from .type_evaluator { TypeEvaluator }

# FIX: py2jac bug - module-level constants must be declared with glob outside with entry block
# Otherwise they become Field descriptors when accessed from functions
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
     ARITHMETIC_OPERATORS: set[str] = {Tok.PLUS,Tok.MINUS,Tok.STAR_MUL,Tok.DIV,Tok.FLOOR_DIV,Tok.MOD,Tok.STAR_POW},
     INT_LIKE_WIDTHS: dict[str, int] = {
         "i8": 8,
         "u8": 8,
         "i16": 16,
         "u16": 16,
         "i32": 32,
         "u32": 32,
         "i64": 64,
         "u64": 64
     },
     FLOAT_LIKE_NAMES: set[str] = {"f32","f64"},
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

"""
Apply numeric type promotion for arithmetic operations.

Rules:
- int op int -> int (except for / which always returns float)
- int op float -> float
- float op int -> float
- float op float -> float
- Fixed-width int op fixed-width int -> wider of the two
- Fixed-width int op int -> int (int is the widest)
- Any int-like op any float-like -> float
- f32 op f64 -> float (f64 / float)
- Division with any numeric -> float

Returns the promoted result type, or None if types are not numeric.
"""
def _is_int_like(t: jtypes.ClassType) -> bool {
    return t.is_builtin("int")
    or (t.is_builtin() and t.shared.class_name in INT_LIKE_WIDTHS);
}

def _is_float_like(t: jtypes.ClassType) -> bool {
    return t.is_builtin("float")
    or (t.is_builtin() and t.shared.class_name in FLOAT_LIKE_NAMES);
}

def get_numeric_promotion_type(
    evaluator: 'TypeEvaluator',
    left_type: jtypes.TypeBase,
    right_type: jtypes.TypeBase,
    op: str
) -> jtypes.TypeBase | None {
    if not isinstance(left_type, jtypes.ClassType)
    or not isinstance(right_type, jtypes.ClassType) {
        return None;
    }
    left_is_int = _is_int_like(left_type);
    left_is_float = _is_float_like(left_type);
    right_is_int = _is_int_like(right_type);
    right_is_float = _is_float_like(right_type);

    # Both must be numeric
    if not ((left_is_int or left_is_float) and (right_is_int or right_is_float)) {
        return None;
    }

    # Division always returns float
    if op == Tok.DIV {
        return evaluator._convert_to_instance(evaluator.prefetch.float_class);
    }

    # If either operand is float-like, result is float
    if left_is_float or right_is_float {
        return evaluator._convert_to_instance(evaluator.prefetch.float_class);
    }

    # Both are int-like: promote to the wider type
    left_name = left_type.shared.class_name;
    right_name = right_type.shared.class_name;
    left_fw = left_name in INT_LIKE_WIDTHS;
    right_fw = right_name in INT_LIKE_WIDTHS;

    # If either is plain int, result is int (int is the widest integer)
    if not left_fw or not right_fw {
        return evaluator._convert_to_instance(evaluator.prefetch.int_class);
    }

    # Both are fixed-width: pick the wider one
    if INT_LIKE_WIDTHS[left_name] >= INT_LIKE_WIDTHS[right_name] {
        return evaluator._convert_to_instance(left_type);
    }
    return evaluator._convert_to_instance(right_type);
}

"""Return the binary operator's jtype."""
def get_type_of_binary_operation(
    evaluator: 'TypeEvaluator', expr: uni.BinaryExpr
) -> jtypes.TypeBase {
    left_type = evaluator.get_type_of_expression(expr.left);
    right_type = evaluator.get_type_of_expression(expr.right);

    # TypeVar binary operation handling
    # Check BEFORE is_any_type since TypeVar.is_any_type() returns True
    # EXCEPT for | operator which is used for union types (T | int)
    if isinstance(expr.op, uni.Token)
    and expr.op.name in BINARY_OPERATOR_MAP
    and expr.op.name != Tok.BW_OR {
        if isinstance(left_type, jtypes.TypeVarType) {
            (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];
            # Constrained TypeVar - check all constraint types
            if left_type.constraints {
                for constraint_type in left_type.constraints {
                    if isinstance(constraint_type, jtypes.ClassType) {
                        result = evaluator.get_type_of_magic_method_call(
                            constraint_type, magic, [expr.right], None
                        );
                        if not result {
                            evaluator.emit_diag(
                                E1010, expr, op=magic, type=str(constraint_type)
                            );
                        }
                    }
                }
                return jtypes.UnknownType();
            }
            if left_type.bound and isinstance(left_type.bound, jtypes.ClassType) {
                # Bounded TypeVar - use bound type for magic method lookup
                result = evaluator.get_type_of_magic_method_call(
                    left_type.bound, magic, [expr.right], None
                );
                if result {
                    return result;
                }
                # Bound type doesn't support this operator
                evaluator.emit_diag(E1010, expr, op=magic, type=str(left_type.bound));
                return jtypes.UnknownType();
            }
            # Unbounded TypeVar
            evaluator.emit_diag(E1010, expr, op=magic, type=left_type.name);
            return jtypes.UnknownType();
        }
        if isinstance(right_type, jtypes.TypeVarType) {
            (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];
            # Constrained TypeVar - check all constraint types
            if right_type.constraints {
                for constraint_type in right_type.constraints {
                    if isinstance(constraint_type, jtypes.ClassType) {
                        result = evaluator.get_type_of_magic_method_call(
                            constraint_type, rmagic, [expr.left], None
                        );
                        if not result {
                            evaluator.emit_diag(
                                E1010, expr, op=rmagic, type=str(constraint_type)
                            );
                        }
                    }
                }
                return jtypes.UnknownType();
            }
            if right_type.bound and isinstance(right_type.bound, jtypes.ClassType) {
                # Bounded TypeVar - use bound type for magic method lookup
                result = evaluator.get_type_of_magic_method_call(
                    right_type.bound, rmagic, [expr.left], None
                );
                if result {
                    return result;
                }
                # Bound type doesn't support this operator
                evaluator.emit_diag(E1010, expr, op=rmagic, type=str(right_type.bound));
                return jtypes.UnknownType();
            }
            # Unbounded TypeVar
            evaluator.emit_diag(E1010, expr, op=rmagic, type=right_type.name);
            return jtypes.UnknownType();
        }
    }

    # Handle '|' union types BEFORE the is_any_type() guard, because TypeVarType
    # reports is_any_type()=True but is valid in type annotations (e.g., _VT | None).
    if (isinstance(expr.op, uni.Token) and expr.op.name == Tok.BW_OR) {
        def is_annotation_type(ty: jtypes.TypeBase) -> bool {
            if ty.is_instantiable() or isinstance(ty, jtypes.UnionType) {
                return True;
            }
            # TypeVars are valid in union type annotations (e.g., _VT | None in typeshed stubs).
            if isinstance(ty, jtypes.TypeVarType) {
                return True;
            }
            # Callable[...] annotations evaluate to a FunctionType with empty
            # func_name. Without this, an alias like `A | type[Any] | Callable[..., Any]`
            # falls into magic-method dispatch on the inner UnionType and gets
            # collapsed to the return type of `type.__or__`.
            if isinstance(ty, jtypes.FunctionType)
            and ty.is_from_callable_annotation() {
                return True;
            }
            # `Never` / `NoReturn` are valid annotation arms (PEP 484, PEP 604).
            if isinstance(ty, jtypes.NeverType) {
                return True;
            }
            # Although None is not a valid class, it can be used as a class in the type annotation.
            if isinstance(ty, jtypes.ClassType) {
                return ty.shared == evaluator.prefetch.none_type_class.shared;
            }
            return False;
        }
        if is_annotation_type(left_type) and is_annotation_type(right_type) {
            return jtypes.UnionType(types=[left_type, right_type]);
        }
    }

    if left_type.is_any_type() or right_type.is_any_type() {
        if not (isinstance(expr.op, uni.Token) and expr.op.name == Tok.BW_OR) {
            return jtypes.UnknownType();
        }
    }
    # Boolean operations
    if (
        (expr.op in (Tok.KW_IS, Tok.KW_ISN, Tok.KW_IN, Tok.KW_NIN))
        and (evaluator.prefetch.bool_class is not None)
    ) {
        return evaluator._convert_to_instance(evaluator.prefetch.bool_class);
    }

    # Magic method lookup for other binary operations
    if (isinstance(expr.op, uni.Token) and (expr.op.name in BINARY_OPERATOR_MAP)) {
        # Handle '|' in the context of Union types
        #
        # TODO: Pyright checks if the types support '__or__' and '__ror__' before returning UnionType
        # If they support, we can treat them as binary operands, instead of Union types.
        def is_annotation_type(ty: jtypes.TypeBase) -> bool {
            if ty.is_instantiable() or isinstance(ty, jtypes.UnionType) {
                return True;
            }
            # TypeVarType is valid in union type annotations (e.g., T | None)
            if isinstance(ty, jtypes.TypeVarType) {
                return True;
            }
            # Callable[...] annotations evaluate to FunctionType with empty func_name.
            if isinstance(ty, jtypes.FunctionType)
            and ty.is_from_callable_annotation() {
                return True;
            }
            # `Never` / `NoReturn` are valid annotation arms.
            if isinstance(ty, jtypes.NeverType) {
                return True;
            }
            # Although None is not a valid class, it can be used as a class in the type annotation.
            if isinstance(ty, jtypes.ClassType) {
                return ty.shared == evaluator.prefetch.none_type_class.shared;
            }
            return False;
        }
        if expr.op.name == Tok.BW_OR {
            # TODO: Handle None instance used
            if is_annotation_type(left_type) and is_annotation_type(right_type) {
                return jtypes.UnionType(types=[left_type, right_type]);
            }
        }
        (magic, rmagic) = BINARY_OPERATOR_MAP[expr.op.name];
        # Apply numeric type promotion for arithmetic operations (int -> float)
        if expr.op.name in ARITHMETIC_OPERATORS {
            promoted_type = get_numeric_promotion_type(
                evaluator, left_type, right_type, expr.op.name
            );
            if promoted_type is not None {
                return promoted_type;
            }
        }
        # Try forward magic method first (e.g., left.__add__(right))
        result = evaluator.get_type_of_magic_method_call(
            left_type, magic, [expr.right], None
        );
        # If forward method fails, try reverse magic method (e.g., right.__radd__(left))
        if result is None {
            result = evaluator.get_type_of_magic_method_call(
                right_type, rmagic, [expr.left], None
            );
        }
        # If both methods fail, handle specially for | operator, else emit diagnostic
        if result is None {
            # For | operator, fall back to UnionType when magic method fails.
            # This handles type annotation contexts where | is used for union types
            # but operands weren't detected as annotation types by is_annotation_type().
            if expr.op.name == Tok.BW_OR {
                return jtypes.UnionType(types=[left_type, right_type]);
            }
            evaluator.emit_diag(E1055, expr, method=magic);
            return jtypes.UnknownType();
        }
        return result;
    }

    # Connection operations
    if isinstance(expr.op, (uni.ConnectOp, uni.DisconnectOp)) {
        def is_node_type_instance(t: jtypes.TypeBase) -> bool {
            return (
                isinstance(t, jtypes.ClassType) and t.is_node_type() and t.is_instance()
            );
        }
        # If `t` is one of the connect-supported builtin collections
        # (list/tuple/set/frozenset) without type arguments, return its
        # class name. Otherwise return None. Used to surface E1118 at
        # connect/disconnect operand sites where element-type validation
        # would otherwise silently pass.
        def unparameterized_connect_collection(t: jtypes.TypeBase) -> str | None {
            if not isinstance(t, jtypes.ClassType) {
                return None;
            }
            if not t.is_builtin() {
                return None;
            }
            if t.shared.class_name not in ("list", "tuple", "set", "frozenset") {
                return None;
            }
            if t.private.type_args and len(t.private.type_args) > 0 {
                return None;
            }
            return t.shared.class_name;
        }
        # Check whether a type is a valid node operand for connections.
        # Accepts: node instances, list of node instances, UnionType where all
        # members are valid, AnyType, and UnknownType (not enough info to diagnose).
        def is_valid_node_operand(t: jtypes.TypeBase) -> bool {
            if t.is_any_type() or isinstance(t, jtypes.UnknownType) {
                return True;
            }
            if is_node_type_instance(t) {
                return True;
            }
            if isinstance(t, jtypes.UnionType) {
                return all(is_valid_node_operand(m) for m in t.types);
            }
            # Also accept list of node instances (runtime accepts list[NodeArchetype])
            if isinstance(t, jtypes.ClassType)
            and t.is_builtin()
            and t.shared.class_name == "list" {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return is_valid_node_operand(t.private.type_args[0]);
                }
                # Unparameterized list — caller must surface E1118.
                return False;
            }
            return False;
        }
        # TODO: In strict mode, UnknownType, AnyType, TypeVarType, and object should be errors
        if (
            left_unparam := unparameterized_connect_collection(left_type)
        ) is not None {
            evaluator.emit_diag(E1118, expr.left, side="left", type=left_unparam);
        } elif not is_valid_node_operand(left_type) {
            evaluator.emit_diag(E1096, expr.left);
        }
        # Check if right operand is a valid node operand or a collection of node instances
        def is_valid_right_operand(t: jtypes.TypeBase) -> bool {
            if is_valid_node_operand(t) {
                return True;
            }
            if not isinstance(t, jtypes.ClassType) {
                return False;
            }
            # Collection of node instances (list, tuple, set, frozenset).
            # Unparameterized collections are intercepted earlier via E1118.
            if (
                t.is_builtin()
                and t.shared.class_name in ("list", "tuple", "set", "frozenset")
            ) {
                if (t.private.type_args is not None and len(t.private.type_args) > 0) {
                    elem_type = t.private.type_args[0];
                    if is_valid_node_operand(elem_type) {
                        return True;
                    }
                }
            }
            return False;
        }
        if (
            right_unparam := unparameterized_connect_collection(right_type)
        ) is not None {
            evaluator.emit_diag(E1118, expr.right, side="right", type=right_unparam);
        } elif not is_valid_right_operand(right_type) {
            evaluator.emit_diag(E1097, expr.right);
        }
        # Validate that a typed-edge expression resolves to an edge type.
        # Used by both connect (`+>: T :+>`) and disconnect (`del ->:T:->`).
        def validate_conn_type(type_expr: uni.Expr) -> jtypes.TypeBase {
            ct = evaluator.get_type_of_expression(type_expr);
            if (
                not ct.is_any_type()
                and not isinstance(ct, jtypes.UnknownType)
                and (not isinstance(ct, jtypes.ClassType) or not ct.is_edge_type())
            ) {
                evaluator.emit_diag(E1098, type_expr);
                return jtypes.UnknownType();
            }
            return ct;
        }
        if isinstance(expr.op, uni.ConnectOp) {
            if expr.op.conn_type {
                conn_type = validate_conn_type(expr.op.conn_type);
                if (
                    not isinstance(conn_type, jtypes.UnknownType)
                    and (assign_compr := expr.op.conn_assign)
                ) {
                    for assign in assign_compr.assigns {
                        if (assign.key is not None) {
                            edge_inst_type = evaluator._convert_to_instance(conn_type);
                            if (
                                member := evaluator._lookup_object_member(
                                    edge_inst_type, assign.key.sym_name
                                )
                            ) {
                                dest_type = evaluator._set_symbol_to_expr(
                                    assign.key, member.symbol
                                );
                                src_type = evaluator.get_type_of_expression(
                                    assign.value
                                );
                                # Edge connection assigns target a declared
                                # field; apply Layer 2 strict-Any via the
                                # centralized site helper.
                                if not evaluator.assign_type(
                                    src_type,
                                    dest_type,
                                    strict=evaluator._is_strict_site(assign.value)
                                ) {
                                    evaluator.emit_diag(
                                        E1035,
                                        assign.value,
                                        src=str(src_type),
                                        dest=str(dest_type)
                                    );
                                }
                            } else {
                                evaluator.emit_diag(
                                    E1033,
                                    assign.key,
                                    member=assign.key.sym_name,
                                    type=str(conn_type)
                                );
                            }
                        }
                    }
                }
            }
            # Connect operator returns list of nodes (right operand)
            if evaluator.prefetch and evaluator.prefetch.list_class {
                list_type = evaluator.prefetch.list_class.clone_as_instance();
                if isinstance(list_type, jtypes.ClassType) {
                    list_type.private.type_args = [right_type];
                    return list_type;
                }
            }
            return right_type;
        }
        if isinstance(expr.op, uni.DisconnectOp) {
            # `del ->:T:->` mirrors connect's typed-edge check: T must be
            # an edge type (or instance). The f_type lives inside the
            # EdgeOpRef's FilterCompr.
            fcond = expr.op.edge_spec.filter_cond;
            if fcond is not None and fcond.f_type is not None {
                validate_conn_type(fcond.f_type);
            }
            # Disconnect compiles to `Jac.disconnect(...)` which returns
            # `bool`. Returning UnknownType here used to flood every
            # disconnect site with W1051 (issue #5885 gap 9).
            if evaluator.prefetch and evaluator.prefetch.bool_class {
                return evaluator._convert_to_instance(evaluator.prefetch.bool_class);
            }
        }
    }
    # Spawn operator: `a spawn b` requires exactly one operand to be a
    # walker instance (or list[Walker]); the other operand must be a node,
    # edge, or collection thereof. Returns the walker side's type so that
    # `(p spawn W()).reports` and `(W() spawn p).reports` are typed alike.
    if isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_SPAWN {
        def is_walker_instance(t: jtypes.TypeBase) -> bool {
            if isinstance(t, jtypes.ClassType)
            and t.is_walker_type()
            and t.is_instance() {
                return True;
            }
            if isinstance(t, jtypes.UnionType) {
                return all(is_walker_instance(m) for m in t.types);
            }
            # list[Walker] is also a valid walker side.
            if isinstance(t, jtypes.ClassType)
            and t.is_builtin()
            and t.shared.class_name == "list" {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return is_walker_instance(t.private.type_args[0]);
                }
            }
            return False;
        }
        def is_archetype_target(t: jtypes.TypeBase) -> bool {
            if t.is_any_type() or isinstance(t, jtypes.UnknownType) {
                return True;
            }
            if isinstance(t, jtypes.ClassType) {
                if t.is_node_type() or t.is_edge_type() {
                    return True;
                }
                if (
                    t.is_builtin()
                    and t.shared.class_name in ("list", "tuple", "set", "frozenset")
                ) {
                    if t.private.type_args and len(t.private.type_args) > 0 {
                        return all(is_archetype_target(a) for a in t.private.type_args);
                    }
                    # Unparameterized collection — accept (matches connect/visit).
                    return True;
                }
            }
            if isinstance(t, jtypes.UnionType) {
                return all(is_archetype_target(m) for m in t.types);
            }
            return False;
        }
        # Skip diagnostics when either side is Any/Unknown — not enough
        # info to diagnose without false positives. This mirrors the
        # connect/visit operand checks.
        left_unknown = (
            left_type.is_any_type() or isinstance(left_type, jtypes.UnknownType)
        );
        right_unknown = (
            right_type.is_any_type() or isinstance(right_type, jtypes.UnknownType)
        );
        left_walker = is_walker_instance(left_type);
        right_walker = is_walker_instance(right_type);
        if not left_walker and not right_walker {
            if not (left_unknown or right_unknown) {
                evaluator.emit_diag(
                    E1114, expr, left=str(left_type), right=str(right_type)
                );
            }
            return right_type;
        }
        # Exactly one side is the walker; the other must be a valid target.
        target_node = expr.right if left_walker else expr.left;
        target_type = right_type if left_walker else left_type;
        if not is_archetype_target(target_type) {
            evaluator.emit_diag(E1115, target_node, type=str(target_type));
        }
        # Spawn returns the walker instance (left_type if left is the walker).
        return left_type if left_walker else right_type;
    }
    #  walrus assignment
    if isinstance(expr.op, uni.Token) and expr.op.name == Tok.WALRUS_EQ {
        # Walrus operator: (x := expr) assigns right to left and returns right's type
        if isinstance(expr.left, uni.Name) and expr.left.sym {
            expr.left.sym.type = right_type;
            expr.left.type = right_type;
        }
        return right_type;
    }
    return jtypes.UnknownType();
}
# Arithmetic operators that support numeric type promotion (int -> float)

# Fixed-width integer type names and their bit widths for promotion

# Maps augmented assignment operator tokens to in-place magic methods

# Maps augmented op tokens to their base binary op tokens
