"""
Type system evaluator for JacLang.

PyrightReference:
    packages/pyright-internal/src/analyzer/typeEvaluator.ts
    packages/pyright-internal/src/analyzer/typeEvaluatorTypes.ts
"""

import ast as py_ast;
import os;
import from pathlib { Path }
import from typing { Callable, TYPE_CHECKING, cast }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.jac_parser { TOKEN_MAP }
import from jaclang.pycore.constant { SymbolType, Tokens as Tok }
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.pycore.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.type_system { types }
import from jaclang.runtimelib.utils { read_file_with_encoding }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.program { JacProgram }
    }
}

# FIXME: Conver the bellow to dot import (from . import ...)
# Currently its not possible with jac+python hybrid repos.
import from jaclang.compiler.type_system {
    operations
}
import from jaclang.compiler.type_system { type_utils }
import from jaclang.compiler.type_system.types { TypeBase }

# The callback type definition for the diagnostic messages.
glob DiagnosticCallback = Callable[
         [uni.UniNode, str, bool],
         None
     ];

"""Types whose definitions are prefetched and cached by the type evaluator."""
obj PrefetchedTypes {
    has none_type_class: TypeBase | None = None,
        object_class: TypeBase | None = None,
        type_class: TypeBase | None = None,
        union_type_class: TypeBase | None = None,
        awaitable_class: TypeBase | None = None,
        function_class: TypeBase | None = None,
        method_class: TypeBase | None = None,
        tuple_class: TypeBase | None = None,
        bool_class: TypeBase | None = None,
        int_class: TypeBase | None = None,
        float_class: TypeBase | None = None,
        str_class: TypeBase | None = None,
        dict_class: TypeBase | None = None,
        list_class: TypeBase | None = None,
        module_type_class: TypeBase | None = None,
        typed_dict_class: TypeBase | None = None,
        typed_dict_private_class: TypeBase | None = None,
        supports_keys_and_get_item_class: TypeBase | None = None,
        mapping_class: TypeBase | None = None,
        template_class: TypeBase | None = None,
        type_var_class: TypeBase | None = None,
        classmethod_class: TypeBase | None = None,
        # Prefetch from typing.pyi file
        protocol_class: TypeBase | None = None,
        any_class: TypeBase | None = None,
        # Prefetched from jac_builtins.pyi file
        final_class: TypeBase | None = None,
        root_class: TypeBase | None = None,
        node_class: TypeBase | None = None,
        walker_class: TypeBase | None = None;
}

"""Represents a single entry in the symbol resolution stack."""
obj SymbolResolutionStackEntry {
    has symbol: uni.Symbol,
        # Initially true, it's set to false if a recursion
        # is detected.
        is_result_valid: bool = True,
        # Some limited forms of recursion are allowed. In these
        # cases, a partially-constructed type can be registered.
        partial_type: TypeBase | None = None;
}

"""Result of matching arguments to parameters."""
obj MatchArgsToParamsResult {
    has arg_params: dict[(uni.Expr | uni.KWPair, types.Parameter | None)],
        overload: types.FunctionType | None = None,
        argument_errors: bool = False;
}

