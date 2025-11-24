# flake8: noqa: I300
"""Provides type evaluation logic for unary, binary, augmented assignment and ternary operators.

PyrightReference: packages/pyright-internal/src/analyzer/operations.ts
"""

from typing import TYPE_CHECKING

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import SymbolType, Tokens as Tok

from . import types as jtypes

if TYPE_CHECKING:
    # Type evaluator is the one depends on this module and not the way around.
    # however this module needs a reference to the type evaluator.
    from .type_evaluator import TypeEvaluator


# Maps binary operators to the magic methods that implement them.
BINARY_OPERATOR_MAP: dict[str, tuple[str, str]] = {
    Tok.PLUS: ("__add__", "__radd__"),
    Tok.MINUS: ("__sub__", "__rsub__"),
    Tok.STAR_MUL: ("__mul__", "__rmul__"),
    Tok.FLOOR_DIV: ("__floordiv__", "__rfloordiv__"),
    Tok.DIV: ("__truediv__", "__rtruediv__"),
    Tok.MOD: ("__mod__", "__rmod__"),
    Tok.STAR_POW: ("__pow__", "__rpow__"),
    Tok.DECOR_OP: ("__matmul__", "__rmatmul__"),
    Tok.BW_AND: ("__and__", "__rand__"),
    Tok.BW_OR: ("__or__", "__ror__"),
    Tok.BW_XOR: ("__xor__", "__rxor__"),
    Tok.LSHIFT: ("__lshift__", "__rlshift__"),
    Tok.RSHIFT: ("__rshift__", "__rrshift__"),
    Tok.EE: ("__eq__", "__eq__"),
    Tok.NE: ("__ne__", "__ne__"),
    Tok.LT: ("__lt__", "__gt__"),
    Tok.LTE: ("__le__", "__ge__"),
    Tok.GT: ("__gt__", "__lt__"),
    Tok.GTE: ("__ge__", "__le__"),
}


# Mirror of the `export function getTypeOfBinaryOperation` function in pyright.
def get_type_of_binary_operation(
    evaluator: "TypeEvaluator", expr: uni.BinaryExpr
) -> jtypes.TypeBase:
    """Return the binary operator's jtype."""
    left_type = evaluator.get_type_of_expression(expr.left)
    right_type = evaluator.get_type_of_expression(expr.right)

    # TODO: Check how pyright is dealing with chaining operation (a < b < c < d) and
    # it handles here with the condition `if operatorSupportsChaining()`.:

    # TODO:
    # Is this a "|" operator used in a context where it is supposed to be
    # interpreted as a union operator?

    # pyright is using another function however I don't see the need of it yet, so imma use
    # the logic here, if needed define `validateBinaryOperation` for re-usability.

    # TODO: Handle and, or
    #
    # <left> and <right>  <--- This is equlavent to the bellow
    #
    # def left_and_right(left, right):
    #     if bool(left):
    #         return left
    #     return right
    #
    # And the type will be Union[left.type, right.type]
    #

    # NOTE: in will call `__contains__` magic method in custom type and should return `bool`
    # however it can technically return anything otherthan `bool` and pyright is handing that way
    # I don't see `__str__` method return anything other than string should be valid either.
    if (expr.op in (Tok.KW_IS, Tok.KW_ISN, Tok.KW_IN, Tok.KW_NIN)) and (
        evaluator.prefetch.bool_class is not None
    ):
        evaluator._convert_to_instance(evaluator.prefetch.bool_class)

    # TODO: `expr.op` can be of 3 types, Token, connect, disconnect.
    if isinstance(expr.op, uni.Token) and (expr.op.name in BINARY_OPERATOR_MAP):
        # TODO: validateArithmeticOperation() has more cases and special conditions that we may
        # need to implement in the future however in this simple case we're implementing the
        # bare minimal checking.
        magic, rmagic = BINARY_OPERATOR_MAP[expr.op.name]

        # TODO: Handle overloaded call check:
        # Grep this in pyright typeEvaluator.ts:
        #    callResult.overloadsUsedForCall.forEach((overload) => {
        #       overloadsUsedForCall.push(overload);
        #       ...
        #    });

        # FIXME: We need to have validateCallArgs() method and do a check here before returning.
        return (
            evaluator.get_type_of_magic_method_call(left_type, magic)
            or evaluator.get_type_of_magic_method_call(right_type, rmagic)
            or jtypes.UnknownType()
        )

    elif isinstance(expr.op, (uni.ConnectOp, uni.DisconnectOp)):
        # Validate left, right types.
        if (
            not isinstance(left_type, jtypes.ClassType)
            or not left_type.is_node_type()
            or not left_type.is_instance()
        ):
            evaluator.add_diagnostic(
                expr.left, "Connection left operand must be a node instance"
            )
        if (
            not isinstance(right_type, jtypes.ClassType)
            or not right_type.is_node_type()
            or not right_type.is_instance()
        ):
            evaluator.add_diagnostic(
                expr.right, "Connection right operand must be a node instance"
            )

        # Validate connection type if provided.
        if isinstance(expr.op, uni.ConnectOp) and expr.op.conn_type:
            conn_type = evaluator.get_type_of_expression(expr.op.conn_type)
            if (
                not isinstance(conn_type, jtypes.ClassType)
                or not conn_type.is_edge_type()
            ):
                evaluator.add_diagnostic(
                    expr.op.conn_type, "Connection type must be an edge instance"
                )
            else:
                # Connection has assign compr.
                if assign_compr := expr.op.conn_assign:
                    for assign in assign_compr.assigns:
                        if assign.key is not None:
                            edge_inst_type = evaluator._convert_to_instance(conn_type)
                            if member := evaluator._lookup_object_member(
                                edge_inst_type, assign.key.sym_name
                            ):
                                dest_type = evaluator._set_symbol_to_expr(
                                    assign.key, member.symbol
                                )
                                src_type = evaluator.get_type_of_expression(
                                    assign.value
                                )
                                if not evaluator.assign_type(src_type, dest_type):
                                    evaluator.add_diagnostic(
                                        assign.value,
                                        f'Type "{src_type}" is not assignable to type "{dest_type}"',
                                    )
                            else:
                                evaluator.add_diagnostic(
                                    assign.key,
                                    f'Edge type "{conn_type}" has no member named "{assign.key.sym_name}"',
                                )

            return right_type
        # Question: What should be the return type of disconnect operation?

    # TODO: Handle for connect and disconnect operators.
    return jtypes.UnknownType()
