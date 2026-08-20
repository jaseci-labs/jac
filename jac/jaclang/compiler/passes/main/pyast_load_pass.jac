import ast as py_ast;
import os;
import re;
import from threading { Event }
import from typing { TypeAlias, cast }
import from jaclang.jac0core.unitree {
    Ability,
    ArchBlockStmt,
    Archetype,
    AssertStmt,
    Assignment,
    AtomExpr,
    AtomTrailer,
    AtomUnit,
    AwaitExpr,
    BinaryExpr,
    Bool,
    BoolExpr,
    CfgExpr,
    CodeBlockStmt,
    CompareExpr,
    CtrlStmt,
    DeleteStmt,
    DictCompr,
    DictVal,
    ElementStmt,
    Ellipsis as UniEllipsis,
    ElseIf,
    ElseStmt,
    EmptyToken,
    Enum,
    Except,
    Expr,
    ExprAsItem,
    ExprStmt,
    FString,
    FinallyStmt,
    Float,
    FormattedValue,
    FuncCall,
    FuncSignature,
    GenCompr,
    IfElseExpr,
    IfStmt,
    Import,
    InForStmt,
    IndexSlice,
    InnerCompr,
    Int,
    KVPair,
    KWPair,
    LambdaExpr,
    ListCompr,
    ListVal,
    Literal,
    MatchArch,
    MatchAs,
    MatchCase,
    MatchKVPair,
    MatchMapping,
    MatchOr,
    MatchPattern,
    MatchSequence,
    MatchSingleton,
    MatchStar,
    MatchStmt,
    MatchValue,
    MatchWild,
    Module,
    ModuleCode,
    ModuleItem,
    ModulePath,
    MultiString,
    Name,
    NameAtom,
    Null,
    ParamKind,
    ParamVar,
    PythonModuleAst,
    RaiseStmt,
    ReturnStmt,
    Semi,
    SetCompr,
    SetVal,
    Slice,
    Source,
    SpecialVarRef,
    String,
    SubTag,
    Token,
    TryStmt,
    TupleVal,
    UnaryExpr,
    UniNode,
    WhileStmt,
    WithStmt,
    YieldExpr
}
import from jaclang.jac0core.constant { Tokens as Tok, RESERVED_IDENT_NAMES }
import from jaclang.jac0core.diagnostics { E5041, E5042 }
import from jaclang.jac0core.passes.transform { Transform }

glob T = TypeVar('T', bound=UniNode),
     _reserved_keywords = RESERVED_IDENT_NAMES;

