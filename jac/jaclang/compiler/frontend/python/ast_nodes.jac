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

obj ast_node {
    def node_kind -> ast_kind abst;
}

obj mod(ast_node) {}

obj Module(mod) {
    has body: list[stmt],
        type_ignores: list[type_ignore];

    def node_kind -> ast_kind;
}

obj Interactive(mod) {
    has body: list[stmt];

    def node_kind -> ast_kind;
}

obj Expression(mod) {
    has body: expr;

    def node_kind -> ast_kind;
}

obj FunctionType(mod) {
    has argtypes: list[expr],
        returns: expr;

    def node_kind -> ast_kind;
}

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

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
}

obj Return(stmt) {
    has value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Delete(stmt) {
    has targets: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Assign(stmt) {
    has targets: list[expr],
        value: expr,
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj TypeAlias(stmt) {
    has name: expr,
        type_params: list[type_param],
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj AugAssign(stmt) {
    has target: expr,
        op: operator,
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
}

obj While(stmt) {
    has `test: expr,
        body: list[stmt],
        orelse: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj If(stmt) {
    has `test: expr,
        body: list[stmt],
        orelse: list[stmt],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj With(stmt) {
    has items: list[withitem],
        body: list[stmt],
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj AsyncWith(stmt) {
    has items: list[withitem],
        body: list[stmt],
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Match(stmt) {
    has subject: expr,
        cases: list[match_case],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Raise(stmt) {
    has exc: expr | None,
        cause: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
}

obj Assert(stmt) {
    has `test: expr,
        msg: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Import(stmt) {
    has names: list[alias],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj ImportFrom(stmt) {
    has module: str | None,
        names: list[alias],
        level: int | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Global(stmt) {
    has names: list[str],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Nonlocal(stmt) {
    has names: list[str],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Expr(stmt) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Pass(stmt) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Break(stmt) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Continue(stmt) {
    has lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

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

    def node_kind -> ast_kind;
}

obj NamedExpr(expr) {
    has target: expr,
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj BinOp(expr) {
    has left: expr,
        op: operator,
        right: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj UnaryOp(expr) {
    has op: unaryop,
        operand: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Lambda(expr) {
    has args: arguments,
        body: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj IfExp(expr) {
    has `test: expr,
        body: expr,
        orelse: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Dict(expr) {
    has keys: list[expr | None],
        values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Set(expr) {
    has elts: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj ListComp(expr) {
    has elt: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj SetComp(expr) {
    has elt: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj DictComp(expr) {
    has key: expr,
        value: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj GeneratorExp(expr) {
    has elt: expr,
        generators: list[comprehension],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Await(expr) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Yield(expr) {
    has value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj YieldFrom(expr) {
    has value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Compare(expr) {
    has left: expr,
        ops: list[cmpop],
        comparators: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Call(expr) {
    has func: expr,
        args: list[expr],
        keywords: list[keyword],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj FormattedValue(expr) {
    has value: expr,
        conversion: int,
        format_spec: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
}

obj JoinedStr(expr) {
    has values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj TemplateStr(expr) {
    has values: list[expr],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Constant(expr) {
    has value: PyObj,
        kind: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind {
        return ast_kind.Constant;
    }
}

obj Attribute(expr) {
    has value: expr,
        attr: str,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Subscript(expr) {
    has value: expr,
        slice: expr,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Starred(expr) {
    has value: expr,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Name(expr) {
    has id: str,
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj List(expr) {
    has elts: list[expr],
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Tuple(expr) {
    has elts: list[expr],
        ctx: expr_context,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj Slice(expr) {
    has lower: expr | None,
        upper: expr | None,
        step: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj expr_context(ast_node) {}

obj Load(expr_context) {
    def node_kind -> ast_kind;
}

obj Store(expr_context) {
    def node_kind -> ast_kind;
}

obj Del(expr_context) {
    def node_kind -> ast_kind;
}

obj boolop(ast_node) {}

obj And(boolop) {
    def node_kind -> ast_kind;
}

obj Or(boolop) {
    def node_kind -> ast_kind;
}

obj operator(ast_node) {}

obj Add(operator) {
    def node_kind -> ast_kind;
}

obj Sub(operator) {
    def node_kind -> ast_kind;
}

obj Mult(operator) {
    def node_kind -> ast_kind;
}

obj MatMult(operator) {
    def node_kind -> ast_kind;
}

obj Div(operator) {
    def node_kind -> ast_kind;
}

obj Mod(operator) {
    def node_kind -> ast_kind;
}

obj Pow(operator) {
    def node_kind -> ast_kind;
}

obj LShift(operator) {
    def node_kind -> ast_kind;
}

obj RShift(operator) {
    def node_kind -> ast_kind;
}

obj BitOr(operator) {
    def node_kind -> ast_kind;
}

obj BitXor(operator) {
    def node_kind -> ast_kind;
}

obj BitAnd(operator) {
    def node_kind -> ast_kind;
}

obj FloorDiv(operator) {
    def node_kind -> ast_kind;
}

obj unaryop(ast_node) {}

obj Invert(unaryop) {
    def node_kind -> ast_kind;
}

obj Not(unaryop) {
    def node_kind -> ast_kind;
}

obj UAdd(unaryop) {
    def node_kind -> ast_kind;
}

obj USub(unaryop) {
    def node_kind -> ast_kind;
}

obj cmpop(ast_node) {}

obj Eq(cmpop) {
    def node_kind -> ast_kind;
}

obj NotEq(cmpop) {
    def node_kind -> ast_kind;
}

obj Lt(cmpop) {
    def node_kind -> ast_kind;
}

obj LtE(cmpop) {
    def node_kind -> ast_kind;
}

obj Gt(cmpop) {
    def node_kind -> ast_kind;
}

obj GtE(cmpop) {
    def node_kind -> ast_kind;
}

obj Is(cmpop) {
    def node_kind -> ast_kind;
}

obj IsNot(cmpop) {
    def node_kind -> ast_kind;
}

obj In(cmpop) {
    def node_kind -> ast_kind;
}

obj NotIn(cmpop) {
    def node_kind -> ast_kind;
}

obj comprehension(ast_node) {
    has target: expr,
        iter: expr,
        ifs: list[expr],
        is_async: int;

    def node_kind -> ast_kind;
}

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

    def node_kind -> ast_kind;
}

obj arguments(ast_node) {
    has posonlyargs: list[arg],
        args: list[arg],
        vararg: arg | None,
        kwonlyargs: list[arg],
        kw_defaults: list[expr | None],
        kwarg: arg | None,
        defaults: list[expr];

    def node_kind -> ast_kind;
}

obj arg(ast_node) {
    has arg: str,
        annotation: expr | None,
        type_comment: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj keyword(ast_node) {
    has arg: str | None,
        value: expr,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj alias(ast_node) {
    has name: str,
        asname: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj withitem(ast_node) {
    has context_expr: expr,
        optional_vars: expr | None;

    def node_kind -> ast_kind;
}

obj match_case(ast_node) {
    has pattern: pattern,
        guard: expr | None,
        body: list[stmt];

    def node_kind -> ast_kind;
}

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

    def node_kind -> ast_kind;
}

obj MatchSingleton(pattern) {
    has value: PyObj,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj MatchSequence(pattern) {
    has patterns: list[pattern],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj MatchMapping(pattern) {
    has keys: list[expr],
        patterns: list[pattern],
        rest: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
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

    def node_kind -> ast_kind;
}

obj MatchStar(pattern) {
    has name: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj MatchAs(pattern) {
    has pattern: pattern | None,
        name: str | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj MatchOr(pattern) {
    has patterns: list[pattern],
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj type_ignore(ast_node) {}

obj TypeIgnore(type_ignore) {
    has lineno: int,
        tag: str;

    def node_kind -> ast_kind;
}

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

    def node_kind -> ast_kind;
}

obj ParamSpec(type_param) {
    has name: str,
        default_value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

obj TypeVarTuple(type_param) {
    has name: str,
        default_value: expr | None,
        lineno: int,
        col_offset: int,
        end_lineno: int | None,
        end_col_offset: int | None;

    def node_kind -> ast_kind;
}

impl Module.node_kind -> ast_kind {
    return ast_kind.Module;
}

impl Interactive.node_kind -> ast_kind {
    return ast_kind.Interactive;
}

impl Expression.node_kind -> ast_kind {
    return ast_kind.Expression;
}

impl FunctionType.node_kind -> ast_kind {
    return ast_kind.FunctionType;
}

impl FunctionDef.node_kind -> ast_kind {
    return ast_kind.FunctionDef;
}

impl AsyncFunctionDef.node_kind -> ast_kind {
    return ast_kind.AsyncFunctionDef;
}

impl ClassDef.node_kind -> ast_kind {
    return ast_kind.ClassDef;
}

impl Return.node_kind -> ast_kind {
    return ast_kind.Return;
}

impl Delete.node_kind -> ast_kind {
    return ast_kind.Delete;
}

impl Assign.node_kind -> ast_kind {
    return ast_kind.Assign;
}

impl TypeAlias.node_kind -> ast_kind {
    return ast_kind.TypeAlias;
}

impl AugAssign.node_kind -> ast_kind {
    return ast_kind.AugAssign;
}

impl AnnAssign.node_kind -> ast_kind {
    return ast_kind.AnnAssign;
}

impl For.node_kind -> ast_kind {
    return ast_kind.For;
}

impl AsyncFor.node_kind -> ast_kind {
    return ast_kind.AsyncFor;
}

impl While.node_kind -> ast_kind {
    return ast_kind.While;
}

impl If.node_kind -> ast_kind {
    return ast_kind.If;
}

impl With.node_kind -> ast_kind {
    return ast_kind.With;
}

impl AsyncWith.node_kind -> ast_kind {
    return ast_kind.AsyncWith;
}

impl Match.node_kind -> ast_kind {
    return ast_kind.Match;
}

impl Raise.node_kind -> ast_kind {
    return ast_kind.Raise;
}

impl Try.node_kind -> ast_kind {
    return ast_kind.Try;
}

impl TryStar.node_kind -> ast_kind {
    return ast_kind.TryStar;
}

impl Assert.node_kind -> ast_kind {
    return ast_kind.Assert;
}

impl Import.node_kind -> ast_kind {
    return ast_kind.Import;
}

impl ImportFrom.node_kind -> ast_kind {
    return ast_kind.ImportFrom;
}

impl Global.node_kind -> ast_kind {
    return ast_kind.Global;
}

impl Nonlocal.node_kind -> ast_kind {
    return ast_kind.Nonlocal;
}

impl Expr.node_kind -> ast_kind {
    return ast_kind.Expr;
}

impl Pass.node_kind -> ast_kind {
    return ast_kind.Pass;
}

impl Break.node_kind -> ast_kind {
    return ast_kind.Break;
}

impl Continue.node_kind -> ast_kind {
    return ast_kind.Continue;
}

impl BoolOp.node_kind -> ast_kind {
    return ast_kind.BoolOp;
}

impl NamedExpr.node_kind -> ast_kind {
    return ast_kind.NamedExpr;
}

impl BinOp.node_kind -> ast_kind {
    return ast_kind.BinOp;
}

impl UnaryOp.node_kind -> ast_kind {
    return ast_kind.UnaryOp;
}

impl Lambda.node_kind -> ast_kind {
    return ast_kind.Lambda;
}

impl IfExp.node_kind -> ast_kind {
    return ast_kind.IfExp;
}

impl Dict.node_kind -> ast_kind {
    return ast_kind.Dict;
}

impl Set.node_kind -> ast_kind {
    return ast_kind.Set;
}

impl ListComp.node_kind -> ast_kind {
    return ast_kind.ListComp;
}

impl SetComp.node_kind -> ast_kind {
    return ast_kind.SetComp;
}

impl DictComp.node_kind -> ast_kind {
    return ast_kind.DictComp;
}

impl GeneratorExp.node_kind -> ast_kind {
    return ast_kind.GeneratorExp;
}

impl Await.node_kind -> ast_kind {
    return ast_kind.Await;
}

impl Yield.node_kind -> ast_kind {
    return ast_kind.Yield;
}

impl YieldFrom.node_kind -> ast_kind {
    return ast_kind.YieldFrom;
}

impl Compare.node_kind -> ast_kind {
    return ast_kind.Compare;
}

impl Call.node_kind -> ast_kind {
    return ast_kind.Call;
}

impl FormattedValue.node_kind -> ast_kind {
    return ast_kind.FormattedValue;
}

impl Interpolation.node_kind -> ast_kind {
    return ast_kind.Interpolation;
}

impl JoinedStr.node_kind -> ast_kind {
    return ast_kind.JoinedStr;
}

impl TemplateStr.node_kind -> ast_kind {
    return ast_kind.TemplateStr;
}

impl Attribute.node_kind -> ast_kind {
    return ast_kind.Attribute;
}

impl Subscript.node_kind -> ast_kind {
    return ast_kind.Subscript;
}

impl Starred.node_kind -> ast_kind {
    return ast_kind.Starred;
}

impl Name.node_kind -> ast_kind {
    return ast_kind.Name;
}

impl List.node_kind -> ast_kind {
    return ast_kind.List;
}

impl Tuple.node_kind -> ast_kind {
    return ast_kind.Tuple;
}

impl Slice.node_kind -> ast_kind {
    return ast_kind.Slice;
}

impl Load.node_kind -> ast_kind {
    return ast_kind.Load;
}

impl Store.node_kind -> ast_kind {
    return ast_kind.Store;
}

impl Del.node_kind -> ast_kind {
    return ast_kind.Del;
}

impl And.node_kind -> ast_kind {
    return ast_kind.And;
}

impl Or.node_kind -> ast_kind {
    return ast_kind.Or;
}

impl Add.node_kind -> ast_kind {
    return ast_kind.Add;
}

impl Sub.node_kind -> ast_kind {
    return ast_kind.Sub;
}

impl Mult.node_kind -> ast_kind {
    return ast_kind.Mult;
}

impl MatMult.node_kind -> ast_kind {
    return ast_kind.MatMult;
}

impl Div.node_kind -> ast_kind {
    return ast_kind.Div;
}

impl Mod.node_kind -> ast_kind {
    return ast_kind.Mod;
}

impl Pow.node_kind -> ast_kind {
    return ast_kind.Pow;
}

impl LShift.node_kind -> ast_kind {
    return ast_kind.LShift;
}

impl RShift.node_kind -> ast_kind {
    return ast_kind.RShift;
}

impl BitOr.node_kind -> ast_kind {
    return ast_kind.BitOr;
}

impl BitXor.node_kind -> ast_kind {
    return ast_kind.BitXor;
}

impl BitAnd.node_kind -> ast_kind {
    return ast_kind.BitAnd;
}

impl FloorDiv.node_kind -> ast_kind {
    return ast_kind.FloorDiv;
}

impl Invert.node_kind -> ast_kind {
    return ast_kind.Invert;
}

impl Not.node_kind -> ast_kind {
    return ast_kind.Not;
}

impl UAdd.node_kind -> ast_kind {
    return ast_kind.UAdd;
}

impl USub.node_kind -> ast_kind {
    return ast_kind.USub;
}

impl Eq.node_kind -> ast_kind {
    return ast_kind.Eq;
}

impl NotEq.node_kind -> ast_kind {
    return ast_kind.NotEq;
}

impl Lt.node_kind -> ast_kind {
    return ast_kind.Lt;
}

impl LtE.node_kind -> ast_kind {
    return ast_kind.LtE;
}

impl Gt.node_kind -> ast_kind {
    return ast_kind.Gt;
}

impl GtE.node_kind -> ast_kind {
    return ast_kind.GtE;
}

impl Is.node_kind -> ast_kind {
    return ast_kind.Is;
}

impl IsNot.node_kind -> ast_kind {
    return ast_kind.IsNot;
}

impl In.node_kind -> ast_kind {
    return ast_kind.In;
}

impl NotIn.node_kind -> ast_kind {
    return ast_kind.NotIn;
}

impl comprehension.node_kind -> ast_kind {
    return ast_kind.comprehension;
}

impl ExceptHandler.node_kind -> ast_kind {
    return ast_kind.ExceptHandler;
}

impl arguments.node_kind -> ast_kind {
    return ast_kind.arguments;
}

impl arg.node_kind -> ast_kind {
    return ast_kind.arg;
}

impl keyword.node_kind -> ast_kind {
    return ast_kind.keyword;
}

impl alias.node_kind -> ast_kind {
    return ast_kind.alias;
}

impl withitem.node_kind -> ast_kind {
    return ast_kind.withitem;
}

impl match_case.node_kind -> ast_kind {
    return ast_kind.match_case;
}

impl MatchValue.node_kind -> ast_kind {
    return ast_kind.MatchValue;
}

impl MatchSingleton.node_kind -> ast_kind {
    return ast_kind.MatchSingleton;
}

impl MatchSequence.node_kind -> ast_kind {
    return ast_kind.MatchSequence;
}

impl MatchMapping.node_kind -> ast_kind {
    return ast_kind.MatchMapping;
}

impl MatchClass.node_kind -> ast_kind {
    return ast_kind.MatchClass;
}

impl MatchStar.node_kind -> ast_kind {
    return ast_kind.MatchStar;
}

impl MatchAs.node_kind -> ast_kind {
    return ast_kind.MatchAs;
}

impl MatchOr.node_kind -> ast_kind {
    return ast_kind.MatchOr;
}

impl TypeIgnore.node_kind -> ast_kind {
    return ast_kind.TypeIgnore;
}

impl TypeVar.node_kind -> ast_kind {
    return ast_kind.TypeVar;
}

impl ParamSpec.node_kind -> ast_kind {
    return ast_kind.ParamSpec;
}

impl TypeVarTuple.node_kind -> ast_kind {
    return ast_kind.TypeVarTuple;
}
