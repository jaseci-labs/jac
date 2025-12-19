"""Python AST to Jac AST Conversion Pass for the Jac compiler.\n\nThis pass transforms Python AST nodes into equivalent Jac AST nodes by:\n\n1. Converting Python modules, classes, functions, and expressions to their Jac equivalents\n2. Preserving source location information and symbol relationships\n3. Handling Python-specific constructs and adapting them to Jac's object model\n4. Supporting both standard Python modules and type stub (.pyi) files\n5. Creating appropriate symbol tables and scopes for the converted nodes\n\nThis pass is crucial for Python interoperability, allowing Python code to be imported\nand used within Jac programs while maintaining type information and semantic relationships.\n"""
import from __future__ { annotations }
import ast as py_ast;
import os;
import re;
import from collections.abc { Sequence }
import from threading { Event }
import from typing { TYPE_CHECKING, TypeAlias, TypeVar, cast }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes.uni_pass { Transform }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.program { JacProgram }
    }
}

glob T = TypeVar('T', bound=uni.UniNode);

"""Jac Parser."""
class PyastBuildPass(Transform[(uni.PythonModuleAst, uni.Module)]) {
    def init(
        self: PyastBuildPass,
        ir_in: uni.PythonModuleAst,
        prog: JacProgram,
        cancel_token: (Event | None) = None
    ) -> None;

    def nu(self: PyastBuildPass, <>node: T) -> T;
    def convert(self: PyastBuildPass, <>node: py_ast.AST) -> uni.UniNode;
    def transform(self: PyastBuildPass, ir_in: uni.PythonModuleAst) -> uni.Module;
    def extract_with_entry(
        self: PyastBuildPass, body: list[uni.UniNode], exclude_types: TypeAlias = T
    ) -> list[(T | uni.ModuleCode)];

    def proc_module(self: PyastBuildPass, <>node: py_ast.Module) -> uni.Module;
    def proc_function_def(
        self: PyastBuildPass, <>node: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
    ) -> uni.Ability;

    def proc_async_function_def(
        self: PyastBuildPass, <>node: py_ast.AsyncFunctionDef
    ) -> uni.Ability;

    def proc_class_def(
        self: PyastBuildPass, <>node: py_ast.ClassDef
    ) -> (uni.Archetype | uni.Enum);

    def proc_return(
        self: PyastBuildPass, <>node: py_ast.Return
    ) -> (uni.ReturnStmt | None);

    def proc_delete(self: PyastBuildPass, <>node: py_ast.Delete) -> uni.DeleteStmt;
    def proc_assign(self: PyastBuildPass, <>node: py_ast.Assign) -> uni.Assignment;
    def proc_aug_assign(
        self: PyastBuildPass, <>node: py_ast.AugAssign
    ) -> uni.Assignment;

    def proc_ann_assign(
        self: PyastBuildPass, <>node: py_ast.AnnAssign
    ) -> uni.Assignment;

    def proc_for(self: PyastBuildPass, <>node: py_ast.For) -> uni.InForStmt;
    def proc_async_for(self: PyastBuildPass, <>node: py_ast.AsyncFor) -> uni.InForStmt;
    def proc_while(self: PyastBuildPass, <>node: py_ast.While) -> uni.WhileStmt;
    def proc_if(self: PyastBuildPass, <>node: py_ast.If) -> uni.IfStmt;
    def proc_with(self: PyastBuildPass, <>node: py_ast.With) -> uni.WithStmt;
    def proc_async_with(self: PyastBuildPass, <>node: py_ast.AsyncWith) -> uni.WithStmt;
    def proc_raise(self: PyastBuildPass, <>node: py_ast.Raise) -> uni.RaiseStmt;
    def proc_assert(self: PyastBuildPass, <>node: py_ast.Assert) -> uni.AssertStmt;
    def proc_attribute(
        self: PyastBuildPass, <>node: py_ast.Attribute
    ) -> uni.AtomTrailer;

    def proc_await(self: PyastBuildPass, <>node: py_ast.Await) -> uni.AwaitExpr;
    def proc_bin_op(
        self: PyastBuildPass, <>node: py_ast.BinOp
    ) -> (uni.AtomUnit | uni.BinaryExpr);

    def proc_unary_op(self: PyastBuildPass, <>node: py_ast.UnaryOp) -> uni.UnaryExpr;
    def proc_bool_op(self: PyastBuildPass, <>node: py_ast.BoolOp) -> uni.AtomUnit;
    def proc_break(self: PyastBuildPass, <>node: py_ast.Break) -> uni.CtrlStmt;
    def proc_call(self: PyastBuildPass, <>node: py_ast.Call) -> uni.FuncCall;
    def proc_compare(self: PyastBuildPass, <>node: py_ast.Compare) -> uni.AtomUnit;
    def proc_constant(self: PyastBuildPass, <>node: py_ast.Constant) -> uni.Literal;
    def proc_continue(self: PyastBuildPass, <>node: py_ast.Continue) -> uni.CtrlStmt;
    def proc_dict(self: PyastBuildPass, <>node: py_ast.Dict) -> uni.DictVal;
    def proc_dict_comp(self: PyastBuildPass, <>node: py_ast.DictComp) -> uni.DictCompr;
    """Process python node."""
    def proc_ellipsis(self: PyastBuildPass, <>node: py_ast.Constant) -> None { }

