# flake8: noqa: I300
"""Provides type evaluation logic for unary, binary, augmented assignment and ternary operators.

PyrightReference: packages/pyright-internal/src/analyzer/operations.ts
"""

from typing import TYPE_CHECKING

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok

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
            evaluator.get_type_of_magic_method_call(left_type, magic, expr.op)
            or evaluator.get_type_of_magic_method_call(right_type, rmagic, expr.op)
            or jtypes.UnknownType()
        )

    # TODO: Handle for connect and disconnect operators.
    return jtypes.UnknownType()
