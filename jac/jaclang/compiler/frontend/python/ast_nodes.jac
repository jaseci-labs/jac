"""jacpython AST node archetypes.

Originally generated from CPython 3.14.6 Parser/Python.asdl.
Maintained directly in Jac.
"""

import from jaclang.runtime.python.objects { PyObj }

# Concrete AST kinds. The numbering is the boundary contract with
# JAC_AST_KINDS in jac/bootstrap/python/compiler_runtime.c.
enum ast_kind {
    Module = 0,
    Interactive = 1,
    Expression = 2,
    FunctionType = 3,
    FunctionDef = 4,
    AsyncFunctionDef = 5,
    ClassDef = 6,
    Return = 7,
    Delete = 8,
    Assign = 9,
    TypeAlias = 10,
    AugAssign = 11,
    AnnAssign = 12,
    For = 13,
    AsyncFor = 14,
    While = 15,
    If = 16,
    With = 17,
    AsyncWith = 18,
    Match = 19,
    Raise = 20,
    Try = 21,
    TryStar = 22,
    Assert = 23,
    Import = 24,
    ImportFrom = 25,
    Global = 26,
    Nonlocal = 27,
    Expr = 28,
    Pass = 29,
    Break = 30,
    Continue = 31,
    BoolOp = 32,
    NamedExpr = 33,
    BinOp = 34,
    UnaryOp = 35,
    Lambda = 36,
    IfExp = 37,
    Dict = 38,
    Set = 39,
    ListComp = 40,
    SetComp = 41,
    DictComp = 42,
    GeneratorExp = 43,
    Await = 44,
    Yield = 45,
    YieldFrom = 46,
    Compare = 47,
    Call = 48,
    FormattedValue = 49,
    Interpolation = 50,
    JoinedStr = 51,
    TemplateStr = 52,
    Constant = 53,
    Attribute = 54,
    Subscript = 55,
    Starred = 56,
    Name = 57,
    List = 58,
    Tuple = 59,
    Slice = 60,
    Load = 61,
    Store = 62,
    Del = 63,
    And = 64,
    Or = 65,
    Add = 66,
    Sub = 67,
    Mult = 68,
    MatMult = 69,
    Div = 70,
    Mod = 71,
    Pow = 72,
    LShift = 73,
    RShift = 74,
    BitOr = 75,
    BitXor = 76,
    BitAnd = 77,
    FloorDiv = 78,
    Invert = 79,
    Not = 80,
    UAdd = 81,
    USub = 82,
    Eq = 83,
    NotEq = 84,
    Lt = 85,
    LtE = 86,
    Gt = 87,
    GtE = 88,
    Is = 89,
    IsNot = 90,
    In = 91,
    NotIn = 92,
    comprehension = 93,
    ExceptHandler = 94,
    arguments = 95,
    arg = 96,
    keyword = 97,
    alias = 98,
    withitem = 99,
    match_case = 100,
    MatchValue = 101,
    MatchSingleton = 102,
    MatchSequence = 103,
    MatchMapping = 104,
    MatchClass = 105,
    MatchStar = 106,
    MatchAs = 107,
    MatchOr = 108,
    TypeIgnore = 109,
    TypeVar = 110,
    ParamSpec = 111,
    TypeVarTuple = 112
}

# AST field names. The numbering is the boundary contract with
# JAC_AST_FIELDS in jac/bootstrap/python/compiler_runtime.c.
enum ast_field {
    ANNOTATION = 0,
    ARG = 1,
    ARGS = 2,
    ARGTYPES = 3,
    ASNAME = 4,
    ATTR = 5,
    BASES = 6,
    BODY = 7,
    BOUND = 8,
    CASES = 9,
    CAUSE = 10,
    CLS = 11,
    COL_OFFSET = 12,
    COMPARATORS = 13,
    CONTEXT_EXPR = 14,
    CONVERSION = 15,
    CTX = 16,
    DECORATOR_LIST = 17,
    DEFAULT_VALUE = 18,
    DEFAULTS = 19,
    ELT = 20,
    ELTS = 21,
    END_COL_OFFSET = 22,
    END_LINENO = 23,
    EXC = 24,
    FINALBODY = 25,
    FORMAT_SPEC = 26,
    FUNC = 27,
    GENERATORS = 28,
    GUARD = 29,
    HANDLERS = 30,
    ID = 31,
    IFS = 32,
    IS_ASYNC = 33,
    ITEMS = 34,
    ITER = 35,
    KEY = 36,
    KEYS = 37,
    KEYWORDS = 38,
    KIND = 39,
    KW_DEFAULTS = 40,
    KWARG = 41,
    KWD_ATTRS = 42,
    KWD_PATTERNS = 43,
    KWONLYARGS = 44,
    LEFT = 45,
    LEVEL = 46,
    LINENO = 47,
    LOWER = 48,
    MODULE = 49,
    MSG = 50,
    NAME = 51,
    NAMES = 52,
    OP = 53,
    OPERAND = 54,
    OPS = 55,
    OPTIONAL_VARS = 56,
    ORELSE = 57,
    PATTERN = 58,
    PATTERNS = 59,
    POSONLYARGS = 60,
    REST = 61,
    RETURNS = 62,
    RIGHT = 63,
    SIMPLE = 64,
    SLICE = 65,
    STEP = 66,
    STR = 67,
    SUBJECT = 68,
    TAG = 69,
    TARGET = 70,
    TARGETS = 71,
    TEST = 72,
    TYPE = 73,
    TYPE_COMMENT = 74,
    TYPE_IGNORES = 75,
    TYPE_PARAMS = 76,
    UPPER = 77,
    VALUE = 78,
    VALUES = 79,
    VARARG = 80
}

