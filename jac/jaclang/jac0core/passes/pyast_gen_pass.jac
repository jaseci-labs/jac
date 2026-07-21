import ast as ast3;
import copy;
import textwrap;
import from collections.abc { Sequence }
import from typing { ClassVar, TypeVar, cast }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant {
    CodeContext,
    EdgeDir,
    is_borrow_kind,
    OwnershipKind
}
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.codeinfo { BoundaryTypeInfo, InteropBinding }
import from jaclang.jac0core.passes.ast_gen { BaseAstGenPass }
import from jaclang.jac0core.passes.ast_gen.jsx_processor { PyJsxProcessor }
import from jaclang.jac0core.diagnostics {
    E5001,
    E5002,
    E5003,
    E5004,
    E5005,
    E5006,
    E5007,
    E5008
}

glob T = TypeVar('T', bound=ast3.AST),
     TOKEN_AST_MAP: dict[(Tok, type[ast3.AST])] = {
         Tok.KW_AND: ast3.And,
         Tok.KW_OR: ast3.Or,
         Tok.PLUS: ast3.Add,
         Tok.ADD_EQ: ast3.Add,
         Tok.BW_AND: ast3.BitAnd,
         Tok.BW_AND_EQ: ast3.BitAnd,
         Tok.BW_OR: ast3.BitOr,
         Tok.BW_OR_EQ: ast3.BitOr,
         Tok.BW_XOR: ast3.BitXor,
         Tok.BW_XOR_EQ: ast3.BitXor,
         Tok.DIV: ast3.Div,
         Tok.DIV_EQ: ast3.Div,
         Tok.FLOOR_DIV: ast3.FloorDiv,
         Tok.FLOOR_DIV_EQ: ast3.FloorDiv,
         Tok.LSHIFT: ast3.LShift,
         Tok.LSHIFT_EQ: ast3.LShift,
         Tok.MOD: ast3.Mod,
         Tok.MOD_EQ: ast3.Mod,
         Tok.STAR_MUL: ast3.Mult,
         Tok.MUL_EQ: ast3.Mult,
         Tok.DECOR_OP: ast3.MatMult,
         Tok.MATMUL_EQ: ast3.MatMult,
         Tok.STAR_POW: ast3.Pow,
         Tok.STAR_POW_EQ: ast3.Pow,
         Tok.RSHIFT: ast3.RShift,
         Tok.RSHIFT_EQ: ast3.RShift,
         Tok.MINUS: ast3.Sub,
         Tok.SUB_EQ: ast3.Sub,
         Tok.BW_NOT: ast3.Invert,
         Tok.NOT: ast3.Not,
         Tok.EQ: ast3.NotEq,
         Tok.EE: ast3.Eq,
         Tok.GT: ast3.Gt,
         Tok.GTE: ast3.GtE,
         Tok.KW_IN: ast3.In,
         Tok.KW_IS: ast3.Is,
         Tok.KW_ISN: ast3.IsNot,
         Tok.LT: ast3.Lt,
         Tok.LTE: ast3.LtE,
         Tok.NE: ast3.NotEq,
         Tok.KW_NIN: ast3.NotIn
     },
     UNARY_OP_MAP: dict[(Tok, type[ast3.unaryop])] = {
         Tok.NOT: ast3.Not,
         Tok.BW_NOT: ast3.Invert,
         Tok.PLUS: ast3.UAdd,
         Tok.MINUS: ast3.USub
     };

