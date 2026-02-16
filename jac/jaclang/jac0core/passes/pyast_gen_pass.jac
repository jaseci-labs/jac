"""Python AST Generation Pass for the Jac compiler.

This pass transforms the Jac AST into equivalent Python AST by:

1. Traversing the Jac AST and generating corresponding Python AST nodes
2. Handling all Jac language constructs and translating them to Python
equivalents:
   - Classes, functions, and methods
   - Control flow statements (if/else, loops, try/except)
   - Data structures (lists, dictionaries, sets)
   - Special Jac features (walkers, abilities, archetypes)
   - Data spatial operations (node/edge connections)

3. Managing imports and dependencies between modules
4. Preserving source location information for error reporting
5. Generating appropriate Python code for Jac-specific constructs

The output of this pass is a complete Python AST representation that can be
compiled to Python bytecode or serialized to Python source code.
"""
import ast as ast3;
import copy;
import textwrap;
import from collections.abc { Sequence }
import from dataclasses { dataclass }
import from typing { ClassVar, TypeVar, cast }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, EdgeDir }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.ast_gen { BaseAstGenPass }
import from jaclang.jac0core.passes.ast_gen.jsx_processor { PyJsxProcessor }
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

"""Jac blue transpilation to python pass."""
class PyastGenPass(BaseAstGenPass[ast3.AST]) {
    with entry {
        _builtin_names: ClassVar[(set[str] | None)] = None;
    }

    """Get the set of builtin names, cached after first successful access."""
    @classmethod
    def _get_builtin_names(cls: Any) -> set[str];

    def before_pass(self: PyastGenPass) -> None;
    """Enter node."""
    def enter_node(self: PyastGenPass, nd: uni.UniNode) -> None;

    """Exit node."""
    def exit_node(self: PyastGenPass, nd: uni.UniNode) -> None;

    """Generate Python stubs for native interop at the NativeBlock position.

        For native_exports (native functions called from Python):
          Generates a Python stub function that calls the native function via
ctypes.
        For native_imports (Python functions called from native):
          Generates a registration statement that stores the Python function
          in the interop callback table.
        """
    def _gen_native_interop_stubs(self: PyastGenPass, nd: uni.NativeBlock) -> None;

    """Return the object from jaclib as ast node based on the import config."""
    def jaclib_obj(self: PyastGenPass, obj_name: str) -> ast3.Name;

    """Return a builtin name and track it for importing.

        Note: Some names like 'Enum' are provided by other imports (e.g.,
needs_enum)
        and should not be added to builtin_imports.
        """
    def builtin_name(self: PyastGenPass, name: str) -> ast3.Name;

    """Append an import statement to the preamble once."""
    def _add_preamble_once(self: PyastGenPass, key: str, nd: ast3.AST) -> None;

    """Ensure typing is imported only once."""
    def needs_typing(self: PyastGenPass) -> None;

    """Ensure Enum utilities are imported only once."""
    def needs_enum(self: PyastGenPass) -> None;

    """Ensure concurrent Future is imported only once."""
    def needs_future(self: PyastGenPass) -> None;

    """Generate a deterministic temporary name for synthesized definitions."""
    def _next_temp_name(self: PyastGenPass, prefix: str) -> str;

    """Convert Jac identifiers to Python runtime identifiers."""
    def _py_name(self: PyastGenPass, nd: uni.AstSymbolNode) -> str;

    """Convert a synthesized function definition into an executable expression.

        Instead of using make_block_lambda at runtime, we hoist the function
        definition to be emitted before the current statement, then return
        a reference to the function name.
        """
    def _function_expr_from_def(
        self: PyastGenPass,
        func_def: (ast3.FunctionDef | ast3.AsyncFunctionDef),
        jac_node: uni.UniNode,
        filename_hint: str
    ) -> ast3.Name;

    """Create a semstring decorator for the given semantic strings.

        Example:
            @_.sem(
                "Returns the weather for a given city.", {
                    "city" : "Name of the city to get the weather for.",
                }
            )
            def get_weather(city: str);

        This the second parameter (dict) will also used in the class `has`
variables
        enum values etc.
        """
    def _get_sem_decorator(self: PyastGenPass, nd: uni.UniNode) -> (ast3.Call | None);

    """Sync ast locations."""
    def sync(
        self: PyastGenPass,
        py_node: T,
        jac_node: (uni.UniNode | None) = None,
        deep: bool = False
    ) -> T;