obj ast_node {}

# --- mod ---
obj mod(ast_node) {}

obj Module(mod) {
    has body: list[stmt],
        type_ignores: list[type_ignore];
}

obj Interactive(mod) {
    has body: list[stmt];
}

obj Expression(mod) {
    has body: expr;
}

obj FunctionType(mod) {
    has argtypes: list[expr],
        returns: expr;
}

# --- stmt ---
obj stmt(ast_node) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj FunctionDef(stmt) {
    has name: str,
        args: arguments,
        body: list[stmt],
        decorator_list: list[expr],
        returns: expr | None,
        type_comment: str | None,
        type_params: list[type_param],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj AsyncFunctionDef(stmt) {
    has name: str,
        args: arguments,
        body: list[stmt],
        decorator_list: list[expr],
        returns: expr | None,
        type_comment: str | None,
        type_params: list[type_param],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj ClassDef(stmt) {
    has name: str,
        bases: list[expr],
        keywords: list[keyword],
        body: list[stmt],
        decorator_list: list[expr],
        type_params: list[type_param],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Return(stmt) {
    has value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Delete(stmt) {
    has targets: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Assign(stmt) {
    has targets: list[expr],
        value: expr,
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj TypeAlias(stmt) {
    has name: expr,
        type_params: list[type_param],
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj AugAssign(stmt) {
    has target: expr,
        op: operator,
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj AnnAssign(stmt) {
    has target: expr,
        annotation: expr,
        value: expr | None,
        simple: int,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj For(stmt) {
    has target: expr,
        iter: expr,
        body: list[stmt],
        orelse: list[stmt],
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj AsyncFor(stmt) {
    has target: expr,
        iter: expr,
        body: list[stmt],
        orelse: list[stmt],
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj While(stmt) {
    has `test: expr,
        body: list[stmt],
        orelse: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj If(stmt) {
    has `test: expr,
        body: list[stmt],
        orelse: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj With(stmt) {
    has items: list[withitem],
        body: list[stmt],
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj AsyncWith(stmt) {
    has items: list[withitem],
        body: list[stmt],
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Match(stmt) {
    has subject: expr,
        cases: list[match_case],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Raise(stmt) {
    has exc: expr | None,
        cause: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Try(stmt) {
    has body: list[stmt],
        handlers: list[excepthandler],
        orelse: list[stmt],
        finalbody: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj TryStar(stmt) {
    has body: list[stmt],
        handlers: list[excepthandler],
        orelse: list[stmt],
        finalbody: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Assert(stmt) {
    has `test: expr,
        msg: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Import(stmt) {
    has names: list[alias],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj ImportFrom(stmt) {
    has module: str | None,
        names: list[alias],
        level: int | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Global(stmt) {
    has names: list[str],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Nonlocal(stmt) {
    has names: list[str],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Expr(stmt) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Pass(stmt) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Break(stmt) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Continue(stmt) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- expr ---
obj expr(ast_node) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj BoolOp(expr) {
    has op: boolop,
        values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj NamedExpr(expr) {
    has target: expr,
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj BinOp(expr) {
    has left: expr,
        op: operator,
        right: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj UnaryOp(expr) {
    has op: unaryop,
        operand: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Lambda(expr) {
    has args: arguments,
        body: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj IfExp(expr) {
    has `test: expr,
        body: expr,
        orelse: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Dict(expr) {
    has keys: list[expr | None],
        values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Set(expr) {
    has elts: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj ListComp(expr) {
    has elt: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj SetComp(expr) {
    has elt: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj DictComp(expr) {
    has key: expr,
        value: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj GeneratorExp(expr) {
    has elt: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Await(expr) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Yield(expr) {
    has value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj YieldFrom(expr) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Compare(expr) {
    has left: expr,
        ops: list[cmpop],
        comparators: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Call(expr) {
    has func: expr,
        args: list[expr],
        keywords: list[keyword],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj FormattedValue(expr) {
    has value: expr,
        conversion: int,
        format_spec: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Interpolation(expr) {
    has value: expr,
        str: PyObj,
        conversion: int,
        format_spec: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj JoinedStr(expr) {
    has values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj TemplateStr(expr) {
    has values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Constant(expr) {
    has value: PyObj,
        kind: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Attribute(expr) {
    has value: expr,
        attr: str,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Subscript(expr) {
    has value: expr,
        slice: expr,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Starred(expr) {
    has value: expr,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Name(expr) {
    has id: str,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj List(expr) {
    has elts: list[expr],
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Tuple(expr) {
    has elts: list[expr],
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj Slice(expr) {
    has lower: expr | None,
        upper: expr | None,
        step: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- expr_context ---
obj expr_context(ast_node) {}

obj Load(expr_context) {}

obj Store(expr_context) {}

obj Del(expr_context) {}

# --- boolop ---
obj boolop(ast_node) {}

obj And(boolop) {}

obj Or(boolop) {}

# --- operator ---
obj operator(ast_node) {}

obj Add(operator) {}

obj Sub(operator) {}

obj Mult(operator) {}

obj MatMult(operator) {}

obj Div(operator) {}

obj Mod(operator) {}

obj Pow(operator) {}

obj LShift(operator) {}

obj RShift(operator) {}

obj BitOr(operator) {}

obj BitXor(operator) {}

obj BitAnd(operator) {}

obj FloorDiv(operator) {}

# --- unaryop ---
obj unaryop(ast_node) {}

obj Invert(unaryop) {}

obj Not(unaryop) {}

obj UAdd(unaryop) {}

obj USub(unaryop) {}

# --- cmpop ---
obj cmpop(ast_node) {}

obj Eq(cmpop) {}

obj NotEq(cmpop) {}

obj Lt(cmpop) {}

obj LtE(cmpop) {}

obj Gt(cmpop) {}

obj GtE(cmpop) {}

obj Is(cmpop) {}

obj IsNot(cmpop) {}

obj In(cmpop) {}

obj NotIn(cmpop) {}

# --- comprehension (product) ---
obj comprehension(ast_node) {
    has target: expr,
        iter: expr,
        ifs: list[expr],
        is_async: int;
}

# --- excepthandler ---
obj excepthandler(ast_node) {
    has type: expr | None,
        name: str | None,
        body: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj ExceptHandler(excepthandler) {
    has type: expr | None,
        name: str | None,
        body: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- arguments (product) ---
obj arguments(ast_node) {
    has posonlyargs: list[arg],
        args: list[arg],
        vararg: arg | None,
        kwonlyargs: list[arg],
        kw_defaults: list[expr | None],
        kwarg: arg | None,
        defaults: list[expr];
}

# --- arg (product) ---
obj arg(ast_node) {
    has arg: str,
        annotation: expr | None,
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- keyword (product) ---
obj keyword(ast_node) {
    has arg: str | None,
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- alias (product) ---
obj alias(ast_node) {
    has name: str,
        asname: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- withitem (product) ---
obj withitem(ast_node) {
    has context_expr: expr,
        optional_vars: expr | None;
}

# --- match_case (product) ---
obj match_case(ast_node) {
    has pattern: pattern,
        guard: expr | None,
        body: list[stmt];
}

# --- pattern ---
obj pattern(ast_node) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchValue(pattern) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchSingleton(pattern) {
    has value: PyObj,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchSequence(pattern) {
    has patterns: list[pattern],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchMapping(pattern) {
    has keys: list[expr],
        patterns: list[pattern],
        rest: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchClass(pattern) {
    has cls: expr,
        patterns: list[pattern],
        kwd_attrs: list[str],
        kwd_patterns: list[pattern],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchStar(pattern) {
    has name: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchAs(pattern) {
    has pattern: pattern | None,
        name: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj MatchOr(pattern) {
    has patterns: list[pattern],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

# --- type_ignore ---
obj type_ignore(ast_node) {}

obj TypeIgnore(type_ignore) {
    has lineno: int,
        tag: str;
}

# --- type_param ---
obj type_param(ast_node) {
    has name: str,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj TypeVar(type_param) {
    has name: str,
        bound: expr | None,
        default_value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj ParamSpec(type_param) {
    has name: str,
        default_value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}

obj TypeVarTuple(type_param) {
    has name: str,
        default_value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;
}
