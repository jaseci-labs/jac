import os;
import from pathlib { Path }
import from typing { cast }
import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    AssertStmt,
    AssignCompr,
    Assignment,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    BinaryExpr,
    Bool,
    BoolExpr,
    BuiltinType,
    CastExpr,
    CfgExpr,
    CodeBlockStmt,
    CompareExpr,
    ConcurrentExpr,
    CtrlStmt,
    DictCompr,
    DictVal,
    EdgeOpRef,
    EdgeRefTrailer,
    Ellipsis,
    ElseIf,
    ElseStmt,
    Enum,
    EventSignature,
    Except,
    Expr,
    ExprStmt,
    FString,
    FilterCompr,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    FuncSignature,
    GenCompr,
    HasVar,
    IfElseExpr,
    IfStmt,
    ImplDef,
    Import,
    InForStmt,
    IndexSlice,
    InnerCompr,
    Int,
    IterForStmt,
    JsxElement,
    JsxElementName,
    JsxNormalAttribute,
    JsxSpreadAttribute,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    MatchArch,
    MatchAs,
    MatchCase,
    MatchOr,
    MatchPattern,
    MatchStmt,
    MatchWild,
    Module,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    Null,
    OpenStmt,
    ParamKind as UniParamKind,
    ParamVar,
    RaiseStmt,
    ReturnStmt,
    Semi,
    SetCompr,
    SetVal,
    Source,
    SpecialVarRef,
    String,
    SubTag,
    SwitchCase,
    SwitchStmt,
    Symbol,
    Token,
    TryStmt,
    TupleVal,
    TypeAlias,
    TypeParam,
    UnaryExpr,
    UniCFGNode,
    UniNode,
    UniScopeNode,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.jac0core.constant {
    TOKEN_MAP,
    SymbolType,
    Tokens as Tok,
    EdgeDir,
    SymbolAccess,
    OwnershipKind,
}
import from jaclang.compiler.type_system.types {
    AnyType,
    ClassDetailsPrivate,
    ClassDetailsShared,
    ClassType,
    EnumMemberInfo,
    EnumMemberType,
    FunctionType,
    FunctionTypeFlags,
    ModuleType,
    NeverType,
    OverloadedType,
    ParamKind,
    Parameter,
    ParameterCategory,
    TypeBase,
    TypeCategory,
    TypeFlags,
    TypeVarType,
    UnionType,
    UnknownType,
    create_callable_type
}
import from jaclang.jac0core.helpers { read_file_with_encoding }
import from jaclang.jac0core.passes.transform { Transform }
import type from jaclang.jac0core.program { JacProgram }

import from jaclang.compiler.type_system.operations {
    BINARY_OPERATOR_MAP,
    get_type_of_binary_operation,
    is_annotation_type
}
import from jaclang.compiler.type_system.type_utils {
    ClassMember,
    ParamAssignmentTracker,
    PropertyWriteKind,
    PropertyWriteResult,
    apply_solved_type_vars,
    build_type_var_solution,
    class_implements_protocol,
    collect_member_syms,
    compute_module_source_flags,
    compute_mro_linearization,
    convert_to_instance,
    get_declared_generator_return_type,
    is_generator_family_type,
    lookup_symtab,
    shadowed_type_var_names,
    specialize_for_base_class,
    synthesize_self_type_var
}
import from jaclang.compiler.type_system.properties {
    is_cached_property_decorator_type,
    is_property_decorator_type
}
import from jaclang.compiler.type_system.enum_utils {
    build_enum_members,
    get_special_enum_value_type_from_bases
}
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
    E1044,
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
    E1121,
    E0049,
    W1050,
    W1051,
    W1100,
    W1101,
    W1102
}