obj PyastBuildPass(Transform) {
    has ir_in: PythonModuleAst,
        cancel_token: Event | None = None,
        mod_path: str postinit,
        orig_src: str postinit,
        _source_lines: list[str] postinit,
        in_type_annotation: bool postinit,
        in_match_pattern: bool postinit,
        in_fstring_expr: bool postinit;

    def postinit -> None;
    def _get_source_segment(nd: py_ast.AST) -> (str | None);
    def _strip_string_continuations(seg: str) -> str;
    def nu(nd: T) -> T;
    def name_node(
        nd: py_ast.AST,
        value: str,
        name_tok: Tok = Tok.NAME,
        col_end: int = -1,
        col_start: int = -1,
        end_line: int = -1,
        is_kwesc: bool = False
    ) -> Name;

    def is_canceled -> bool;
    def convert(nd: py_ast.AST) -> UniNode;
    def transform(ir_in: PythonModuleAst) -> Module;
    def extract_with_entry(
        body: list[UniNode], exclude_types: TypeAlias = T
    ) -> list[(T | ModuleCode)];

    def proc_module(nd: py_ast.Module) -> Module;
    def proc_function_def(
        nd: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
    ) -> Ability;

    def proc_async_function_def(nd: py_ast.AsyncFunctionDef) -> Ability;
    def proc_class_def(nd: py_ast.ClassDef) -> (Archetype | Enum);
    def proc_return(nd: py_ast.Return) -> (ReturnStmt | None);
    def proc_delete(nd: py_ast.Delete) -> DeleteStmt;
    def proc_assign(nd: py_ast.Assign) -> Assignment;
    def proc_aug_assign(nd: py_ast.AugAssign) -> Assignment;
    def proc_ann_assign(nd: py_ast.AnnAssign) -> Assignment;
    def proc_for(nd: py_ast.For) -> InForStmt;
    def proc_async_for(nd: py_ast.AsyncFor) -> InForStmt;
    def proc_while(nd: py_ast.While) -> WhileStmt;
    def proc_if(nd: py_ast.If) -> IfStmt;
    def proc_with(nd: py_ast.With) -> WithStmt;
    def proc_async_with(nd: py_ast.AsyncWith) -> WithStmt;
    def proc_raise(nd: py_ast.Raise) -> RaiseStmt;
    def proc_assert(nd: py_ast.Assert) -> AssertStmt;
    def proc_attribute(nd: py_ast.Attribute) -> AtomTrailer;
    def proc_await(nd: py_ast.Await) -> AwaitExpr;
    def proc_bin_op(nd: py_ast.BinOp) -> (AtomUnit | BinaryExpr);
    def proc_unary_op(nd: py_ast.UnaryOp) -> UnaryExpr;
    def proc_bool_op(nd: py_ast.BoolOp) -> AtomUnit;
    def proc_break(nd: py_ast.Break) -> CtrlStmt;
    def proc_call(nd: py_ast.Call) -> FuncCall;
    def proc_compare(nd: py_ast.Compare) -> AtomUnit;
    def proc_constant(nd: py_ast.Constant) -> Literal;
    def proc_continue(nd: py_ast.Continue) -> CtrlStmt;
    def proc_dict(nd: py_ast.Dict) -> DictVal;
    def proc_dict_comp(nd: py_ast.DictComp) -> DictCompr;
    def proc_ellipsis(nd: py_ast.Constant) { }
    def proc_except_handler(nd: py_ast.ExceptHandler) -> Except;
    def proc_expr(nd: py_ast.Expr) -> ExprStmt;
    def proc_formatted_value(nd: py_ast.FormattedValue) -> FormattedValue;
    def proc_function_type(nd: py_ast.FunctionType) { }
    def proc_interactive(nd: py_ast.Interactive) { }
    def proc_template_str(nd: py_ast.AST) -> UniNode;
    def proc_interpolation(nd: py_ast.AST) -> UniNode;
    def proc_generator_exp(nd: py_ast.GeneratorExp) -> GenCompr;
    def proc_global(nd: py_ast.Global) -> Semi;
    def proc_if_exp(nd: py_ast.IfExp) -> IfElseExpr;
    def proc_import(nd: py_ast.Import) -> Import;
    def proc_import_from(nd: py_ast.ImportFrom) -> Import;
    def proc_joined_str(nd: py_ast.JoinedStr) -> MultiString;
    def proc_lambda(nd: py_ast.Lambda) -> LambdaExpr;
    def proc_list(nd: py_ast.List) -> ListVal;
    def proc_list_comp(nd: py_ast.ListComp) -> ListCompr;
    def proc_match(nd: py_ast.Match) -> MatchStmt;
    def proc_match_as(nd: py_ast.MatchAs) -> (MatchAs | MatchWild);
    def proc_match_class(nd: py_ast.MatchClass) -> MatchArch;
    def proc_match_mapping(nd: py_ast.MatchMapping) -> MatchMapping;
    def proc_match_or(nd: py_ast.MatchOr) -> MatchOr;
    def proc_match_sequence(nd: py_ast.MatchSequence) -> MatchSequence;
    def proc_match_singleton(nd: py_ast.MatchSingleton) -> MatchSingleton;
    def proc_match_star(nd: py_ast.MatchStar) -> MatchStar;
    def proc_match_value(nd: py_ast.MatchValue) -> MatchValue;
    def proc_name(nd: py_ast.Name) -> Name;
    def proc_named_expr(nd: py_ast.NamedExpr) -> AtomUnit;
    def proc_nonlocal(nd: py_ast.Nonlocal) -> Semi;
    def proc_pass(nd: py_ast.Pass) -> Semi;
    def proc_set(nd: py_ast.Set) -> SetVal;
    def _proc_compr(nd: py_ast.AST, compr_cls: type) -> UniNode;
    def proc_set_comp(nd: py_ast.SetComp) -> ListCompr;
    def proc_slice(nd: py_ast.Slice) -> IndexSlice;
    def proc_starred(nd: py_ast.Starred) -> UnaryExpr;
    def proc_subscript(nd: py_ast.Subscript) -> AtomTrailer;
    def proc_try(nd: (py_ast.Try | py_ast.TryStar)) -> TryStmt;
    def proc_try_star(nd: py_ast.TryStar) -> TryStmt;
    def proc_tuple(nd: py_ast.Tuple) -> TupleVal;
    def proc_yield(nd: py_ast.Yield) -> YieldExpr;
    def proc_yield_from(nd: py_ast.YieldFrom) -> YieldExpr;
    def proc_alias(nd: py_ast.alias) -> ExprAsItem;
    def proc_arg(nd: py_ast.arg) -> ParamVar;
    def proc_arguments(nd: py_ast.arguments) -> FuncSignature;
    def operator(tok: Tok, value: str) -> Token;
    def proc_and(nd: py_ast.And) -> Token;
    def proc_or(nd: py_ast.Or) -> Token;
    def proc_add(nd: py_ast.Add) -> Token;
    def proc_bit_and(nd: py_ast.BitAnd) -> Token;
    def proc_bit_or(nd: py_ast.BitOr) -> Token;
    def proc_bit_xor(nd: py_ast.BitXor) -> Token;
    def proc_div(nd: py_ast.Div) -> Token;
    def proc_floor_div(nd: py_ast.FloorDiv) -> Token;
    def proc_l_shift(nd: py_ast.LShift) -> Token;
    def proc_mod(nd: py_ast.Mod) -> Token;
    def proc_mult(nd: py_ast.Mult) -> Token;
    def proc_mat_mult(nd: py_ast.MatMult) -> Token;
    def proc_pow(nd: py_ast.Pow) -> Token;
    def proc_r_shift(nd: py_ast.RShift) -> Token;
    def proc_sub(nd: py_ast.Sub) -> Token;
    def proc_invert(nd: py_ast.Invert) -> Token;
    def proc_not(nd: py_ast.Not) -> Token;
    def proc_u_add(nd: py_ast.UAdd) -> Token;
    def proc_u_sub(nd: py_ast.USub) -> Token;
    def proc_eq(nd: py_ast.Eq) -> Token;
    def proc_gt(nd: py_ast.Gt) -> Token;
    def proc_gt_e(nd: py_ast.GtE) -> Token;
    def proc_in(nd: py_ast.In) -> Token;
    def proc_is(nd: py_ast.Is) -> Token;
    def proc_is_not(nd: py_ast.IsNot) -> Token;
    def proc_lt(nd: py_ast.Lt) -> Token;
    def proc_lt_e(nd: py_ast.LtE) -> Token;
    def proc_not_eq(nd: py_ast.NotEq) -> Token;
    def proc_not_in(nd: py_ast.NotIn) -> Token;
    def proc_comprehension(nd: py_ast.comprehension) -> InnerCompr;
    def proc_keyword(nd: py_ast.keyword) -> KWPair;
    def proc_match_case(nd: py_ast.match_case) -> MatchCase;
    def proc_withitem(nd: py_ast.withitem) -> ExprAsItem;
    def proc_param_spec(nd: py_ast.ParamSpec) { }
    def proc_type_alias(nd: py_ast.TypeAlias) { }
    def proc_type_var(nd: py_ast.TypeVar) { }
    def proc_type_var_tuple(nd: py_ast.TypeVarTuple) { }
    def convert_to_doc(string: String) -> None;
    def aug_op_map(tok_dict: dict, op: Token) -> str;
}
