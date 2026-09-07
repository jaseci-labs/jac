import from jaclang.runtime.osp_kernel { osp_skip_rest }
import json;
import from typing { cast }
import jaclang.compiler.backends.es.estree as es;
import jaclang.compiler.frontend.unitree as uni;
import type from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.backends.es.es_unparse { es_to_js }
import from jaclang.compiler.frontend.constant { CodeContext, SymbolType }
import from jaclang.compiler.frontend.constant { Tokens as Tok }
import from jaclang.runtime.osp_model { OspAnalysis, OspModel }
import from jaclang.compiler.backends.common.ast_gen_base { BaseAstGenPass }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
import from jaclang.compiler.backends.es.jsx_processor { EsJsxProcessor }
import from jaclang.compiler.frontend.codeinfo { ClientManifest }
import from jaclang.compiler.backends.es.scoped_styles {
    ScopedStyleSheet,
    load_style_annex
}
import from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }
import from jaclang.compiler.backends.es.free_ident_audit {
    FreeIdentifier,
    RUNTIME_PRELUDE_GLOBALS,
    client_ambient_globals,
    free_identifiers
}
import from jaclang.compiler.driver.modresolver {
    convert_to_js_import_path,
    relative_js_specifier,
    resolve_relative_path
}
import from jaclang.compiler.frontend.diagnostics {
    E2025,
    E5010,
    E5011,
    E5012,
    E5016,
    E5017,
    E5018,
    W5013,
    W5014,
    W5015,
    E5080,
    E5081,
    E5085,
    E5086,
    E5099,
    E5101,
    E5103
}

