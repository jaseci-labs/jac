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
import jaclang.pycore.unitree as uni;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.pycore.constant { SymbolType }
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes.ast_gen { BaseAstGenPass }
import from jaclang.pycore.passes.ast_gen.jsx_processor { EsJsxProcessor }
import from jaclang.pycore.modresolver {
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
     LiteralValue = str | bool | int | float | None;

"""Track declarations within a lexical scope."""
obj ScopeInfo {
    has <>node: uni.UniScopeNode,
        declared: set[str] = set(),
        hoisted: list[es.Statement] = [];
}

"""Container for processed assignment targets."""
obj AssignmentTargetInfo {
    has <>node: uni.Expr,
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
    has <>node: uni.Expr,
        expression: es.Expression;
}

"""Deconstructed spawn expression ready for runtime lowering."""
obj SpawnCallParts {
    has <>walker: SpawnWalkerInfo,
        target: SpawnTargetInfo;
}

"""Jac to ECMAScript AST transpilation pass."""
obj EsastGenPass(BaseAstGenPass[es.Statement]) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: (Any | None) = None) -> None;
    def before_pass -> None;
    def enter_node(<>node: uni.UniNode) -> None;
    def exit_node(<>node: uni.UniNode) -> None;
    def sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T;
    def _push_scope(<>node: uni.UniScopeNode) -> None;
    def _pop_scope(<>node: uni.UniScopeNode) -> None;
    def _current_scope -> (ScopeInfo | None);
    def _is_declared_in_current_scope(name: str) -> bool;
    def _is_declared_in_any_scope(name: str) -> bool;
    def _register_declaration(name: str) -> None;
    def _ensure_identifier_declared(name: str, jac_node: uni.UniNode) -> None;
    def _prepend_hoisted(
        <>node: uni.UniScopeNode, statements: list[es.Statement]
    ) -> list[es.Statement];

    def _strip_spawn_await(
        node_expr: uni.Expr, es_expr: es.Expression
    ) -> tuple[uni.Expr, es.Expression];

    def _resolve_expr_symbol(expr: uni.Expr) -> (uni.Symbol | None);
    def search_sym_in_main_mod(expr: uni.Expr) -> (uni.Symbol | None);
    def get_main_mod -> uni.Module;
    def _collect_walker_field_names(walker_symbol: (uni.Symbol | None)) -> list[str];
    def _expr_from_node(
        <>node: (uni.UniNode | None), <>default: LiteralValue = None
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
        <>node: uni.BinaryExpr, left_expr: es.Expression, right_expr: es.Expression
    ) -> (SpawnCallParts | None);

    def _build_spawn_runtime_call(
        <>node: uni.BinaryExpr, parts: SpawnCallParts
    ) -> es.AwaitExpression;

    def _collect_stmt_body(body: (Sequence[uni.UniNode] | None)) -> list[es.Statement];
    def _get_ast_or_default(
        <>node: (uni.UniNode | None),
        default_factory: Callable[([(uni.UniNode | None)], _T)]
    ) -> _T;

    def _build_block_statement(
        scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
    ) -> es.BlockStatement;

    def exit_module(<>node: uni.Module) -> None;
    def populate_client_manifest(<>node: uni.Module) -> None;
    def _populate_client_manifest(<>node: uni.Module) -> None;
    def exit_sub_tag(<>node: uni.SubTag[uni.T]) -> None;
    def exit_import(<>node: uni.Import) -> None;
    def exit_archetype(<>node: uni.Archetype) -> None;
    def exit_enum(<>node: uni.Enum) -> None;
    def enter_ability(<>node: uni.Ability) -> None;
    def exit_ability(<>node: uni.Ability) -> None;
    def exit_func_signature(<>node: uni.FuncSignature) -> None;
    def exit_param_var(<>node: uni.ParamVar) -> None;
    def exit_arch_has(<>node: uni.ArchHas) -> None;
    def exit_has_var(<>node: uni.HasVar) -> None;
    def _get_setter_name(var_name: str) -> str;
    def _inject_usestate_import(<>node: uni.UniNode) -> None;
    def _has_usestate_import -> bool;
    def exit_jsx_element(<>node: uni.JsxElement) -> None;
    def exit_jsx_element_name(<>node: uni.JsxElementName) -> None;
    def exit_jsx_spread_attribute(<>node: uni.JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(<>node: uni.JsxNormalAttribute) -> None;
    def exit_jsx_text(<>node: uni.JsxText) -> None;
    def exit_jsx_expression(<>node: uni.JsxExpression) -> None;
    def exit_if_stmt(<>node: uni.IfStmt) -> None;
    def exit_else_if(<>node: uni.ElseIf) -> None;
    def exit_else_stmt(<>node: uni.ElseStmt) -> None;
    def exit_while_stmt(<>node: uni.WhileStmt) -> None;
    def exit_iter_for_stmt(<>node: uni.IterForStmt) -> None;
    def exit_in_for_stmt(<>node: uni.InForStmt) -> None;
    def exit_try_stmt(<>node: uni.TryStmt) -> None;
    def exit_except(<>node: uni.Except) -> None;
    def exit_finally_stmt(<>node: uni.FinallyStmt) -> None;
    def exit_raise_stmt(<>node: uni.RaiseStmt) -> None;
    def exit_assert_stmt(<>node: uni.AssertStmt) -> None;
    def exit_return_stmt(<>node: uni.ReturnStmt) -> None;
    def exit_ctrl_stmt(<>node: uni.CtrlStmt) -> None;
    def exit_expr_stmt(<>node: uni.ExprStmt) -> None;
    def exit_switch_stmt(<>node: uni.SwitchStmt) -> None;
    def exit_switch_case(<>node: uni.SwitchCase) -> None;
    def exit_binary_expr(<>node: uni.BinaryExpr) -> None;
    def exit_bool_expr(<>node: uni.BoolExpr) -> None;
    def exit_compare_expr(<>node: uni.CompareExpr) -> None;
    def exit_unary_expr(<>node: uni.UnaryExpr) -> None;
    def _convert_assignment_target(
        target: uni.UniNode
    ) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)];

    def _collect_pattern_names(target: uni.UniNode) -> list[tuple[(str, uni.Name)]];
    def _is_name_first_definition(name_node: uni.Name) -> bool;
    def exit_assignment(<>node: uni.Assignment) -> None;
    def exit_func_call(<>node: uni.FuncCall) -> None;
    def exit_index_slice(<>node: uni.IndexSlice) -> None;
    def exit_special_var_ref(<>node: uni.SpecialVarRef) -> None;
    def exit_atom_trailer(<>node: uni.AtomTrailer) -> None;
    def exit_lambda_expr(<>node: uni.LambdaExpr) -> None;
    def exit_atom_unit(<>node: uni.AtomUnit) -> None;
    def exit_list_val(<>node: uni.ListVal) -> None;
    def exit_set_val(<>node: uni.SetVal) -> None;
    def exit_tuple_val(<>node: uni.TupleVal) -> None;
    def exit_dict_val(<>node: uni.DictVal) -> None;
    def exit_k_v_pair(<>node: uni.KVPair) -> None;
    def exit_inner_compr(<>node: uni.InnerCompr) -> None;
    def exit_bool(<>node: uni.Bool) -> None;
    def exit_int(<>node: uni.Int) -> None;
    def exit_float(<>node: uni.Float) -> None;
    def exit_multi_string(<>node: uni.MultiString) -> None;
    def exit_string(<>node: uni.String) -> None;
    def exit_formatted_value(<>node: uni.FormattedValue) -> None;
    def exit_f_string(<>node: uni.FString) -> None;
    def exit_if_else_expr(<>node: uni.IfElseExpr) -> None;
    def exit_await_expr(<>node: uni.AwaitExpr) -> None;
    def exit_null(<>node: uni.Null) -> None;
    def exit_name(<>node: uni.Name) -> None;
    def exit_global_vars(<>node: uni.GlobalVars) -> None;
    def exit_non_local_stmt(<>node: uni.NonLocalStmt) -> None;
    def exit_module_code(<>node: uni.ModuleCode) -> None;
    def exit_client_block(<>node: uni.ClientBlock) -> None;
    def exit_test(<>node: uni.Test) -> None;
    def exit_token(<>node: uni.Token) -> None;
    def exit_semi(<>node: uni.Semi) -> None;
    def _literal_value(expr: (uni.UniNode | None)) -> (object | None);
}