obj PrefetchedTypes {
    has none_type_class: ClassType | None = None,
        object_class: ClassType | None = None,
        type_class: ClassType | None = None,
        coroutine_class: ClassType | None = None,
        function_class: ClassType | None = None,
        tuple_class: ClassType | None = None,
        bool_class: ClassType | None = None,
        int_class: ClassType | None = None,
        float_class: ClassType | None = None,
        str_class: ClassType | None = None,
        bytes_class: ClassType | None = None,
        dict_class: ClassType | None = None,
        list_class: ClassType | None = None,
        slice_class: ClassType | None = None,
        type_var_class: ClassType | None = None,
        param_spec_class: ClassType | None = None,
        type_var_tuple_class: ClassType | None = None,
        classmethod_class: ClassType | None = None,
        protocol_class: ClassType | None = None,
        any_class: ClassType | None = None,
        callable_class: ClassType | None = None,
        final_class: ClassType | None = None,
        literal_string_class: ClassType | None = None,
        root_class: ClassType | None = None,
        node_class: ClassType | None = None,
        walker_class: ClassType | None = None,
        path_class: ClassType | None = None,
        jsx_element_class: ClassType | None = None,
        html_common_props_class: ClassType | None = None,
        jsx_intrinsic_elements_class: ClassType | None = None,
        enum_class: ClassType | None = None,
        mappingproxy_class: ClassType | None = None,
        set_class: ClassType | None = None;
}

obj MatchArgsToParamsResult {
    has arg_params: dict[(Expr | KWPair, Parameter | None)],
        overload: FunctionType | None = None,
        argument_errors: bool = False;
}

obj NarrowingTarget {
    has key: str,
        declared_type: TypeBase,
        symbol: Symbol | None = None,
        deps: frozenset[str] = frozenset();
}

obj NarrowingPredicate {
    has key: str,
        narrow_type: TypeBase,
        is_inverted: bool = False,
        attr_name: str | None = None,
        narrows_on_true: bool = True,
        narrows_on_false: bool = True,
        replaces_declared: bool = False;
}

enum NarrowingKind {
    ISINSTANCE = "isinstance",
    CALLABLE = "callable",
    NONE_IS = "none_is",
    NONE_IS_NOT = "none_is_not",
    TRUTHINESS = "truthiness",
    LITERAL_EQ = "literal_eq",
    LITERAL_NE = "literal_ne",
    HASATTR = "hasattr",
    TYPE_IS = "type_is",
    TYPE_GUARD = "type_guard",
    MEMBERSHIP_IN = "membership_in",
    MEMBERSHIP_NOT_IN = "membership_not_in"
}

obj ConditionInfo {
    has kind: NarrowingKind,
        key: str,
        narrow_type: (TypeBase | None) = None,
        attr_name: str | None = None;
}

glob _stub_module_memo: dict[str, tuple[float, Module]] = {};

