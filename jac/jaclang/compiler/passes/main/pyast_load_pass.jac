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
obj PyastBuildPass(Transform[(uni.PythonModuleAst, uni.Module)]) {
    has ir_in: uni.PythonModuleAst,
        prog: JacProgram,
        cancel_token: Event | None = None;

    def postinit -> None;
    def nu(<>node: T) -> T;
    def convert(<>node: py_ast.AST) -> uni.UniNode;
    def transform(ir_in: uni.PythonModuleAst) -> uni.Module;
    def extract_with_entry(
        body: list[uni.UniNode], exclude_types: TypeAlias = T
    ) -> list[(T | uni.ModuleCode)];

    def proc_module(<>node: py_ast.Module) -> uni.Module;
    def proc_function_def(
        <>node: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
    ) -> uni.Ability;

    def proc_async_function_def(<>node: py_ast.AsyncFunctionDef) -> uni.Ability;
    def proc_class_def(<>node: py_ast.ClassDef) -> (uni.Archetype | uni.Enum);
    def proc_return(<>node: py_ast.Return) -> (uni.ReturnStmt | None);
    def proc_delete(<>node: py_ast.Delete) -> uni.DeleteStmt;
    def proc_assign(<>node: py_ast.Assign) -> uni.Assignment;
    def proc_aug_assign(<>node: py_ast.AugAssign) -> uni.Assignment;
    def proc_ann_assign(<>node: py_ast.AnnAssign) -> uni.Assignment;
    def proc_for(<>node: py_ast.For) -> uni.InForStmt;
    def proc_async_for(<>node: py_ast.AsyncFor) -> uni.InForStmt;
    def proc_while(<>node: py_ast.While) -> uni.WhileStmt;
    def proc_if(<>node: py_ast.If) -> uni.IfStmt;
    def proc_with(<>node: py_ast.With) -> uni.WithStmt;
    def proc_async_with(<>node: py_ast.AsyncWith) -> uni.WithStmt;
    def proc_raise(<>node: py_ast.Raise) -> uni.RaiseStmt;
    def proc_assert(<>node: py_ast.Assert) -> uni.AssertStmt;
    def proc_attribute(<>node: py_ast.Attribute) -> uni.AtomTrailer;
    def proc_await(<>node: py_ast.Await) -> uni.AwaitExpr;
    def proc_bin_op(<>node: py_ast.BinOp) -> (uni.AtomUnit | uni.BinaryExpr);
    def proc_unary_op(<>node: py_ast.UnaryOp) -> uni.UnaryExpr;
    def proc_bool_op(<>node: py_ast.BoolOp) -> uni.AtomUnit;
    def proc_break(<>node: py_ast.Break) -> uni.CtrlStmt;
    def proc_call(<>node: py_ast.Call) -> uni.FuncCall;
    def proc_compare(<>node: py_ast.Compare) -> uni.AtomUnit;
    def proc_constant(<>node: py_ast.Constant) -> uni.Literal;
    def proc_continue(<>node: py_ast.Continue) -> uni.CtrlStmt;
    def proc_dict(<>node: py_ast.Dict) -> uni.DictVal;
    def proc_dict_comp(<>node: py_ast.DictComp) -> uni.DictCompr;
    """Process python node."""
    def proc_ellipsis(<>node: py_ast.Constant) -> None { }

    def proc_except_handler(<>node: py_ast.ExceptHandler) -> uni.Except;
    def proc_expr(<>node: py_ast.Expr) -> uni.ExprStmt;
    def proc_formatted_value(<>node: py_ast.FormattedValue) -> uni.FormattedValue;
    """Process python node."""
    def proc_function_type(<>node: py_ast.FunctionType) -> None { }

    def proc_generator_exp(<>node: py_ast.GeneratorExp) -> uni.GenCompr;
    def proc_global(<>node: py_ast.Global) -> uni.GlobalStmt;
    def proc_if_exp(<>node: py_ast.IfExp) -> uni.IfElseExpr;
    def proc_import(<>node: py_ast.Import) -> uni.Import;
    def proc_import_from(<>node: py_ast.ImportFrom) -> uni.Import;
    def proc_joined_str(<>node: py_ast.JoinedStr) -> uni.MultiString;
    def proc_lambda(<>node: py_ast.Lambda) -> uni.LambdaExpr;
    def proc_list(<>node: py_ast.List) -> uni.ListVal;
    def proc_list_comp(<>node: py_ast.ListComp) -> uni.ListCompr;
    def proc_match(<>node: py_ast.Match) -> uni.MatchStmt;
    def proc_match_as(<>node: py_ast.MatchAs) -> (uni.MatchAs | uni.MatchWild);
    def proc_match_class(<>node: py_ast.MatchClass) -> uni.MatchArch;
    def proc_match_mapping(<>node: py_ast.MatchMapping) -> uni.MatchMapping;
    def proc_match_or(<>node: py_ast.MatchOr) -> uni.MatchOr;
    def proc_match_sequence(<>node: py_ast.MatchSequence) -> uni.MatchSequence;
    def proc_match_singleton(<>node: py_ast.MatchSingleton) -> uni.MatchSingleton;
    def proc_match_star(<>node: py_ast.MatchStar) -> uni.MatchStar;
    def proc_match_value(<>node: py_ast.MatchValue) -> uni.MatchValue;
    def proc_name(<>node: py_ast.Name) -> uni.Name;
    def proc_named_expr(<>node: py_ast.NamedExpr) -> uni.AtomUnit;
    def proc_nonlocal(<>node: py_ast.Nonlocal) -> uni.NonLocalStmt;
    def proc_pass(<>node: py_ast.Pass) -> uni.Semi;
    def proc_set(<>node: py_ast.Set) -> uni.SetVal;
    def proc_set_comp(<>node: py_ast.SetComp) -> uni.ListCompr;
    def proc_slice(<>node: py_ast.Slice) -> uni.IndexSlice;
    def proc_starred(<>node: py_ast.Starred) -> uni.UnaryExpr;
    def proc_subscript(<>node: py_ast.Subscript) -> uni.AtomTrailer;
    def proc_try(<>node: (py_ast.Try | py_ast.TryStar)) -> uni.TryStmt;
    def proc_try_star(<>node: py_ast.TryStar) -> uni.TryStmt;
    def proc_tuple(<>node: py_ast.Tuple) -> uni.TupleVal;
    def proc_yield(<>node: py_ast.Yield) -> uni.YieldExpr;
    def proc_yield_from(<>node: py_ast.YieldFrom) -> uni.YieldExpr;
    def proc_alias(<>node: py_ast.alias) -> uni.ExprAsItem;
    def proc_arg(<>node: py_ast.arg) -> uni.ParamVar;
    def proc_arguments(<>node: py_ast.arguments) -> uni.FuncSignature;
    def operator(tok: Tok, value: str) -> uni.Token;
    def proc_and(<>node: py_ast.And) -> uni.Token;
    def proc_or(<>node: py_ast.Or) -> uni.Token;
    def proc_add(<>node: py_ast.Add) -> uni.Token;
    def proc_bit_and(<>node: py_ast.BitAnd) -> uni.Token;
    def proc_bit_or(<>node: py_ast.BitOr) -> uni.Token;
    def proc_bit_xor(<>node: py_ast.BitXor) -> uni.Token;
    def proc_div(<>node: py_ast.Div) -> uni.Token;
    def proc_floor_div(<>node: py_ast.FloorDiv) -> uni.Token;
    def proc_l_shift(<>node: py_ast.LShift) -> uni.Token;
    def proc_mod(<>node: py_ast.Mod) -> uni.Token;
    def proc_mult(<>node: py_ast.Mult) -> uni.Token;
    def proc_mat_mult(<>node: py_ast.MatMult) -> uni.Token;
    def proc_pow(<>node: py_ast.Pow) -> uni.Token;
    def proc_r_shift(<>node: py_ast.RShift) -> uni.Token;
    def proc_sub(<>node: py_ast.Sub) -> uni.Token;
    def proc_invert(<>node: py_ast.Invert) -> uni.Token;
    def proc_not(<>node: py_ast.Not) -> uni.Token;
    def proc_u_add(<>node: py_ast.UAdd) -> uni.Token;
    def proc_u_sub(<>node: py_ast.USub) -> uni.Token;
    def proc_eq(<>node: py_ast.Eq) -> uni.Token;
    def proc_gt(<>node: py_ast.Gt) -> uni.Token;
    def proc_gt_e(<>node: py_ast.GtE) -> uni.Token;
    def proc_in(<>node: py_ast.In) -> uni.Token;
    def proc_is(<>node: py_ast.Is) -> uni.Token;
    def proc_is_not(<>node: py_ast.IsNot) -> uni.Token;
    def proc_lt(<>node: py_ast.Lt) -> uni.Token;
    def proc_lt_e(<>node: py_ast.LtE) -> uni.Token;
    def proc_not_eq(<>node: py_ast.NotEq) -> uni.Token;
    def proc_not_in(<>node: py_ast.NotIn) -> uni.Token;
    def proc_comprehension(<>node: py_ast.comprehension) -> uni.InnerCompr;
    def proc_keyword(<>node: py_ast.keyword) -> uni.KWPair;
    def proc_match_case(<>node: py_ast.match_case) -> uni.MatchCase;
    def proc_withitem(<>node: py_ast.withitem) -> uni.ExprAsItem;
    """Process python node."""
    def proc_param_spec(<>node: py_ast.ParamSpec) -> None { }

    """Process python node."""
    def proc_type_alias(<>node: py_ast.TypeAlias) -> None { }

    """Process python node."""
    def proc_type_var(<>node: py_ast.TypeVar) -> None { }

    """Process python node."""
    def proc_type_var_tuple(<>node: py_ast.TypeVarTuple) -> None { }

    def convert_to_doc(string: uni.String) -> None;
    def aug_op_map(tok_dict: dict, op: uni.Token) -> str;
}
