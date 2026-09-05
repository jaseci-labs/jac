import from jaclang.runtime.osp_kernel { osp_skip_rest }
import textwrap;
import from collections.abc { Sequence }
import from jaclang.compiler.frontend.unitree {
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
import from jaclang.compiler.frontend.constant {
    CodeContext,
    EdgeDir,
    is_borrow_kind,
    OwnershipKind
}
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.runtime.scalars { shape_of }

import from jaclang.compiler.backends.py.codegen_ir { CodegenIrWriter }
import from jaclang.compiler.frontend.codeinfo { BoundaryTypeInfo, InteropBinding }
import from jaclang.compiler.backends.py.jcir_facts {
    JCIR_AMBIENT_TYPING_NAMES,
    JCIR_BUILTIN_NAMES,
    jcir_is_test_path
}
import from jaclang.compiler.passes.ast_gen.base_ast_gen_pass { BaseAstGenPass }
import from jaclang.compiler.frontend.diagnostics {
    E5001,
    E5002,
    E5003,
    E5004,
    E5005,
    E5006,
    E5007,
    E5008,
    E5094,
    W5096,
    E5098,
    E5102
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

glob FW_ELIDABLE_OPS: frozenset = frozenset({Tok.PLUS, Tok.MINUS, Tok.STAR_MUL}),
     FW_AUG_TO_BIN: dict[str, str] = {
         "ADD_EQ": "PLUS",
         "SUB_EQ": "MINUS",
         "MUL_EQ": "STAR_MUL",
         "FLOOR_DIV_EQ": "FLOOR_DIV",
         "STAR_POW_EQ": "STAR_POW",
         "LSHIFT_EQ": "LSHIFT",
         "RSHIFT_EQ": "RSHIFT"
     },
     FW_WRAPPING_OPS: dict[str, str] = {
         "wrapping_add": "+",
         "wrapping_sub": "-",
         "wrapping_mul": "*",
         "wrapping_shl": "<<",
         "wrapping_neg": "neg"
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

walker JcirGenPass(BaseAstGenPass[CgItem]) {
    has already_added: list[str] = [],
        _ct_only_names: (set[str] | None) = None,
        jaclib_imports: set[str] postinit,
        builtin_imports: set[str] postinit,
        sized_imports: set[str] postinit,
        typing_imports: set[str] postinit,
        _lambda_counter: int = 0,
        _hoist_frames: list[list[CgNode]] postinit,
        preamble: list[CgItem] postinit,
        _sink: dict[UniNode, list[CgItem]] postinit,
        _module_root: (CgNode | None) = None,
        _module_path: str = "",
        _interop_stub_node: (UniNode | None) = None;

    with entry {}

    def _get_builtin_names -> set[str];
    def _get_ambient_typing_names -> set[str];
    def postinit -> None;
    can enter_walk with UniNode entry;
    can exit_walk with UniNode exit;
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
    def _apply_coercion(nd: Expr) -> None;
    def _apply_fw(nd: Expr) -> None;
    def _fw_helper(name: str) -> CgNode;
    def _fw_call_node(helper: str, args: list, jac_node: UniNode) -> CgNode;
    def _fw_wrap_call(nd: Expr, helper: str, args: list) -> None;
    def _fw_binary(nd: BinaryExpr, name: str) -> None;
    def _fw_unary(nd: UnaryExpr, name: str) -> None;
    def _fw_call(nd: FuncCall) -> None;
    def _fw_checked(
        name: str, op: str, left: CgNode, right: CgNode, op_node: any, jac_node: UniNode
    ) -> (CgNode | None);

    def _fw_as_load(item: any) -> any;
    def _fw_aug_assign(nd: Assignment, target: any, value: any) -> (CgNode | None);
    def val(nd: UniNode) -> CgNode;
    def const_of(value: any, jac_node: (UniNode | None) = None) -> CgNode;
    def _ct_kind(v: any) -> str;
    def _ct_order_key(v: any) -> str;
    def _ct_materializable(v: any) -> bool;
    def _ct_concrete(nd: Expr) -> bool;
    def _is_comptime_only_name(nd: Name) -> bool;
    def _comptime_only_names -> set[str];
    def _record_bypasses_init(v: any) -> bool;
    def _is_ct_type_param(nd: Name) -> bool;
    def _ct_param_decls(cls_expr: Expr) -> (list[TypeParam] | None);
    def _ct_ctor_slots(nd: AtomTrailer) -> (list[tuple] | None);
    def _trailer_reaches_ct_class(nd: AtomTrailer) -> bool;
    def _ct_param_fields(nd: Archetype) -> list[CgNode];
    def _import_ref(module: str, name: str, jac_node: UniNode) -> CgNode;
    def _class_ref(module: str, name: str, jac_node: UniNode) -> CgNode;
    def _materialize(v: any, jac_node: UniNode) -> (CgNode | None);
    def _comptime_if_out(nd: IfStmt) -> bool;
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
    def _sv_consumer_app_expr -> str;
    def _sv_endpoint_effects(binding: InteropBinding, key: str) -> list[str];
    def _sv_bridge_walker_call(expr: Expr) -> (FuncCall | None);
    def _gen_py_sv_func_stub(
        local_name: str,
        func_name: str,
        provider_app: str,
        binding: InteropBinding,
        boundary_types: dict[(str, BoundaryTypeInfo)]
    ) -> str;

    def _gen_py_sv_walker_stub(
        local_name: str,
        walker_name: str,
        provider_app: str,
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
    def _order_name_of(x: Expr) -> (tuple[str, bool] | None);
    def _query_filter_kws_ord(
        fc: FilterCompr,
        type_arg: str,
        preds_arg: str,
        on_edge: bool,
        order_out: list[CgNode]
    ) -> tuple[list[CgNode], bool];

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
    def _del_ctx_target(target: Expr, ctx_cls: str) -> CgNode;
    def _destroy_call(value: CgNode, strict: bool) -> CgNode;
    def _del_is_trivial(cgn: CgNode) -> bool;
    def _del_slice_value(value: CgNode, nd: DeleteStmt) -> CgNode;
    def _del_bind_temp(
        value: CgNode, name: str, stmts: list[CgItem], nd: DeleteStmt
    ) -> CgNode;

    def _del_location(target: Expr, nd: DeleteStmt, ordinal: int) -> list[CgItem];
    def ir_bytes -> bytes;
    can exit_sub_tag with SubTag exit;
    can exit_module with Module exit;
    can exit_type_param with TypeParam exit;
    can exit_type_alias with TypeAlias exit;
    can exit_global_vars with GlobalVars exit;
    can enter_test with Test entry;
    can exit_test with Test exit;
    can exit_module_code with ModuleCode exit;
    can exit_py_inline_code with PyInlineCode exit;
    can exit_import with Import exit;
    can exit_module_path with ModulePath exit;
    can exit_module_item with ModuleItem exit;
    can enter_archetype with Archetype entry;
    can exit_archetype with Archetype exit;
    can enter_enum with Enum entry;
    can exit_enum with Enum exit;
    can enter_ability with Ability entry;
    can exit_ability with Ability exit;
    can exit_impl_def with ImplDef exit;
    can exit_sem_def with SemDef exit;
    can exit_func_signature with FuncSignature exit;
    can exit_event_signature with EventSignature exit;
    can exit_param_var with ParamVar exit;
    can exit_arch_has with ArchHas exit;
    can exit_has_var with HasVar exit;
    can exit_typed_ctx_block with TypedCtxBlock exit;
    can exit_open_stmt with OpenStmt exit;
    can exit_if_stmt with IfStmt exit;
    can exit_else_if with ElseIf exit;
    can exit_else_stmt with ElseStmt exit;
    can exit_expr_stmt with ExprStmt exit;
    can exit_concurrent_expr with ConcurrentExpr exit;
    can exit_try_stmt with TryStmt exit;
    can exit_except with Except exit;
    can exit_finally_stmt with FinallyStmt exit;
    can exit_iter_for_stmt with IterForStmt exit;
    can exit_in_for_stmt with InForStmt exit;
    can exit_while_stmt with WhileStmt exit;
    can exit_forever_stmt with ForeverStmt exit;
    can exit_with_stmt with WithStmt exit;
    can exit_expr_as_item with ExprAsItem exit;
    can exit_raise_stmt with RaiseStmt exit;
    can exit_assert_stmt with AssertStmt exit;
    can exit_ctrl_stmt with CtrlStmt exit;
    can exit_delete_stmt with DeleteStmt exit;
    can exit_report_stmt with ReportStmt exit;
    can exit_return_stmt with ReturnStmt exit;
    can exit_yield_expr with YieldExpr exit;
    can exit_visit_stmt with VisitStmt exit;
    can exit_disengage_stmt with DisengageStmt exit;
    can exit_await_expr with AwaitExpr exit;
    can exit_cast_expr with CastExpr exit;
    can exit_assignment with Assignment exit;
    can exit_binary_expr with BinaryExpr exit;
    def translate_jac_bin_op(nd: BinaryExpr) -> list;
    can exit_compare_expr with CompareExpr exit;
    can exit_cfg_expr with CfgExpr exit;
    can exit_bool_expr with BoolExpr exit;
    can exit_lambda_expr with LambdaExpr exit;
    def _emit_lambda_expr_body(nd: LambdaExpr, body_node: Expr) -> None;
    def _remove_lambda_param_annotations(signature: FuncSignature) -> None;
    can exit_unary_expr with UnaryExpr exit;
    def _emit_jobj_ref(nd: UnaryExpr) -> None;
    can exit_if_else_expr with IfElseExpr exit;
    def _multi_string_pieces(str_seq: Sequence[UniNode]) -> list;
    can exit_multi_string with MultiString exit;
    can exit_f_string with FString exit;
    can exit_formatted_value with FormattedValue exit;
    can exit_list_val with ListVal exit;
    can exit_set_val with SetVal exit;
    can exit_tuple_val with TupleVal exit;
    can exit_dict_val with DictVal exit;
    can exit_k_v_pair with KVPair exit;
    can exit_k_w_pair with KWPair exit;
    can exit_inner_compr with InnerCompr exit;
    can exit_list_compr with ListCompr exit;
    can exit_gen_compr with GenCompr exit;
    can exit_set_compr with SetCompr exit;
    can exit_dict_compr with DictCompr exit;
    can exit_atom_trailer with AtomTrailer exit;
    can exit_atom_unit with AtomUnit exit;
    can exit_func_call with FuncCall exit;
    def _place_parts(arg: UniNode) -> (tuple | None);
    def _name_swap_expr(store_id: str, value: CgNode) -> CgNode;
    def _lower_take(nd: FuncCall) -> (CgNode | None);
    def _lower_swap(nd: FuncCall) -> (CgNode | None);
    def _exit_func_call_impl(nd: FuncCall) -> None;
    def _fold_sorted_traversal(nd: FuncCall) -> bool;
    def _order_term(
        expr: Expr, param: str, node_ty: str, edge_ty: str
    ) -> (tuple[str, bool, bool] | None);

    def _sort_order_specs(
        key: Expr, node_ty: str, edge_ty: str
    ) -> (list[tuple[str, bool, bool]] | None);

    def _final_hop_types(nd: EdgeRefTrailer) -> tuple[str, str];
    def _simple_hop(nd: EdgeRefTrailer) -> (list[CgNode] | None);
    can exit_index_slice with IndexSlice exit;
    can exit_special_var_ref with SpecialVarRef exit;
    can exit_edge_ref_trailer with EdgeRefTrailer exit;
    def _traversal_consumed_now(nd: EdgeRefTrailer) -> bool;
    def _warn_inplace_sort(nd: FuncCall) -> None;
    can exit_edge_op_ref with EdgeOpRef exit;
    can exit_disconnect_op with DisconnectOp exit;
    can exit_connect_op with ConnectOp exit;
    can exit_filter_compr with FilterCompr exit;
    can exit_assign_compr with AssignCompr exit;
    can exit_match_stmt with MatchStmt exit;
    can exit_match_case with MatchCase exit;
    can exit_match_or with MatchOr exit;
    can exit_match_as with MatchAs exit;
    can exit_match_wild with MatchWild exit;
    can exit_match_value with MatchValue exit;
    can exit_match_singleton with MatchSingleton exit;
    can exit_match_sequence with MatchSequence exit;
    can exit_match_mapping with MatchMapping exit;
    can exit_match_k_v_pair with MatchKVPair exit;
    can exit_match_star with MatchStar exit;
    can exit_match_arch with MatchArch exit;
    can exit_token with Token exit;
    can exit_name with Name exit;
    can exit_float with Float exit;
    can exit_int with Int exit;
    can exit_string with String exit;
    can exit_bool with Bool exit;
    can exit_builtin_type with BuiltinType exit;
    can exit_null with Null exit;
    can exit_ellipsis with Ellipsis exit;
    can exit_jsx_element with JsxElement exit;
    can exit_jsx_element_name with JsxElementName exit;
    can exit_jsx_spread_attribute with JsxSpreadAttribute exit;
    can exit_jsx_normal_attribute with JsxNormalAttribute exit;
    can exit_jsx_text with JsxText exit;
    can exit_jsx_expression with JsxExpression exit;
    can exit_jsx_slot with JsxSlot exit;
    can exit_jsx_comment with JsxComment exit;
    can exit_semi with Semi exit;
    can exit_comment_token with CommentToken exit;
    can finish_expr with Expr exit;
}