obj TypeEvaluator {
    has program: JacProgram,
        _BUILTINS_STUB_FILE_PATH: str postinit,
        _TYPING_STUB_FILE_PATH: str postinit,
        _TYPES_STUB_FILE_PATH: str postinit,
        _JAC_BUILTINS_STUB_FILE_PATH: str postinit,
        _BUILTIN_OVERRIDES_STUB_FILE_PATH: str postinit,
        _DOM_TYPES_STUB_FILE_PATH: str postinit,
        _NA_BUILTINS_STUB_FILE_PATH: str postinit,
        _JS_GLOBALS_STUB_FILE_PATH: str postinit,
        _TYPING_AMBIENT_STUB_FILE_PATH: str postinit,
        ambient_typing_names_by_module: dict[str, set[str]] = {},
        _ENUM_STUB_FILE_PATH: str postinit,
        symbol_resolution_stack: list[Symbol] = [],
        prefetch: PrefetchedTypes postinit,
        _pass: Transform | None = None,
        builtins_module: Module | None = None,
        _flow_node_type_cache: dict[tuple[int, int], TypeBase | None] = {},
        _flow_key_type_cache: dict[tuple[int, str], TypeBase | None] = {},
        _flow_pending_symbols: set[int] postinit,
        _flow_pending_keys: set[str] postinit,
        _module_type_cache: dict[str, ModuleType] = {},
        _modules_in_compile: set[str] postinit,
        _mobui_module_cache: dict[str, bool] = {},
        _strict_site_cache: dict[int, bool] = {},
        _sv_async_syms_cache: dict[int, set[int]] = {},
        _and_narrowing_overrides: dict[int, TypeBase] = {},
        _type_guard_probes: set[int] = set(),
        _loop_written_keys_cache: dict[int, set[str]] = {},
        _ts_decl_cache: dict[str, (dict[str, TsDecl] | None)] = {},
        _ts_decl_path_cache: dict[str, (str | None)] = {},
        _ts_synth_class_cache: dict[int, (dict[str, ClassType] | None)] = {},
        _untyped_external_cfg_cache: dict[str, bool] = {},
        typing_module: Module postinit,
        types_module: Module postinit,
        enum_module: Module postinit,
        jac_builtins_module: Module postinit,
        dom_types_module: Module postinit,
        na_builtins_module: Module postinit,
        js_globals_module: Module postinit;

    def postinit -> None;
    def _read_dunder_all(path: str) -> (set[str] | None);
    def _read_ambient_imports_by_module(path: str) -> dict[str, set[str]];
    def _load_stub_module(path: str) -> Module;
    def _get_type_from_module(module: Module, name: str) -> TypeBase;
    def _prefetch_types;
    def get_none_type -> TypeBase;
    def emit_diag(diag: DiagnosticInfo, nd: UniNode, **kwargs: object) -> None;
    def _invalidate_expr_type_cache(node_: UniNode) -> None;
    def get_index_of_symbol_resolution(symbol: Symbol) -> int | None;
    def push_symbol_resolution(symbol: Symbol) -> bool;
    def pop_symbol_resolution(symbol: Symbol) -> None;
    def get_type_of_symbol(symbol: Symbol) -> TypeBase;
    def resolve_to_definition_symbol(symbol: Symbol) -> Symbol;
    def _widen_literal_for_declaration(ty: TypeBase) -> TypeBase;
    def _import_module_from_path(
        path: str, importer_path: (str | None) = None
    ) -> Module;

    def _resolve_importer_path(ast_node: UniNode) -> (str | None);
    def forget_module(resolved_path: str) -> None;
    def _resolve_from_path(from_mod: ModulePath) -> Path;
    def _resolve_client_npm_module(node_: ModulePath) -> (str | None);
    def _client_npm_base(spec: str, mod_path: str) -> (str | None);
    def _client_entry_mod_path -> (str | None);
    def _get_ts_declared_item_type(
        from_loc: ModulePath, item_name: str
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
        shells: (dict[str, ClassType] | None) = None
    ) -> TypeBase;

    def _synthesize_ts_decl_class(
        decls: dict[str, TsDecl], item_name: str
    ) -> (TypeBase | None);

    def _install_synth_member(
        scope: UniScopeNode, synth_src: Source, mname: str, member_type: TypeBase
    ) -> None;

    def _ts_synth_class_types(
        decls: dict[str, TsDecl]
    ) -> (dict[str, ClassType] | None);

    def _emit_untyped_external(name_node: Name, name: str, module: str) -> None;
    def _untyped_external_is_error(node_: UniNode) -> bool;
    def _is_fstring_all_literal(fstring: FString) -> bool;
    def _try_resolve_forward_ref(expr: String) -> TypeBase | None;
    def _type_from_union_annotation_arg(val: Expr) -> TypeBase;
    def get_type_of_module(node_: ModulePath) -> TypeBase;
    def get_type_of_module_item(node_: ModuleItem) -> TypeBase;
    def _resolve_submodule_attr(
        base_type: ModuleType, attr_name: str
    ) -> (ModuleType | None);

    def _resolve_star_import_symbol(
        mod: Module, name: str, visited: set[int] | None = None
    ) -> Symbol | None;

    def _extract_type_params(node_: Archetype) -> list[TypeVarType];
    def _is_class_scoped_type_param(node_: TypeParam) -> bool;
    def _collect_typevars_from_base(
        base_class: AtomTrailer,
        outer_names: set[str],
        seen_names: set[str],
        type_params: list[TypeVarType]
    ) -> None;

    def get_type_of_class(node_: Archetype) -> ClassType;
    def get_type_of_enum(node_: Enum) -> ClassType;
    def get_type_of_ability(node_: Ability) -> TypeBase;
    def _apply_function_decorators(
        node_: Ability, func_type: FunctionType
    ) -> FunctionType;

    def get_type_of_int(nd: Int) -> TypeBase;
    def get_type_of_float(nd: Float) -> TypeBase;
    def get_type_of_expression(
        node_: Expr, expected_type: TypeBase | None = None
    ) -> TypeBase;

    def is_any_type(ty: TypeBase) -> bool;
    def is_explicit_any(ty: TypeBase) -> bool;
    def is_none_type(ty: TypeBase) -> bool;
    def _is_strict_site(nd: UniNode) -> bool;
    def _diag_unnarrowed_optional(nd: UniNode, ty: TypeBase, required: str) -> bool;
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
        arg_nodes: (Sequence[Expr | KWPair] | None),
        node_for_error: Expr | None = None
    ) -> TypeBase | None;

    def slice_assignment_is_valid(target: Expr, value_node: Expr) -> bool;
    def is_sub_class(super_cls: ClassType, sub_cls: ClassType) -> bool;
    def _assign_callable(
        src_func: FunctionType, dest_func: FunctionType, strict: bool = False
    ) -> bool;

    def _is_ability_classmethod(node_: Ability) -> bool;
    def _is_ability_staticmethod(node_: Ability) -> bool;
    def _classify_property_symbol(symbol: Symbol) -> PropertyWriteKind;
    def get_getter_type_from_property(symbol: Symbol) -> (TypeBase | None);
    def get_property_write_type(symbol: Symbol) -> PropertyWriteResult;
    def _get_setter_value_type(symbol: Symbol, prop_name: str) -> (TypeBase | None);
    def _assign_class(
        src_type: ClassType, dest_type: ClassType, strict: bool = False
    ) -> bool;

    def _get_type_of_symbol(symbol: Symbol) -> TypeBase;
    def _get_enum_member_type_for_decl(node_: Name) -> (EnumMemberType | None);
    def get_type_of_member(member: ClassMember, class_type: ClassType) -> TypeBase;
    def declaring_class_of(symbol: Symbol, base_type: ClassType) -> (ClassType | None);
    def specialize_member_type(
        member_type: TypeBase,
        class_type: ClassType,
        declaring_class: (ClassType | None) = None
    ) -> TypeBase;

    def _get_type_of_expression_core(
        expr: Expr, expected_type: TypeBase | None = None
    ) -> TypeBase;

    def _walk_compr_clauses(comprs: list[InnerCompr]) -> None;
    def _null_ok_attr_type(expr: AtomTrailer) -> TypeBase;
    def _set_module_item_symbol_and_type(node_: ModuleItem, sym: Symbol) -> TypeBase;
    def resolve_imported_symbols(sym: Symbol) -> Symbol;
    def _set_symbol_to_expr(expr: Expr, sym: Symbol) -> TypeBase;
    def _resolution_scope_for(expr: UniNode) -> UniScopeNode | None;
    def _is_expr_self(expr: Expr) -> bool;
    def _is_expr_super(expr: Expr) -> bool;
    def _get_enclosing_function(nd: UniNode) -> Ability | None;
    def _get_enclosing_return_scope(nd: UniNode) -> Ability | LambdaExpr | None;
    def _get_declared_return_type(scope: Ability | LambdaExpr) -> TypeBase | None;
    def _infer_lambda_block_return_type(body: list[CodeBlockStmt]) -> TypeBase;
    def _collect_return_types(stmts: list[CodeBlockStmt], out: list[TypeBase]) -> bool;
    def _collect_if_else_returns(
        else_body: ElseIf | ElseStmt | None, out: list[TypeBase]
    ) -> bool;

    def _get_enclosing_method(nd: UniNode) -> Ability | None;
    def _get_enclosing_class(nd: UniNode) -> Archetype | None;
    def _get_type_of_self(node_: SpecialVarRef) -> TypeBase;
    def _get_type_of_super(node_: SpecialVarRef) -> TypeBase;
    def _get_type_of_root(node_: SpecialVarRef) -> TypeBase;
    def _get_type_of_lhs_assignment(expr: Name) -> TypeBase | None;
    def _extract_tuple_element_type(tuple_type: TypeBase, idx: int) -> TypeBase | None;
    def _tuple_has_variadic_arg(cls: ClassType) -> bool;
    def _tuple_literal_index_type(
        base_type: TypeBase, subscript_arg: Expr
    ) -> TypeBase | None;

    def _extract_tuple_element_type_path(
        tuple_type: TypeBase, path: list[int]
    ) -> TypeBase | None;

    def _get_iterable_element_type(
        iterable_type: TypeBase, node_for_error: Expr | None = None
    ) -> TypeBase | None;

    def _native_iter_next_result(expr: FuncCall) -> TypeBase | None;
    def _convert_to_instance(jtype: TypeBase) -> TypeBase;
    def _edge_endpoint_type(
        edge_type: ClassType, edge_dir: EdgeDir
    ) -> TypeBase | None;

    def _type_in_list(ty: TypeBase, type_list: list[TypeBase]) -> bool;
    def _collect_unique_types(ty: TypeBase, result: list[TypeBase]) -> None;
    def _get_expected_element_type(
        expected_type: TypeBase | None, container_class: TypeBase
    ) -> TypeBase | None;

    def _get_expected_kv_types(
        expected_type: TypeBase | None, dict_class: TypeBase
    ) -> tuple[TypeBase, TypeBase] | None;

    def _infer_list_elem_from_mutations(expr: ListVal) -> TypeBase | None;
    def _list_mutation_elem_contrib(ref: NameAtom) -> TypeBase | None;
    def _get_special_form_type(name: str, symbol_type: TypeBase) -> TypeBase | None;
    def _create_callable_type(
        type_args_expr: Expr | None, error_node: Expr
    ) -> FunctionType;

    def _lookup_class_member(base_type: ClassType, member: str) -> ClassMember | None;
    def _lookup_object_member(base_type: ClassType, member: str) -> ClassMember | None;
    def _is_type_subscript(class_type: ClassType) -> bool;
    def _get_type_for_member_lookup(object_type: ClassType) -> ClassType;
    def _get_getattr_return_type(base_type: ClassType) -> TypeBase | None;
    def _resolve_enum_value_type(enum_type: ClassType) -> TypeBase | None;
    def _synthesize_enum_metaclass_attr(
        enum_type: ClassType, attr_name: str
    ) -> TypeBase | None;

    def match_args_to_params(
        arg_nodes: (Sequence[Expr | KWPair] | None),
        node_for_error: Expr | None,
        func_type: FunctionType,
        checking_overload: bool = False,
        is_unbound_call: bool = False
    ) -> MatchArgsToParamsResult;

    def _is_unbound_method_call(expr: FuncCall) -> bool;
    def validate_call_args(expr: FuncCall) -> TypeBase;
    def _unannotated_lambda_arg_name(expr: FuncCall) -> str | None;
    def _make_coroutine_type(inner: TypeBase) -> TypeBase;
    def _is_awaitable_type(t: TypeBase) -> bool;
    def _unwrap_awaitable_type(t: TypeBase, node_: UniNode) -> TypeBase;
    def _is_sv_async_call(expr: FuncCall) -> bool;
    def validate_arg_types(
        args: MatchArgsToParamsResult,
        checking_overload: bool = False,
        solved_type_vars: (dict[str, TypeBase] | None) = None
    ) -> bool;

    def _build_field_params(
        class_type: ClassType, skip_deferred: bool = True
    ) -> dict[str, Parameter];

    def _literal_type_from_expr(val: Expr) -> TypeBase | None;
    def _build_typeddict_fields(class_type: ClassType) -> dict[str, TypeBase];
    def _has_typeddict_special_form_base(node_: Archetype) -> bool;
    def _typeddict_value_union(base_type: ClassType) -> TypeBase;
    def _get_typeddict_indexed_type(
        base_type: ClassType, key_expr: Expr, err_node: UniNode
    ) -> TypeBase | None;

    def _typeddict_as_dict(base_type: ClassType) -> ClassType | None;
    def _synthesize_typeddict_method(
        base_type: ClassType, method: str
    ) -> OverloadedType | None;

    def _create_dataclass_init_method(class_type: ClassType) -> FunctionType;
    def _create_namedtuple_new_method(class_type: ClassType) -> FunctionType;
    def _create_special_builtin_type(name: str, base_class: ClassType) -> ClassType;
    def _validate_constructor_method(
        expr: FuncCall, method_type: TypeBase
    ) -> FunctionType | None;

    def _strip_implicit_self_cls(method: FunctionType) -> FunctionType;
    def _get_method_with_overloads(
        method_member: ClassMember, caller_type: ClassType
    ) -> TypeBase;

    def assign_type_to_type_var(
        param_type: TypeBase, arg_type: TypeBase, bindings: dict[str, TypeBase]
    ) -> bool;

    def _infer_type_args_from_method(
        caller_type: ClassType, expr: FuncCall, matched_method: FunctionType | None
    ) -> list[TypeBase];

    def _find_matching_raw_constructor(
        caller_type: ClassType, expr: FuncCall, matched_method: FunctionType | None
    ) -> FunctionType | None;

    def _find_overload_by_arg_count(
        method_type: TypeBase, arg_count: int, overload_symbols: list[Symbol]
    ) -> FunctionType | None;

    def _substitute_type_vars(
        typ: TypeBase, bindings: dict[str, TypeBase]
    ) -> TypeBase;

    def _collect_type_var_bindings(
        method: FunctionType,
        expr: FuncCall,
        is_unbound_call: bool = False,
        is_constructor_call: bool = False
    ) -> dict[str, TypeBase];

    def _validate_jsx_props(
        expr: JsxElement, expected_type: TypeBase | None = None
    ) -> None;

    def _resolve_jsx_component_type(name: JsxElementName) -> FunctionType | None;
    def _is_mobui_module(nd: UniNode) -> bool;
    def _get_intrinsic_props_type(tag_name: str) -> ClassType | None;
    def _validate_component_jsx_props(
        expr: JsxElement, component_name: str, func_type: FunctionType | None = None
    ) -> None;

    def _validate_intrinsic_jsx_props(expr: JsxElement, tag_name: str) -> None;
    def _resolve_intrinsic_jsx_tag(part: Name, tag_name: str) -> None;
    def validate_typevar_in_type_expr(expr: Expr) -> None;
    def validate_typevar_scope(expr: Expr, type_var: TypeVarType) -> None;
    def validate_typevar_variance(func: Ability) -> None;
    def _type_var_bound_in_scope(node_: UniNode, name: str) -> bool;
    def _get_signature_type_params(sig: FuncSignature) -> list[TypeVarType];
    def _get_function_type_params(func: Ability) -> list[TypeVarType];
    def _get_outer_scope_type_params(node_: UniNode) -> list[TypeVarType];
    def create_key_for_reference(expr: Expr) -> str | None;
    def _find_symbol_by_key(key: str, condition: Expr) -> Symbol | None;
    def classify_condition(condition: Expr) -> ConditionInfo | None;
    def get_narrowed_type(symbol: Symbol, at_node: UniNode) -> TypeBase | None;
    def get_narrowed_type_for_expr(
        expr: Expr, declared_type: TypeBase, at_node: UniNode
    ) -> TypeBase | None;

    def _get_type_from_flow_node(
        target: NarrowingTarget, flow_node: UniCFGNode, visited: set
    ) -> TypeBase | None;

    def _node_encloses(outer: UniNode, inner: UniNode) -> bool;
    def _loop_body_writes_target(
        loop_node: UniCFGNode, target: NarrowingTarget
    ) -> bool;

    def _classify_edge(pred: IfStmt, succ: UniCFGNode) -> str;
    def _find_predicate_for(
        target: NarrowingTarget, condition: Expr
    ) -> NarrowingPredicate | None;

    def _narrowing_equivalent(
        left: NarrowingPredicate, right: NarrowingPredicate
    ) -> bool;

    def _apply_narrowing(
        predicate: NarrowingPredicate,
        incoming: TypeBase | None,
        is_true_branch: bool,
        target: NarrowingTarget
    ) -> TypeBase | None;

    def _narrow_type_to(base_type: TypeBase, narrow_type: TypeBase) -> TypeBase | None;
    def _narrow_member_to(member: TypeBase, narrow_type: TypeBase) -> TypeBase | None;
    def _specialize_narrow_from_base(
        base_type: TypeBase, narrow_type: TypeBase
    ) -> TypeBase;

    def _type_matches_isinstance(t: TypeBase, target_type: TypeBase) -> bool;
    def _union_narrowed_types(types_list: list) -> TypeBase;
    def _if_exit_type(
        target: NarrowingTarget,
        stmt: IfStmt,
        entry_type: (TypeBase | None),
        visited: set
    ) -> (TypeBase | None);

    def exclude_type_from_union(original: TypeBase, to_exclude: TypeBase) -> TypeBase;
    def _get_type_from_match_pattern(pattern: MatchPattern) -> TypeBase | None;
    def _union_contains_none(union_type: TypeBase) -> bool;
    def _extract_isinstance_info(condition: Expr) -> tuple[str, TypeBase] | None;
    def _isinstance_tuple_alternatives(arg_type: TypeBase) -> list[TypeBase] | None;
    def _extract_type_guard_info(condition: Expr) -> tuple[str, TypeBase, bool] | None;
    def _create_type_guard_type(name: str, guarded: TypeBase | None) -> TypeBase;
    def _type_guard_form_of(ty: TypeBase) -> str | None;
    def _unwrap_type_guard_return(ty: TypeBase) -> TypeBase;
    def _extract_callable_info(condition: Expr) -> str | None;
    def _extract_hasattr_info(condition: Expr) -> tuple[str, str] | None;
    def _type_has_attribute(t: TypeBase, attr_name: str) -> bool;
    def _filter_union_for_hasattr(
        base_type: TypeBase, attr_name: str, keep_with_attr: bool
    ) -> TypeBase | None;

    def _is_callable_type(t: TypeBase) -> bool;
    def _filter_union_to_callables(union_type: TypeBase) -> TypeBase;
    def _is_ellipsis_only_body(body: list[CodeBlockStmt]) -> bool;
    def _is_type_alias_annotation(annotation_type: TypeBase, tag_expr: Expr) -> bool;
    def _resolve_type_alias_rhs(value: Expr) -> TypeBase;
    def _brand_distinct_alias(node_: TypeAlias, resolved: TypeBase) -> TypeBase;
    def _distinct_brand_mismatch(src_type: TypeBase, dest_type: TypeBase) -> bool;
    def _resolve_string_type_expr(
        type_str: str, scope: UniScopeNode
    ) -> TypeBase | None;

    def _resolve_py_ast_type_node(
        ast_node: object, scope: UniScopeNode
    ) -> TypeBase | None;
}
