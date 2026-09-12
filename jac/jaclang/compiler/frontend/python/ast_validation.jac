"""Native validation of manually constructed ASTs after schema conversion."""
import from jaclang.compiler.frontend.python.ast_nodes {
    ast_node,
    mod,
    Module,
    Interactive,
    Expression,
    FunctionType,
    stmt,
    FunctionDef,
    AsyncFunctionDef,
    ClassDef,
    Return,
    Delete,
    Assign,
    TypeAlias,
    AugAssign,
    AnnAssign,
    For,
    AsyncFor,
    While,
    If,
    With,
    AsyncWith,
    Match,
    Raise,
    Try,
    TryStar,
    Assert,
    Import,
    ImportFrom,
    Global,
    Nonlocal,
    Expr,
    Pass,
    Break,
    Continue,
    expr,
    BoolOp,
    NamedExpr,
    BinOp,
    UnaryOp,
    Lambda,
    IfExp,
    Dict,
    Set,
    ListComp,
    SetComp,
    DictComp,
    GeneratorExp,
    Await,
    Yield,
    YieldFrom,
    Compare,
    Call,
    FormattedValue,
    Interpolation,
    JoinedStr,
    TemplateStr,
    Constant,
    Attribute,
    Subscript,
    Starred,
    Name,
    List,
    Tuple,
    Slice,
    expr_context,
    Load,
    Store,
    Del,
    boolop,
    And,
    Or,
    operator,
    Add,
    Sub,
    Mult,
    MatMult,
    Div,
    Mod,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    FloorDiv,
    unaryop,
    Invert,
    Not,
    UAdd,
    USub,
    cmpop,
    Eq,
    NotEq,
    Lt,
    LtE,
    Gt,
    GtE,
    Is,
    IsNot,
    In,
    NotIn,
    comprehension,
    excepthandler,
    ExceptHandler,
    arguments,
    arg,
    keyword,
    alias,
    withitem,
    match_case,
    pattern,
    MatchValue,
    MatchSingleton,
    MatchSequence,
    MatchMapping,
    MatchClass,
    MatchStar,
    MatchAs,
    MatchOr,
    type_ignore,
    TypeIgnore,
    type_param,
    TypeVar,
    ParamSpec,
    TypeVarTuple
}
import from jaclang.runtime.python.objects {
    PyObj,
    PyNoneType,
    PyEllipsis,
    PyBool,
    PyInt,
    PyFloat,
    PyComplex,
    PyStr,
    PyBytes,
    PyTuple,
    PySet
}
import from jaclang.runtime.python.compiler_integer { PyBigInt }
import from jaclang.compiler.frontend.python.ast_walk { ast_children }
def ast_kind(value: ast_node) -> str {
    if isinstance(value, Module) {
        return "Module";
    }
    if isinstance(value, Interactive) {
        return "Interactive";
    }
    if isinstance(value, Expression) {
        return "Expression";
    }
    if isinstance(value, FunctionType) {
        return "FunctionType";
    }
    if isinstance(value, FunctionDef) {
        return "FunctionDef";
    }
    if isinstance(value, AsyncFunctionDef) {
        return "AsyncFunctionDef";
    }
    if isinstance(value, ClassDef) {
        return "ClassDef";
    }
    if isinstance(value, Return) {
        return "Return";
    }
    if isinstance(value, Delete) {
        return "Delete";
    }
    if isinstance(value, Assign) {
        return "Assign";
    }
    if isinstance(value, TypeAlias) {
        return "TypeAlias";
    }
    if isinstance(value, AugAssign) {
        return "AugAssign";
    }
    if isinstance(value, AnnAssign) {
        return "AnnAssign";
    }
    if isinstance(value, For) {
        return "For";
    }
    if isinstance(value, AsyncFor) {
        return "AsyncFor";
    }
    if isinstance(value, While) {
        return "While";
    }
    if isinstance(value, If) {
        return "If";
    }
    if isinstance(value, With) {
        return "With";
    }
    if isinstance(value, AsyncWith) {
        return "AsyncWith";
    }
    if isinstance(value, Match) {
        return "Match";
    }
    if isinstance(value, Raise) {
        return "Raise";
    }
    if isinstance(value, Try) {
        return "Try";
    }
    if isinstance(value, TryStar) {
        return "TryStar";
    }
    if isinstance(value, Assert) {
        return "Assert";
    }
    if isinstance(value, Import) {
        return "Import";
    }
    if isinstance(value, ImportFrom) {
        return "ImportFrom";
    }
    if isinstance(value, Global) {
        return "Global";
    }
    if isinstance(value, Nonlocal) {
        return "Nonlocal";
    }
    if isinstance(value, Expr) {
        return "Expr";
    }
    if isinstance(value, Pass) {
        return "Pass";
    }
    if isinstance(value, Break) {
        return "Break";
    }
    if isinstance(value, Continue) {
        return "Continue";
    }
    if isinstance(value, BoolOp) {
        return "BoolOp";
    }
    if isinstance(value, NamedExpr) {
        return "NamedExpr";
    }
    if isinstance(value, BinOp) {
        return "BinOp";
    }
    if isinstance(value, UnaryOp) {
        return "UnaryOp";
    }
    if isinstance(value, Lambda) {
        return "Lambda";
    }
    if isinstance(value, IfExp) {
        return "IfExp";
    }
    if isinstance(value, Dict) {
        return "Dict";
    }
    if isinstance(value, Set) {
        return "Set";
    }
    if isinstance(value, ListComp) {
        return "ListComp";
    }
    if isinstance(value, SetComp) {
        return "SetComp";
    }
    if isinstance(value, DictComp) {
        return "DictComp";
    }
    if isinstance(value, GeneratorExp) {
        return "GeneratorExp";
    }
    if isinstance(value, Await) {
        return "Await";
    }
    if isinstance(value, Yield) {
        return "Yield";
    }
    if isinstance(value, YieldFrom) {
        return "YieldFrom";
    }
    if isinstance(value, Compare) {
        return "Compare";
    }
    if isinstance(value, Call) {
        return "Call";
    }
    if isinstance(value, FormattedValue) {
        return "FormattedValue";
    }
    if isinstance(value, Interpolation) {
        return "Interpolation";
    }
    if isinstance(value, JoinedStr) {
        return "JoinedStr";
    }
    if isinstance(value, TemplateStr) {
        return "TemplateStr";
    }
    if isinstance(value, Constant) {
        return "Constant";
    }
    if isinstance(value, Attribute) {
        return "Attribute";
    }
    if isinstance(value, Subscript) {
        return "Subscript";
    }
    if isinstance(value, Starred) {
        return "Starred";
    }
    if isinstance(value, Name) {
        return "Name";
    }
    if isinstance(value, List) {
        return "List";
    }
    if isinstance(value, Tuple) {
        return "Tuple";
    }
    if isinstance(value, Slice) {
        return "Slice";
    }
    if isinstance(value, Load) {
        return "Load";
    }
    if isinstance(value, Store) {
        return "Store";
    }
    if isinstance(value, Del) {
        return "Del";
    }
    if isinstance(value, And) {
        return "And";
    }
    if isinstance(value, Or) {
        return "Or";
    }
    if isinstance(value, Add) {
        return "Add";
    }
    if isinstance(value, Sub) {
        return "Sub";
    }
    if isinstance(value, Mult) {
        return "Mult";
    }
    if isinstance(value, MatMult) {
        return "MatMult";
    }
    if isinstance(value, Div) {
        return "Div";
    }
    if isinstance(value, Mod) {
        return "Mod";
    }
    if isinstance(value, Pow) {
        return "Pow";
    }
    if isinstance(value, LShift) {
        return "LShift";
    }
    if isinstance(value, RShift) {
        return "RShift";
    }
    if isinstance(value, BitOr) {
        return "BitOr";
    }
    if isinstance(value, BitXor) {
        return "BitXor";
    }
    if isinstance(value, BitAnd) {
        return "BitAnd";
    }
    if isinstance(value, FloorDiv) {
        return "FloorDiv";
    }
    if isinstance(value, Invert) {
        return "Invert";
    }
    if isinstance(value, Not) {
        return "Not";
    }
    if isinstance(value, UAdd) {
        return "UAdd";
    }
    if isinstance(value, USub) {
        return "USub";
    }
    if isinstance(value, Eq) {
        return "Eq";
    }
    if isinstance(value, NotEq) {
        return "NotEq";
    }
    if isinstance(value, Lt) {
        return "Lt";
    }
    if isinstance(value, LtE) {
        return "LtE";
    }
    if isinstance(value, Gt) {
        return "Gt";
    }
    if isinstance(value, GtE) {
        return "GtE";
    }
    if isinstance(value, Is) {
        return "Is";
    }
    if isinstance(value, IsNot) {
        return "IsNot";
    }
    if isinstance(value, In) {
        return "In";
    }
    if isinstance(value, NotIn) {
        return "NotIn";
    }
    if isinstance(value, comprehension) {
        return "comprehension";
    }
    if isinstance(value, ExceptHandler) {
        return "ExceptHandler";
    }
    if isinstance(value, arguments) {
        return "arguments";
    }
    if isinstance(value, arg) {
        return "arg";
    }
    if isinstance(value, keyword) {
        return "keyword";
    }
    if isinstance(value, alias) {
        return "alias";
    }
    if isinstance(value, withitem) {
        return "withitem";
    }
    if isinstance(value, match_case) {
        return "match_case";
    }
    if isinstance(value, MatchValue) {
        return "MatchValue";
    }
    if isinstance(value, MatchSingleton) {
        return "MatchSingleton";
    }
    if isinstance(value, MatchSequence) {
        return "MatchSequence";
    }
    if isinstance(value, MatchMapping) {
        return "MatchMapping";
    }
    if isinstance(value, MatchClass) {
        return "MatchClass";
    }
    if isinstance(value, MatchStar) {
        return "MatchStar";
    }
    if isinstance(value, MatchAs) {
        return "MatchAs";
    }
    if isinstance(value, MatchOr) {
        return "MatchOr";
    }
    if isinstance(value, TypeIgnore) {
        return "TypeIgnore";
    }
    if isinstance(value, TypeVar) {
        return "TypeVar";
    }
    if isinstance(value, ParamSpec) {
        return "ParamSpec";
    }
    if isinstance(value, TypeVarTuple) {
        return "TypeVarTuple";
    }
    return "AST";
}