    """Sync ast locations."""
    def pyinline_sync(self: PyastGenPass, py_nodes: list[ast3.AST]) -> list[ast3.AST];

    """Resolve switch case pattern."""
    def resolve_switch_pattern(
        self: PyastGenPass, pattern: uni.MatchPattern, target: uni.Expr
    ) -> ast3.expr;

    """Resolve switch statement."""
    def resolve_switch_stmt(self: PyastGenPass, nd: uni.SwitchStmt) -> list[ast3.AST];

    """Unwind codeblock."""
    def resolve_stmt_block(
        self: PyastGenPass,
        nd: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
        doc: (uni.String | None) = None
    ) -> list[ast3.AST];

    """Sync ast locations."""
    def sync_many(
        self: PyastGenPass, py_nodes: list[T], jac_node: uni.UniNode
    ) -> list[T];

    """Convert list to attribute."""
    def list_to_attrib(
        self: PyastGenPass,
        attribute_list: list[str],
        sync_node_list: Sequence[uni.UniNode]
    ) -> ast3.AST;

    def exit_sub_tag(self: PyastGenPass, nd: uni.SubTag[uni.T]) -> None;
    def exit_module(self: PyastGenPass, nd: uni.Module) -> None;
    def exit_global_vars(self: PyastGenPass, nd: uni.GlobalVars) -> None;
    def exit_test(self: PyastGenPass, nd: uni.Test) -> None;
    def exit_module_code(self: PyastGenPass, nd: uni.ModuleCode) -> None;
    """Handle ClientBlock - already set to empty in enter_node."""
    def exit_client_block(self: PyastGenPass, nd: uni.ClientBlock) -> None;

    """Handle ServerBlock - unwrap its children to module level."""
    def exit_server_block(self: PyastGenPass, nd: uni.ServerBlock) -> None;

    """Handle NativeBlock - already pruned in enter_node."""
    def exit_native_block(self: PyastGenPass, nd: uni.NativeBlock) -> None;

    def exit_py_inline_code(self: PyastGenPass, nd: uni.PyInlineCode) -> None;
    """Exit import node."""
    def exit_import(self: PyastGenPass, nd: uni.Import) -> None;

    def exit_module_path(self: PyastGenPass, nd: uni.ModulePath) -> None;
    def exit_module_item(self: PyastGenPass, nd: uni.ModuleItem) -> None;
    def enter_archetype(self: PyastGenPass, nd: uni.Archetype) -> None;
    def exit_archetype(self: PyastGenPass, nd: uni.Archetype) -> None;
    def enter_enum(self: PyastGenPass, nd: uni.Enum) -> None;
    def exit_enum(self: PyastGenPass, nd: uni.Enum) -> None;
    def enter_ability(self: PyastGenPass, nd: uni.Ability) -> None;
    """Reusable method to codegen call_llm(model, caller, args)."""
    def _invoke_llm_call(
        self: PyastGenPass, model: ast3.expr, caller: ast3.expr, args: ast3.Dict
    ) -> ast3.Call;

    """Generate the by LLM body."""
    def gen_llm_body(self: PyastGenPass, nd: uni.Ability) -> list[ast3.stmt];

    def exit_ability(self: PyastGenPass, nd: uni.Ability) -> None;
    def exit_impl_def(self: PyastGenPass, nd: uni.ImplDef) -> None;
    def exit_sem_def(self: PyastGenPass, nd: uni.SemDef) -> None;
    def exit_func_signature(self: PyastGenPass, nd: uni.FuncSignature) -> None;
    def exit_event_signature(self: PyastGenPass, nd: uni.EventSignature) -> None;
    def exit_param_var(self: PyastGenPass, nd: uni.ParamVar) -> None;
    def exit_arch_has(self: PyastGenPass, nd: uni.ArchHas) -> None;
    def exit_has_var(self: PyastGenPass, nd: uni.HasVar) -> None;
    def exit_typed_ctx_block(self: PyastGenPass, nd: uni.TypedCtxBlock) -> None;
    def exit_if_stmt(self: PyastGenPass, nd: uni.IfStmt) -> None;
    def exit_else_if(self: PyastGenPass, nd: uni.ElseIf) -> None;
    def exit_else_stmt(self: PyastGenPass, nd: uni.ElseStmt) -> None;
    def exit_expr_stmt(self: PyastGenPass, nd: uni.ExprStmt) -> None;
    def exit_concurrent_expr(self: PyastGenPass, nd: uni.ConcurrentExpr) -> None;
    def exit_try_stmt(self: PyastGenPass, nd: uni.TryStmt) -> None;
    def exit_except(self: PyastGenPass, nd: uni.Except) -> None;
    def exit_finally_stmt(self: PyastGenPass, nd: uni.FinallyStmt) -> None;
    def exit_iter_for_stmt(self: PyastGenPass, nd: uni.IterForStmt) -> None;
    def exit_in_for_stmt(self: PyastGenPass, nd: uni.InForStmt) -> None;
    def exit_while_stmt(self: PyastGenPass, nd: uni.WhileStmt) -> None;
    def exit_with_stmt(self: PyastGenPass, nd: uni.WithStmt) -> None;
    def exit_expr_as_item(self: PyastGenPass, nd: uni.ExprAsItem) -> None;
    def exit_raise_stmt(self: PyastGenPass, nd: uni.RaiseStmt) -> None;
    def exit_assert_stmt(self: PyastGenPass, nd: uni.AssertStmt) -> None;
    """Sub objects.

        target: ExprType,
        """
    def assert_helper(self: PyastGenPass, nd: uni.AssertStmt) -> None;

