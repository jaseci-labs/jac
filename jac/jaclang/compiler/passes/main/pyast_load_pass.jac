"""
Python AST to Jac AST Conversion Pass for the Jac compiler.

This pass transforms Python AST nodes into equivalent Jac AST nodes by:

1. Converting Python modules, classes, functions, and expressions to their Jac equivalents
2. Preserving source location information and symbol relationships
3. Handling Python-specific constructs and adapting them to Jac's object model
4. Supporting both standard Python modules and type stub (.pyi) files
5. Creating appropriate symbol tables and scopes for the converted nodes

This pass is crucial for Python interoperability, allowing Python code to be imported
and used within Jac programs while maintaining type information and semantic relationships.
"""

import ast as py_ast;
import os;
import re;
import from collections.abc { Sequence }
import from threading { Event }
import from typing { TYPE_CHECKING, TypeAlias, TypeVar, cast }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { Transform }

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.program { JacProgram }
    }
}

glob T = TypeVar('T', bound=uni.UniNode);

"""Jac Parser."""
obj PyastBuildPass(Transform[(uni.PythonModuleAst, uni.Module)]) {
    has ir_in: uni.PythonModuleAst,
        prog: JacProgram,
        cancel_token: Event | None = None,
        mod_path: str by postinit,
        orig_src: str by postinit,
        in_type_annotation: bool by postinit,
        in_match_pattern: bool by postinit,
        in_fstring_expr: bool by postinit;

    def postinit -> None;
    def nu(nd: T) -> T;
    def convert(nd: py_ast.AST) -> uni.UniNode;
    def transform(ir_in: uni.PythonModuleAst) -> uni.Module;
    def extract_with_entry(
        body: list[uni.UniNode], exclude_types: TypeAlias = T
    ) -> list[(T | uni.ModuleCode)];

    def proc_module(nd: py_ast.Module) -> uni.Module;
    def proc_function_def(
        nd: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
    ) -> uni.Ability;

    def proc_async_function_def(nd: py_ast.AsyncFunctionDef) -> uni.Ability;
    def proc_class_def(nd: py_ast.ClassDef) -> (uni.Archetype | uni.Enum);
    def proc_return(nd: py_ast.Return) -> (uni.ReturnStmt | None);
    def proc_delete(nd: py_ast.Delete) -> uni.DeleteStmt;
    def proc_assign(nd: py_ast.Assign) -> uni.Assignment;
    def proc_aug_assign(nd: py_ast.AugAssign) -> uni.Assignment;
    def proc_ann_assign(nd: py_ast.AnnAssign) -> uni.Assignment;
    def proc_for(nd: py_ast.For) -> uni.InForStmt;
    def proc_async_for(nd: py_ast.AsyncFor) -> uni.InForStmt;
    def proc_while(nd: py_ast.While) -> uni.WhileStmt;
    def proc_if(nd: py_ast.If) -> uni.IfStmt;
    def proc_with(nd: py_ast.With) -> uni.WithStmt;
    def proc_async_with(nd: py_ast.AsyncWith) -> uni.WithStmt;
    def proc_raise(nd: py_ast.Raise) -> uni.RaiseStmt;
    def proc_assert(nd: py_ast.Assert) -> uni.AssertStmt;
    def proc_attribute(nd: py_ast.Attribute) -> uni.AtomTrailer;
    def proc_await(nd: py_ast.Await) -> uni.AwaitExpr;
    def proc_bin_op(nd: py_ast.BinOp) -> (uni.AtomUnit | uni.BinaryExpr);
    def proc_unary_op(nd: py_ast.UnaryOp) -> uni.UnaryExpr;
    def proc_bool_op(nd: py_ast.BoolOp) -> uni.AtomUnit;
    def proc_break(nd: py_ast.Break) -> uni.CtrlStmt;
    def proc_call(nd: py_ast.Call) -> uni.FuncCall;
    def proc_compare(nd: py_ast.Compare) -> uni.AtomUnit;
    def proc_constant(nd: py_ast.Constant) -> uni.Literal;
    def proc_continue(nd: py_ast.Continue) -> uni.CtrlStmt;
    def proc_dict(nd: py_ast.Dict) -> uni.DictVal;
    def proc_dict_comp(nd: py_ast.DictComp) -> uni.DictCompr;
    """Process python node."""
    def proc_ellipsis(nd: py_ast.Constant) -> None { }

    def proc_except_handler(nd: py_ast.ExceptHandler) -> uni.Except;
    def proc_expr(nd: py_ast.Expr) -> uni.ExprStmt;
    def proc_formatted_value(nd: py_ast.FormattedValue) -> uni.FormattedValue;
    """Process python node."""
    def proc_function_type(nd: py_ast.FunctionType) -> None { }

    def proc_generator_exp(nd: py_ast.GeneratorExp) -> uni.GenCompr;
    def proc_global(nd: py_ast.Global) -> uni.GlobalStmt;
    def proc_if_exp(nd: py_ast.IfExp) -> uni.IfElseExpr;
    def proc_import(nd: py_ast.Import) -> uni.Import;
    def proc_import_from(nd: py_ast.ImportFrom) -> uni.Import;
    def proc_joined_str(nd: py_ast.JoinedStr) -> uni.MultiString;
    def proc_lambda(nd: py_ast.Lambda) -> uni.LambdaExpr;
    def proc_list(nd: py_ast.List) -> uni.ListVal;
    def proc_list_comp(nd: py_ast.ListComp) -> uni.ListCompr;
    def proc_match(nd: py_ast.Match) -> uni.MatchStmt;
    def proc_match_as(nd: py_ast.MatchAs) -> (uni.MatchAs | uni.MatchWild);
    def proc_match_class(nd: py_ast.MatchClass) -> uni.MatchArch;
    def proc_match_mapping(nd: py_ast.MatchMapping) -> uni.MatchMapping;
    def proc_match_or(nd: py_ast.MatchOr) -> uni.MatchOr;
    def proc_match_sequence(nd: py_ast.MatchSequence) -> uni.MatchSequence;
    def proc_match_singleton(nd: py_ast.MatchSingleton) -> uni.MatchSingleton;
    def proc_match_star(nd: py_ast.MatchStar) -> uni.MatchStar;
    def proc_match_value(nd: py_ast.MatchValue) -> uni.MatchValue;
    def proc_name(nd: py_ast.Name) -> uni.Name;
    def proc_named_expr(nd: py_ast.NamedExpr) -> uni.AtomUnit;
    def proc_nonlocal(nd: py_ast.Nonlocal) -> uni.NonLocalStmt;
    def proc_pass(nd: py_ast.Pass) -> uni.Semi;
    def proc_set(nd: py_ast.Set) -> uni.SetVal;
    def proc_set_comp(nd: py_ast.SetComp) -> uni.ListCompr;
    def proc_slice(nd: py_ast.Slice) -> uni.IndexSlice;
    def proc_starred(nd: py_ast.Starred) -> uni.UnaryExpr;
    def proc_subscript(nd: py_ast.Subscript) -> uni.AtomTrailer;
    def proc_try(nd: (py_ast.Try | py_ast.TryStar)) -> uni.TryStmt;
    def proc_try_star(nd: py_ast.TryStar) -> uni.TryStmt;
    def proc_tuple(nd: py_ast.Tuple) -> uni.TupleVal;
    def proc_yield(nd: py_ast.Yield) -> uni.YieldExpr;
    def proc_yield_from(nd: py_ast.YieldFrom) -> uni.YieldExpr;
    def proc_alias(nd: py_ast.alias) -> uni.ExprAsItem;
    def proc_arg(nd: py_ast.arg) -> uni.ParamVar;
    def proc_arguments(nd: py_ast.arguments) -> uni.FuncSignature;
    def operator(tok: Tok, value: str) -> uni.Token;
    def proc_and(nd: py_ast.And) -> uni.Token;
    def proc_or(nd: py_ast.Or) -> uni.Token;
    def proc_add(nd: py_ast.Add) -> uni.Token;
    def proc_bit_and(nd: py_ast.BitAnd) -> uni.Token;
    def proc_bit_or(nd: py_ast.BitOr) -> uni.Token;
    def proc_bit_xor(nd: py_ast.BitXor) -> uni.Token;
    def proc_div(nd: py_ast.Div) -> uni.Token;
    def proc_floor_div(nd: py_ast.FloorDiv) -> uni.Token;
    def proc_l_shift(nd: py_ast.LShift) -> uni.Token;
    def proc_mod(nd: py_ast.Mod) -> uni.Token;
    def proc_mult(nd: py_ast.Mult) -> uni.Token;
    def proc_mat_mult(nd: py_ast.MatMult) -> uni.Token;
    def proc_pow(nd: py_ast.Pow) -> uni.Token;
    def proc_r_shift(nd: py_ast.RShift) -> uni.Token;
    def proc_sub(nd: py_ast.Sub) -> uni.Token;
    def proc_invert(nd: py_ast.Invert) -> uni.Token;
    def proc_not(nd: py_ast.Not) -> uni.Token;
    def proc_u_add(nd: py_ast.UAdd) -> uni.Token;
    def proc_u_sub(nd: py_ast.USub) -> uni.Token;
    def proc_eq(nd: py_ast.Eq) -> uni.Token;
    def proc_gt(nd: py_ast.Gt) -> uni.Token;
    def proc_gt_e(nd: py_ast.GtE) -> uni.Token;
    def proc_in(nd: py_ast.In) -> uni.Token;
    def proc_is(nd: py_ast.Is) -> uni.Token;
    def proc_is_not(nd: py_ast.IsNot) -> uni.Token;
    def proc_lt(nd: py_ast.Lt) -> uni.Token;
    def proc_lt_e(nd: py_ast.LtE) -> uni.Token;
    def proc_not_eq(nd: py_ast.NotEq) -> uni.Token;
    def proc_not_in(nd: py_ast.NotIn) -> uni.Token;
    def proc_comprehension(nd: py_ast.comprehension) -> uni.InnerCompr;
    def proc_keyword(nd: py_ast.keyword) -> uni.KWPair;
    def proc_match_case(nd: py_ast.match_case) -> uni.MatchCase;
    def proc_withitem(nd: py_ast.withitem) -> uni.ExprAsItem;
    """Process python node."""
    def proc_param_spec(nd: py_ast.ParamSpec) -> None { }

    """Process python node."""
    def proc_type_alias(nd: py_ast.TypeAlias) -> None { }

    """Process python node."""
    def proc_type_var(nd: py_ast.TypeVar) -> None { }

    """Process python node."""
    def proc_type_var_tuple(nd: py_ast.TypeVarTuple) -> None { }

    def convert_to_doc(string: uni.String) -> None;
    def aug_op_map(tok_dict: dict, op: uni.Token) -> str;
}