def ast_positions(value: ast_node) -> tuple[int, int, int, int] {
    if isinstance(value, expr) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, stmt) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, pattern) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, arg) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, excepthandler) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    if isinstance(value, type_param) {
        return (
            value.lineno,
            value.col_offset,
            value.end_lineno if value.end_lineno is not None else value.lineno,
            value.end_col_offset
                if value.end_col_offset is not None
                else value.col_offset
        );
    }
    return (0, 0, 0, 0);
}

def ast_has_items(value: ast_node, field: str) -> bool {
    if isinstance(value, Module) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Interactive) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, FunctionDef) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, AsyncFunctionDef) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, ClassDef) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Delete) {
        if field == "targets" {
            return len(value.targets) > 0;
        }
    }
    if isinstance(value, Assign) {
        if field == "targets" {
            return len(value.targets) > 0;
        }
    }
    if isinstance(value, For) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, AsyncFor) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, While) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, If) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, With) {
        if field == "items" {
            return len(value.items) > 0;
        }
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, AsyncWith) {
        if field == "items" {
            return len(value.items) > 0;
        }
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Match) {
        if field == "cases" {
            return len(value.cases) > 0;
        }
    }
    if isinstance(value, Try) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, TryStar) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, Import) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, ImportFrom) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, Global) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, Nonlocal) {
        if field == "names" {
            return len(value.names) > 0;
        }
    }
    if isinstance(value, ExceptHandler) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    if isinstance(value, match_case) {
        if field == "body" {
            return len(value.body) > 0;
        }
    }
    return False;
}

