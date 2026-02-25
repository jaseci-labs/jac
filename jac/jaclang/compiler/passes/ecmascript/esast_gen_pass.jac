"""
ECMAScript AST Generation Pass for the Jac compiler.

This pass transforms the Jac AST into equivalent ECMAScript AST following
the ESTree specification by:

1. Traversing the Jac AST and generating corresponding ESTree nodes
2. Handling all Jac language constructs and translating them to JavaScript/ECMAScript equivalents:
   - Classes, functions, and methods
   - Control flow statements (if/else, loops, try/catch)
   - Data structures (arrays, objects)
   - Special Jac features (walkers, abilities, archetypes) converted to JS classes
   - Data spatial operations converted to appropriate JS patterns

3. Managing imports and module dependencies
4. Preserving source location information
5. Generating valid ECMAScript code that can be executed in JavaScript environments

The output of this pass is a complete ESTree AST representation that can be
serialized to JavaScript source code or used by JavaScript tooling.
"""

import json;
import from collections.abc { Callable, Sequence }
import from typing { Any, TypeVar, cast }
import jaclang.compiler.passes.ecmascript.estree as es;
import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.constant { CodeContext, SymbolType }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.ast_gen { BaseAstGenPass }
import from jaclang.jac0core.passes.ast_gen.jsx_processor { EsJsxProcessor }
import from jaclang.jac0core.modresolver {
    convert_to_js_import_path,
    resolve_relative_path
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

"""Track declarations within a lexical scope."""
obj ScopeInfo {
    has nd: uni.UniScopeNode,
        declared: set[str] = set(),
        hoisted: list[es.Statement] = [];
}

"""Container for processed assignment targets."""
obj AssignmentTargetInfo {
    has nd: uni.Expr,
        left: (es.Pattern | es.Expression),
        reference: (es.Expression | None),
        decl_name: (str | None),
        pattern_names: list[tuple[(str, uni.Name)]],
        is_first: bool;
}

"""Describes the walker-side of a spawn expression."""
obj SpawnWalkerInfo {
    has call_node: uni.FuncCall,
        walker_name: str,
        fields_object: es.ObjectExpression;
}

"""Describes the target-side of a spawn expression."""
obj SpawnTargetInfo {
    has nd: uni.Expr,
        expression: es.Expression;
}

"""Deconstructed spawn expression ready for runtime lowering."""
obj SpawnCallParts {
    has `walker: SpawnWalkerInfo,
        target: SpawnTargetInfo;
}

"""Jac to ECMAScript AST transpilation pass."""
obj EsastGenPass(BaseAstGenPass[es.Statement]) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: (Any | None) = None) -> None;
    def before_pass -> None;
    def enter_node(nd: uni.UniNode) -> None;
    def exit_node(nd: uni.UniNode) -> None;
    def sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T;
    def _push_scope(nd: uni.UniScopeNode) -> None;
    def _pop_scope(nd: uni.UniScopeNode) -> None;
    def _current_scope -> (ScopeInfo | None);
    def _is_declared_in_any_scope(name: str) -> bool;
    def _register_declaration(name: str) -> None;
    def _ensure_identifier_declared(name: str, jac_node: uni.UniNode) -> None;
    def _prepend_hoisted(
        nd: uni.UniScopeNode, statements: list[es.Statement]
    ) -> list[es.Statement];

    def _strip_spawn_await(
        node_expr: uni.Expr, es_expr: es.Expression
    ) -> tuple[uni.Expr, es.Expression];

    def _resolve_expr_symbol(expr: uni.Expr) -> (uni.Symbol | None);
    def search_sym_in_main_mod(expr: uni.Expr) -> (uni.Symbol | None);
    def get_main_mod -> uni.Module;
    def _collect_walker_field_names(walker_symbol: (uni.Symbol | None)) -> list[str];
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

    def _build_spawn_runtime_call(
        nd: uni.BinaryExpr, parts: SpawnCallParts
    ) -> es.AwaitExpression;

    def _analyze_body_effects(body_nodes: Sequence[uni.UniNode]) -> dict;
    def _collect_stmt_body(body: (Sequence[uni.UniNode] | None)) -> list[es.Statement];
    def _get_ast_or_default(
        nd: (uni.UniNode | None),
        default_factory: Callable[([(uni.UniNode | None)], _T)]
    ) -> _T;

    def _build_block_statement(
        scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
    ) -> es.BlockStatement;

    def exit_module(nd: uni.Module) -> None;
    def populate_client_manifest(nd: uni.Module) -> None;
    def _populate_client_manifest(nd: uni.Module) -> None;
    def exit_sub_tag(nd: uni.SubTag[uni.T]) -> None;
    def exit_import(nd: uni.Import) -> None;
    def _generate_sv_import_stubs(nd: uni.Import) -> None;
    def exit_type_alias(nd: uni.TypeAlias) -> None;
    def exit_type_param(nd: uni.TypeParam) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def exit_enum(nd: uni.Enum) -> None;
    def enter_ability(nd: uni.Ability) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_func_signature(nd: uni.FuncSignature) -> None;
    def exit_param_var(nd: uni.ParamVar) -> None;
    def exit_arch_has(nd: uni.ArchHas) -> None;
    def exit_has_var(nd: uni.HasVar) -> None;
    def _get_setter_name(var_name: str) -> str;
    def _has_import(name: str) -> bool;
    def _inject_runtime_import(name: str, nd: uni.UniNode) -> None;
    def _register_jac_runtime_import -> None;
    def _transform_to_useeffect(nd: uni.Ability) -> None;
    def exit_jsx_element(nd: uni.JsxElement) -> None;
    def exit_jsx_element_name(nd: uni.JsxElementName) -> None;
    def exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None;
    def exit_jsx_text(nd: uni.JsxText) -> None;
    def exit_jsx_expression(nd: uni.JsxExpression) -> None;
    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def exit_else_if(nd: uni.ElseIf) -> None;
    def exit_else_stmt(nd: uni.ElseStmt) -> None;
    def exit_while_stmt(nd: uni.WhileStmt) -> None;
    def exit_iter_for_stmt(nd: uni.IterForStmt) -> None;
    def exit_in_for_stmt(nd: uni.InForStmt) -> None;
    def exit_try_stmt(nd: uni.TryStmt) -> None;
    def exit_except(nd: uni.Except) -> None;
    def exit_finally_stmt(nd: uni.FinallyStmt) -> None;
    def exit_raise_stmt(nd: uni.RaiseStmt) -> None;
    def exit_assert_stmt(nd: uni.AssertStmt) -> None;
    def exit_return_stmt(nd: uni.ReturnStmt) -> None;
    def exit_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    def exit_expr_stmt(nd: uni.ExprStmt) -> None;
    def exit_switch_stmt(nd: uni.SwitchStmt) -> None;
    def exit_switch_case(nd: uni.SwitchCase) -> None;
    def _try_primitive_op(
        expr_node: uni.UniNode,
        emit_method: str,
        left_es: es.Expression,
        right_es: (es.Expression | None),
        jac_node: uni.UniNode
    ) -> (es.Expression | None);

    def exit_binary_expr(nd: uni.BinaryExpr) -> None;
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_compare_expr(nd: uni.CompareExpr) -> None;
    def exit_unary_expr(nd: uni.UnaryExpr) -> None;
    def _convert_assignment_target(
        target: uni.UniNode
    ) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)];

    def _collect_pattern_names(target: uni.UniNode) -> list[tuple[(str, uni.Name)]];
    def _is_name_first_definition(name_node: uni.Name) -> bool;
    def exit_assignment(nd: uni.Assignment) -> None;
    def exit_func_call(nd: uni.FuncCall) -> None;
    def exit_index_slice(nd: uni.IndexSlice) -> None;
    def exit_special_var_ref(nd: uni.SpecialVarRef) -> None;
    def exit_atom_trailer(nd: uni.AtomTrailer) -> None;
    def exit_lambda_expr(nd: uni.LambdaExpr) -> None;
    def exit_atom_unit(nd: uni.AtomUnit) -> None;
    def exit_list_val(nd: uni.ListVal) -> None;
    def exit_set_val(nd: uni.SetVal) -> None;
    def exit_tuple_val(nd: uni.TupleVal) -> None;
    def exit_dict_val(nd: uni.DictVal) -> None;
    def exit_k_v_pair(nd: uni.KVPair) -> None;
    def exit_inner_compr(nd: uni.InnerCompr) -> None;
    def exit_list_compr(nd: uni.ListCompr) -> None;
    def exit_set_compr(nd: uni.SetCompr) -> None;
    def exit_gen_compr(nd: uni.GenCompr) -> None;
    def exit_dict_compr(nd: uni.DictCompr) -> None;
    def _build_compr_chain(nd: uni.ListCompr) -> None;
    def _build_compr_expr(
        comprs: list[uni.InnerCompr], out_expr: es.Expression, nd: uni.UniNode
    ) -> (es.Expression | None);

    def _compr_param(target: es.Expression, jac_node: uni.UniNode) -> es.Node;
    def exit_bool(nd: uni.Bool) -> None;
    def exit_int(nd: uni.Int) -> None;
    def exit_float(nd: uni.Float) -> None;
    def exit_multi_string(nd: uni.MultiString) -> None;
    def exit_string(nd: uni.String) -> None;
    def exit_formatted_value(nd: uni.FormattedValue) -> None;
    def exit_f_string(nd: uni.FString) -> None;
    def exit_if_else_expr(nd: uni.IfElseExpr) -> None;
    def exit_await_expr(nd: uni.AwaitExpr) -> None;
    def exit_null(nd: uni.Null) -> None;
    def exit_name(nd: uni.Name) -> None;
    def exit_global_vars(nd: uni.GlobalVars) -> None;
    def exit_non_local_stmt(nd: uni.NonLocalStmt) -> None;
    def exit_module_code(nd: uni.ModuleCode) -> None;
    def exit_client_block(nd: uni.ClientBlock) -> None;
    def exit_native_block(nd: uni.NativeBlock) -> None;
    def exit_test(nd: uni.Test) -> None;
    def exit_token(nd: uni.Token) -> None;
    def exit_semi(nd: uni.Semi) -> None;
    def _literal_value(expr: (uni.UniNode | None)) -> (object | None);
}