    def exit_ctrl_stmt(self: PyastGenPass, nd: uni.CtrlStmt) -> None;
    def exit_delete_stmt(self: PyastGenPass, nd: uni.DeleteStmt) -> None;
    def exit_report_stmt(self: PyastGenPass, nd: uni.ReportStmt) -> None;
    def exit_return_stmt(self: PyastGenPass, nd: uni.ReturnStmt) -> None;
    def exit_yield_expr(self: PyastGenPass, nd: uni.YieldExpr) -> None;
    def exit_visit_stmt(self: PyastGenPass, nd: uni.VisitStmt) -> None;
    def exit_disengage_stmt(self: PyastGenPass, nd: uni.DisengageStmt) -> None;
    def exit_await_expr(self: PyastGenPass, nd: uni.AwaitExpr) -> None;
    def exit_global_stmt(self: PyastGenPass, nd: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(self: PyastGenPass, nd: uni.NonLocalStmt) -> None;
    def exit_assignment(self: PyastGenPass, nd: uni.Assignment) -> None;
    def exit_binary_expr(self: PyastGenPass, nd: uni.BinaryExpr) -> None;
    def translate_jac_bin_op(self: PyastGenPass, nd: uni.BinaryExpr) -> list[ast3.AST];
    def exit_compare_expr(self: PyastGenPass, nd: uni.CompareExpr) -> None;
    def exit_bool_expr(self: PyastGenPass, nd: uni.BoolExpr) -> None;
    def exit_lambda_expr(self: PyastGenPass, nd: uni.LambdaExpr) -> None;
    def _remove_lambda_param_annotations(
        self: PyastGenPass, signature: uni.FuncSignature
    ) -> None;

    def exit_unary_expr(self: PyastGenPass, nd: uni.UnaryExpr) -> None;
    def exit_if_else_expr(self: PyastGenPass, nd: uni.IfElseExpr) -> None;
    def exit_multi_string(self: PyastGenPass, nd: uni.MultiString) -> None;
    def exit_f_string(self: PyastGenPass, nd: uni.FString) -> None;
    def exit_formatted_value(self: PyastGenPass, nd: uni.FormattedValue) -> None;
    def exit_list_val(self: PyastGenPass, nd: uni.ListVal) -> None;
    def exit_set_val(self: PyastGenPass, nd: uni.SetVal) -> None;
    def exit_tuple_val(self: PyastGenPass, nd: uni.TupleVal) -> None;
    def exit_dict_val(self: PyastGenPass, nd: uni.DictVal) -> None;
    def exit_k_v_pair(self: PyastGenPass, nd: uni.KVPair) -> None;
    def exit_k_w_pair(self: PyastGenPass, nd: uni.KWPair) -> None;
    def exit_inner_compr(self: PyastGenPass, nd: uni.InnerCompr) -> None;
    def exit_list_compr(self: PyastGenPass, nd: uni.ListCompr) -> None;
    def exit_gen_compr(self: PyastGenPass, nd: uni.GenCompr) -> None;
    def exit_set_compr(self: PyastGenPass, nd: uni.SetCompr) -> None;
    def exit_dict_compr(self: PyastGenPass, nd: uni.DictCompr) -> None;
    def exit_atom_trailer(self: PyastGenPass, nd: uni.AtomTrailer) -> None;
    def exit_atom_unit(self: PyastGenPass, nd: uni.AtomUnit) -> None;
    """Generate the arguments for a function call."""
    def gen_call_args(
        self: PyastGenPass, nd: uni.FuncCall
    ) -> tuple[(list[ast3.expr], list[ast3.keyword])];

    def exit_func_call(self: PyastGenPass, nd: uni.FuncCall) -> None;
    def exit_index_slice(self: PyastGenPass, nd: uni.IndexSlice) -> None;
    def exit_special_var_ref(self: PyastGenPass, nd: uni.SpecialVarRef) -> None;
    def exit_edge_ref_trailer(self: PyastGenPass, nd: uni.EdgeRefTrailer) -> None;
    def exit_edge_op_ref(self: PyastGenPass, nd: uni.EdgeOpRef) -> None;
    def exit_disconnect_op(self: PyastGenPass, nd: uni.DisconnectOp) -> None;
    def exit_connect_op(self: PyastGenPass, nd: uni.ConnectOp) -> None;
    def exit_filter_compr(self: PyastGenPass, nd: uni.FilterCompr) -> None;
    def exit_assign_compr(self: PyastGenPass, nd: uni.AssignCompr) -> None;
    def exit_match_stmt(self: PyastGenPass, nd: uni.MatchStmt) -> None;
    def exit_match_case(self: PyastGenPass, nd: uni.MatchCase) -> None;
    def exit_match_or(self: PyastGenPass, nd: uni.MatchOr) -> None;
    def exit_match_as(self: PyastGenPass, nd: uni.MatchAs) -> None;
    def exit_match_wild(self: PyastGenPass, nd: uni.MatchWild) -> None;
    def exit_match_value(self: PyastGenPass, nd: uni.MatchValue) -> None;
    def exit_match_singleton(self: PyastGenPass, nd: uni.MatchSingleton) -> None;
    def exit_match_sequence(self: PyastGenPass, nd: uni.MatchSequence) -> None;
    def exit_match_mapping(self: PyastGenPass, nd: uni.MatchMapping) -> None;
    def exit_match_k_v_pair(self: PyastGenPass, nd: uni.MatchKVPair) -> None;
    def exit_match_star(self: PyastGenPass, nd: uni.MatchStar) -> None;
    def exit_match_arch(self: PyastGenPass, nd: uni.MatchArch) -> None;
    def exit_token(self: PyastGenPass, nd: uni.Token) -> None;
    def exit_name(self: PyastGenPass, nd: uni.Name) -> None;
    def exit_float(self: PyastGenPass, nd: uni.Float) -> None;
    def exit_int(self: PyastGenPass, nd: uni.Int) -> None;
    def exit_string(self: PyastGenPass, nd: uni.String) -> None;
    def exit_bool(self: PyastGenPass, nd: uni.Bool) -> None;
    def exit_builtin_type(self: PyastGenPass, nd: uni.BuiltinType) -> None;
    def exit_null(self: PyastGenPass, nd: uni.Null) -> None;
    def exit_ellipsis(self: PyastGenPass, nd: uni.Ellipsis) -> None;
    """Generate Python AST for JSX elements."""
    def exit_jsx_element(self: PyastGenPass, nd: uni.JsxElement) -> None;

    """Generate Python AST for JSX element names."""
    def exit_jsx_element_name(self: PyastGenPass, nd: uni.JsxElementName) -> None;

    """Bases class for JSX attributes - handled by subclasses."""
    def exit_jsx_attribute(self: PyastGenPass, nd: uni.JsxAttribute) -> None;

    """Generate Python AST for JSX spread attributes."""
    def exit_jsx_spread_attribute(
        self: PyastGenPass, nd: uni.JsxSpreadAttribute
    ) -> None;

    """Generate Python AST for JSX normal attributes."""
    def exit_jsx_normal_attribute(
        self: PyastGenPass, nd: uni.JsxNormalAttribute
    ) -> None;

    """Bases class for JSX children - handled by subclasses."""
    def exit_jsx_child(self: PyastGenPass, nd: uni.JsxChild) -> None;

    """Generate Python AST for JSX text nodes."""
    def exit_jsx_text(self: PyastGenPass, nd: uni.JsxText) -> None;

    """Generate Python AST for JSX expression children."""
    def exit_jsx_expression(self: PyastGenPass, nd: uni.JsxExpression) -> None;

    def exit_semi(self: PyastGenPass, nd: uni.Semi) -> None;
    def exit_comment_token(self: PyastGenPass, nd: uni.CommentToken) -> None;
}