def validate_ast_positions(value_node: ast_node) {
    (line, col, end_line, end_col) = ast_positions(value_node);
    if line > end_line {
        raise ValueError(f"AST node line range ({line}, {end_line}) is not valid");
    }
    if (line < 0 and end_line != line) or (col < 0 and end_col != col) {
        raise ValueError(
            f"AST node column range ({col}, {end_col}) for line range ({line}, {end_line}) is not valid"
        );
    }
    if line == end_line and col > end_col {
        raise ValueError(f"line {line}, column {col}-{end_col} is not a valid range");
    }
}

def validate_ast_identifier(name: str, capture: bool = False) {
    if capture and name == "_" {
        raise ValueError("can't capture name '_' in patterns");
    }
    if name in ("True", "False", "None") {
        raise ValueError(f"identifier field can't represent '{name}' constant");
    }
}

def require_ast_items(value_node: ast_node, field: str) {
    if not ast_has_items(value_node, field) {
        raise ValueError("empty " + field + " on " + ast_kind(value_node));
    }
}

def ast_literal_number(
    value_node: ast_node, real: bool = True, imaginary: bool = True
) -> bool {
    return isinstance(value_node, Constant)
        and (
            (real and isinstance(value_node.value, (PyInt, PyBigInt, PyFloat)))
            or (imaginary and isinstance(value_node.value, PyComplex))
        );
}

