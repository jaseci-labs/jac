import textwrap;
import from collections.abc { Sequence }
import from jaclang.jac0core.unitree {
    Ability,
    ArchHas,
    Archetype,
    AssertStmt,
    AssignCompr,
    Assignment,
    AstSymbolNode,
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
    CommentToken,
    CompareExpr,
    ConcurrentExpr,
    ConnectOp,
    ContextAwareNode,
    CtrlStmt,
    DeleteStmt,
    DictCompr,
    DictVal,
    DisconnectOp,
    DisengageStmt,
    EdgeOpRef,
    EdgeRefTrailer,
    Ellipsis,
    ElseIf,
    ElseStmt,
    Enum,
    EnumBlockStmt,
    EventSignature,
    Except,
    Expr,
    ExprAsItem,
    ExprCtx,
    ExprStmt,
    FString,
    FilterCompr,
    FinallyStmt,
    Float,
    ForeverStmt,
    FormattedValue,
    FuncCall,
    FuncSignature,
    GenCompr,
    GlobalVars,
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
    JsxComment,
    JsxElement,
    JsxElementName,
    JsxExpression,
    JsxNormalAttribute,
    JsxSlot,
    JsxSpreadAttribute,
    JsxText,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    MatchArch,
    MatchAs,
    MatchCase,
    MatchKVPair,
    MatchMapping,
    MatchOr,
    MatchPattern,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchStmt,
    MatchValue,
    MatchWild,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    Null,
    OpenStmt,
    ParamVar,
    PyInlineCode,
    RaiseStmt,
    ReportStmt,
    ReturnStmt,
    SemDef,
    Semi,
    SetCompr,
    SetVal,
    SpecialVarRef,
    String,
    SubTag,
    SwitchStmt,
    Test,
    Token,
    TryStmt,
    TupleVal,
    TypeAlias,
    TypeParam,
    TypedCtxBlock,
    UnaryExpr,
    UniNode,
    UniScopeNode,
    VisitStmt,
    WhileStmt,
    WithStmt,
    YieldExpr,
    is_identifier_slot
}
import from jaclang.jac0core.constant {
    CodeContext,
    EdgeDir,
    is_borrow_kind,
    OwnershipKind
}
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.constant { Tokens as Tok }

import from jaclang.jac0core.codegen_ir { CodegenIrWriter }
import from jaclang.jac0core.codeinfo { BoundaryTypeInfo, InteropBinding }
import from jaclang.jac0core.jcir_facts {
    JCIR_AMBIENT_TYPING_NAMES,
    JCIR_BUILTIN_NAMES,
    jcir_is_test_path
}
import from jaclang.jac0core.passes.ast_gen.base_ast_gen_pass { BaseAstGenPass }
import from jaclang.jac0core.diagnostics {
    E5001,
    E5002,
    E5003,
    E5004,
    E5005,
    E5006,
    E5007,
    E5008,
    E5094,
    E5098
}

glob TOKEN_CLS_BY_NAME: dict[(str, str)] = {
         'KW_AND': 'And',
         'KW_OR': 'Or',
         'PLUS': 'Add',
         'ADD_EQ': 'Add',
         'BW_AND': 'BitAnd',
         'BW_AND_EQ': 'BitAnd',
         'BW_OR': 'BitOr',
         'BW_OR_EQ': 'BitOr',
         'BW_XOR': 'BitXor',
         'BW_XOR_EQ': 'BitXor',
         'DIV': 'Div',
         'DIV_EQ': 'Div',
         'FLOOR_DIV': 'FloorDiv',
         'FLOOR_DIV_EQ': 'FloorDiv',
         'LSHIFT': 'LShift',
         'LSHIFT_EQ': 'LShift',
         'MOD': 'Mod',
         'MOD_EQ': 'Mod',
         'STAR_MUL': 'Mult',
         'MUL_EQ': 'Mult',
         'DECOR_OP': 'MatMult',
         'MATMUL_EQ': 'MatMult',
         'STAR_POW': 'Pow',
         'STAR_POW_EQ': 'Pow',
         'RSHIFT': 'RShift',
         'RSHIFT_EQ': 'RShift',
         'MINUS': 'Sub',
         'SUB_EQ': 'Sub',
         'BW_NOT': 'Invert',
         'NOT': 'Not',
         'EQ': 'NotEq',
         'EE': 'Eq',
         'GT': 'Gt',
         'GTE': 'GtE',
         'KW_IN': 'In',
         'KW_IS': 'Is',
         'KW_ISN': 'IsNot',
         'LT': 'Lt',
         'LTE': 'LtE',
         'NE': 'NotEq',
         'KW_NIN': 'NotIn'
     },
     UNARY_CLS_BY_NAME: dict[(str, str)] = {
         'NOT': 'Not',
         'BW_NOT': 'Invert',
         'PLUS': 'UAdd',
         'MINUS': 'USub'
     };

