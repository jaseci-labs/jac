"""
Type system evaluator for JacLang.

PyrightReference:
    packages/pyright-internal/src/analyzer/typeEvaluator.ts
    packages/pyright-internal/src/analyzer/typeEvaluatorTypes.ts
"""

import ast as py_ast;
import os;
import from pathlib { Path }
import from typing { TYPE_CHECKING, cast }
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

# FIXME: Conver the bellow to dot import (from . import ...)
# Currently its not possible with jac+python hybrid repos.
import from jaclang.compiler.type_system { operations }
import from jaclang.compiler.type_system { type_utils }
import from jaclang.compiler.type_system { properties }
import from jaclang.compiler.type_system { enum_utils }
import from jaclang.compiler.type_system.types { TypeBase }

import from jaclang.jac0core.diagnostics {
    DiagnosticInfo,
    E1001,
    E1002,
    E1003,
    E1004,
    E1010,
    E1011,
    E1020,
    E1021,
    E1022,
    E1023,
    E1030,
    E1031,
    E1032,
    E1033,
    E1034,
    E1035,
    E1040,
    E1041,
    E1050,
    E1051,
    E1052,
    E1053,
    E1054,
    E1056,
    E1057,
    E1060,
    E1061,
    E1062,
    E1063,
    E1064,
    E1065,
    E1070,
    E1071,
    E1072,
    E1073,
    E1080,
    E1081,
    E1090,
    E1091,
    E1092,
    E1093,
    E1094,
    E1095,
    E1096,
    E1097,
    E1098,
    E1099,
    E1100,
    E1101,
    E1102,
    E1103,
    E1104,
    W1050,
    W1100,
    W1101,
    W1102
}

