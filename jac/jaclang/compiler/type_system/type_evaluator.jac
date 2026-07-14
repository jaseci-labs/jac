import ast as py_ast;
import os;
import from pathlib { Path }
import from typing { cast }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant {
    TOKEN_MAP,
    SymbolType,
    Tokens as Tok,
    EdgeDir,
    SymbolAccess,
}
import from jaclang.compiler.passes.main.pyast_load_pass { PyastBuildPass }
import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.type_system { types }
import from jaclang.jac0core.helpers { read_file_with_encoding }
import type from jaclang.jac0core.program { JacProgram }

import from jaclang.compiler.type_system { operations }
import from jaclang.compiler.type_system { type_utils }
import from jaclang.compiler.type_system { properties }
import from jaclang.compiler.symbol_utils { int_subscript_suffix }
import from jaclang.compiler.type_system { enum_utils }
import from jaclang.compiler.type_system.types { TypeBase }
import from jaclang.compiler.type_system.ts_decl_parser {
    TsDecl,
    TsType,
    TsTypeKind,
    TsDeclKind,
    TsAccess,
    TsMember
}

import from jaclang.jac0core.diagnostics {
    DiagnosticInfo,
    E1001,
    E1010,
    E1023,
    E1030,
    E1031,
    E1032,
    E1033,
    E1034,
    E1035,
    E1040,
    E1041,
    E1043,
    E1050,
    E1051,
    E1052,
    E1053,
    E1054,
    E1056,
    E1057,
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
    E1096,
    E1097,
    E1098,
    E1099,
    E1100,
    E1101,
    E1102,
    E1103,
    E1104,
    E1110,
    E1111,
    E1120,
    W0062,
    W1050,
    W1051,
    W1100,
    W1101,
    W1102
}

"""Types whose definitions are prefetched and cached by the type evaluator."""
obj PrefetchedTypes {
    has none_type_class: types.ClassType | None = None,
        object_class: types.ClassType | None = None,
        type_class: types.ClassType | None = None,
        coroutine_class: types.ClassType | None = None,
        function_class: types.ClassType | None = None,
        tuple_class: types.ClassType | None = None,
        bool_class: types.ClassType | None = None,
        int_class: types.ClassType | None = None,
        float_class: types.ClassType | None = None,
        str_class: types.ClassType | None = None,
        bytes_class: types.ClassType | None = None,
        dict_class: types.ClassType | None = None,
        list_class: types.ClassType | None = None,
        slice_class: types.ClassType | None = None,
        type_var_class: types.ClassType | None = None,
        param_spec_class: types.ClassType | None = None,
        type_var_tuple_class: types.ClassType | None = None,
        classmethod_class: types.ClassType | None = None,
        protocol_class: types.ClassType | None = None,
        any_class: types.ClassType | None = None,
        callable_class: types.ClassType | None = None,
        final_class: types.ClassType | None = None,
        literal_string_class: types.ClassType | None = None,
        root_class: types.ClassType | None = None,
        node_class: types.ClassType | None = None,
        walker_class: types.ClassType | None = None,
        path_class: types.ClassType | None = None,
        jsx_element_class: types.ClassType | None = None,
        html_common_props_class: types.ClassType | None = None,
        jsx_intrinsic_elements_class: types.ClassType | None = None,
        enum_class: types.ClassType | None = None,
        set_class: types.ClassType | None = None;
}

obj SymbolResolutionStackEntry {
    has symbol: uni.Symbol,
        is_result_valid: bool = True,
        partial_type: TypeBase | None = None;
}

obj MatchArgsToParamsResult {
    has arg_params: dict[(uni.Expr | uni.KWPair, types.Parameter | None)],
        overload: types.FunctionType | None = None,
        argument_errors: bool = False;
}

obj NarrowingTarget {
    has key: str,
        declared_type: TypeBase,
        symbol: uni.Symbol | None = None,
        deps: frozenset[str] = frozenset();
}