glob EDGE_DIR_NAMES: dict[(int, str)] = {
         int(EdgeDir.IN): 'IN',
         int(EdgeDir.OUT): 'OUT',
         int(EdgeDir.ANY): 'ANY'
     };

obj CgItem {}

obj CgNode(CgItem) {
    has cls: str,
        keys: list[str],
        vals: list,
        l1: int = 0,
        c1: int = 0,
        l2: int = 0,
        c2: int = 0,
        jac_src: (UniNode | None) = None;

    def get(key: str) -> any {
        i = 0;
        while i < len(self.keys) {
            if self.keys[i] == key {
                return self.vals[i];
            }
            i += 1;
        }
        raise KeyError(f"CgNode {self.cls} has no field {key}");
    }

    def setf(key: str, value: any) -> None {
        i = 0;
        while i < len(self.keys) {
            if self.keys[i] == key {
                self.vals[i] = value;
                return;
            }
            i += 1;
        }
        self.keys.append(key);
        self.vals.append(value);
    }

    def hasf(key: str) -> bool {
        return key in self.keys;
    }
}

obj CgSplice(CgItem) {
    has src: str,
        offset: int = 0,
        bound_names: list[str] = [];
}

obj CgEllipsis(CgItem) {}

def write_ir_value(w: CodegenIrWriter, v: object) {
    if v is None {
        w.emit_none();
    } elif isinstance(v, CgEllipsis) {
        w.emit_ellipsis();
    } elif isinstance(v, CgNode) {
        for item in v.vals {
            write_ir_value(w, item);
        }
        w.emit_loc_needed(v.l1, v.c1, v.l2, v.c2);
        w.emit_node(v.cls, v.keys);
    } elif isinstance(v, CgSplice) {
        w.emit_parse_splice(v.src, v.offset);
    } elif isinstance(v, bool) {
        if v {
            w.emit_true();
        } else {
            w.emit_false();
        }
    } elif isinstance(v, int) {
        w.emit_int(v);
    } elif isinstance(v, float) {
        w.emit_float(v);
    } elif isinstance(v, str) {
        w.emit_str(v);
    } elif isinstance(v, bytes) {
        w.emit_bytes(v);
    } elif isinstance(v, list) {
        for item in v {
            write_ir_value(w, item);
        }
        w.emit_list(len(v));
    } else {
        raise ValueError(
            "JCIR emitter produced a value outside the v1 constant domain. "
            "The whole domain is None, a CgEllipsis marker, a CgNode, a "
            "CgSplice, bool, int, float, str, bytes, and a list of those; a "
            "value of any other type reached a recipe slot, most often "
            "because a producer put a live Python object where an encodable "
            "one belongs."
        );
    }
}

def module_container_bytes(mod_path: str, root_node: CgNode) -> bytes {
    w = CodegenIrWriter();
    w.begin_module(mod_path);
    write_ir_value(w, root_node);
    w.end_module();
    return w.to_bytes();
}