"""Type evaluator for JacLang."""
obj TypeEvaluator {
    def init(program: "JacProgram") -> None;
    def _load_stub_module(path: str) -> uni.Module;
    def _get_type_from_module(module: uni.Module, name: str) -> TypeBase;
    def _prefetch_types;
    def get_none_type -> TypeBase;
    def add_diagnostic(node: uni.UniNode, message: str, warning: bool = False) -> None;
    # -------------------------------------------------------------------------
    # Symbol resolution stack
    # -------------------------------------------------------------------------
    def get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None;
    def push_symbol_resolution(symbol: uni.Symbol) -> bool;
    def pop_symbol_resolution(symbol: uni.Symbol) -> bool;
    # Pyright equivalent function name = getEffectiveTypeOfSymbol.
    def get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    # NOTE: This function doesn't exists in pyright, however it exists as a helper function
    # for the following functions.
    def _import_module_from_path(path: str) -> uni.Module;
    def get_type_of_module(node_: uni.ModulePath) -> types.TypeBase;
    def get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase;
    def _extract_type_params(node_: uni.Archetype) -> list[types.TypeVarType];
    def get_type_of_class(node_: uni.Archetype) -> types.ClassType;
    def get_type_of_ability(node_: uni.Ability) -> TypeBase;
    def get_type_of_string(node: uni.String | uni.MultiString) -> TypeBase;
    def get_type_of_int(node: uni.Int) -> TypeBase;
    def get_type_of_float(node: uni.Float) -> TypeBase;
    # Pyright equivalent function name = getTypeOfExpression();
    def get_type_of_expression(node_: uni.Expr) -> TypeBase;
    # Check if a type is Any, object, Unknown, or TypeVar.
    def is_any_type(ty: TypeBase) -> bool;
    # Comments from pyright:
    # // Determines if the source type can be assigned to the dest type.
    # // If constraint are provided, type variables within the destType are
    # // matched against existing type variables in the map. If a type variable
    # // in the dest type is not in the type map already, it is assigned a type
    # // and added to the map.
    #
    # dest_type = src_type;
    def assign_type(src_type: TypeBase, dest_type: TypeBase) -> bool;
    # TODO: This should take an argument list as parameter.
    def get_type_of_magic_method_call(
        obj_type: TypeBase,
        method_name: str,
        arg_nodes: list[uni.Expr],
        node_for_error: uni.Expr | None = None
    ) -> TypeBase | None;

    def is_sub_class(super_cls: types.ClassType, sub_cls: types.ClassType) -> bool;
    def _is_ability_classmethod(node_: uni.Ability) -> bool;
    def _is_symbol_property(symbol: uni.Symbol) -> bool;
    def _assign_class(src_type: types.ClassType, dest_type: types.ClassType) -> bool;
    # This function is a combination of the bellow pyright functions.
    #  - getDeclaredTypeOfSymbol
    #  - getTypeForDeclaration
    #
    # Implementation Note:
    # Pyright is actually have some duplicate logic for handling declared
    # type and inferred type, we're going to unify them (if it's required
    # in the future, we can refactor this).
    def _get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    # Pyright equivalent function name = getTypeOfExpressionCore();
    def _get_type_of_expression_core(expr: uni.Expr) -> TypeBase;
    # -----------------------------------------------------------------------------
    # Helper functions
    # -----------------------------------------------------------------------------
    def _set_module_item_symbol_and_type(
        node_: uni.ModuleItem, sym: uni.Symbol
    ) -> TypeBase;

    def resolve_imported_symbols(sym: uni.Symbol) -> uni.Symbol;
    def _set_symbol_to_expr(expr: uni.Expr, sym: uni.Symbol) -> TypeBase;
    def _is_expr_self(expr: uni.Expr) -> bool;
    def _get_enclosing_function(node: uni.UniNode) -> uni.Ability | None;
    def _get_enclosing_method(node: uni.UniNode) -> uni.Ability | None;
    def _get_enclosing_class(node: uni.UniNode) -> uni.Archetype | None;
    def _get_type_of_self(node_: uni.SpecialVarRef) -> TypeBase;
    def _get_type_of_root(node_: uni.SpecialVarRef) -> TypeBase;
    def _convert_to_instance(jtype: TypeBase) -> TypeBase;
    def _lookup_class_member(
        base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None;

    def _lookup_object_member(
        base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None;

    def match_args_to_params(
        arg_nodes: list[uni.Expr | uni.KWPair],
        node_for_error: uni.Expr | None,
        func_type: types.FunctionType,
        checking_overload: bool = False
    ) -> MatchArgsToParamsResult;

    def validate_call_args(expr: uni.FuncCall) -> TypeBase;
    def validate_arg_types(
        args: MatchArgsToParamsResult, checking_overload: bool = False
    ) -> None;

    def _create_dataclass_init_method(
        class_type: types.ClassType
    ) -> types.FunctionType;

    def _validate_constructor_method(expr: uni.FuncCall, method_type: TypeBase) -> bool;
}
# FIXME: This class implementation is modified from pyright to make it
# simple and work for now, however this needs to be revisited and
# implemented properly.

# NOTE: This is done in the binder pass of pyright, however I'm doing this
# here, cause this will be the entry point of the type checker and we're not
# relying on the binder pass at the moment and we can go back to binder pass
# in the future if we needed it.