glob _T = TypeVar('_T', bound=es.Node),
     ES_LOGICAL_OPS: dict[(Tok, str)] = {Tok.KW_AND: '&&', Tok.KW_OR: '||'},
     ES_BINARY_OPS: dict[(Tok, str)] = {
         Tok.EE: '===',
         Tok.NE: '!==',
         Tok.LT: '<',
         Tok.GT: '>',
         Tok.LTE: '<=',
         Tok.GTE: '>=',
         Tok.PLUS: '+',
         Tok.MINUS: '-',
         Tok.STAR_MUL: '*',
         Tok.DIV: '/',
         Tok.MOD: '%',
         Tok.BW_AND: '&',
         Tok.BW_OR: '|',
         Tok.BW_XOR: '^',
         Tok.LSHIFT: '<<',
         Tok.RSHIFT: '>>'
     },
     ES_COMPARISON_OPS: dict[(Tok, str)] = {
         Tok.EE: '===',
         Tok.NE: '!==',
         Tok.LT: '<',
         Tok.GT: '>',
         Tok.LTE: '<=',
         Tok.GTE: '>=',
         Tok.KW_IS: '===',
         Tok.KW_ISN: '!==',
         Tok.KW_IN: 'in',
         Tok.KW_NIN: 'in'
     },
     ES_UNARY_OPS: dict[(Tok, str)] = {
         Tok.MINUS: '-',
         Tok.PLUS: '+',
         Tok.NOT: '!',
         Tok.BW_NOT: '~'
     },
     ES_AUG_ASSIGN_OPS: dict[(Tok, str)] = {
         Tok.ADD_EQ: '+=',
         Tok.SUB_EQ: '-=',
         Tok.MUL_EQ: '*=',
         Tok.DIV_EQ: '/=',
         Tok.MOD_EQ: '%=',
         Tok.BW_AND_EQ: '&=',
         Tok.BW_OR_EQ: '|=',
         Tok.BW_XOR_EQ: '^=',
         Tok.LSHIFT_EQ: '<<=',
         Tok.RSHIFT_EQ: '>>=',
         Tok.STAR_POW_EQ: '**='
     },
     OP_EMIT_MAP: dict[(Tok, str)] = {
         Tok.PLUS: "emit_op_add",
         Tok.MINUS: "emit_op_sub",
         Tok.STAR_MUL: "emit_op_mul",
         Tok.DIV: "emit_op_truediv",
         Tok.FLOOR_DIV: "emit_op_floordiv",
         Tok.MOD: "emit_op_mod",
         Tok.STAR_POW: "emit_op_pow",
         Tok.BW_AND: "emit_op_and",
         Tok.BW_OR: "emit_op_or",
         Tok.BW_XOR: "emit_op_xor",
         Tok.LSHIFT: "emit_op_lshift",
         Tok.RSHIFT: "emit_op_rshift"
     },
     CMP_EMIT_MAP: dict[(Tok, str)] = {
         Tok.EE: "emit_op_eq",
         Tok.NE: "emit_op_ne",
         Tok.LT: "emit_op_lt",
         Tok.GT: "emit_op_gt",
         Tok.LTE: "emit_op_le",
         Tok.GTE: "emit_op_ge",
         Tok.KW_IN: "emit_op_contains",
         Tok.KW_NIN: "emit_op_contains"
     },
     FW_JS_PLAIN_OPS: frozenset = frozenset({"&", "|", "^"}),
     FW_JS_CHECKED_OPS: frozenset = frozenset({"+", "-", "*"}),
     FW_JS_HELPER_OPS: dict[(str, str)] = {
         "/": "div",
         "//": "fdiv",
         "%": "mod",
         "**": "pow",
         "<<": "shl",
         ">>": "shr"
     },
     FW_JS_FLOAT_HELPERS: dict[(str, str)] = {
         "/": "div",
         "//": "fdiv",
         "%": "mod",
         "**": "pow"
     },
     FW_BINARY_OPS: dict[(Tok, str)] = {
         Tok.PLUS: "+",
         Tok.MINUS: "-",
         Tok.STAR_MUL: "*",
         Tok.DIV: "/",
         Tok.FLOOR_DIV: "//",
         Tok.MOD: "%",
         Tok.STAR_POW: "**",
         Tok.BW_AND: "&",
         Tok.BW_OR: "|",
         Tok.BW_XOR: "^",
         Tok.LSHIFT: "<<",
         Tok.RSHIFT: ">>"
     },
     AUG_TO_BINARY_TOK: dict[(Tok, Tok)] = {
         Tok.ADD_EQ: Tok.PLUS,
         Tok.SUB_EQ: Tok.MINUS,
         Tok.MUL_EQ: Tok.STAR_MUL,
         Tok.DIV_EQ: Tok.DIV,
         Tok.FLOOR_DIV_EQ: Tok.FLOOR_DIV,
         Tok.MOD_EQ: Tok.MOD,
         Tok.STAR_POW_EQ: Tok.STAR_POW,
         Tok.BW_AND_EQ: Tok.BW_AND,
         Tok.BW_OR_EQ: Tok.BW_OR,
         Tok.BW_XOR_EQ: Tok.BW_XOR,
         Tok.LSHIFT_EQ: Tok.LSHIFT,
         Tok.RSHIFT_EQ: Tok.RSHIFT
     },
     UNARY_EMIT_MAP: dict[(Tok, str)] = {
         Tok.MINUS: "emit_op_neg",
         Tok.PLUS: "emit_op_pos",
         Tok.BW_NOT: "emit_op_invert"
     },
     AUG_EMIT_MAP: dict[(Tok, str)] = {
         Tok.ADD_EQ: "emit_op_iadd",
         Tok.SUB_EQ: "emit_op_isub",
         Tok.MUL_EQ: "emit_op_imul",
         Tok.BW_OR_EQ: "emit_op_ior",
         Tok.BW_AND_EQ: "emit_op_iand",
         Tok.BW_XOR_EQ: "emit_op_ixor"
     },
     LiteralValue = str | bool | int | float | None;

glob VIEW_ACC: str = "__jac_view_kids";

glob ES_STMT_DISPLAY: dict[str, str] = {
         'DeleteStmt': "'del' statement",
         'MatchStmt': "'match' statement",
         'WithStmt': "'with' statement",
         'OpenStmt': "'open' block",
         'TypedCtxBlock': 'typed context block',
         'PyInlineCode': 'inline Python block'
     };

obj ScopeInfo {
    has nd: uni.UniScopeNode,
        declared: set[str] = set(),
        hoisted: list[es.Statement] = [];
}

