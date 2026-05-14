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
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

# Primitives recognized by the LLM metadata serializer. Sourced from the
# central type registry (single source of truth) so this set can't drift
# from what other backends and the type evaluator consider primitive.
# 'None' is added explicitly because the registry tracks instantiable
# primitive types only; for MTIR purposes 'None' is also a valid
# type-info string when an enum/field has a None literal.
glob PRIMITIVE_TYPES: set[str] = JAC_TYPE_REGISTRY.primitive_names() | {'None'};

"""Jac MTIR Generation Pass.

Does not need per-node traversal; uses the sub-node table to find
all Ability nodes, so we extend Transform directly instead of UniPass.
"""
obj MTIRGenPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: Any,
        cancel_token: Any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _is_primitive_type(type_expr: uni.Expr | None) -> bool;
    def _parse_type_expr(
        type_expr: uni.Expr | None, scope: uni.UniScopeNode
    ) -> ClassInfo | str | tuple | None;

    def _extract_type_symbol(
        type_expr: uni.Expr | None, scope: uni.UniScopeNode
    ) -> uni.Symbol | None;

    def _extract_enum_info(symbol: uni.Symbol) -> EnumInfo;
    def _extract_class_info(symbol: uni.Symbol) -> ClassInfo | None;
    def _extract_function_info(nd: uni.Ability) -> FunctionInfo;
    def _extract_method_info(nd: uni.Ability, by_call: bool = False) -> MethodInfo;
    def _get_scope_str(nd: uni.UniScopeNode) -> str;
    def _extract_tools_from_expr(
        expr: uni.Expr, scope: uni.UniScopeNode
    ) -> list[FunctionInfo];

    def _process_ability(nd: uni.Ability) -> None;
}