    def proc_except_handler(
        self: PyastBuildPass, <>node: py_ast.ExceptHandler
    ) -> uni.Except;

    def proc_expr(self: PyastBuildPass, <>node: py_ast.Expr) -> uni.ExprStmt;
    def proc_formatted_value(
        self: PyastBuildPass, <>node: py_ast.FormattedValue
    ) -> uni.FormattedValue;

    """Process python node."""
    def proc_function_type(self: PyastBuildPass, <>node: py_ast.FunctionType) -> None { }

    def proc_generator_exp(
        self: PyastBuildPass, <>node: py_ast.GeneratorExp
    ) -> uni.GenCompr;

    def proc_global(self: PyastBuildPass, <>node: py_ast.Global) -> uni.GlobalStmt;
    def proc_if_exp(self: PyastBuildPass, <>node: py_ast.IfExp) -> uni.IfElseExpr;
    def proc_import(self: PyastBuildPass, <>node: py_ast.Import) -> uni.Import;
    def proc_import_from(self: PyastBuildPass, <>node: py_ast.ImportFrom) -> uni.Import;
    def proc_joined_str(
        self: PyastBuildPass, <>node: py_ast.JoinedStr
    ) -> uni.MultiString;

    def proc_lambda(self: PyastBuildPass, <>node: py_ast.Lambda) -> uni.LambdaExpr;
    def proc_list(self: PyastBuildPass, <>node: py_ast.List) -> uni.ListVal;
    def proc_list_comp(self: PyastBuildPass, <>node: py_ast.ListComp) -> uni.ListCompr;
    def proc_match(self: PyastBuildPass, <>node: py_ast.Match) -> uni.MatchStmt;
    def proc_match_as(
        self: PyastBuildPass, <>node: py_ast.MatchAs
    ) -> (uni.MatchAs | uni.MatchWild);

    def proc_match_class(
        self: PyastBuildPass, <>node: py_ast.MatchClass
    ) -> uni.MatchArch;

    def proc_match_mapping(
        self: PyastBuildPass, <>node: py_ast.MatchMapping
    ) -> uni.MatchMapping;

    def proc_match_or(self: PyastBuildPass, <>node: py_ast.MatchOr) -> uni.MatchOr;
    def proc_match_sequence(
        self: PyastBuildPass, <>node: py_ast.MatchSequence
    ) -> uni.MatchSequence;

    def proc_match_singleton(
        self: PyastBuildPass, <>node: py_ast.MatchSingleton
    ) -> uni.MatchSingleton;

    def proc_match_star(
        self: PyastBuildPass, <>node: py_ast.MatchStar
    ) -> uni.MatchStar;

    def proc_match_value(
        self: PyastBuildPass, <>node: py_ast.MatchValue
    ) -> uni.MatchValue;

    def proc_name(self: PyastBuildPass, <>node: py_ast.Name) -> uni.Name;
    def proc_named_expr(self: PyastBuildPass, <>node: py_ast.NamedExpr) -> uni.AtomUnit;
    def proc_nonlocal(
        self: PyastBuildPass, <>node: py_ast.Nonlocal
    ) -> uni.NonLocalStmt;

    def proc_pass(self: PyastBuildPass, <>node: py_ast.Pass) -> uni.Semi;
    def proc_set(self: PyastBuildPass, <>node: py_ast.Set) -> uni.SetVal;
    def proc_set_comp(self: PyastBuildPass, <>node: py_ast.SetComp) -> uni.ListCompr;
    def proc_slice(self: PyastBuildPass, <>node: py_ast.Slice) -> uni.IndexSlice;
    def proc_starred(self: PyastBuildPass, <>node: py_ast.Starred) -> uni.UnaryExpr;
    def proc_subscript(
        self: PyastBuildPass, <>node: py_ast.Subscript
    ) -> uni.AtomTrailer;

    def proc_try(
        self: PyastBuildPass, <>node: (py_ast.Try | py_ast.TryStar)
    ) -> uni.TryStmt;

    def proc_try_star(self: PyastBuildPass, <>node: py_ast.TryStar) -> uni.TryStmt;
    def proc_tuple(self: PyastBuildPass, <>node: py_ast.Tuple) -> uni.TupleVal;
    def proc_yield(self: PyastBuildPass, <>node: py_ast.Yield) -> uni.YieldExpr;
    def proc_yield_from(
        self: PyastBuildPass, <>node: py_ast.YieldFrom
    ) -> uni.YieldExpr;

