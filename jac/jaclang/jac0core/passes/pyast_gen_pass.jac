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
    E5008,
    W0062
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

"""Jac blue transpilation to python pass."""
obj PyastGenPass(BaseAstGenPass[ast3.AST]) {
    has debuginfo: dict[str, list[str]] by postinit,
        already_added: list[str] = [],
        jaclib_imports: set[str] by postinit,
        builtin_imports: set[str] by postinit,
        _temp_name_counter: int = 0,
        _hoisted_funcs: list[ast3.FunctionDef | ast3.AsyncFunctionDef] = [],
        child_passes: list[PyastGenPass] by postinit,
        preamble: list[ast3.AST] by postinit,
        jsx_processor: PyJsxProcessor by postinit;

    with entry {
        _builtin_names: ClassVar[(set[str] | None)] = None;
    }

    """Get the set of builtin names, cached after first successful access."""
    @classmethod
    def _get_builtin_names(cls: Any) -> set[str];

    def postinit -> None;
    """Enter node."""
    def enter_node(nd: uni.UniNode) -> None;

    """Exit node."""
    def exit_node(nd: uni.UniNode) -> None;

    """Generate Python stubs for native interop at the NativeBlock position.

        For native_exports (native functions called from Python):
          Generates a Python stub function that calls the native function via
ctypes.
        For native_imports (Python functions called from native):
          Generates a registration statement that stores the Python function
          in the interop callback table.
        """
    def _gen_native_interop_stubs(nd: uni.NativeBlock) -> None;

    """Generate Python HTTP client stubs for sv-to-sv microservice imports.

        For each function imported via an sv import from another server module,
        generates a Python function that routes the call over HTTP via
        jaclang.runtimelib.sv_client. For each typed object imported, generates
        a lightweight stub class with from_wire / to_wire reconstruction.
        Returns True if the import was handled (caller should not emit a normal
        Python import), False otherwise.
        """
    def _generate_sv_to_sv_stubs(nd: uni.Import) -> bool;

    """Build a Python source string for an sv-to-sv function stub."""
    def _gen_py_sv_func_stub(
        local_name: str,
        func_name: str,
        module_name: str,
        binding: InteropBinding,
        boundary_types: dict[str, BoundaryTypeInfo]
    ) -> str;

    """Build a Python source string for a boundary type stub class."""
    def _gen_py_boundary_stub_class(class_name: str, info: BoundaryTypeInfo) -> str;

    """Return the object from jaclib as ast node based on the import config."""
    def jaclib_obj(obj_name: str) -> ast3.Name;

    """Return a builtin name and track it for importing.

        Note: Some names like 'Enum' are provided by other imports (e.g.,
needs_enum)
        and should not be added to builtin_imports.
        """
    def builtin_name(name: str) -> ast3.Name;

    """Append an import statement to the preamble once."""
    def _add_preamble_once(key: str, nd: ast3.AST) -> None;

    """Ensure typing is imported only once."""
    def needs_typing -> None;

    """Ensure Enum utilities are imported only once."""
    def needs_enum -> None;

    """Ensure concurrent Future is imported only once."""
    def needs_future -> None;

    """Generate a deterministic temporary name for synthesized definitions."""
    def _next_temp_name(prefix: str) -> str;

    """Convert Jac identifiers to Python runtime identifiers."""
    def _py_name(nd: uni.AstSymbolNode) -> str;

    """Convert a synthesized function definition into an executable expression.

        Instead of using make_block_lambda at runtime, we hoist the function
        definition to be emitted before the current statement, then return
        a reference to the function name.
        """
    def _function_expr_from_def(
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
    def _get_sem_decorator(nd: uni.UniNode) -> (ast3.Call | None);

    """Safe accessor for a node's generated py_ast.

        Raises an ICE with source location instead of a bare IndexError
        when py_ast is unexpectedly empty.
        """
    def py_ast_val(nd: uni.UniNode) -> ast3.AST;

    """Sync ast locations."""
    def sync(
        py_node: T, jac_node: (uni.UniNode | None) = None, deep: bool = False
    ) -> T;

    """Sync ast locations."""
    def pyinline_sync(py_nodes: list[ast3.AST]) -> list[ast3.AST];

    """Resolve switch case pattern."""
    def resolve_switch_pattern(
        pattern: uni.MatchPattern, target: uni.Expr
    ) -> ast3.expr;

    """Resolve switch statement."""
    def resolve_switch_stmt(nd: uni.SwitchStmt) -> list[ast3.AST];

    """Unwind codeblock."""
    def resolve_stmt_block(
        nd: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
        doc: (uni.String | None) = None
    ) -> list[ast3.AST];

    """Sync ast locations."""
    def sync_many(py_nodes: list[T], jac_node: uni.UniNode) -> list[T];

    """Convert list to attribute."""
    def list_to_attrib(
        attribute_list: list[str], sync_node_list: Sequence[uni.UniNode]
    ) -> ast3.AST;

    """Resolve Self to the appropriate Python construct based on context."""
    def _resolve_self_type(nd: uni.Name) -> (ast3.expr | None);

    """Check if a node is in a type annotation context."""
    def _is_in_type_annotation(nd: uni.UniNode) -> bool;

    """Check if a node is or is a descendant of another node."""
    def _is_descendant_of(nd: uni.UniNode, ancestor: uni.UniNode) -> bool;

    def exit_sub_tag(nd: uni.SubTag[uni.T]) -> None;
    def exit_module(nd: uni.Module) -> None;
    def exit_type_param(nd: uni.TypeParam) -> None;
    def exit_type_alias(nd: uni.TypeAlias) -> None;
    def exit_global_vars(nd: uni.GlobalVars) -> None;
    def exit_test(nd: uni.Test) -> None;
    def exit_module_code(nd: uni.ModuleCode) -> None;
    """Handle ClientBlock - already set to empty in enter_node."""
    def exit_client_block(nd: uni.ClientBlock) -> None;

    """Handle ServerBlock - unwrap its children to module level."""
    def exit_server_block(nd: uni.ServerBlock) -> None;

    """Handle NativeBlock - already pruned in enter_node."""
    def exit_native_block(nd: uni.NativeBlock) -> None;

    def exit_py_inline_code(nd: uni.PyInlineCode) -> None;
    """Exit import node."""
    def exit_import(nd: uni.Import) -> None;

    def exit_module_path(nd: uni.ModulePath) -> None;
    def exit_module_item(nd: uni.ModuleItem) -> None;
    def enter_archetype(nd: uni.Archetype) -> None;
    def exit_archetype(nd: uni.Archetype) -> None;
    def enter_enum(nd: uni.Enum) -> None;
    def exit_enum(nd: uni.Enum) -> None;
    def enter_ability(nd: uni.Ability) -> None;
    """Reusable method to codegen call_llm(model, caller, args)."""
    def _invoke_llm_call(
        model: ast3.expr, caller: ast3.expr, args: ast3.Dict
    ) -> ast3.Call;

    """Generate the by LLM body."""
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
    def exit_with_stmt(nd: uni.WithStmt) -> None;
    def exit_expr_as_item(nd: uni.ExprAsItem) -> None;
    def exit_raise_stmt(nd: uni.RaiseStmt) -> None;
    def exit_assert_stmt(nd: uni.AssertStmt) -> None;
    """Sub objects.

        target: ExprType,
        """
    def assert_helper(nd: uni.AssertStmt) -> None;

    def exit_ctrl_stmt(nd: uni.CtrlStmt) -> None;
    def exit_delete_stmt(nd: uni.DeleteStmt) -> None;
    def exit_report_stmt(nd: uni.ReportStmt) -> None;
    def exit_return_stmt(nd: uni.ReturnStmt) -> None;
    def exit_yield_expr(nd: uni.YieldExpr) -> None;
    def exit_visit_stmt(nd: uni.VisitStmt) -> None;
    def exit_disengage_stmt(nd: uni.DisengageStmt) -> None;
    def exit_await_expr(nd: uni.AwaitExpr) -> None;
    def exit_global_stmt(nd: uni.GlobalStmt) -> None;
    def exit_non_local_stmt(nd: uni.NonLocalStmt) -> None;
    def exit_assignment(nd: uni.Assignment) -> None;
    def exit_binary_expr(nd: uni.BinaryExpr) -> None;
    def translate_jac_bin_op(nd: uni.BinaryExpr) -> list[ast3.AST];
    def exit_compare_expr(nd: uni.CompareExpr) -> None;
    def exit_cfg_expr(nd: uni.CfgExpr) -> None;
    def exit_bool_expr(nd: uni.BoolExpr) -> None;
    def exit_lambda_expr(nd: uni.LambdaExpr) -> None;
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
    """Generate the arguments for a function call."""
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
    """Generate Python AST for JSX elements."""
    def exit_jsx_element(nd: uni.JsxElement) -> None;

    """Generate Python AST for JSX element names."""
    def exit_jsx_element_name(nd: uni.JsxElementName) -> None;

    """Bases class for JSX attributes - handled by subclasses."""
    def exit_jsx_attribute(nd: uni.JsxAttribute) -> None;

    """Generate Python AST for JSX spread attributes."""
    def exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None;

    """Generate Python AST for JSX normal attributes."""
    def exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None;

    """Bases class for JSX children - handled by subclasses."""
    def exit_jsx_child(nd: uni.JsxChild) -> None;

    """Generate Python AST for JSX text nodes."""
    def exit_jsx_text(nd: uni.JsxText) -> None;

    """Generate Python AST for JSX expression children."""
    def exit_jsx_expression(nd: uni.JsxExpression) -> None;

    def exit_semi(nd: uni.Semi) -> None;
    def exit_comment_token(nd: uni.CommentToken) -> None;
}