obj PyastGenPass(BaseAstGenPass[ast3.AST]) {
    has debuginfo: dict[str, list[str]] postinit,
        already_added: list[str] = [],
        jaclib_imports: set[str] postinit,
        builtin_imports: set[str] postinit,
        typing_imports: set[str] postinit,
        _temp_name_counter: int = 0,
        _hoisted_funcs: list[ast3.FunctionDef | ast3.AsyncFunctionDef] = [],
        child_passes: list[PyastGenPass] postinit,
        preamble: list[ast3.AST] postinit,
        jsx_processor: PyJsxProcessor postinit;

    with entry {
        _builtin_names: ClassVar[(set[str] | None)] = None;
        _ambient_typing_names: ClassVar[(set[str] | None)] = None;
    }

    @classmethod
    def _get_builtin_names(cls: any) -> set[str];

    @classmethod
    def _get_ambient_typing_names(cls: any) -> set[str];

    def postinit -> None;
    def enter_node(nd: uni.UniNode) -> None;
    def exit_node(nd: uni.UniNode) -> None;
    def _gen_native_interop_stubs(nd: uni.UniNode) -> None;
    def _is_native_ext_module -> bool;
    def _native_test_shim_stmts(nd: uni.Test) -> list;
    def _generate_sv_to_sv_stubs(nd: uni.Import) -> bool;
    def _gen_py_sv_func_stub(
        local_name: str,
        func_name: str,
        module_name: str,
        binding: InteropBinding,
        boundary_types: dict[str, BoundaryTypeInfo]
    ) -> str;

    def _gen_py_sv_walker_stub(
        local_name: str,
        walker_name: str,
        module_name: str,
        binding: InteropBinding,
        boundary_types: dict[str, BoundaryTypeInfo]
    ) -> str;

    def _gen_py_boundary_stub_class(class_name: str, info: BoundaryTypeInfo) -> str;
    def jaclib_obj(obj_name: str) -> ast3.Name;
    def builtin_name(name: str) -> ast3.Name;
    def _is_edge_ref_target(target: uni.UniNode) -> bool;
    def _add_preamble_once(key: str, nd: ast3.AST) -> None;
    def needs_enum_kind(kind: str) -> None;
    def _next_temp_name(prefix: str) -> str;
    def _py_name(nd: uni.AstSymbolNode) -> str;
    def _emit_jobj_ref(nd: uni.UnaryExpr) -> None;
    def _function_expr_from_def(
        func_def: (ast3.FunctionDef | ast3.AsyncFunctionDef),
        jac_node: uni.UniNode,
        filename_hint: str
    ) -> ast3.Name;

    def _get_sem_decorator(nd: uni.UniNode) -> (ast3.Call | None);
    def py_ast_val(nd: uni.UniNode) -> ast3.AST;
    def sync(
        py_node: T, jac_node: (uni.UniNode | None) = None, deep: bool = False
    ) -> T;

    def pyinline_sync(py_nodes: list[ast3.AST]) -> list[ast3.AST];
    def resolve_switch_pattern(
        pattern: uni.MatchPattern, target: uni.Expr
    ) -> ast3.expr;

    def resolve_switch_stmt(nd: uni.SwitchStmt) -> list[ast3.AST];
    def resolve_stmt_block(
        nd: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
        doc: (uni.String | None) = None
    ) -> list[ast3.AST];

    def _resolve_self_type(nd: uni.Name) -> (ast3.expr | None);
    def _is_in_type_annotation(nd: uni.UniNode) -> bool;
    def _is_descendant_of(nd: uni.UniNode, ancestor: uni.UniNode) -> bool;
    def exit_sub_tag(nd: uni.SubTag[uni.T]) -> None;
    def exit_module(nd: uni.Module) -> None;
    def exit_type_param(nd: uni.TypeParam) -> None;
    def exit_type_alias(nd: uni.TypeAlias) -> None;
    def exit_global_vars(nd: uni.GlobalVars) -> None;
    def exit_test(nd: uni.Test) -> None;
    def exit_module_code(nd: uni.ModuleCode) -> None;
    def exit_client_block(nd: uni.ClientBlock) -> None;
    def exit_server_block(nd: uni.ServerBlock) -> None;
    def exit_native_block(nd: uni.NativeBlock) -> None;
    def exit_py_inline_code(nd: uni.PyInlineCode) -> None;
    def exit_import(nd: uni.Import) -> None;
    def exit_module_path(nd: uni.ModulePath) -> None;
    def exit_module_item(nd: uni.ModuleItem) -> None;
    def enter_archetype(nd: uni.Archetype) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def enter_enum(nd: uni.Enum) -> None;
    def exit_enum(nd: uni.Enum) -> None;
    def enter_ability(nd: uni.Ability) -> None;
    def _invoke_llm_call(
        model: ast3.expr, caller: ast3.expr, args: ast3.Dict, is_async: bool = False
    ) -> ast3.expr;

    def gen_llm_body(nd: uni.Ability) -> list[ast3.stmt];
    def exit_ability(nd: uni.Ability) -> None;
    def exit_impl_def(nd: uni.ImplDef) -> None;
    def exit_sem_def(nd: uni.SemDef) -> None;
    def exit_func_signature(nd: uni.FuncSignature) -> None;
    def exit_event_signature(nd: uni.EventSignature) -> None;
    def exit_param_var(nd: uni.ParamVar) -> None;
    def exit_arch_has(nd: uni.ArchHas) -> None;
    def exit_has_var(nd: uni.HasVar) -> None;
    def exit_typed_ctx_block(nd: uni.TypedCtxBlock) -> None;
    def exit_open_stmt(nd: uni.OpenStmt) -> None;
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def exit_else_if(nd: uni.ElseIf) -> None;
    def exit_else_stmt(nd: uni.ElseStmt) -> None;
    def exit_expr_stmt(nd: uni.ExprStmt) -> None;
    def exit_concurrent_expr(nd: uni.ConcurrentExpr) -> None;
    def exit_try_stmt(nd: uni.TryStmt) -> None;
    def exit_except(nd: uni.Except) -> None;
    def exit_finally_stmt(nd: uni.FinallyStmt) -> None;
    def exit_iter_for_stmt(nd: uni.IterForStmt) -> None;
    def exit_in_for_stmt(nd: uni.InForStmt) -> None;
    def exit_while_stmt(nd: uni.WhileStmt) -> None;
    def exit_forever_stmt(nd: uni.ForeverStmt) -> None;
    def exit_with_stmt(nd: uni.WithStmt) -> None;
    def exit_expr_as_item(nd: uni.ExprAsItem) -> None;
    def exit_raise_stmt(nd: uni.RaiseStmt) -> None;
    def exit_assert_stmt(nd: uni.AssertStmt) -> None;
    def exit_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    def exit_delete_stmt(nd: uni.DeleteStmt) -> None;
    def exit_report_stmt(nd: uni.ReportStmt) -> None;
    def exit_return_stmt(nd: uni.ReturnStmt) -> None;
    def exit_yield_expr(nd: uni.YieldExpr) -> None;
    def exit_visit_stmt(nd: uni.VisitStmt) -> None;
    def exit_disengage_stmt(nd: uni.DisengageStmt) -> None;
    def exit_await_expr(nd: uni.AwaitExpr) -> None;
    def exit_cast_expr(nd: uni.CastExpr) -> None;
    def scope_directive_stmts(scopes: list) -> list[ast3.AST];
    def exit_assignment(nd: uni.Assignment) -> None;
    def exit_binary_expr(nd: uni.BinaryExpr) -> None;
    def translate_jac_bin_op(nd: uni.BinaryExpr) -> list[ast3.AST];
    def exit_compare_expr(nd: uni.CompareExpr) -> None;
    def exit_cfg_expr(nd: uni.CfgExpr) -> None;
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_lambda_expr(nd: uni.LambdaExpr) -> None;
    def _emit_lambda_expr_body(nd: uni.LambdaExpr, body_node: uni.Expr) -> None;
    def _remove_lambda_param_annotations(signature: uni.FuncSignature) -> None;
    def exit_unary_expr(nd: uni.UnaryExpr) -> None;
    def exit_if_else_expr(nd: uni.IfElseExpr) -> None;
    def exit_multi_string(nd: uni.MultiString) -> None;
    def exit_f_string(nd: uni.FString) -> None;
    def exit_formatted_value(nd: uni.FormattedValue) -> None;
    def exit_list_val(nd: uni.ListVal) -> None;
    def exit_set_val(nd: uni.SetVal) -> None;
    def exit_tuple_val(nd: uni.TupleVal) -> None;
    def exit_dict_val(nd: uni.DictVal) -> None;
    def exit_k_v_pair(nd: uni.KVPair) -> None;
    def exit_k_w_pair(nd: uni.KWPair) -> None;
    def exit_inner_compr(nd: uni.InnerCompr) -> None;
    def exit_list_compr(nd: uni.ListCompr) -> None;
    def exit_gen_compr(nd: uni.GenCompr) -> None;
    def exit_set_compr(nd: uni.SetCompr) -> None;
    def exit_dict_compr(nd: uni.DictCompr) -> None;
    def exit_atom_trailer(nd: uni.AtomTrailer) -> None;
    def exit_atom_unit(nd: uni.AtomUnit) -> None;
    def gen_call_args(
        nd: uni.FuncCall
    ) -> tuple[(list[ast3.expr], list[ast3.keyword])];

    def exit_func_call(nd: uni.FuncCall) -> None;
    def exit_index_slice(nd: uni.IndexSlice) -> None;
    def exit_special_var_ref(nd: uni.SpecialVarRef) -> None;
    def exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None;
    def exit_edge_op_ref(nd: uni.EdgeOpRef) -> None;
    def exit_disconnect_op(nd: uni.DisconnectOp) -> None;
    def exit_connect_op(nd: uni.ConnectOp) -> None;
    def exit_filter_compr(nd: uni.FilterCompr) -> None;
    def exit_assign_compr(nd: uni.AssignCompr) -> None;
    def exit_match_stmt(nd: uni.MatchStmt) -> None;
    def exit_match_case(nd: uni.MatchCase) -> None;
    def exit_match_or(nd: uni.MatchOr) -> None;
    def exit_match_as(nd: uni.MatchAs) -> None;
    def exit_match_wild(nd: uni.MatchWild) -> None;
    def exit_match_value(nd: uni.MatchValue) -> None;
    def exit_match_singleton(nd: uni.MatchSingleton) -> None;
    def exit_match_sequence(nd: uni.MatchSequence) -> None;
    def exit_match_mapping(nd: uni.MatchMapping) -> None;
    def exit_match_k_v_pair(nd: uni.MatchKVPair) -> None;
    def exit_match_star(nd: uni.MatchStar) -> None;
    def exit_match_arch(nd: uni.MatchArch) -> None;
    def exit_token(nd: uni.Token) -> None;
    def exit_name(nd: uni.Name) -> None;
    def exit_float(nd: uni.Float) -> None;
    def exit_int(nd: uni.Int) -> None;
    def exit_string(nd: uni.String) -> None;
    def exit_bool(nd: uni.Bool) -> None;
    def exit_builtin_type(nd: uni.BuiltinType) -> None;
    def exit_null(nd: uni.Null) -> None;
    def exit_ellipsis(nd: uni.Ellipsis) -> None;
    def exit_jsx_element(nd: uni.JsxElement) -> None;
    def exit_jsx_element_name(nd: uni.JsxElementName) -> None;
    def exit_jsx_attribute(nd: uni.JsxAttribute) -> None;
    def exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None;
    def exit_jsx_child(nd: uni.JsxChild) -> None;
    def exit_jsx_text(nd: uni.JsxText) -> None;
    def exit_jsx_expression(nd: uni.JsxExpression) -> None;
    def exit_jsx_slot(nd: uni.JsxSlot) -> None;
    def exit_jsx_comment(nd: uni.JsxComment) -> None;
    def exit_semi(nd: uni.Semi) -> None;
    def exit_comment_token(nd: uni.CommentToken) -> None;
}
