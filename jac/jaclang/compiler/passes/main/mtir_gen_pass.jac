"""Jac MTIR Generation Pass.

This module defines the MTIRGenPass class for generating MTIR (Method Type
Information Registry) from JacLang code. The pass extracts type information
from GenAI abilities for use by the LLM runtime.
"""

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.mtp {
    ClassInfo,
    EnumInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
    mk_tuple,
    type_to_str
}

import from jaclang.jac0core.passes { UniPass }

glob PRIMITIVE_TYPES: list[str] = [
         'int',
         'float',
         'str',
         'bool',
         'None',
         'bytes',
         'list',
         'dict',
         'set',
         'tuple'
     ];

"""Jac MTIR Generation Pass."""
obj MTIRGenPass(UniPass) {
    has ir_in: uni.Module,
        prog: Any,
        cancel_token: Any = None;

    def postinit -> None;
    """Check if a type expression represents a primitive type."""
    def _is_primitive_type(type_expr: uni.Expr | None) -> bool;

    """Parse a unitree type expression into a primitive name, ClassInfo,
    or tuple-based generic representation (using mk_list/mk_dict/mk_tuple)."""
    def _parse_type_expr(
        type_expr: uni.Expr | None, scope: uni.UniScopeNode
    ) -> ClassInfo | str | tuple | None;

    """Extract symbol from type expression if it's not a primitive type."""
    def _extract_type_symbol(
        type_expr: uni.Expr | None, scope: uni.UniScopeNode
    ) -> uni.Symbol | None;

    """Extract enum information from a symbol."""
    def _extract_enum_info(symbol: uni.Symbol) -> EnumInfo;

    """Extract class structure information from a symbol."""
    def _extract_class_info(symbol: uni.Symbol) -> ClassInfo | None;

    """Extract comprehensive information from an Ability node."""
    def _extract_function_info(nd: uni.Ability) -> FunctionInfo;

    """Extract method information from an Ability node."""
    def _extract_method_info(nd: uni.Ability, by_call: bool = False) -> MethodInfo;

    """Get a unique scope string for a given scope node."""
    def _get_scope_str(nd: uni.UniScopeNode) -> str;

    """Extract tools from a by clause expression."""
    def _extract_tools_from_expr(
        expr: uni.Expr, scope: uni.UniScopeNode
    ) -> list[FunctionInfo];

    """Handle entering an ability node for MTIR generation."""
    def enter_ability(nd: uni.Ability) -> None;
}