    def proc_alias(self: PyastBuildPass, <>node: py_ast.alias) -> uni.ExprAsItem;
    def proc_arg(self: PyastBuildPass, <>node: py_ast.arg) -> uni.ParamVar;
    def proc_arguments(
        self: PyastBuildPass, <>node: py_ast.arguments
    ) -> uni.FuncSignature;

    def operator(self: PyastBuildPass, tok: Tok, value: str) -> uni.Token;
    def proc_and(self: PyastBuildPass, <>node: py_ast.And) -> uni.Token;
    def proc_or(self: PyastBuildPass, <>node: py_ast.Or) -> uni.Token;
    def proc_add(self: PyastBuildPass, <>node: py_ast.Add) -> uni.Token;
    def proc_bit_and(self: PyastBuildPass, <>node: py_ast.BitAnd) -> uni.Token;
    def proc_bit_or(self: PyastBuildPass, <>node: py_ast.BitOr) -> uni.Token;
    def proc_bit_xor(self: PyastBuildPass, <>node: py_ast.BitXor) -> uni.Token;
    def proc_div(self: PyastBuildPass, <>node: py_ast.Div) -> uni.Token;
    def proc_floor_div(self: PyastBuildPass, <>node: py_ast.FloorDiv) -> uni.Token;
    def proc_l_shift(self: PyastBuildPass, <>node: py_ast.LShift) -> uni.Token;
    def proc_mod(self: PyastBuildPass, <>node: py_ast.Mod) -> uni.Token;
    def proc_mult(self: PyastBuildPass, <>node: py_ast.Mult) -> uni.Token;
    def proc_mat_mult(self: PyastBuildPass, <>node: py_ast.MatMult) -> uni.Token;
    def proc_pow(self: PyastBuildPass, <>node: py_ast.Pow) -> uni.Token;
    def proc_r_shift(self: PyastBuildPass, <>node: py_ast.RShift) -> uni.Token;
    def proc_sub(self: PyastBuildPass, <>node: py_ast.Sub) -> uni.Token;
    def proc_invert(self: PyastBuildPass, <>node: py_ast.Invert) -> uni.Token;
    def proc_not(self: PyastBuildPass, <>node: py_ast.Not) -> uni.Token;
    def proc_u_add(self: PyastBuildPass, <>node: py_ast.UAdd) -> uni.Token;
    def proc_u_sub(self: PyastBuildPass, <>node: py_ast.USub) -> uni.Token;
    def proc_eq(self: PyastBuildPass, <>node: py_ast.Eq) -> uni.Token;
    def proc_gt(self: PyastBuildPass, <>node: py_ast.Gt) -> uni.Token;
    def proc_gt_e(self: PyastBuildPass, <>node: py_ast.GtE) -> uni.Token;
    def proc_in(self: PyastBuildPass, <>node: py_ast.In) -> uni.Token;
    def proc_is(self: PyastBuildPass, <>node: py_ast.Is) -> uni.Token;
    def proc_is_not(self: PyastBuildPass, <>node: py_ast.IsNot) -> uni.Token;
    def proc_lt(self: PyastBuildPass, <>node: py_ast.Lt) -> uni.Token;
    def proc_lt_e(self: PyastBuildPass, <>node: py_ast.LtE) -> uni.Token;
    def proc_not_eq(self: PyastBuildPass, <>node: py_ast.NotEq) -> uni.Token;
    def proc_not_in(self: PyastBuildPass, <>node: py_ast.NotIn) -> uni.Token;
    def proc_comprehension(
        self: PyastBuildPass, <>node: py_ast.comprehension
    ) -> uni.InnerCompr;

    def proc_keyword(self: PyastBuildPass, <>node: py_ast.keyword) -> uni.KWPair;
    def proc_match_case(
        self: PyastBuildPass, <>node: py_ast.match_case
    ) -> uni.MatchCase;

    def proc_withitem(self: PyastBuildPass, <>node: py_ast.withitem) -> uni.ExprAsItem;
    """Process python node."""
    def proc_param_spec(self: PyastBuildPass, <>node: py_ast.ParamSpec) -> None { }

    """Process python node."""
    def proc_type_alias(self: PyastBuildPass, <>node: py_ast.TypeAlias) -> None { }

    """Process python node."""
    def proc_type_var(self: PyastBuildPass, <>node: py_ast.TypeVar) -> None { }

    """Process python node."""
    def proc_type_var_tuple(self: PyastBuildPass, <>node: py_ast.TypeVarTuple) -> None { }

    def convert_to_doc(self: PyastBuildPass, string: uni.String) -> None;
    def aug_op_map(self: PyastBuildPass, tok_dict: dict, op: uni.Token) -> str;
}