obj NarrowingPredicate {
    has key: str,
        narrow_type: TypeBase,
        is_inverted: bool = False,
        attr_name: str | None = None;
}

enum NarrowingKind {
    ISINSTANCE = "isinstance",
    CALLABLE = "callable",
    NONE_IS = "none_is",
    NONE_IS_NOT = "none_is_not",
    TRUTHINESS = "truthiness",
    LITERAL_EQ = "literal_eq",
    LITERAL_NE = "literal_ne",
    HASATTR = "hasattr"
}

obj ConditionInfo {
    has kind: NarrowingKind,
        key: str,
        narrow_type: (TypeBase | None) = None,
        attr_name: str | None = None;
}

obj TypeEvaluator {
    has program: "JacProgram",
        _BUILTINS_STUB_FILE_PATH: str by postinit,
        _TYPING_STUB_FILE_PATH: str by postinit,
        _TYPES_STUB_FILE_PATH: str by postinit,
        _JAC_BUILTINS_STUB_FILE_PATH: str by postinit,
        _DOM_TYPES_STUB_FILE_PATH: str by postinit,
        _NA_BUILTINS_STUB_FILE_PATH: str by postinit,
        _JS_GLOBALS_STUB_FILE_PATH: str by postinit,
        _TYPING_AMBIENT_STUB_FILE_PATH: str by postinit,
        ambient_typing_names_by_module: dict[str, set[str]] = {},
        _ENUM_STUB_FILE_PATH: str by postinit,
        symbol_resolution_stack: list[SymbolResolutionStackEntry] = [],
        prefetch: PrefetchedTypes by postinit,
        _pass: object | None = None,
        builtins_module: uni.Module | None = None,
        _flow_node_type_cache: dict[tuple, types.TypeBase | None] = {},
        _flow_pending_symbols: set[int] by postinit,
        _flow_pending_keys: set[str] by postinit,
        _module_type_cache: dict[str, types.ModuleType] = {},
        _mobui_module_cache: dict[str, bool] = {},
        _strict_site_cache: dict[int, bool] = {},
        _sv_async_syms_cache: dict[int, set[int]] = {},
        _and_narrowing_overrides: dict[int, TypeBase] = {},
        _ts_decl_cache: dict[str, (dict[str, TsDecl] | None)] = {},
        _ts_decl_path_cache: dict[str, (str | None)] = {},
        _ts_synth_class_cache: dict[int, (dict[str, types.ClassType] | None)] = {},
        _untyped_external_cfg_cache: dict[str, bool] = {},
        typing_module: uni.Module by postinit,
        types_module: uni.Module by postinit,
        enum_module: uni.Module by postinit,
        jac_builtins_module: uni.Module by postinit,
        dom_types_module: uni.Module by postinit,
        na_builtins_module: uni.Module by postinit,
        js_globals_module: uni.Module by postinit;

    def postinit -> None;
    def _load_stub_module(path: str) -> uni.Module;
    def _get_type_from_module(module: uni.Module, name: str) -> TypeBase;
    def _prefetch_types;
    def get_none_type -> TypeBase;
    def emit_diag(diag: DiagnosticInfo, nd: uni.UniNode, **kwargs: object) -> None;
    def _invalidate_expr_type_cache(node_: uni.UniNode) -> None;
    def get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None;
    def push_symbol_resolution(symbol: uni.Symbol) -> bool;
    def pop_symbol_resolution(symbol: uni.Symbol) -> bool;
    def get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    def resolve_to_definition_symbol(symbol: uni.Symbol) -> uni.Symbol;
    def _widen_literal_for_declaration(ty: TypeBase) -> TypeBase;
    def _import_module_from_path(
        path: str, importer_path: (str | None) = None
    ) -> uni.Module;

    def _resolve_importer_path(ast_node: uni.UniNode) -> (str | None);
    def _try_read_jir_cache(resolved_path: str) -> (uni.Module | None);
    def forget_module(resolved_path: str) -> None;
    def _resolve_from_path(from_mod: uni.ModulePath) -> Path;
    def _resolve_client_npm_module(node_: uni.ModulePath) -> (str | None);
    def _get_ts_declared_item_type(
        from_loc: uni.ModulePath, item_name: str
    ) -> (TypeBase | None);

    def _ts_declared_type_from_file(
        dts_path: str, item_name: str
    ) -> (TypeBase | None);

    def _load_ts_declarations(dts_path: str) -> (dict[str, TsDecl] | None);
    def _map_ts_decl(
        decl: TsDecl, decls: dict[str, TsDecl], item_name: str
    ) -> (TypeBase | None);

    def _map_ts_type(
        ts: (TsType | None),
        decls: dict[str, TsDecl],
        seen: (set[str] | None) = None,
        shells: (dict[str, types.ClassType] | None) = None
    ) -> TypeBase;

    def _synthesize_ts_decl_class(
        decls: dict[str, TsDecl], item_name: str
    ) -> (TypeBase | None);

    def _install_synth_member(
        scope: uni.UniScopeNode,
        synth_src: uni.Source,
        mname: str,
        member_type: TypeBase
    ) -> None;

    def _ts_synth_class_types(
        decls: dict[str, TsDecl]
    ) -> (dict[str, types.ClassType] | None);

    def _emit_untyped_external(name_node: uni.Name, name: str, module: str) -> None;
    def _untyped_external_is_error(node_: uni.UniNode) -> bool;
    def _is_fstring_all_literal(fstring: uni.FString) -> bool;
    def _try_resolve_forward_ref(expr: uni.String) -> TypeBase | None;
    def _type_from_union_annotation_arg(val: uni.Expr) -> TypeBase;
    def get_type_of_module(node_: uni.ModulePath) -> types.TypeBase;
    def get_type_of_module_item(node_: uni.ModuleItem) -> types.TypeBase;
    def _resolve_submodule_attr(
        base_type: types.ModuleType, attr_name: str
    ) -> (types.ModuleType | None);

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
    def _apply_function_decorators(
        node_: uni.Ability, func_type: types.FunctionType
    ) -> types.FunctionType;

    def get_type_of_int(nd: uni.Int) -> TypeBase;
    def get_type_of_float(nd: uni.Float) -> TypeBase;
    def get_type_of_expression(
        node_: uni.Expr, expected_type: TypeBase | None = None
    ) -> TypeBase;

    def is_any_type(ty: TypeBase) -> bool;
    def is_explicit_any(ty: TypeBase) -> bool;
    def is_none_type(ty: TypeBase) -> bool;
    def _is_strict_site(nd: uni.UniNode) -> bool;
    def _in_native_context -> bool;
    def is_typevar_class(ty: TypeBase) -> bool;
    def is_paramspec_class(ty: TypeBase) -> bool;
    def is_type_var_tuple_class(ty: TypeBase) -> bool;
    def _is_typing_special_form(ty: TypeBase, name: str) -> bool;
    def assign_type(
        src_type: TypeBase, dest_type: TypeBase, strict: bool = False
    ) -> bool;

    def get_type_of_magic_method_call(
        obj_type: TypeBase,
        method_name: str,
        arg_nodes: list[uni.Expr],
        node_for_error: uni.Expr | None = None
    ) -> TypeBase | None;

    def slice_assignment_is_valid(target: uni.Expr, value_node: uni.Expr) -> bool;
    def is_sub_class(super_cls: types.ClassType, sub_cls: types.ClassType) -> bool;
    def _assign_callable(
        src_func: types.FunctionType,
        dest_func: types.FunctionType,
        strict: bool = False
    ) -> bool;

    def _is_ability_classmethod(node_: uni.Ability) -> bool;
    def _is_ability_staticmethod(node_: uni.Ability) -> bool;
    def _classify_property_symbol(symbol: uni.Symbol) -> type_utils.PropertyWriteKind;
    def get_getter_type_from_property(symbol: uni.Symbol) -> (TypeBase | None);
    def get_property_write_type(symbol: uni.Symbol) -> type_utils.PropertyWriteResult;
    def _get_setter_value_type(
        symbol: uni.Symbol, prop_name: str
    ) -> (TypeBase | None);

    def _assign_class(
        src_type: types.ClassType, dest_type: types.ClassType, strict: bool = False
    ) -> bool;

    def _get_type_of_symbol(symbol: uni.Symbol) -> TypeBase;
    def _get_enum_member_type_for_decl(
        node_: uni.Name
    ) -> (types.EnumMemberType | None);

    def get_type_of_member(member: any, class_type: types.ClassType) -> TypeBase;
    def specialize_member_type(
        member_type: TypeBase, class_type: types.ClassType
    ) -> TypeBase;

    def _get_type_of_expression_core(
        expr: uni.Expr, expected_type: TypeBase | None = None
    ) -> TypeBase;

    def _walk_compr_clauses(comprs: list[uni.InnerCompr]) -> None;
    def _null_ok_attr_type(expr: uni.AtomTrailer) -> TypeBase;
    def _set_module_item_symbol_and_type(
        node_: uni.ModuleItem, sym: uni.Symbol
    ) -> TypeBase;

    def resolve_imported_symbols(sym: uni.Symbol) -> uni.Symbol;
    def _set_symbol_to_expr(expr: uni.Expr, sym: uni.Symbol) -> TypeBase;
    def _resolution_scope_for(expr: uni.UniNode) -> uni.UniScopeNode | None;
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
    def _get_type_of_root(node_: uni.SpecialVarRef) -> TypeBase;
    def _get_type_of_lhs_assignment(expr: uni.Name) -> TypeBase | None;
    def _extract_tuple_element_type(tuple_type: TypeBase, idx: int) -> TypeBase | None;
    def _tuple_has_variadic_arg(cls: types.ClassType) -> bool;
    def _tuple_literal_index_type(
        base_type: TypeBase, subscript_arg: uni.Expr
    ) -> TypeBase | None;

    def _extract_tuple_element_type_path(
        tuple_type: TypeBase, path: list[int]
    ) -> TypeBase | None;

    def _get_iterable_element_type(
        iterable_type: TypeBase, node_for_error: uni.Expr | None = None
    ) -> TypeBase | None;

    def _native_iter_next_result(expr: uni.FuncCall) -> TypeBase | None;
    def _convert_to_instance(jtype: TypeBase) -> TypeBase;
    def _edge_endpoint_type(
        edge_type: types.ClassType, edge_dir: EdgeDir
    ) -> TypeBase | None;

    def _type_in_list(ty: TypeBase, type_list: list[TypeBase]) -> bool;
    def _collect_unique_types(ty: TypeBase, result: list[TypeBase]) -> None;
    def _get_expected_element_type(
        expected_type: TypeBase | None, container_class: TypeBase
    ) -> TypeBase | None;

    def _get_expected_kv_types(
        expected_type: TypeBase | None, dict_class: TypeBase
    ) -> tuple[TypeBase, TypeBase] | None;

    def _infer_list_elem_from_mutations(expr: uni.ListVal) -> TypeBase | None;
    def _list_mutation_elem_contrib(ref: uni.NameAtom) -> TypeBase | None;
    def _get_special_form_type(
        name: str, symbol_type: types.TypeBase
    ) -> types.TypeBase | None;

    def _create_callable_type(
        type_args_expr: uni.Expr | None, error_node: uni.Expr
    ) -> types.FunctionType;

    def _lookup_class_member(
        base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None;

    def _lookup_object_member(
        base_type: types.ClassType, member: str
    ) -> type_utils.ClassMember | None;

    def _is_type_subscript(class_type: types.ClassType) -> bool;
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
    def _unannotated_lambda_arg_name(expr: uni.FuncCall) -> str | None;
    def _make_coroutine_type(inner: TypeBase) -> TypeBase;
    def _is_awaitable_type(t: TypeBase) -> bool;
    def _unwrap_awaitable_type(t: TypeBase, node_: uni.UniNode) -> TypeBase;
    def _is_sv_async_call(expr: uni.FuncCall) -> bool;
    def validate_arg_types(
        args: MatchArgsToParamsResult, checking_overload: bool = False
    ) -> None;

    def _build_field_params(
        class_type: types.ClassType, skip_deferred: bool = True
    ) -> dict[str, types.Parameter];

    def _literal_type_from_expr(val: uni.Expr) -> types.TypeBase | None;
    def _build_typeddict_fields(
        class_type: types.ClassType
    ) -> dict[str, types.TypeBase];

    def _has_typeddict_special_form_base(node_: uni.Archetype) -> bool;
    def _typeddict_value_union(base_type: types.ClassType) -> types.TypeBase;
    def _get_typeddict_indexed_type(
        base_type: types.ClassType, key_expr: uni.Expr, err_node: uni.UniNode
    ) -> types.TypeBase | None;

    def _typeddict_as_dict(base_type: types.ClassType) -> types.ClassType | None;
    def _synthesize_typeddict_method(
        base_type: types.ClassType, method: str
    ) -> types.OverloadedType | None;

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
        method_member: any, caller_type: types.ClassType
    ) -> TypeBase;

    def assign_type_to_type_var(
        param_type: TypeBase, arg_type: TypeBase, bindings: dict[str, TypeBase]
    ) -> bool;

    def _infer_type_args_from_method(
        caller_type: types.ClassType,
        expr: uni.FuncCall,
        matched_method: types.FunctionType | None
    ) -> list[TypeBase];

    def _extract_self_annotation_bindings(
        caller_type: types.ClassType,
        method: types.FunctionType,
        bindings: dict[str, TypeBase]
    ) -> None;

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

    def _collect_type_var_bindings(
        method: types.FunctionType,
        expr: uni.FuncCall,
        is_unbound_call: bool = False,
        is_constructor_call: bool = False
    ) -> dict[str, TypeBase];

    def _validate_jsx_props(
        expr: uni.JsxElement, expected_type: TypeBase | None = None
    ) -> None;

    def _resolve_jsx_component_type(
        name: uni.JsxElementName
    ) -> types.FunctionType | None;

    def _is_mobui_module(nd: uni.UniNode) -> bool;
    def _get_intrinsic_props_type(tag_name: str) -> types.ClassType | None;
    def _validate_component_jsx_props(
        expr: uni.JsxElement,
        component_name: str,
        func_type: types.FunctionType | None = None
    ) -> None;

    def _validate_intrinsic_jsx_props(expr: uni.JsxElement, tag_name: str) -> None;
    def _resolve_intrinsic_jsx_tag(part: uni.Name, tag_name: str) -> None;
    def validate_typevar_in_type_expr(expr: uni.Expr) -> None;
    def validate_typevar_scope(expr: uni.Expr, type_var: types.TypeVarType) -> None;
    def validate_typevar_variance(func: uni.Ability) -> None;
    def _get_enclosing_class_type_params(
        node_: uni.UniNode
    ) -> list[types.TypeVarType];

    def _get_function_type_params(func: uni.Ability) -> list[types.TypeVarType];
    def _get_outer_scope_type_params(node_: uni.UniNode) -> list[types.TypeVarType];
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
    def _find_predicate_for(
        target: NarrowingTarget, condition: uni.Expr
    ) -> NarrowingPredicate | None;

    def _apply_narrowing(
        predicate: NarrowingPredicate,
        incoming: TypeBase | None,
        is_true_branch: bool,
        target: NarrowingTarget
    ) -> TypeBase | None;

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
    def _extract_hasattr_info(condition: uni.Expr) -> tuple[str, str] | None;
    def _type_has_attribute(t: TypeBase, attr_name: str) -> bool;
    def _filter_union_for_hasattr(
        base_type: TypeBase, attr_name: str, keep_with_attr: bool
    ) -> TypeBase | None;

    def _is_callable_type(t: TypeBase) -> bool;
    def _filter_union_to_callables(union_type: TypeBase) -> TypeBase;
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