obj JcirGenPass(BaseAstGenPass[CgItem]) {
    has already_added: list[str] = [],
        jaclib_imports: set[str] postinit,
        builtin_imports: set[str] postinit,
        typing_imports: set[str] postinit,
        _lambda_counter: int = 0,
        _hoist_frames: list[list[CgNode]] postinit,
        preamble: list[CgItem] postinit,
        _sink: dict[UniNode, list[CgItem]] postinit,
        _module_root: (CgNode | None) = None,
        _module_path: str = "",
        _interop_stub_node: (UniNode | None) = None;

    with entry { }

    def _get_builtin_names -> set[str];
    def _get_ambient_typing_names -> set[str];
    def postinit -> None;
    def enter_node(nd: UniNode) -> None;
    def exit_node(nd: UniNode) -> None;
    def _is_native_ext_module -> bool;
    def _refuse(nd: (UniNode | None), construct: str) -> None;
    def nod(
        cls_name: str, keys: list[str], vals: list, jac_node: (UniNode | None) = None
    ) -> CgNode;

    def nod_loc(
        cls_name: str, keys: list[str], vals: list, l1: int, c1: int, l2: int, c2: int
    ) -> CgNode;

    def _flatten_ast_list(items: list[CgItem | list[CgItem] | None]) -> list[CgItem];
    def outs(nd: UniNode) -> list[CgItem];
    def set_out(nd: UniNode, items: list[CgItem]) -> None;
    def val(nd: UniNode) -> CgNode;
    def const_of(value: any, jac_node: (UniNode | None) = None) -> CgNode;
    def name_load(name_id: str, jac_node: (UniNode | None) = None) -> CgNode;
    def _with_ctx(cgn: CgNode, ctx_cls: str) -> CgNode;
    def jaclib_obj(obj_name: str) -> CgNode;
    def builtin_name(name: str) -> CgNode;
    def _add_preamble_once(key: str, cgn: CgNode) -> None;
    def needs_enum_kind(kind: str) -> None;
    def _py_name(nd: AstSymbolNode) -> str;
    def py_ctx(nd: AstSymbolNode) -> CgNode;
    def _next_lambda_name -> str;
    def _push_hoist_frame -> None;
    def _hoist_lambda(func_def: CgNode) -> None;
    def _ancestor_is_one_of(nd: (UniNode | None), roots: list[UniNode]) -> bool;
    def _split_scope_hoists(
        hoists: list[CgNode], sig_roots: list[UniNode]
    ) -> tuple[(list[CgNode], list[CgNode])];

    def _drain_module_hoists -> list[CgNode];
    def _docstring_offset(body: list[CgItem]) -> int;
    def _report_leaked_hoisted_lambdas -> None;
    def _function_expr_from_def(func_def: CgNode, jac_node: UniNode) -> CgNode;
    def _get_sem_decorator(nd: UniNode) -> (CgNode | None);
    def _gen_native_interop_stubs(nd: UniNode) -> None;
    def _native_import_registration_map -> dict;
    def _top_level_bound_names(items: any) -> list;
    def _native_test_shim_stmts(nd: Test) -> list;
    def _generate_sv_to_sv_stubs(nd: Import) -> bool;
    def _gen_py_sv_func_stub(
        local_name: str,
        func_name: str,
        module_name: str,
        binding: InteropBinding,
        boundary_types: dict[(str, BoundaryTypeInfo)]
    ) -> str;

    def _gen_py_sv_walker_stub(
        local_name: str,
        walker_name: str,
        module_name: str,
        binding: InteropBinding,
        boundary_types: dict[(str, BoundaryTypeInfo)]
    ) -> str;

    def _gen_py_boundary_stub_class(class_name: str, info: BoundaryTypeInfo) -> str;
    def _invoke_llm_call(
        model: CgNode, caller: CgNode, args: CgNode, is_async: bool = False
    ) -> CgNode;

    def gen_llm_body(nd: Ability) -> list;
    def _is_edge_ref_target(target: UniNode) -> bool;
    def _cmp_op_str(op: CgNode) -> (str | None);
    def _query_filter_kws(fc: FilterCompr, type_arg: str, preds_arg: str) -> list;
    def _recipe_contains_root(v: any) -> bool;
    def resolve_switch_pattern(pattern: MatchPattern, target: Expr) -> CgNode;
    def resolve_switch_stmt(nd: SwitchStmt) -> list[CgItem];
    def resolve_stmt_block(
        nd:
            (
                Sequence[UniNode]
                | Sequence[CodeBlockStmt]
                | Sequence[EnumBlockStmt]
                | None
            ),
        doc: (String | None) = None
    ) -> list[CgItem];

    def scope_directive_stmts(scopes: list[UniScopeNode | None]) -> list[CgNode];
    def _resolve_self_type(nd: Name) -> (CgNode | None);
    def _is_in_type_annotation(nd: UniNode) -> bool;
    def _is_descendant_of(nd: UniNode, ancestor: UniNode) -> bool;
    def gen_call_args(nd: FuncCall) -> tuple[(list, list)];
    def _delete_targets(nd: DeleteStmt) -> list[CgNode];
    def _delete_ctx_targets(targets: list[CgNode], ctx_cls: str) -> list[CgNode];
    def ir_bytes -> bytes;
    def exit_sub_tag(nd: SubTag) -> None;
    def exit_module(nd: Module) -> None;
    def exit_type_param(nd: TypeParam) -> None;
    def exit_type_alias(nd: TypeAlias) -> None;
    def exit_global_vars(nd: GlobalVars) -> None;
    def enter_test(nd: Test) -> None;
    def exit_test(nd: Test) -> None;
    def exit_module_code(nd: ModuleCode) -> None;
    def exit_py_inline_code(nd: PyInlineCode) -> None;
    def exit_import(nd: Import) -> None;
    def exit_module_path(nd: ModulePath) -> None;
    def exit_module_item(nd: ModuleItem) -> None;
    def enter_archetype(nd: Archetype) -> None;
    def exit_archetype(nd: Archetype) -> None;
    def enter_enum(nd: Enum) -> None;
    def exit_enum(nd: Enum) -> None;
    def enter_ability(nd: Ability) -> None;
    def exit_ability(nd: Ability) -> None;
    def exit_impl_def(nd: ImplDef) -> None;
    def exit_sem_def(nd: SemDef) -> None;
    def exit_func_signature(nd: FuncSignature) -> None;
    def exit_event_signature(nd: EventSignature) -> None;
    def exit_param_var(nd: ParamVar) -> None;
    def exit_arch_has(nd: ArchHas) -> None;
    def exit_has_var(nd: HasVar) -> None;
    def exit_typed_ctx_block(nd: TypedCtxBlock) -> None;
    def exit_open_stmt(nd: OpenStmt) -> None;
    def exit_if_stmt(nd: IfStmt) -> None;
    def exit_else_if(nd: ElseIf) -> None;
    def exit_else_stmt(nd: ElseStmt) -> None;
    def exit_expr_stmt(nd: ExprStmt) -> None;
    def exit_concurrent_expr(nd: ConcurrentExpr) -> None;
    def exit_try_stmt(nd: TryStmt) -> None;
    def exit_except(nd: Except) -> None;
    def exit_finally_stmt(nd: FinallyStmt) -> None;
    def exit_iter_for_stmt(nd: IterForStmt) -> None;
    def exit_in_for_stmt(nd: InForStmt) -> None;
    def exit_while_stmt(nd: WhileStmt) -> None;
    def exit_forever_stmt(nd: ForeverStmt) -> None;
    def exit_with_stmt(nd: WithStmt) -> None;
    def exit_expr_as_item(nd: ExprAsItem) -> None;
    def exit_raise_stmt(nd: RaiseStmt) -> None;
    def exit_assert_stmt(nd: AssertStmt) -> None;
    def exit_ctrl_stmt(nd: CtrlStmt) -> None;
    def exit_delete_stmt(nd: DeleteStmt) -> None;
    def exit_report_stmt(nd: ReportStmt) -> None;
    def exit_return_stmt(nd: ReturnStmt) -> None;
    def exit_yield_expr(nd: YieldExpr) -> None;
    def exit_visit_stmt(nd: VisitStmt) -> None;
    def exit_disengage_stmt(nd: DisengageStmt) -> None;
    def exit_await_expr(nd: AwaitExpr) -> None;
    def exit_cast_expr(nd: CastExpr) -> None;
    def exit_assignment(nd: Assignment) -> None;
    def exit_binary_expr(nd: BinaryExpr) -> None;
    def translate_jac_bin_op(nd: BinaryExpr) -> list;
    def exit_compare_expr(nd: CompareExpr) -> None;
    def exit_cfg_expr(nd: CfgExpr) -> None;
    def exit_bool_expr(nd: BoolExpr) -> None;
    def exit_lambda_expr(nd: LambdaExpr) -> None;
    def _emit_lambda_expr_body(nd: LambdaExpr, body_node: Expr) -> None;
    def _remove_lambda_param_annotations(signature: FuncSignature) -> None;
    def exit_unary_expr(nd: UnaryExpr) -> None;
    def _emit_jobj_ref(nd: UnaryExpr) -> None;
    def exit_if_else_expr(nd: IfElseExpr) -> None;
    def _multi_string_pieces(str_seq: Sequence[UniNode]) -> list;
    def exit_multi_string(nd: MultiString) -> None;
    def exit_f_string(nd: FString) -> None;
    def exit_formatted_value(nd: FormattedValue) -> None;
    def exit_list_val(nd: ListVal) -> None;
    def exit_set_val(nd: SetVal) -> None;
    def exit_tuple_val(nd: TupleVal) -> None;
    def exit_dict_val(nd: DictVal) -> None;
    def exit_k_v_pair(nd: KVPair) -> None;
    def exit_k_w_pair(nd: KWPair) -> None;
    def exit_inner_compr(nd: InnerCompr) -> None;
    def exit_list_compr(nd: ListCompr) -> None;
    def exit_gen_compr(nd: GenCompr) -> None;
    def exit_set_compr(nd: SetCompr) -> None;
    def exit_dict_compr(nd: DictCompr) -> None;
    def exit_atom_trailer(nd: AtomTrailer) -> None;
    def exit_atom_unit(nd: AtomUnit) -> None;
    def exit_func_call(nd: FuncCall) -> None;
    def exit_index_slice(nd: IndexSlice) -> None;
    def exit_special_var_ref(nd: SpecialVarRef) -> None;
    def exit_edge_ref_trailer(nd: EdgeRefTrailer) -> None;
    def exit_edge_op_ref(nd: EdgeOpRef) -> None;
    def exit_disconnect_op(nd: DisconnectOp) -> None;
    def exit_connect_op(nd: ConnectOp) -> None;
    def exit_filter_compr(nd: FilterCompr) -> None;
    def exit_assign_compr(nd: AssignCompr) -> None;
    def exit_match_stmt(nd: MatchStmt) -> None;
    def exit_match_case(nd: MatchCase) -> None;
    def exit_match_or(nd: MatchOr) -> None;
    def exit_match_as(nd: MatchAs) -> None;
    def exit_match_wild(nd: MatchWild) -> None;
    def exit_match_value(nd: MatchValue) -> None;
    def exit_match_singleton(nd: MatchSingleton) -> None;
    def exit_match_sequence(nd: MatchSequence) -> None;
    def exit_match_mapping(nd: MatchMapping) -> None;
    def exit_match_k_v_pair(nd: MatchKVPair) -> None;
    def exit_match_star(nd: MatchStar) -> None;
    def exit_match_arch(nd: MatchArch) -> None;
    def exit_token(nd: Token) -> None;
    def exit_name(nd: Name) -> None;
    def exit_float(nd: Float) -> None;
    def exit_int(nd: Int) -> None;
    def exit_string(nd: String) -> None;
    def exit_bool(nd: Bool) -> None;
    def exit_builtin_type(nd: BuiltinType) -> None;
    def exit_null(nd: Null) -> None;
    def exit_ellipsis(nd: Ellipsis) -> None;
    def exit_jsx_element(nd: JsxElement) -> None;
    def exit_jsx_element_name(nd: JsxElementName) -> None;
    def exit_jsx_spread_attribute(nd: JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(nd: JsxNormalAttribute) -> None;
    def exit_jsx_text(nd: JsxText) -> None;
    def exit_jsx_expression(nd: JsxExpression) -> None;
    def exit_jsx_slot(nd: JsxSlot) -> None;
    def exit_jsx_comment(nd: JsxComment) -> None;
    def exit_semi(nd: Semi) -> None;
    def exit_comment_token(nd: CommentToken) -> None;
}