def ast_literal_negative(
    value_node: ast_node, real: bool = True, imaginary: bool = True
) -> bool {
    return isinstance(value_node, UnaryOp)
        and isinstance(value_node.op, USub)
        and ast_literal_number(value_node.operand, real, imaginary);
}

def validate_ast_pattern_value(value_node: ast_node) {
    validate_ast_value(value_node);
    if isinstance(value_node, Constant) {
        if not isinstance(
            value_node.value, (PyInt, PyBigInt, PyFloat, PyComplex, PyStr, PyBytes)
        ) {
            raise ValueError("unexpected constant inside of a literal pattern");
        }
        return;
    }
    if isinstance(value_node, (Attribute, JoinedStr, TemplateStr))
        or ast_literal_negative(value_node) {
        return;
    }
    if isinstance(value_node, BinOp)
        and isinstance(value_node.op, (Add, Sub))
        and (
            ast_literal_number(value_node.left, True, False)
            or ast_literal_negative(value_node.left, True, False)
        )
        and ast_literal_number(value_node.right, False, True) {
        return;
    }
    raise ValueError("patterns may only match literals and attribute lookups");
}

def validate_ast_constant(value: PyObj) {
    if isinstance(
        value,
        (
            PyNoneType,
            PyEllipsis,
            PyBool,
            PyInt,
            PyBigInt,
            PyFloat,
            PyComplex,
            PyStr,
            PyBytes
        )
    ) {
        return;
    }
    if isinstance(value, PyTuple) {
        for item in value.items {
            validate_ast_constant(item);
        }
        return;
    }
    if isinstance(value, PySet) and value.frozen {
        for item in value.items.values() {
            validate_ast_constant(item);
        }
        return;
    }
    raise TypeError("got an invalid type in Constant");
}