"""Types whose definitions are prefetched and cached by the type evaluator."""
obj PrefetchedTypes {
    has none_type_class: types.ClassType | None = None,
        object_class: types.ClassType | None = None,
        type_class: types.ClassType | None = None,
        union_type_class: types.ClassType | None = None,
        awaitable_class: types.ClassType | None = None,
        function_class: types.ClassType | None = None,
        method_class: types.ClassType | None = None,
        tuple_class: types.ClassType | None = None,
        bool_class: types.ClassType | None = None,
        int_class: types.ClassType | None = None,
        float_class: types.ClassType | None = None,
        str_class: types.ClassType | None = None,
        bytes_class: types.ClassType | None = None,
        dict_class: types.ClassType | None = None,
        list_class: types.ClassType | None = None,
        module_type_class: types.ClassType | None = None,
        typed_dict_class: types.ClassType | None = None,
        typed_dict_private_class: types.ClassType | None = None,
        supports_keys_and_get_item_class: types.ClassType | None = None,
        mapping_class: types.ClassType | None = None,
        template_class: types.ClassType | None = None,
        type_var_class: types.ClassType | None = None,
        param_spec_class: types.ClassType | None = None,
        type_var_tuple_class: types.ClassType | None = None,
        classmethod_class: types.ClassType | None = None,
        # Prefetch from typing.pyi file
        protocol_class: types.ClassType | None = None,
        any_class: types.ClassType | None = None,
        callable_class: types.ClassType | None = None,
        # Prefetched from jac_builtins.pyi file
        final_class: types.ClassType | None = None,
        literal_string_class: types.ClassType | None = None,
        root_class: types.ClassType | None = None,
        node_class: types.ClassType | None = None,
        walker_class: types.ClassType | None = None,
        jsx_element_class: types.ClassType | None = None,
        # Intrinsic element prop types (from dom_types.pyi)
        html_common_props_class: types.ClassType | None = None,
        jsx_intrinsic_elements_class: types.ClassType | None = None,
        # Fixed-width numeric types
        i8_class: types.ClassType | None = None,
        u8_class: types.ClassType | None = None,
        i16_class: types.ClassType | None = None,
        u16_class: types.ClassType | None = None,
        i32_class: types.ClassType | None = None,
        u32_class: types.ClassType | None = None,
        i64_class: types.ClassType | None = None,
        u64_class: types.ClassType | None = None,
        f32_class: types.ClassType | None = None,
        f64_class: types.ClassType | None = None,
        # Prefetched enum base class
        enum_class: types.ClassType | None = None,
        set_class: types.ClassType | None = None;
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

"""Wraps the identity of what is being narrowed (a symbol or a dotted expression)."""
obj NarrowingTarget {
    has key: str,  # "x" or "bmw.speed"
        declared_type: TypeBase,
        symbol: uni.Symbol | None = None;  # None for expression-based narrowing
}

"""Represents a narrowing operation from a conditional predicate."""
obj NarrowingPredicate {
    has key: str,
        narrow_type: TypeBase,
        is_inverted: bool = False;
}

"""Classification of a leaf narrowing condition."""
enum NarrowingKind {
    ISINSTANCE = "isinstance",
    CALLABLE = "callable",
    NONE_IS = "none_is",
    NONE_IS_NOT = "none_is_not",
    TRUTHINESS = "truthiness",
    LITERAL_EQ = "literal_eq",
    LITERAL_NE = "literal_ne"
}

"""Result of classifying a leaf condition node.

Captures the narrowing-kind-specific info extracted from the AST.
Structural wrappers (parens, NOT, AND, OR) are handled by callers
before reaching classification.
"""
obj ConditionInfo {
    has kind: NarrowingKind,
        key: str,
        narrow_type: (TypeBase | None) = None;
}

"""Type evaluator for JacLang."""
obj TypeEvaluator {
    has program: "JacProgram",
        # Path constants - initialized in postinit (use __file__ from impl)
        _BUILTINS_STUB_FILE_PATH: str by postinit,
        _TYPING_STUB_FILE_PATH: str by postinit,
        _TYPES_STUB_FILE_PATH: str by postinit,
        _JAC_BUILTINS_STUB_FILE_PATH: str by postinit,
        _DOM_TYPES_STUB_FILE_PATH: str by postinit,
        _ENUM_STUB_FILE_PATH: str by postinit,
        _SPECIAL_FORM_CLASS_NAMES: tuple[(str, ...)] = (
            "Union",
            "Protocol",
            "Callable",
            "Type",
            "NoReturn",
            "ClassVar",
            "Optional",
            "Tuple",
            "Final",
            "Literal",
            "TypedDict"
        ),
        # Resolution and state
        symbol_resolution_stack: list[SymbolResolutionStackEntry] = [],
        prefetch: PrefetchedTypes by postinit,
        _pass: object | None = None,
        builtins_module: uni.Module | None = None,
        # Type narrowing (CFG-based only — no scope stack)
        _flow_node_type_cache: dict[tuple, types.TypeBase | None] = {},
        _flow_pending_symbols: set[int] by postinit,
        _flow_pending_keys: set[str] by postinit,
        _module_type_cache: dict[str, types.ModuleType] = {},
        # Stub modules - initialized in postinit
        typing_module: uni.Module by postinit,
        types_module: uni.Module by postinit,
        enum_module: uni.Module by postinit,
        jac_builtins_module: uni.Module by postinit,
        dom_types_module: uni.Module by postinit;

    def postinit -> None;
    def _load_stub_module(path: str) -> uni.Module;
    def _get_type_from_module(module: uni.Module, name: str) -> TypeBase;
    def _prefetch_types;
    def get_none_type -> TypeBase;
    def emit_diag(diag: DiagnosticInfo, nd: uni.UniNode, **kwargs: object) -> None;
    def get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None;
    def push_symbol_resolution(symbol: uni.Symbol) -> bool;
    def pop_symbol_resolution(symbol: uni.Symbol) -> bool;
    # Pyright equivalent function name = getEffectiveTypeOfSymbol.
    def get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    # NOTE: This function doesn't exists in pyright, however it exists as a helper function
    # for the following functions.
    def _import_module_from_path(path: str) -> uni.Module;
    def _try_read_jir_cache(resolved_path: str) -> (uni.Module | None);
    def _reattach_impl_modules(mod: uni.Module, source_path: str) -> None;
    def _resolve_from_path(from_mod: uni.ModulePath) -> Path;
    def _is_fstring_all_literal(fstring: uni.FString) -> bool;
    def _try_resolve_forward_ref(expr: uni.String) -> TypeBase | None;
    def get_type_of_module(node_: uni.ModulePath) -> types.TypeBase;
    def get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase;
    def _resolve_star_import_symbol(
        mod: uni.Module, name: str, visited: set[int] | None = None
    ) -> uni.Symbol | None;

    def _extract_type_params(node_: uni.Archetype) -> list[types.TypeVarType];
    def _collect_typevars_from_base(
        base_class: uni.AtomTrailer,
        outer_names: set[str],
        seen_names: set[str],
        type_params: list[types.TypeVarType]
    ) -> None;

    def get_type_of_class(node_: uni.Archetype) -> types.ClassType;
    def get_type_of_enum(node_: uni.Enum) -> types.ClassType;
    def get_type_of_ability(node_: uni.Ability) -> TypeBase;
    def get_type_of_string(nd: uni.String | uni.MultiString) -> TypeBase;
    def get_type_of_int(nd: uni.Int) -> TypeBase;
    def get_type_of_float(nd: uni.Float) -> TypeBase;
    def get_type_of_expression(
        node_: uni.Expr, expected_type: TypeBase | None = None
    ) -> TypeBase;
    # Check if a type is Any, object, Unknown, or TypeVar.
    def is_any_type(ty: TypeBase) -> bool;
    # Check if a type is the TypeVar class itself (the callable used to create TypeVars).
    def is_typevar_class(ty: TypeBase) -> bool;
    # Check if a type is the ParamSpec class itself (not a TypeVarType instance).
    def is_paramspec_class(ty: TypeBase) -> bool;
    # Check if a type is the TypeVarTuple class itself (not a TypeVarType instance).
    def is_type_var_tuple_class(ty: TypeBase) -> bool;
    # Match a typing special form by canonical name from stdlib stubs so
    # typing.X and typing_extensions.X (distinct classes in typeshed) both count.
    def _is_typing_special_form(ty: TypeBase, name: str) -> bool;
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
    # --- Callable assignment compatibility ---
    def _assign_callable(
        src_func: types.FunctionType, dest_func: types.FunctionType
    ) -> bool;

    def _is_ability_classmethod(node_: uni.Ability) -> bool;
    # Shared classifier: single decorator walk, returns the property kind.
    def _classify_property_symbol(symbol: uni.Symbol) -> type_utils.PropertyWriteKind;
    # Property type utilities — both delegate to _classify_property_symbol.
    def get_getter_type_from_property(symbol: uni.Symbol) -> (TypeBase | None);
    # Classifies a property symbol's writability for assignment checking.
    # Returns a PropertyWriteResult with kind:
    #   NOT_PROPERTY → normal field, caller should fall through
    #   READ_ONLY    → @property with no setter, assignment is illegal
    #   WRITABLE     → @cached_property or @property+setter, write_type set
    def get_property_write_type(symbol: uni.Symbol) -> type_utils.PropertyWriteResult;
    # Extract setter value-param type from a @name.setter overload symbol.
    def _get_setter_value_type(
        symbol: uni.Symbol, prop_name: str
    ) -> (TypeBase | None);

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
    # gets member type and specializes it with class type_args
    def get_type_of_member(member: Any, class_type: types.ClassType) -> TypeBase;
    # Pyright: partiallySpecializeType - substitutes TypeVars using class type_args
    # Now uses type_utils.apply_solved_type_vars
    def specialize_member_type(
        member_type: TypeBase, class_type: types.ClassType
    ) -> TypeBase;
    # Pyright equivalent function name = getTypeOfExpressionCore();
    def _get_type_of_expression_core(
        expr: uni.Expr, expected_type: TypeBase | None = None
    ) -> TypeBase;
    # -----------------------------------------------------------------------------
    # Helper functions
    # -----------------------------------------------------------------------------
    def _set_module_item_symbol_and_type(
        node_: uni.ModuleItem, sym: uni.Symbol
    ) -> TypeBase;

    def resolve_imported_symbols(sym: uni.Symbol) -> uni.Symbol;
    def _set_symbol_to_expr(expr: uni.Expr, sym: uni.Symbol) -> TypeBase;
    def _is_expr_self(expr: uni.Expr) -> bool;
    def _is_expr_super(expr: uni.Expr) -> bool;
    def _get_enclosing_function(nd: uni.UniNode) -> uni.Ability | None;
    def _get_enclosing_return_scope(
        nd: uni.UniNode
    ) -> uni.Ability | uni.LambdaExpr | None;

    def _get_declared_return_type(
        scope: uni.Ability | uni.LambdaExpr
    ) -> TypeBase | None;

    def _infer_lambda_block_return_type(body: list[uni.CodeBlockStmt]) -> TypeBase;
    def _collect_return_types(
        stmts: list[uni.CodeBlockStmt], out: list[TypeBase]
    ) -> bool;

    def _collect_if_else_returns(
        else_body: uni.ElseIf | uni.ElseStmt | None, out: list[TypeBase]
    ) -> bool;

    def _get_enclosing_method(nd: uni.UniNode) -> uni.Ability | None;
    def _get_enclosing_class(nd: uni.UniNode) -> uni.Archetype | None;
    def _get_type_of_self(node_: uni.SpecialVarRef) -> TypeBase;
    def _get_type_of_super(node_: uni.SpecialVarRef) -> TypeBase;
    def _get_type_of_lhs_assignment(expr: uni.Name) -> TypeBase | None;
    def _extract_tuple_element_type(tuple_type: TypeBase, idx: int) -> TypeBase | None;
    def _extract_tuple_element_type_path(
        tuple_type: TypeBase, path: list[int]
    ) -> TypeBase | None;

    def _convert_to_instance(jtype: TypeBase) -> TypeBase;
    def _type_in_list(ty: TypeBase, type_list: list[TypeBase]) -> bool;
    def _collect_unique_types(ty: TypeBase, result: list[TypeBase]) -> None;
    # --- Expected type helpers for bidirectional inference ---
    def _get_expected_element_type(
        expected_type: TypeBase | None, container_class: TypeBase
    ) -> TypeBase | None;

    def _get_expected_kv_types(
        expected_type: TypeBase | None, dict_class: TypeBase
    ) -> tuple[TypeBase, TypeBase] | None;
    # --- Special form handling (Callable, Union, etc.) ---
    # Returns the prefetched special form type if the name AND type match.
    # Verifies both name and that type is _SpecialForm to avoid conflicts
    # with user-defined classes named "Callable".
    def _get_special_form_type(
        name: str, symbol_type: types.TypeBase
    ) -> types.TypeBase | None;
    # creates Self TypeVar if symbol is typing.Self
    def create_self_type(symbol_type: types.TypeBase) -> types.TypeVarType | None;
    # --- Callable type handling (similar to Pyright's createCallableType) ---
    def _create_callable_type(
        type_args_expr: uni.Expr | None, error_node: uni.Expr
    ) -> types.FunctionType;

    def _lookup_class_member(
        base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None;

    def _lookup_object_member(
        base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None;

    # Get bound member from a class type, handling type[T] subscripts.
    def get_type_of_bound_member(
        object_type: types.ClassType, member_name: str
    ) -> type_utils.ClassMember | None;

    # Check if ClassType is type[T] (builtin type with type args).
    def _is_type_subscript(class_type: types.ClassType) -> bool;
    # Get lookup type for member access (extracts T from type[T]).
    def _get_type_for_member_lookup(object_type: types.ClassType) -> types.ClassType;
    def _get_getattr_return_type(base_type: types.ClassType) -> TypeBase | None;
    def match_args_to_params(
        arg_nodes: list[uni.Expr | uni.KWPair],
        node_for_error: uni.Expr | None,
        func_type: types.FunctionType,
        checking_overload: bool = False,
        is_unbound_call: bool = False
    ) -> MatchArgsToParamsResult;

    def _is_unbound_method_call(expr: uni.FuncCall) -> bool;
    def validate_call_args(expr: uni.FuncCall) -> TypeBase;
    def validate_arg_types(
        args: MatchArgsToParamsResult, checking_overload: bool = False
    ) -> None;

    def _build_field_params(
        class_type: types.ClassType, skip_deferred: bool = True
    ) -> dict[str, types.Parameter];

    def _create_dataclass_init_method(
        class_type: types.ClassType
    ) -> types.FunctionType;

    def _create_namedtuple_new_method(
        class_type: types.ClassType
    ) -> types.FunctionType;

    def _create_special_builtin_type(
        name: str, base_class: types.ClassType
    ) -> types.ClassType;

    def _validate_constructor_method(
        expr: uni.FuncCall, method_type: TypeBase
    ) -> types.FunctionType | None;

    def _strip_implicit_self_cls(method: types.FunctionType) -> types.FunctionType;
    def _get_method_with_overloads(
        method_member: Any, caller_type: types.ClassType
    ) -> TypeBase;

    # -------------------------------------------------------------------------
    # Generic type inference
    # -------------------------------------------------------------------------
    def assign_type_to_type_var(
        param_type: TypeBase, arg_type: TypeBase, bindings: dict[str, TypeBase]
    ) -> bool;

    def infer_type_args(
        caller_type: types.ClassType, expr: uni.FuncCall
    ) -> list[TypeBase];

    def _infer_type_args_from_method(
        caller_type: types.ClassType,
        expr: uni.FuncCall,
        matched_method: types.FunctionType | None
    ) -> list[TypeBase];

    def _find_matching_raw_constructor(
        caller_type: types.ClassType,
        expr: uni.FuncCall,
        matched_method: types.FunctionType | None
    ) -> types.FunctionType | None;

    def _find_overload_by_arg_count(
        method_type: types.TypeBase, arg_count: int, overload_symbols: list
    ) -> types.FunctionType | None;

    def _substitute_type_vars(
        typ: types.TypeBase, bindings: dict[str, types.TypeBase]
    ) -> types.TypeBase;

    def _get_constructor_for_inference(
        caller_type: types.ClassType
    ) -> types.FunctionType | None;

    def _has_meaningful_params(method: types.FunctionType) -> bool;
    def _collect_type_var_bindings(
        method: types.FunctionType,
        expr: uni.FuncCall,
        is_unbound_call: bool = False,
        is_constructor_call: bool = False
    ) -> dict[str, TypeBase];

    # -------------------------------------------------------------------------
    # JSX prop validation
    # -------------------------------------------------------------------------
    def _validate_jsx_props(
        expr: uni.JsxElement, expected_type: TypeBase | None = None
    ) -> None;

    def _resolve_jsx_component_type(
        name: uni.JsxElementName
    ) -> types.FunctionType | None;

    def _get_intrinsic_props_type(tag_name: str) -> types.ClassType | None;
    def _validate_component_jsx_props(
        expr: uni.JsxElement, component_name: str
    ) -> None;

    def _validate_intrinsic_jsx_props(expr: uni.JsxElement, tag_name: str) -> None;
    def _resolve_intrinsic_jsx_tag(part: uni.Name, tag_name: str) -> None;
    # -------------------------------------------------------------------------
    # TypeVar scope validation (Pyright: validateTypeVarUsage)
    # -------------------------------------------------------------------------
    def validate_typevar_in_type_expr(expr: uni.Expr) -> None;
    def validate_typevar_scope(expr: uni.Expr, type_var: types.TypeVarType) -> None;
    def validate_typevar_variance(func: uni.Ability) -> None;
    def validate_typevar_operation(
        expr: uni.Expr, operand_type: types.TypeBase, operation: str
    ) -> None;

    def _get_enclosing_class_type_params(
        node_: uni.UniNode
    ) -> list[types.TypeVarType];

    def _get_function_type_params(func: uni.Ability) -> list[types.TypeVarType];
    def _get_outer_scope_type_params(node_: uni.UniNode) -> list[types.TypeVarType];
    # -------------------------------------------------------------------------
    # Type narrowing support
    #
    # Two narrowing systems work together:
    # 1. Scope-based narrowing: Tracks narrowings within if/AND blocks using a
    #    stack of scope dictionaries. Used during forward AST traversal.
    # 2. CFG-based narrowing: Walks backward through the control flow graph to
    #    find narrowing conditions. Used for flow-sensitive analysis.
    # -------------------------------------------------------------------------

    # --- CFG-based narrowing (backward traversal) ---
    def create_key_for_reference(expr: uni.Expr) -> str | None;
    def _find_symbol_by_key(key: str, condition: uni.Expr) -> uni.Symbol | None;
    def classify_condition(condition: uni.Expr) -> ConditionInfo | None;
    def get_narrowed_type(symbol: uni.Symbol, at_node: uni.UniNode) -> TypeBase | None;
    def get_narrowed_type_for_expr(
        expr: uni.Expr, declared_type: TypeBase, at_node: uni.UniNode
    ) -> TypeBase | None;

    def _get_type_from_flow_node(
        target: NarrowingTarget, flow_node: uni.UniCFGNode, visited: set
    ) -> TypeBase | None;

    def _classify_edge(pred: uni.IfStmt, succ: uni.UniCFGNode) -> str;
    # --- Shared narrowing utilities ---
    def _find_predicate_for(
        target: NarrowingTarget, condition: uni.Expr
    ) -> NarrowingPredicate | None;

    def _apply_narrowing(
        predicate: NarrowingPredicate,
        incoming: TypeBase | None,
        is_true_branch: bool,
        target: NarrowingTarget
    ) -> TypeBase | None;

    def _refine_isinstance_type(
        narrowing_key: str, isinstance_type: TypeBase, condition: uni.Expr
    ) -> TypeBase;

    def _filter_union_for_isinstance(
        base_type: TypeBase, target_type: TypeBase
    ) -> TypeBase | None;

    def _type_matches_isinstance(t: TypeBase, target_type: TypeBase) -> bool;
    def _union_narrowed_types(types_list: list) -> TypeBase;
    def exclude_type_from_union(original: TypeBase, to_exclude: TypeBase) -> TypeBase;
    def _get_type_from_match_pattern(pattern: uni.MatchPattern) -> TypeBase | None;
    def _union_contains_none(union_type: TypeBase) -> bool;
    def _extract_isinstance_info(condition: uni.Expr) -> tuple[str, TypeBase] | None;
    def _extract_callable_info(condition: uni.Expr) -> str | None;
    def _is_callable_type(t: TypeBase) -> bool;
    def _filter_union_to_callables(union_type: TypeBase) -> TypeBase;
    def _filter_union_to_non_callables(union_type: TypeBase) -> TypeBase;
    def _is_ellipsis_only_body(body: list[uni.CodeBlockStmt]) -> bool;
    def _is_type_alias_annotation(
        annotation_type: TypeBase, tag_expr: uni.Expr
    ) -> bool;

    def _resolve_type_alias_rhs(value: uni.Expr) -> TypeBase;
    def _resolve_string_type_expr(
        type_str: str, scope: uni.UniScopeNode
    ) -> TypeBase | None;

    def _resolve_py_ast_type_node(
        ast_node: object, scope: uni.UniScopeNode
    ) -> TypeBase | None;
}
