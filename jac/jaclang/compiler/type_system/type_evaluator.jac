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
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { TOKEN_MAP }
import from jaclang.jac0core.constant { SymbolType, Tokens as Tok }
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.type_system { types }
import from jaclang.runtimelib.utils { read_file_with_encoding }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

import from jaclang.compiler.type_system { operations }
import from jaclang.compiler.type_system { type_utils }
import from jaclang.compiler.type_system.types { TypeBase }

glob DiagnosticCallback = Callable[[uni.UniNode, str, bool], None];

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
        protocol_class: TypeBase | None = None,
        any_class: TypeBase | None = None,
        final_class: TypeBase | None = None,
        literal_string_class: TypeBase | None = None,
        root_class: TypeBase | None = None,
        node_class: TypeBase | None = None,
        walker_class: TypeBase | None = None,
        jsx_element_class: TypeBase | None = None;
}

"""Represents a single entry in the symbol resolution stack."""
obj SymbolResolutionStackEntry {
    has symbol: uni.Symbol,
        is_result_valid: bool = True,
        partial_type: TypeBase | None = None;
}

"""Result of matching arguments to parameters."""
obj MatchArgsToParamsResult {
    has arg_params: dict[(uni.Expr | uni.KWPair, types.Parameter | None)],
        overload: types.FunctionType | None = None,
        argument_errors: bool = False;
}

"""Represents a narrowing operation from a conditional predicate."""
obj NarrowingPredicate {
    has sym_name: str,
        narrow_type: TypeBase,
        is_inverted: bool = False;
}

"""Type evaluator for JacLang."""
obj TypeEvaluator {
    def init(program: "JacProgram") -> None;
    def _load_stub_module(path: str) -> uni.Module;
    def _get_type_from_module(module: uni.Module, name: str) -> TypeBase;
    def _prefetch_types;
    def get_none_type -> TypeBase;
    def add_diagnostic(nd: uni.UniNode, message: str, warning: bool = False) -> None;
    def get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None;
    def push_symbol_resolution(symbol: uni.Symbol) -> bool;
    def pop_symbol_resolution(symbol: uni.Symbol) -> bool;
    def get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    def _import_module_from_path(path: str) -> uni.Module;
    def get_type_of_module(node_: uni.ModulePath) -> types.TypeBase;
    def get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase;
    def _extract_type_params(node_: uni.Archetype) -> list[types.TypeVarType];
    def get_type_of_class(node_: uni.Archetype) -> types.ClassType;
    def get_type_of_ability(node_: uni.Ability) -> TypeBase;
    def get_type_of_string(nd: uni.String | uni.MultiString) -> TypeBase;
    def get_type_of_int(nd: uni.Int) -> TypeBase;
    def get_type_of_float(nd: uni.Float) -> TypeBase;
    def get_type_of_expression(node_: uni.Expr) -> TypeBase;
    def is_any_type(ty: TypeBase) -> bool;
    def assign_type(src_type: TypeBase, dest_type: TypeBase) -> bool;
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
    def _get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    def _get_type_of_expression_core(expr: uni.Expr) -> TypeBase;
    def _set_module_item_symbol_and_type(
        node_: uni.ModuleItem, sym: uni.Symbol
    ) -> TypeBase;

    def resolve_imported_symbols(sym: uni.Symbol) -> uni.Symbol;
    def _set_symbol_to_expr(expr: uni.Expr, sym: uni.Symbol) -> TypeBase;
    def _is_expr_self(expr: uni.Expr) -> bool;
    def _is_expr_super(expr: uni.Expr) -> bool;
    def _get_enclosing_function(nd: uni.UniNode) -> uni.Ability | None;
    def _get_enclosing_method(nd: uni.UniNode) -> uni.Ability | None;
    def _get_enclosing_class(nd: uni.UniNode) -> uni.Archetype | None;
    def _get_type_of_self(node_: uni.SpecialVarRef) -> TypeBase;
    def _get_type_of_super(node_: uni.SpecialVarRef) -> TypeBase;
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
    def get_narrowed_type(symbol: uni.Symbol, at_node: uni.UniNode) -> TypeBase | None;
    def _compute_narrowed_at(
        symbol: uni.Symbol, stmt: uni.UniCFGNode, visited: set
    ) -> TypeBase | None;

    def _classify_edge(pred: uni.IfStmt, succ: uni.UniCFGNode) -> str;
    def _find_predicate_for(
        symbol: uni.Symbol, condition: uni.Expr
    ) -> NarrowingPredicate | None;

    def _apply_narrowing(
        predicate: NarrowingPredicate,
        incoming: TypeBase | None,
        is_true_branch: bool,
        symbol: uni.Symbol
    ) -> TypeBase | None;

    def _union_narrowed_types(types_list: list) -> TypeBase;
    def exclude_type_from_union(original: TypeBase, to_exclude: TypeBase) -> TypeBase;
}