def validate_ast_value(
    value_node: ast_node | None, context: str = "Load", star_ok: bool = False
) {
    if value_node is None {
        return;
    }
    if isinstance(value_node, (expr, stmt, pattern, arg, excepthandler, type_param)) {
        validate_ast_positions(value_node);
    }
    if isinstance(value_node, expr) {
        if isinstance(value_node, Name) {
            validate_ast_identifier(value_node.id);
        }
        if isinstance(value_node, (Name, Attribute, Subscript, Starred, List, Tuple)) {
            actual = ast_kind(value_node.ctx);
            if actual != context {
                raise ValueError(
                    f"expression must have {context} context but has {actual} instead"
                );
            }
        } elif context != "Load" {
            raise ValueError(
                f"expression which can't be assigned to in {context} context"
            );
        }
    }
    if isinstance(value_node, Constant) {
        validate_ast_constant(value_node.value);
        return;
    }
    if isinstance(value_node, BoolOp) and len(value_node.values) < 2 {
        raise ValueError("BoolOp with less than 2 values");
    }
    if isinstance(value_node, Compare) {
        if not value_node.comparators {
            raise ValueError("Compare with no comparators");
        }
        if len(value_node.comparators) != len(value_node.ops) {
            raise ValueError(
                "Compare has a different number of comparators and operands"
            );
        }
    }
    if isinstance(value_node, Dict)
        and len(value_node.keys) != len(value_node.values) {
        raise ValueError("Dict doesn't have the same number of keys as values");
    }
    if isinstance(value_node, (ListComp, SetComp, GeneratorExp, DictComp)) {
        if not value_node.generators {
            raise ValueError("comprehension with no generators");
        }
        for item in value_node.generators {
            validate_ast_value(item);
        }
    }
    if isinstance(value_node, arguments) {
        for item in value_node.posonlyargs {
            validate_ast_value(item);
        }
        for item in value_node.args {
            validate_ast_value(item);
        }
        if value_node.vararg is not None {
            validate_ast_value(value_node.vararg.annotation);
        }
        for item in value_node.kwonlyargs {
            validate_ast_value(item);
        }
        if value_node.kwarg is not None {
            validate_ast_value(value_node.kwarg.annotation);
        }
        if len(value_node.defaults)
            > len(value_node.args) + len(value_node.posonlyargs) {
            raise ValueError("more positional defaults than args on arguments");
        }
        if len(value_node.kw_defaults) != len(value_node.kwonlyargs) {
            raise ValueError(
                "length of kwonlyargs is not the same as kw_defaults on arguments"
            );
        }
        for item in value_node.defaults {
            validate_ast_value(item);
        }
        for item in value_node.kw_defaults {
            validate_ast_value(item);
        }
        return;
    }
    if isinstance(
        value_node,
        (
            FunctionDef,
            AsyncFunctionDef,
            ClassDef,
            For,
            AsyncFor,
            While,
            If,
            With,
            AsyncWith,
            Try,
            TryStar,
            ExceptHandler,
            match_case
        )
    ) {
        require_ast_items(value_node, "body");
    }
    if isinstance(value_node, (Assign, Delete)) {
        require_ast_items(value_node, "targets");
    }
    if isinstance(value_node, (Import, ImportFrom, Global, Nonlocal)) {
        require_ast_items(value_node, "names");
    }
    if isinstance(value_node, (With, AsyncWith)) {
        require_ast_items(value_node, "items");
    }
    if isinstance(value_node, Match) {
        require_ast_items(value_node, "cases");
    }
    if isinstance(value_node, ImportFrom) and (value_node.level or 0) < 0 {
        raise ValueError("Negative ImportFrom level");
    }
    if isinstance(value_node, Raise)
        and value_node.exc is None
        and value_node.cause is not None {
        raise ValueError("Raise with cause but no exception");
    }
    if isinstance(value_node, (Try, TryStar)) {
        name = ast_kind(value_node);
        if not value_node.handlers and not value_node.finalbody {
            raise ValueError(f"{name} has neither except handlers nor finalbody");
        }
        if not value_node.handlers and value_node.orelse {
            raise ValueError(f"{name} has orelse but no except handlers");
        }
    }
    if isinstance(value_node, NamedExpr) {
        if not isinstance(value_node.target, Name) {
            raise TypeError("NamedExpr target must be a Name");
        }
        validate_ast_value(value_node.value);
        return;
    }
    if isinstance(value_node, AnnAssign)
        and value_node.simple
        and not isinstance(value_node.target, Name) {
        raise TypeError("AnnAssign with simple non-Name target");
    }
    if isinstance(value_node, TypeAlias) and not isinstance(value_node.name, Name) {
        raise TypeError("TypeAlias with non-Name name");
    }
    if isinstance(value_node, (TypeVar, TypeVarTuple, ParamSpec)) {
        validate_ast_identifier(value_node.name);
    }
    if isinstance(value_node, MatchValue) {
        validate_ast_pattern_value(value_node.value);
        return;
    }
    if isinstance(value_node, MatchSingleton) {
        if not isinstance(value_node.value, (PyNoneType, PyBool)) {
            raise ValueError("MatchSingleton can only contain True, False and None");
        }
        return;
    }
    if isinstance(value_node, MatchMapping) {
        if len(value_node.keys) != len(value_node.patterns) {
            raise ValueError(
                "MatchMapping doesn't have the same number of keys as patterns"
            );
        }
        if value_node.rest is not None {
            validate_ast_identifier(value_node.rest, True);
        }
        for key in value_node.keys {
            if isinstance(key, Constant)
                and (isinstance(key.value, (PyNoneType, PyBool))) {
                continue;
            }
            validate_ast_pattern_value(key);
        }
    }
    if isinstance(value_node, MatchClass) {
        if len(value_node.kwd_attrs) != len(value_node.kwd_patterns) {
            raise ValueError(
                "MatchClass doesn't have the same number of keyword attributes as patterns"
            );
        }
        cls = value_node.cls;
        while isinstance(cls, Attribute) {
            cls = cls.value;
        }
        if not isinstance(cls, Name) {
            raise ValueError(
                "MatchClass cls field can only contain Name or Attribute nodes."
            );
        }
        for name in value_node.kwd_attrs {
            validate_ast_identifier(name);
        }
    }
    if isinstance(value_node, (MatchStar, MatchAs)) {
        if value_node.name is not None {
            validate_ast_identifier(value_node.name, True);
        }
        if isinstance(value_node, MatchStar) and not star_ok {
            raise ValueError("can't use MatchStar here");
        }
        if isinstance(value_node, MatchAs)
            and value_node.pattern is not None
            and value_node.name is None {
            raise ValueError(
                "MatchAs must specify a target name if a pattern is given"
            );
        }
    }
    if isinstance(value_node, MatchOr) and len(value_node.patterns) < 2 {
        raise ValueError("MatchOr requires at least 2 patterns");
    }
    for edge in ast_children(value_node) {
        key = edge.field;
        child = edge.value;
        if key == "ctx"
            or (
                key == "generators"
                and isinstance(value_node, (ListComp, SetComp, GeneratorExp, DictComp))
            )
            or (key == "keys" and isinstance(value_node, MatchMapping)) {
            continue;
        }
        child_context = "Load";
        if key == "targets" and isinstance(value_node, Delete) {
            child_context = "Del";
        } elif (
            key == "target"
            and isinstance(
                value_node, (AugAssign, AnnAssign, For, AsyncFor, comprehension)
            )
        )
            or (key == "targets" and isinstance(value_node, Assign))
            or (key == "name" and isinstance(value_node, TypeAlias))
            or (key == "optional_vars" and isinstance(value_node, withitem)) {
            child_context = "Store";
        } elif (key == "elts" and isinstance(value_node, (List, Tuple)))
            or (key == "value" and isinstance(value_node, Starred)) {
            child_context = context;
        }
        validate_ast_value(child, child_context, isinstance(value_node, MatchSequence));
    }
}