obj AssignmentTargetInfo {
    has nd: uni.Expr,
        left: (es.Pattern | es.Expression),
        reference: (es.Expression | None),
        decl_name: (str | None),
        pattern_names: list[tuple[(str, uni.Name)]];
}

obj SpawnWalkerInfo {
    has call_node: uni.FuncCall,
        walker_name: str,
        fields_object: es.ObjectExpression;
}

obj SpawnTargetInfo {
    has nd: uni.Expr,
        expression: es.Expression;
}

obj SpawnCallParts {
    has `walker: SpawnWalkerInfo,
        target: SpawnTargetInfo;
}

obj CallArgSlot {
    has name: (str | None),
        value: (es.Expression | es.SpreadElement | None);
}

walker EsastGenPass(BaseAstGenPass[es.Statement]) {
    has prog: JacProgram,
        _ct_only_names: (set[str] | None) = None,
        child_passes: list[EsastGenPass] = [],
        imports: list[es.ImportDeclaration] = [],
        exports: list[es.ExportNamedDeclaration] = [],
        scope_stack: list[ScopeInfo] = [],
        scope_map: dict[(uni.UniScopeNode, ScopeInfo)] = {},
        backend: (FrameworkBackend | None) = None,
        client_manifest: (ClientManifest | None) = None,
        jsx_processor: (EsJsxProcessor | None) = None,
        scoped_styles: (ScopedStyleSheet | None) = None,
        reactive_vars: set[str] = set(),
        component_export_names: set[str] = set(),
        reactive_vars_stack: list[set[str]] = [],
        injected_imports: set[str] = set(),
        match_seq: int = 0,
        _view_stack: list[(str | None)] = [],
        _view_used_base: bool = False,
        _view_acc_counter: int = 0,
        _view_awaiting_tries: set[int] = set(),
        _view_dynamic_accs: set[str] = set(),
        _view_acc_next: dict[(str, int)] = {},
        _view_acc_high: dict[(str, int)] = {},
        _view_branch_base: dict[(int, int)] = {},
        _view_slot_loops: set[int] = set(),
        sv_import_stubs: list[es.Statement] = [],
        na_import_stubs: list[es.Statement] = [],
        needs_jac_runtime: bool = False,
        needs_osp_kernel: bool = False,
        needs_osp_graph: bool = False,
        _unlowered_reported: set = set(),
        _unbound_reported: set[str] = set(),
        _osp_var_arch_cache: (dict | None) = None,
        _primitive_emitters: (dict[str, object] | None) = None,
        _builtin_emitter: (object | None) = None,
        _primitives_es_mod: (object | None) = None,
        _poly_methods: (set[str] | None) = None;

    static has HOST_PASS: bool = True;

    def before_pass -> None;
    can enter_walk with uni.UniNode entry;
    can exit_walk with uni.UniNode exit;
    def _fw_call(
        name: str, args: list[es.Expression], jac_node: uni.UniNode
    ) -> es.Expression;

    def _apply_fw_coercion(nd: uni.Expr) -> None;
    def _fw_js_binop(
        op: str, left: es.Expression, right: es.Expression, jac_node: uni.UniNode
    ) -> es.Expression;

    def _fw_to_number(expr: es.Expression, jac_node: uni.UniNode) -> es.Expression;
    def _fw_binary(
        nd: uni.Expr, op: str, left: es.Expression, right: es.Expression
    ) -> (es.Expression | None);

    def sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T;
    def _template_element(
        text: str, tail: bool, jac_node: uni.UniNode
    ) -> es.TemplateElement;

    def _push_scope(nd: uni.UniScopeNode) -> None;
    def _pop_scope(nd: uni.UniScopeNode) -> None;
    def _alt_branch_scope_to_finalize(nd: uni.UniNode) -> (uni.UniScopeNode | None);
    def _current_scope -> (ScopeInfo | None);
    def _is_declared_in_any_scope(name: str) -> bool;
    def _register_declaration(name: str) -> None;
    def _declaring_scope_for(name_node: uni.UniNode) -> (ScopeInfo | None);
    def _operand_str(unparser: object, es_node: es.Expression) -> str;
    def _is_null_literal(nd: (uni.UniNode | None)) -> bool;
    def _hoist_into(scope: ScopeInfo, name: str, jac_node: uni.UniNode) -> None;
    def _ensure_identifier_declared(name: str, jac_node: uni.UniNode) -> None;
    def _prepend_hoisted(
        nd: uni.UniScopeNode, statements: list[es.Statement]
    ) -> list[es.Statement];

    def _collect_body_stmts(body: Sequence[uni.UniNode]) -> list[es.Statement];
    def _strip_spawn_await(
        node_expr: uni.Expr, es_expr: es.Expression
    ) -> tuple[uni.Expr, es.Expression];

    def get_main_mod -> uni.Module;
    def _expr_from_node(
        nd: (uni.UniNode | None), `default: LiteralValue = None
    ) -> es.Expression;

    def _build_spawn_arg_object(
        call_node: uni.FuncCall, walker_symbol: (uni.Symbol | None)
    ) -> es.ObjectExpression;

    def _resolve_spawn_walker(
        expr: uni.Expr, es_expr: es.Expression
    ) -> (SpawnWalkerInfo | None);

    def _is_root_reference(expr: uni.Expr) -> bool;
    def _resolve_spawn_target(
        expr: uni.Expr, es_expr: es.Expression
    ) -> SpawnTargetInfo;

    def _prepare_spawn_call(
        nd: uni.BinaryExpr, left_expr: es.Expression, right_expr: es.Expression
    ) -> (SpawnCallParts | None);

    def _import_item_named(name: str) -> (uni.ModuleItem | None);
    def _build_spawn_runtime_call(
        nd: uni.BinaryExpr, parts: SpawnCallParts
    ) -> es.AwaitExpression;

    def _osp_model -> OspModel;
    def _osp_ability_info(nd: uni.Ability) -> (dict | None);
    def _osp_const_decl(
        name: str, `init: es.Expression, nd: uni.UniNode
    ) -> es.VariableDeclaration;

    def _emit_osp_slot_method(nd: uni.Ability, osp: dict) -> None;
    def _build_osp_tags_js -> str;
    def _build_osp_setup_js -> str;
    def _osp_slots_js(slots: list, tags: dict) -> str;
    def _osp_arch_kinds -> dict[str, str];
    def _osp_arch_set -> set[str];
    def _osp_var_arch -> dict[str, str];
    def _osp_expr_arch_name(expr: (uni.UniNode | None)) -> (str | None);
    def _arch_kind_by_name(name: str) -> (str | None);
    def _arch_kind_of_type(ty: object) -> (str | None);
    def _expr_class_type(expr: (uni.UniNode | None)) -> (object | None);
    def _osp_expr_arch_kind(expr: (uni.UniNode | None)) -> (str | None);
    def _spawn_walker_arch(expr: uni.Expr) -> (str | None);
    def _spawn_target_is_local_node(expr: uni.Expr) -> bool;
    def _build_osp_graph_call(
        nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
    ) -> (es.Expression | None);

    def _build_osp_disconnect_call(
        nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
    ) -> es.Expression;

    def _build_edge_ref(nd: uni.EdgeRefTrailer) -> es.Expression;
    def _build_osp_filter_pred(
        nd: uni.UniNode, filt: uni.FilterCompr
    ) -> (es.Expression | None);

    def _edge_tag_literal(
        nd: uni.UniNode, type_expr: (uni.UniNode | None), hard: bool
    ) -> int;

    def _is_client_destined(nd: uni.UniNode) -> bool;
    def _build_local_osp_spawn(
        nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
    ) -> (es.Expression | None);

    def _collect_stmt_body(body: (Sequence[uni.UniNode] | None)) -> list[es.Statement];
    def _get_ast_or_default(
        nd: (uni.UniNode | None),
        default_factory: Callable[([(uni.UniNode | None)], _T)]
    ) -> _T;

    def _ct_es_expr(cv: any, jac_node: uni.UniNode) -> (es.Expression | None);
    def _ct_es_value(v: any) -> (es.Expression | None);
    def _ct_only_name(nd: uni.Name) -> bool;
    def _comptime_only_names -> set[str];
    def _is_ct_type_param(nd: uni.Name) -> bool;
    def _ct_ctor_slots(nd: uni.UniNode) -> (list[tuple] | None);
    def _trailer_reaches_ct_class(nd: uni.AtomTrailer) -> bool;
    def _build_block_statement(
        scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
    ) -> es.BlockStatement;

    def _jac_exc_ref(
        member: str, jac_node: (uni.UniNode | None)
    ) -> es.MemberExpression;

    can exit_module with uni.Module exit;
    def _audit_free_identifiers(nd: uni.Module, program: es.Program) -> None;
    def _free_ident_site(
        names: list[uni.Name], free: FreeIdentifier
    ) -> (uni.Name | None);

    def populate_client_manifest(nd: uni.Module) -> None;
    can exit_sub_tag with uni.SubTag exit;
    can exit_import with uni.Import exit;
    def _partition_client_import_items(nd: uni.Import) -> (tuple[list, list] | None);
    def _generate_sv_import_stubs(
        nd: uni.Import, items: (Sequence[uni.ModuleItem] | None) = None
    ) -> None;

    def _sv_import_item_is_type(nd: uni.Import, item: uni.ModuleItem) -> bool;
    def _is_service_bridge_import(nd: uni.Import) -> bool;
    def _sv_provider_options(nd: uni.Import) -> (es.Expression | None);
    def _record_sv_backend(nd: uni.Import) -> None;
    def _generate_na_import_binding(nd: uni.Import) -> None;
    def _is_client_native_import(nd: uni.Import) -> bool;
    def _emit_boundary_type_stubs(nd: uni.Module) -> list;
    def _es_json_literal(value: any) -> any;
    can exit_type_alias with uni.TypeAlias exit;
    can exit_type_param with uni.TypeParam exit;
    can exit_archetype with uni.Archetype exit;
    can exit_enum with uni.Enum exit;
    can enter_ability with uni.Ability entry;
    can exit_ability with uni.Ability exit;
    can exit_visit_stmt with uni.VisitStmt exit;
    can exit_disengage_stmt with uni.DisengageStmt exit;
    can exit_report_stmt with uni.ReportStmt exit;
    can exit_edge_ref_trailer with uni.EdgeRefTrailer exit;
    can exit_func_signature with uni.FuncSignature exit;
    can exit_param_var with uni.ParamVar exit;
    can exit_arch_has with uni.ArchHas exit;
    def _setter_name_taken(has_var: uni.HasVar, setter_name: str) -> bool;
    can exit_has_var with uni.HasVar exit;
    def _has_import(name: str) -> bool;
    def _inject_runtime_import(name: str, nd: uni.UniNode) -> None;
    def _ref_head_name(expr: (uni.UniNode | None)) -> (str | None);
    def _ref_forward_param(nd: uni.Ability) -> (uni.ParamVar | None);
    def _register_jac_virtual_import(module_id: str) -> None;
    def _register_jac_runtime_import -> None;
    def _ensure_backend -> None;
    def _transform_to_useeffect(nd: uni.Ability) -> None;
    can exit_jsx_element with uni.JsxElement exit;
    can exit_jsx_element_name with uni.JsxElementName exit;
    can exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit;
    can exit_jsx_normal_attribute with uni.JsxNormalAttribute exit;
    can exit_jsx_text with uni.JsxText exit;
    can exit_jsx_expression with uni.JsxExpression exit;
    can enter_jsx_slot with uni.JsxSlot entry;
    can exit_jsx_slot with uni.JsxSlot exit;
    can exit_jsx_comment with uni.JsxComment exit;
    can enter_try_stmt with uni.TryStmt entry;
    can enter_except with uni.Except entry;
    can enter_awaiting_clause with uni.AwaitingClause entry;
    can exit_awaiting_clause with uni.AwaitingClause exit;
    def _cur_view_acc -> (str | None);
    def _push_view_acc -> str;
    def _view_push_stmt(
        acc_name: str, value: es.Expression, anchor: uni.UniNode
    ) -> es.ExpressionStatement;

    def _jsx_fragment(
        children: es.Expression, anchor: uni.UniNode
    ) -> es.CallExpression;

    def _view_alloc_index(acc_name: str) -> int;
    def _view_assign_stmt(
        acc_name: str, index: int, value: es.Expression, anchor: uni.UniNode
    ) -> es.ExpressionStatement;

    def _view_emit_child(
        acc_name: str, value: es.Expression, anchor: uni.UniNode
    ) -> es.ExpressionStatement;

    def _view_open_loop_acc(nd: uni.UniNode) -> None;
    def _view_loop_stmt(nd: uni.UniNode, loop_stmt: es.Statement) -> es.Statement;
    def _view_chain_open(nd: uni.UniNode) -> None;
    def _view_chain_arm(nd: uni.UniNode) -> None;
    def _view_chain_close(nd: uni.UniNode) -> None;
    can enter_if_stmt with uni.IfStmt entry;
    can enter_else_if with uni.ElseIf entry;
    can enter_else_stmt with uni.ElseStmt entry;
    can enter_in_for_stmt with uni.InForStmt entry;
    can enter_iter_for_stmt with uni.IterForStmt entry;
    can enter_while_stmt with uni.WhileStmt entry;
    can enter_forever_stmt with uni.ForeverStmt entry;
    def _view_fragment_return(
        acc_name: str, anchor: uni.UniNode
    ) -> es.ReturnStatement;

    def _build_view_iife(
        body_nodes: (Sequence[uni.UniNode] | None), acc_name: str, anchor: uni.UniNode
    ) -> es.CallExpression;

    def _view_iife_from_stmts(
        stmts: list[es.Statement], acc_name: str, anchor: uni.UniNode
    ) -> es.CallExpression;

    can exit_if_stmt with uni.IfStmt exit;
    can exit_else_if with uni.ElseIf exit;
    can exit_else_stmt with uni.ElseStmt exit;
    can exit_while_stmt with uni.WhileStmt exit;
    can exit_forever_stmt with uni.ForeverStmt exit;
    can exit_iter_for_stmt with uni.IterForStmt exit;
    can exit_in_for_stmt with uni.InForStmt exit;
    def _target_to_pattern(target: es.Node, loc: uni.UniNode) -> es.Node;
    can exit_try_stmt with uni.TryStmt exit;
    can exit_except with uni.Except exit;
    can exit_finally_stmt with uni.FinallyStmt exit;
    can exit_raise_stmt with uni.RaiseStmt exit;
    can exit_assert_stmt with uni.AssertStmt exit;
    can exit_return_stmt with uni.ReturnStmt exit;
    can exit_ctrl_stmt with uni.CtrlStmt exit;
    can exit_expr_stmt with uni.ExprStmt exit;
    can exit_switch_stmt with uni.SwitchStmt exit;
    can exit_switch_case with uni.SwitchCase exit;
    can exit_delete_stmt with uni.DeleteStmt exit;
    def _es_destroy_stmt(
        target: uni.Expr, nd: uni.DeleteStmt
    ) -> (es.Statement | None);

    def _es_poly_destroy_stmt(
        value: es.Expression, nd: uni.DeleteStmt
    ) -> es.Statement;

    def _es_del_trivial(expr: es.Expression) -> bool;
    def _es_del_bind(
        expr: es.Expression, name: str, stmts: list[es.Statement], nd: uni.DeleteStmt
    ) -> es.Expression;

    def _es_delete_location(
        target: uni.AtomTrailer, nd: uni.DeleteStmt, ordinal: int
    ) -> list[es.Statement];

    def _es_release_name_stmt(
        target: uni.Name, nd: uni.DeleteStmt
    ) -> (es.Statement | None);

    def _es_slice_part(part: (uni.Expr | None), nd: uni.DeleteStmt) -> es.Expression;
    can exit_match_stmt with uni.MatchStmt exit;
    def _lower_match_pattern(
        pat: uni.MatchPattern, subj: es.Expression
    ) -> tuple[(es.Expression | None), list[es.Statement], bool];

    def _match_bind_name(name_node: uni.UniNode, value: es.Expression) -> es.Statement;
    def _match_arch_field_order(pat: uni.MatchArch) -> (list[str] | None);
    def _match_subj_member(subj: es.Expression, field: str) -> es.Expression;
    def _ensure_emitters -> None;
    def _resolve_primitive_type_name(_obj_type: object) -> str;
    def _try_primitive_op(
        expr_node: uni.UniNode,
        emit_method: str,
        left_es: es.Expression,
        right_es: (es.Expression | None),
        jac_node: uni.UniNode
    ) -> (es.Expression | None);

    def _expr_type_name(expr_node: uni.UniNode) -> str;
    def _is_collection_expr(expr_node: uni.UniNode) -> bool;
    def _is_native_iterable_builtin_call(expr_node: uni.UniNode) -> bool;
    def _build_jac_ref(
        path: list[str], jac_node: (uni.UniNode | None)
    ) -> es.Expression;

    def _build_jac_call(
        path: list[str], args: list[es.Expression], jac_node: uni.UniNode
    ) -> es.Expression;

    def _coerce_truthy(
        expr_node: (uni.UniNode | None), es_expr: es.Expression, jac_node: uni.UniNode
    ) -> es.Expression;

    def _is_literal_index(idx_es: es.Expression) -> bool;
    def _lower_subscript(
        target_node: uni.UniNode,
        obj_es: es.Expression,
        idx_es: es.Expression,
        jac_node: uni.UniNode
    ) -> es.Expression;

    def _try_subscript_setitem(
        target: uni.UniNode, value_es: (es.Expression | None), jac_node: uni.UniNode
    ) -> (es.Statement | None);

    can exit_binary_expr with uni.BinaryExpr exit;
    can exit_cfg_expr with uni.CfgExpr exit;
    can exit_bool_expr with uni.BoolExpr exit;
    can exit_compare_expr with uni.CompareExpr exit;
    can exit_unary_expr with uni.UnaryExpr exit;
    def _convert_assignment_target(
        target: uni.UniNode
    ) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)];

    def _collect_pattern_names(target: uni.UniNode) -> list[tuple[(str, uni.Name)]];
    can exit_assignment with uni.Assignment exit;
    def _resolve_source_module(nd: uni.Import) -> (uni.Module | None);
    def _resolve_call_ability(nd: uni.FuncCall) -> (uni.Ability | None);
    def _return_type_route_role(rt: uni.Expr) -> (str | None);
    def _component_pascal_name(nd: uni.Ability) -> (str | None);
    def _component_call_abi(ability_node: uni.Ability) -> str;
    def _build_props_spread_component_call(
        nd: uni.FuncCall,
        callee_expr: es.Expression,
        ability_node: uni.Ability,
        args: list[(es.Expression | es.SpreadElement)],
        props: list[(es.Property | es.SpreadElement)]
    ) -> es.Expression;

    def _pos_params_from_ability(ability_node: uni.Ability) -> list[uni.ParamVar];
    def _param_names_from_ability(ability_node: uni.Ability) -> list[str];
    def _param_type_map_from_ability(ability_node: uni.Ability) -> dict[(str, str)];
    def _wrap_to_wire_if_boundary(
        expr: es.Expression,
        type_name: str,
        boundary_types: dict[(str, any)],
        jac_node: uni.UniNode
    ) -> es.Expression;

    def _extract_return_type(
        ability_node: uni.Ability, func_name: str, manifest: any
    ) -> str;

    def _wrap_return_with_boundary(
        call_expr: es.Expression,
        ret_type: str,
        boundary_types: dict[(str, any)],
        jac_node: uni.UniNode,
        pre_awaited: bool
    ) -> es.Expression;

    def _resolve_call_arg_slots(
        nd: uni.FuncCall,
        args: list[(es.Expression | es.SpreadElement)],
        props: list[(es.Property | es.SpreadElement)],
        param_names: list[str],
        func_name: str,
        spread_read_source: (es.Expression | None)
    ) -> list[CallArgSlot];

    def _call_args_from_slots(
        slots: list[CallArgSlot]
    ) -> (list[(es.Expression | es.SpreadElement)] | None);

    def _kwargs_spread_arg(
        props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
    ) -> (es.Expression | None);

    def _kwargs_spread_needs_temp(
        props: list[(es.Property | es.SpreadElement)]
    ) -> bool;

    def _make_kwargs_spread_context(
        props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
    ) -> tuple[((es.Expression | None), (es.Expression | None))];

    def _wrap_with_kwargs_temp(
        expr: es.Expression, spread_arg: es.Expression, nd: uni.FuncCall
    ) -> es.Expression;

    def _try_lower_server_rpc_call(
        nd: uni.FuncCall,
        args: list[(es.Expression | es.SpreadElement)],
        props: list[(es.Property | es.SpreadElement)]
    ) -> (es.Expression | None);

    def _warn_rpc_callable_params(
        ability_node: uni.Ability, func_name: str, at: uni.UniNode
    ) -> None;

    def _forwarder_ret_label(ability_node: uni.Ability) -> str;
    def _build_server_forwarder(
        ability_node: uni.Ability, func_name: str, jac_node: uni.UniNode
    ) -> es.FunctionDeclaration;

    def _bind_client_value_refs(nd: uni.Module) -> list[es.Statement];
    can exit_func_call with uni.FuncCall exit;
    def _place_accessors(place: es.Expression) -> es.Expression | None;
    def _lower_place_builtin(nd: uni.FuncCall) -> es.Expression | None;
    can exit_index_slice with uni.IndexSlice exit;
    can exit_special_var_ref with uni.SpecialVarRef exit;
    can exit_atom_trailer with uni.AtomTrailer exit;
    can exit_lambda_expr with uni.LambdaExpr exit;
    can exit_atom_unit with uni.AtomUnit exit;
    can exit_list_val with uni.ListVal exit;
    can exit_set_val with uni.SetVal exit;
    def _gen_seq_array(nd: uni.UniNode) -> None;
    can exit_tuple_val with uni.TupleVal exit;
    can exit_dict_val with uni.DictVal exit;
    can exit_k_v_pair with uni.KVPair exit;
    can exit_inner_compr with uni.InnerCompr exit;
    can exit_list_compr with uni.ListCompr exit;
    can exit_set_compr with uni.SetCompr exit;
    can exit_gen_compr with uni.GenCompr exit;
    can exit_dict_compr with uni.DictCompr exit;
    def _build_compr_chain(nd: uni.ListCompr) -> None;
    def _build_compr_expr(
        comprs: list[uni.InnerCompr], out_expr: es.Expression, nd: uni.UniNode
    ) -> (es.Expression | None);

    def _compr_param(target: es.Expression, jac_node: uni.UniNode) -> es.Node;
    can exit_bool with uni.Bool exit;
    can exit_int with uni.Int exit;
    can exit_float with uni.Float exit;
    can exit_multi_string with uni.MultiString exit;
    can exit_string with uni.String exit;
    def _str_literal(nd: uni.String) -> es.Literal;
    can exit_formatted_value with uni.FormattedValue exit;
    can exit_f_string with uni.FString exit;
    can exit_if_else_expr with uni.IfElseExpr exit;
    can exit_await_expr with uni.AwaitExpr exit;
    can exit_yield_expr with uni.YieldExpr exit;
    def _ability_is_generator(nd: uni.Ability) -> bool;
    can exit_cast_expr with uni.CastExpr exit;
    can exit_null with uni.Null exit;
    can exit_name with uni.Name exit;
    def _exit_name_impl(nd: uni.Name) -> None;
    can exit_builtin_type with uni.BuiltinType exit;
    def _in_identifier_slot(nd: uni.UniNode) -> bool;
    def _in_type_slot(nd: uni.UniNode) -> bool;
    def _is_call_target(nd: uni.UniNode) -> bool;
    can exit_global_vars with uni.GlobalVars exit;
    can exit_module_code with uni.ModuleCode exit;
    can exit_test with uni.Test exit;
    can exit_token with uni.Token exit;
    can exit_semi with uni.Semi exit;
    can finish_expr with uni.Expr exit;
    can finish_scope with uni.UniScopeNode exit;
    def _literal_value(expr: (uni.UniNode | None)) -> (object | None);
}
