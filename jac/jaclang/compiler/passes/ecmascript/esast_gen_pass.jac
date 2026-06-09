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
   - Object spatial operations converted to appropriate JS patterns

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
import from jaclang.jac0core.codeinfo { ClientManifest }
import from jaclang.compiler.passes.ecmascript.scoped_styles {
    ScopedStyleSheet,
    load_style_annex
}
import from jaclang.jac0core.modresolver {
    convert_to_js_import_path,
    resolve_relative_path
}
import from jaclang.jac0core.diagnostics {
    E2025,
    E5010,
    E5011,
    E5012,
    E5016,
    W5013,
    W5014,
    W5015,
    E5080
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

"""Name of the synthesized children accumulator local for a JSX `{...}`
slot. The outermost slot in a given scope uses this name; nested slot
scopes (a `try`/`awaiting`/`except` arm's own accumulator) get a unique
`__jac_view_kids_N` suffix so hoisted `let` bindings never collide."""
glob VIEW_ACC: str = "__jac_view_kids";

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
        pattern_names: list[tuple[(str, uni.Name)]];
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

"""Resolved function-call argument slot."""
obj CallArgSlot {
    has name: (str | None),
        value: (es.Expression | es.SpreadElement | None);
}

"""Jac to ECMAScript AST transpilation pass."""
obj EsastGenPass(BaseAstGenPass[es.Statement]) {
    has child_passes: list[EsastGenPass] = [],
        imports: list[es.ImportDeclaration] = [],
        exports: list[es.ExportNamedDeclaration] = [],
        scope_stack: list[ScopeInfo] = [],
        scope_map: dict[(uni.UniScopeNode, ScopeInfo)] = {},
        client_manifest: (ClientManifest | None) = None,
        jsx_processor: (EsJsxProcessor | None) = None,
        scoped_styles: (ScopedStyleSheet | None) = None,
        # Reactive state variables: var_name -> setter_name (e.g., "count" -> "setCount")
        reactive_vars: dict[str, str] = {},
        # Stack to save/restore reactive_vars per function boundary
        reactive_vars_stack: list[dict[str, str]] = [],
        # Runtime imports auto-injected by the codegen; tracked to avoid duplicates
        injected_imports: set[str] = set(),
        # JSX `{...}` slot view-lowering state. Holds the accumulator name of each
        # enclosing slot scope (a `str`), or `None` for a nested-`def` barrier that
        # suspends lowering. The topmost `str` is the accumulator a JSX statement
        # pushes into; a `None` on top means we are inside a nested function and
        # JSX should NOT be accumulated. The counter gives nested slot scopes
        # (try/awaiting/except arms) unique local names.
        _view_stack: list[(str | None)] = [],
        # The first slot keeps the bare `__jac_view_kids` name; every later slot
        # (sibling or nested) draws a unique `__jac_view_kids_N` suffix.
        _view_used_base: bool = False,
        _view_acc_counter: int = 0,
        # TryStmt nodes (by id) being lowered into a `<JacAwaiting>` wrapper, so
        # the clause handlers know to scope their own accumulators.
        _view_awaiting_tries: set[int] = set(),
        # JS function stubs for def:pub functions imported via sv import
        sv_import_stubs: list[es.Statement] = [],
        # True iff the primitive emitter produced `_jac.*` calls and the runtime needs importing
        needs_jac_runtime: bool = False,
        # OSP local-kernel lowering: set when a local walker is spawned via the
        # portable kernel (not `__jacSpawn` RPC). Triggers kernel + descriptor
        # injection in exit_module. `_osp_slots` collects one record per OSP
        # ability: {owner, kind, name, trigger_names (list, empty = untyped),
        # is_entry}. `_osp_arch_names` is the set of local node/edge/walker
        # archetypes that need a compile-time type tag.
        needs_osp_kernel: bool = False,
        # Set when a connect op / edge ref is lowered: pulls in the cl OSP graph
        # runtime (`__ospConn` / `__ospRefs`).
        needs_osp_graph: bool = False,
        _osp_slots: list[dict] = [],
        _osp_arch_names: list[str] = [],
        # Memoized {archetype name -> kind} for every local walker/node/edge in a
        # module that has local OSP (any event ability). Includes edge types with
        # no abilities (e.g. used only in connects/refs) so they still get a type
        # tag + field constructor. Computed up front so emission order doesn't
        # matter; empty for non-OSP modules.
        _osp_prescan: (dict | None) = None,
        # Memoized {variable name -> local archetype name} for `x = Arch(...)`
        # bindings, so a spawn whose walker is held in a variable (`w spawn n`)
        # can identify the walker side without type inference.
        _osp_var_arch_cache: (dict | None) = None,
        # Memoized {archetype name -> direct local base archetype names}, for the
        # subtype `is_a` table (a `with Base entry` ability firing on a `Sub`).
        _osp_bases_cache: (dict | None) = None,
        # Primitive emitter instances for codegen dispatch (lazily initialized to avoid circular imports)
        _primitive_emitters: (dict[str, object] | None) = None,
        _builtin_emitter: (object | None) = None,
        _primitives_es_mod: (object | None) = None,
        # Set of Python method names that any primitive emitter knows how to
        # emit (derived from the emitter registry, never hand-maintained). A
        # method call on a receiver whose static type is not provably a
        # primitive is routed through `_jac.poly.call(obj, "name", ...)` iff its
        # name is in this set; otherwise it is a user-defined method and emits a
        # plain member call. Lazily computed alongside the emitter singletons.
        _poly_methods: (set[str] | None) = None;

    def before_pass -> None;
    def enter_node(nd: uni.UniNode) -> None;
    def exit_node(nd: uni.UniNode) -> None;
    def sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T;
    def _push_scope(nd: uni.UniScopeNode) -> None;
    def _pop_scope(nd: uni.UniScopeNode) -> None;
    def _alt_branch_scope_to_finalize(nd: uni.UniNode) -> (uni.UniScopeNode | None);
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

    def search_sym_in_main_mod(expr: uni.Expr) -> (uni.Symbol | None);
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

    def _build_spawn_runtime_call(
        nd: uni.BinaryExpr, parts: SpawnCallParts
    ) -> es.AwaitExpression;

    def _osp_ability_info(nd: uni.Ability) -> (dict | None);
    def _osp_trigger_names(expr: (uni.Expr | None)) -> list[str];
    def _osp_const_decl(
        name: str, `init: es.Expression, nd: uni.UniNode
    ) -> es.VariableDeclaration;

    def _emit_osp_slot_method(nd: uni.Ability, osp: dict) -> None;
    def _build_osp_setup_js -> str;
    def _osp_slots_js(slots: list, tags: dict) -> str;
    def _local_walker_names -> set[str];
    def _osp_arch_kinds -> dict[str, str];
    def _osp_arch_set -> set[str];
    def _osp_var_arch -> dict[str, str];
    def _osp_arch_bases -> dict[str, list[str]];
    def _spawn_walker_arch(expr: uni.Expr) -> (str | None);
    def _spawn_target_is_local_node(expr: uni.Expr) -> bool;
    def _build_osp_graph_call(
        nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
    ) -> (es.Expression | None);

    def _build_edge_ref(nd: uni.EdgeRefTrailer) -> (es.Expression | None);
    def _build_local_osp_spawn(
        nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
    ) -> (es.Expression | None);

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
    def _record_sv_backend(nd: uni.Import) -> None;
    def _emit_boundary_type_stubs(nd: uni.Module) -> list;
    def exit_type_alias(nd: uni.TypeAlias) -> None;
    def exit_type_param(nd: uni.TypeParam) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def exit_enum(nd: uni.Enum) -> None;
    def enter_ability(nd: uni.Ability) -> None;
    def exit_ability(nd: uni.Ability) -> None;
    def exit_visit_stmt(nd: uni.VisitStmt) -> None;
    def exit_disengage_stmt(nd: uni.DisengageStmt) -> None;
    def exit_report_stmt(nd: uni.ReportStmt) -> None;
    def exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None;
    def exit_func_signature(nd: uni.FuncSignature) -> None;
    def exit_param_var(nd: uni.ParamVar) -> None;
    def exit_arch_has(nd: uni.ArchHas) -> None;
    def exit_has_var(nd: uni.HasVar) -> None;
    def _get_setter_name(var_name: str) -> str;
    def _has_import(name: str) -> bool;
    def _inject_runtime_import(name: str, nd: uni.UniNode) -> None;
    def _ref_head_name(expr: (uni.UniNode | None)) -> (str | None);
    def _ref_forward_param(nd: uni.Ability) -> (uni.ParamVar | None);
    def _register_jac_runtime_import -> None;
    def _transform_to_useeffect(nd: uni.Ability) -> None;
    def exit_jsx_element(nd: uni.JsxElement) -> None;
    def exit_jsx_element_name(nd: uni.JsxElementName) -> None;
    def exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None;
    def exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None;
    def exit_jsx_text(nd: uni.JsxText) -> None;
    def exit_jsx_expression(nd: uni.JsxExpression) -> None;
    def enter_jsx_slot(nd: uni.JsxSlot) -> None;
    def exit_jsx_slot(nd: uni.JsxSlot) -> None;
    def exit_jsx_comment(nd: uni.JsxComment) -> None;
    def enter_try_stmt(nd: uni.TryStmt) -> None;
    def enter_except(nd: uni.Except) -> None;
    def enter_awaiting_clause(nd: uni.AwaitingClause) -> None;
    def exit_awaiting_clause(nd: uni.AwaitingClause) -> None;
    # ----- JSX `{...}` slot view-lowering (direct es_ast) ------------------
    """Name of the slot accumulator currently in scope, or None when not
    directly inside a slot body (e.g. inside a nested `def` barrier)."""
    def _cur_view_acc -> (str | None);

    """Push a fresh slot-accumulator scope and return its local name."""
    def _push_view_acc -> str;

    """Build `acc.push(<value>);` — accumulate one template element."""
    def _view_push_stmt(
        acc_name: str, value: es.Expression, anchor: uni.UniNode
    ) -> es.ExpressionStatement;

    """Build `<>{children...}</>` as a `__jacJsx(null, {}, [children])` call."""
    def _jsx_fragment(
        children: list[es.Expression], anchor: uni.UniNode
    ) -> es.CallExpression;

    """Build `return <>{acc}</>;` — the fragment of all content so far."""
    def _view_fragment_return(
        acc_name: str, anchor: uni.UniNode
    ) -> es.ReturnStatement;

    """Wrap a lowered slot body in an inline accumulator IIFE expression."""
    def _build_view_iife(
        body_nodes: (Sequence[uni.UniNode] | None), acc_name: str, anchor: uni.UniNode
    ) -> es.CallExpression;

    """Assemble the `<JacAwaiting>`/`<JacClientErrorBoundary>` wrapper for a
    slot `try { ... } awaiting { ... } except { ... }` on the cl target."""
    def _build_awaiting_wrapper(nd: uni.TryStmt, try_acc: str) -> None;

    def exit_if_stmt(nd: uni.IfStmt) -> None;
    def exit_else_if(nd: uni.ElseIf) -> None;
    def exit_else_stmt(nd: uni.ElseStmt) -> None;
    def exit_while_stmt(nd: uni.WhileStmt) -> None;
    def exit_iter_for_stmt(nd: uni.IterForStmt) -> None;
    def exit_in_for_stmt(nd: uni.InForStmt) -> None;
    def _target_to_pattern(target: es.Node, loc: uni.UniNode) -> es.Node;
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
    def _build_jac_ref(path: list[str], jac_node: uni.UniNode) -> es.Expression;
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

    def exit_binary_expr(nd: uni.BinaryExpr) -> None;
    def exit_cfg_expr(nd: uni.CfgExpr) -> None;
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_compare_expr(nd: uni.CompareExpr) -> None;
    def exit_unary_expr(nd: uni.UnaryExpr) -> None;
    def _convert_assignment_target(
        target: uni.UniNode
    ) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)];

    def _collect_pattern_names(target: uni.UniNode) -> list[tuple[(str, uni.Name)]];
    def exit_assignment(nd: uni.Assignment) -> None;
    def _resolve_source_module(nd: uni.Import) -> (uni.Module | None);
    def _ability_from_symbol(sym: (uni.Symbol | None)) -> (uni.Ability | None);
    def _resolve_call_ability(nd: uni.FuncCall) -> (uni.Ability | None);
    def _param_names_from_ability(ability_node: uni.Ability) -> list[str];
    def _param_type_map_from_ability(ability_node: uni.Ability) -> dict[(str, str)];
    def _wrap_to_wire_if_boundary(
        expr: es.Expression,
        type_name: str,
        boundary_types: dict[(str, Any)],
        jac_node: uni.UniNode
    ) -> es.Expression;

    def _extract_return_type(
        ability_node: uni.Ability, func_name: str, manifest: any
    ) -> str;

    def _wrap_return_with_boundary(
        call_expr: es.Expression,
        ret_type: str,
        boundary_types: dict[(str, Any)],
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
    def _str_literal(nd: uni.String) -> es.Literal;
    def exit_formatted_value(nd: uni.FormattedValue) -> None;
    def exit_f_string(nd: uni.FString) -> None;
    def exit_if_else_expr(nd: uni.IfElseExpr) -> None;
    def exit_await_expr(nd: uni.AwaitExpr) -> None;
    def exit_cast_expr(nd: uni.CastExpr) -> None;
    def exit_null(nd: uni.Null) -> None;
    def exit_name(nd: uni.Name) -> None;
    def exit_builtin_type(nd: uni.BuiltinType) -> None;
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
