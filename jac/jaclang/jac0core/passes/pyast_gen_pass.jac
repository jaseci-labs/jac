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
    def enter_node(self: PyastGenPass, `node: uni.UniNode) -> None;

    """Exit node."""
    def exit_node(self: PyastGenPass, `node: uni.UniNode) -> None;

    """Generate Python stubs for native interop at the NativeBlock position.

        For native_exports (native functions called from Python):
          Generates a Python stub function that calls the native function via
ctypes.
        For native_imports (Python functions called from native):
          Generates a registration statement that stores the Python function
          in the interop callback table.
        """
    def _gen_native_interop_stubs(self: PyastGenPass, `node: uni.NativeBlock) -> None;

    """Return the object from jaclib as ast node based on the import config."""
    def jaclib_obj(self: PyastGenPass, obj_name: str) -> ast3.Name;

    """Return a builtin name and track it for importing.

        Note: Some names like 'Enum' are provided by other imports (e.g.,
needs_enum)
        and should not be added to builtin_imports.
        """
    def builtin_name(self: PyastGenPass, name: str) -> ast3.Name;

    """Append an import statement to the preamble once."""
    def _add_preamble_once(self: PyastGenPass, key: str, `node: ast3.AST) -> None;

    """Ensure typing is imported only once."""
    def needs_typing(self: PyastGenPass) -> None;

    """Ensure Enum utilities are imported only once."""
    def needs_enum(self: PyastGenPass) -> None;

    """Ensure concurrent Future is imported only once."""
    def needs_future(self: PyastGenPass) -> None;

    """Generate a deterministic temporary name for synthesized definitions."""
    def _next_temp_name(self: PyastGenPass, prefix: str) -> str;

    """Convert Jac identifiers to Python runtime identifiers."""
    def _py_name(self: PyastGenPass, `node: uni.AstSymbolNode) -> str;

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
    def _get_sem_decorator(
        self: PyastGenPass, `node: uni.UniNode
    ) -> (ast3.Call | None);

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
    def resolve_switch_stmt(
        self: PyastGenPass, `node: uni.SwitchStmt
    ) -> list[ast3.AST];

    """Unwind codeblock."""
    def resolve_stmt_block(
        self: PyastGenPass,
        `node: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
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

    def exit_sub_tag(self: PyastGenPass, `node: uni.SubTag[uni.T]) -> None;
    def exit_module(self: PyastGenPass, `node: uni.Module) -> None;
    def exit_global_vars(self: PyastGenPass, `node: uni.GlobalVars) -> None;
    def exit_test(self: PyastGenPass, `node: uni.Test) -> None;
    def exit_module_code(self: PyastGenPass, `node: uni.ModuleCode) -> None;
    """Handle ClientBlock - already set to empty in enter_node."""
    def exit_client_block(self: PyastGenPass, `node: uni.ClientBlock) -> None;

    """Handle ServerBlock - unwrap its children to module level."""
    def exit_server_block(self: PyastGenPass, `node: uni.ServerBlock) -> None;

    """Handle NativeBlock - already pruned in enter_node."""
    def exit_native_block(self: PyastGenPass, `node: uni.NativeBlock) -> None;

    def exit_py_inline_code(self: PyastGenPass, `node: uni.PyInlineCode) -> None;
    """Exit import node."""
    def exit_import(self: PyastGenPass, `node: uni.Import) -> None;

    def exit_module_path(self: PyastGenPass, `node: uni.ModulePath) -> None;
    def exit_module_item(self: PyastGenPass, `node: uni.ModuleItem) -> None;
    def enter_archetype(self: PyastGenPass, `node: uni.Archetype) -> None;
    def exit_archetype(self: PyastGenPass, `node: uni.Archetype) -> None;
    def enter_enum(self: PyastGenPass, `node: uni.Enum) -> None;
    def exit_enum(self: PyastGenPass, `node: uni.Enum) -> None;
    def enter_ability(self: PyastGenPass, `node: uni.Ability) -> None;
    """Reusable method to codegen call_llm(model, caller, args)."""
    def _invoke_llm_call(
        self: PyastGenPass, model: ast3.expr, caller: ast3.expr, args: ast3.Dict
    ) -> ast3.Call;

    """Generate the by LLM body."""
    def gen_llm_body(self: PyastGenPass, `node: uni.Ability) -> list[ast3.stmt];

    def exit_ability(self: PyastGenPass, `node: uni.Ability) -> None;
    def exit_impl_def(self: PyastGenPass, `node: uni.ImplDef) -> None;
    def exit_sem_def(self: PyastGenPass, `node: uni.SemDef) -> None;
    def exit_func_signature(self: PyastGenPass, `node: uni.FuncSignature) -> None;
    def exit_event_signature(self: PyastGenPass, `node: uni.EventSignature) -> None;
    def exit_param_var(self: PyastGenPass, `node: uni.ParamVar) -> None;
    def exit_arch_has(self: PyastGenPass, `node: uni.ArchHas) -> None;
    def exit_has_var(self: PyastGenPass, `node: uni.HasVar) -> None;
    def exit_typed_ctx_block(self: PyastGenPass, `node: uni.TypedCtxBlock) -> None;
    def exit_if_stmt(self: PyastGenPass, `node: uni.IfStmt) -> None;
    def exit_else_if(self: PyastGenPass, `node: uni.ElseIf) -> None;
    def exit_else_stmt(self: PyastGenPass, `node: uni.ElseStmt) -> None;
    def exit_expr_stmt(self: PyastGenPass, `node: uni.ExprStmt) -> None;
    def exit_concurrent_expr(self: PyastGenPass, `node: uni.ConcurrentExpr) -> None;
    def exit_try_stmt(self: PyastGenPass, `node: uni.TryStmt) -> None;
    def exit_except(self: PyastGenPass, `node: uni.Except) -> None;
    def exit_finally_stmt(self: PyastGenPass, `node: uni.FinallyStmt) -> None;
    def exit_iter_for_stmt(self: PyastGenPass, `node: uni.IterForStmt) -> None;
    def exit_in_for_stmt(self: PyastGenPass, `node: uni.InForStmt) -> None;
    def exit_while_stmt(self: PyastGenPass, `node: uni.WhileStmt) -> None;
    def exit_with_stmt(self: PyastGenPass, `node: uni.WithStmt) -> None;
    def exit_expr_as_item(self: PyastGenPass, `node: uni.ExprAsItem) -> None;
    def exit_raise_stmt(self: PyastGenPass, `node: uni.RaiseStmt) -> None;
    def exit_assert_stmt(self: PyastGenPass, `node: uni.AssertStmt) -> None;
    """Sub objects.

        target: ExprType,
        """
    def assert_helper(self: PyastGenPass, `node: uni.AssertStmt) -> None;

    def exit_ctrl_stmt(self: PyastGenPass, `node: uni.CtrlStmt) -> None;
    def exit_delete_stmt(self: PyastGenPass, `node: uni.DeleteStmt) -> None;
    def exit_report_stmt(self: PyastGenPass, `node: uni.ReportStmt) -> None;
    def exit_return_stmt(self: PyastGenPass, `node: uni.ReturnStmt) -> None;
    def exit_yield_expr(self: PyastGenPass, `node: uni.YieldExpr) -> None;
    def exit_visit_stmt(self: PyastGenPass, `node: uni.VisitStmt) -> None;
    def exit_disengage_stmt(self: PyastGenPass, `node: uni.DisengageStmt) -> None;
    def exit_await_expr(self: PyastGenPass, `node: uni.AwaitExpr) -> None;
    def exit_global_stmt(self: PyastGenPass, `node: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(self: PyastGenPass, `node: uni.NonLocalStmt) -> None;
    def exit_assignment(self: PyastGenPass, `node: uni.Assignment) -> None;
    def exit_binary_expr(self: PyastGenPass, `node: uni.BinaryExpr) -> None;
    def translate_jac_bin_op(
        self: PyastGenPass, `node: uni.BinaryExpr
    ) -> list[ast3.AST];

    def exit_compare_expr(self: PyastGenPass, `node: uni.CompareExpr) -> None;
    def exit_bool_expr(self: PyastGenPass, `node: uni.BoolExpr) -> None;
    def exit_lambda_expr(self: PyastGenPass, `node: uni.LambdaExpr) -> None;
    def _remove_lambda_param_annotations(
        self: PyastGenPass, signature: uni.FuncSignature
    ) -> None;

    def exit_unary_expr(self: PyastGenPass, `node: uni.UnaryExpr) -> None;
    def exit_if_else_expr(self: PyastGenPass, `node: uni.IfElseExpr) -> None;
    def exit_multi_string(self: PyastGenPass, `node: uni.MultiString) -> None;
    def exit_f_string(self: PyastGenPass, `node: uni.FString) -> None;
    def exit_formatted_value(self: PyastGenPass, `node: uni.FormattedValue) -> None;
    def exit_list_val(self: PyastGenPass, `node: uni.ListVal) -> None;
    def exit_set_val(self: PyastGenPass, `node: uni.SetVal) -> None;
    def exit_tuple_val(self: PyastGenPass, `node: uni.TupleVal) -> None;
    def exit_dict_val(self: PyastGenPass, `node: uni.DictVal) -> None;
    def exit_k_v_pair(self: PyastGenPass, `node: uni.KVPair) -> None;
    def exit_k_w_pair(self: PyastGenPass, `node: uni.KWPair) -> None;
    def exit_inner_compr(self: PyastGenPass, `node: uni.InnerCompr) -> None;
    def exit_list_compr(self: PyastGenPass, `node: uni.ListCompr) -> None;
    def exit_gen_compr(self: PyastGenPass, `node: uni.GenCompr) -> None;
    def exit_set_compr(self: PyastGenPass, `node: uni.SetCompr) -> None;
    def exit_dict_compr(self: PyastGenPass, `node: uni.DictCompr) -> None;
    def exit_atom_trailer(self: PyastGenPass, `node: uni.AtomTrailer) -> None;
    def exit_atom_unit(self: PyastGenPass, `node: uni.AtomUnit) -> None;
    """Generate the arguments for a function call."""
    def gen_call_args(
        self: PyastGenPass, `node: uni.FuncCall
    ) -> tuple[(list[ast3.expr], list[ast3.keyword])];

    def exit_func_call(self: PyastGenPass, `node: uni.FuncCall) -> None;
    def exit_index_slice(self: PyastGenPass, `node: uni.IndexSlice) -> None;
    def exit_special_var_ref(self: PyastGenPass, `node: uni.SpecialVarRef) -> None;
    def exit_edge_ref_trailer(self: PyastGenPass, `node: uni.EdgeRefTrailer) -> None;
    def exit_edge_op_ref(self: PyastGenPass, `node: uni.EdgeOpRef) -> None;
    def exit_disconnect_op(self: PyastGenPass, `node: uni.DisconnectOp) -> None;
    def exit_connect_op(self: PyastGenPass, `node: uni.ConnectOp) -> None;
    def exit_filter_compr(self: PyastGenPass, `node: uni.FilterCompr) -> None;
    def exit_assign_compr(self: PyastGenPass, `node: uni.AssignCompr) -> None;
    def exit_match_stmt(self: PyastGenPass, `node: uni.MatchStmt) -> None;
    def exit_match_case(self: PyastGenPass, `node: uni.MatchCase) -> None;
    def exit_match_or(self: PyastGenPass, `node: uni.MatchOr) -> None;
    def exit_match_as(self: PyastGenPass, `node: uni.MatchAs) -> None;
    def exit_match_wild(self: PyastGenPass, `node: uni.MatchWild) -> None;
    def exit_match_value(self: PyastGenPass, `node: uni.MatchValue) -> None;
    def exit_match_singleton(self: PyastGenPass, `node: uni.MatchSingleton) -> None;
    def exit_match_sequence(self: PyastGenPass, `node: uni.MatchSequence) -> None;
    def exit_match_mapping(self: PyastGenPass, `node: uni.MatchMapping) -> None;
    def exit_match_k_v_pair(self: PyastGenPass, `node: uni.MatchKVPair) -> None;
    def exit_match_star(self: PyastGenPass, `node: uni.MatchStar) -> None;
    def exit_match_arch(self: PyastGenPass, `node: uni.MatchArch) -> None;
    def exit_token(self: PyastGenPass, `node: uni.Token) -> None;
    def exit_name(self: PyastGenPass, `node: uni.Name) -> None;
    def exit_float(self: PyastGenPass, `node: uni.Float) -> None;
    def exit_int(self: PyastGenPass, `node: uni.Int) -> None;
    def exit_string(self: PyastGenPass, `node: uni.String) -> None;
    def exit_bool(self: PyastGenPass, `node: uni.Bool) -> None;
    def exit_builtin_type(self: PyastGenPass, `node: uni.BuiltinType) -> None;
    def exit_null(self: PyastGenPass, `node: uni.Null) -> None;
    def exit_ellipsis(self: PyastGenPass, `node: uni.Ellipsis) -> None;
    """Generate Python AST for JSX elements."""
    def exit_jsx_element(self: PyastGenPass, `node: uni.JsxElement) -> None;

    """Generate Python AST for JSX element names."""
    def exit_jsx_element_name(self: PyastGenPass, `node: uni.JsxElementName) -> None;

    """Bases class for JSX attributes - handled by subclasses."""
    def exit_jsx_attribute(self: PyastGenPass, `node: uni.JsxAttribute) -> None;

    """Generate Python AST for JSX spread attributes."""
    def exit_jsx_spread_attribute(
        self: PyastGenPass, `node: uni.JsxSpreadAttribute
    ) -> None;

    """Generate Python AST for JSX normal attributes."""
    def exit_jsx_normal_attribute(
        self: PyastGenPass, `node: uni.JsxNormalAttribute
    ) -> None;

    """Bases class for JSX children - handled by subclasses."""
    def exit_jsx_child(self: PyastGenPass, `node: uni.JsxChild) -> None;

    """Generate Python AST for JSX text nodes."""
    def exit_jsx_text(self: PyastGenPass, `node: uni.JsxText) -> None;

    """Generate Python AST for JSX expression children."""
    def exit_jsx_expression(self: PyastGenPass, `node: uni.JsxExpression) -> None;

    def exit_semi(self: PyastGenPass, `node: uni.Semi) -> None;
    def exit_comment_token(self: PyastGenPass, `node: uni.CommentToken) -> None;
}
