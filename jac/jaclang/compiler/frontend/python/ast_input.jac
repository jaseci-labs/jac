"""Typed conversion and schema checks for Python AST input."""
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
import from jaclang.runtime.python.objects { PyObj }
import from jaclang.runtime.python.native_services { runtime_failure, take_buffer }
import from jaclang.runtime.python.constant_input { read_constant }
import from c {
    def jacpy_field(handle: u64, name: str) -> u64;  def jacpy_optional_field(
        handle: u64, name: str
    ) -> u64;  def jacpy_ast_is(handle: u64, name: str) -> i64;  def jacpy_value_kind(
        handle: u64
    ) -> i64;  def jacpy_is_list(handle: u64) -> i64;  def jacpy_sequence_size(
        handle: u64
    ) -> i64;  def jacpy_sequence_item(handle: u64, index: i64) -> u64;  def jacpy_integer_value(
        handle: u64
    ) -> i64;  def jacpy_error_pending -> i64;  def jacpy_utf8(handle: u64) -> u64;  def jacpy_release(
        handle: u64
    );
}

def ast_instance(handle: u64, name: str) -> bool {
    result = jacpy_ast_is(handle, name);
    if result < 0 {
        raise runtime_failure();
    }
    return result != 0;
}

def read_PyObj(handle: u64, depth: int) -> PyObj {
    return read_constant(handle);
}

def field_PyObj(handle: u64, name: str, depth: int, optional: bool = False) -> PyObj {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_PyObj(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_alias(handle: u64, depth: int) -> alias {
    result = read_node(handle, depth);
    if not isinstance(result, alias) {
        raise TypeError("AST field requires alias");
    }
    return result as alias;
}

def field_alias(handle: u64, name: str, depth: int, optional: bool = False) -> alias {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_alias(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_arg(handle: u64, depth: int) -> arg {
    result = read_node(handle, depth);
    if not isinstance(result, arg) {
        raise TypeError("AST field requires arg");
    }
    return result as arg;
}

def field_arg(handle: u64, name: str, depth: int, optional: bool = False) -> arg {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_arg(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_arg_optional(handle: u64, depth: int) -> arg | None {
    if jacpy_value_kind(handle) == 0 {
        return None;
    }
    return read_arg(handle, depth);
}

def field_arg_optional(
    handle: u64, name: str, depth: int, optional: bool = False
) -> arg | None {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_arg_optional(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_arguments(handle: u64, depth: int) -> arguments {
    result = read_node(handle, depth);
    if not isinstance(result, arguments) {
        raise TypeError("AST field requires arguments");
    }
    return result as arguments;
}

def field_arguments(
    handle: u64, name: str, depth: int, optional: bool = False
) -> arguments {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_arguments(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_boolop(handle: u64, depth: int) -> boolop {
    result = read_node(handle, depth);
    if not isinstance(result, boolop) {
        raise TypeError("AST field requires boolop");
    }
    return result as boolop;
}

def field_boolop(handle: u64, name: str, depth: int, optional: bool = False) -> boolop {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_boolop(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_cmpop(handle: u64, depth: int) -> cmpop {
    result = read_node(handle, depth);
    if not isinstance(result, cmpop) {
        raise TypeError("AST field requires cmpop");
    }
    return result as cmpop;
}

def field_cmpop(handle: u64, name: str, depth: int, optional: bool = False) -> cmpop {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_cmpop(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_comprehension(handle: u64, depth: int) -> comprehension {
    result = read_node(handle, depth);
    if not isinstance(result, comprehension) {
        raise TypeError("AST field requires comprehension");
    }
    return result as comprehension;
}

def field_comprehension(
    handle: u64, name: str, depth: int, optional: bool = False
) -> comprehension {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_comprehension(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_excepthandler(handle: u64, depth: int) -> excepthandler {
    result = read_node(handle, depth);
    if not isinstance(result, excepthandler) {
        raise TypeError("AST field requires excepthandler");
    }
    return result as excepthandler;
}

def field_excepthandler(
    handle: u64, name: str, depth: int, optional: bool = False
) -> excepthandler {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_excepthandler(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_expr(handle: u64, depth: int) -> expr {
    result = read_node(handle, depth);
    if not isinstance(result, expr) {
        raise TypeError("AST field requires expr");
    }
    return result as expr;
}

def field_expr(handle: u64, name: str, depth: int, optional: bool = False) -> expr {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_expr(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_expr_optional(handle: u64, depth: int) -> expr | None {
    if jacpy_value_kind(handle) == 0 {
        return None;
    }
    return read_expr(handle, depth);
}

def field_expr_optional(
    handle: u64, name: str, depth: int, optional: bool = False
) -> expr | None {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_expr_optional(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_expr_context(handle: u64, depth: int) -> expr_context {
    result = read_node(handle, depth);
    if not isinstance(result, expr_context) {
        raise TypeError("AST field requires expr_context");
    }
    return result as expr_context;
}

def field_expr_context(
    handle: u64, name: str, depth: int, optional: bool = False
) -> expr_context {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_expr_context(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_int(handle: u64, depth: int) -> int {
    kind = jacpy_value_kind(handle);
    if kind != 2 and kind != 3 {
        raise ValueError("invalid integer value");
    }
    result = int(jacpy_integer_value(handle));
    if jacpy_error_pending() != 0 {
        raise runtime_failure();
    }
    if result < -2147483648 or result > 2147483647 {
        raise OverflowError("Python int too large to convert to C int");
    }
    return result;
}

def field_int(handle: u64, name: str, depth: int, optional: bool = False) -> int {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_int(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_int_optional(handle: u64, depth: int) -> int | None {
    if jacpy_value_kind(handle) == 0 {
        return None;
    }
    return read_int(handle, depth);
}

def field_int_optional(
    handle: u64, name: str, depth: int, optional: bool = False
) -> int | None {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_int_optional(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_keyword(handle: u64, depth: int) -> keyword {
    result = read_node(handle, depth);
    if not isinstance(result, keyword) {
        raise TypeError("AST field requires keyword");
    }
    return result as keyword;
}

def field_keyword(
    handle: u64, name: str, depth: int, optional: bool = False
) -> keyword {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_keyword(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_alias(handle: u64, depth: int) -> list[alias] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[alias] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_alias(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_alias(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[alias] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_alias(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_arg(handle: u64, depth: int) -> list[arg] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[arg] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_arg(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_arg(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[arg] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_arg(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_cmpop(handle: u64, depth: int) -> list[cmpop] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[cmpop] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_cmpop(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_cmpop(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[cmpop] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_cmpop(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_comprehension(handle: u64, depth: int) -> list[comprehension] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[comprehension] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_comprehension(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_comprehension(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[comprehension] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_comprehension(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_excepthandler(handle: u64, depth: int) -> list[excepthandler] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[excepthandler] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_excepthandler(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_excepthandler(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[excepthandler] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_excepthandler(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_expr_optional(handle: u64, depth: int) -> list[expr | None] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[expr | None] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_expr_optional(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_expr_optional(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[expr | None] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_expr_optional(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_expr(handle: u64, depth: int) -> list[expr] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[expr] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_expr(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_expr(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[expr] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_expr(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_keyword(handle: u64, depth: int) -> list[keyword] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[keyword] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_keyword(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_keyword(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[keyword] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_keyword(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_match_case(handle: u64, depth: int) -> list[match_case] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[match_case] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_match_case(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_match_case(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[match_case] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_match_case(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_pattern(handle: u64, depth: int) -> list[pattern] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[pattern] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_pattern(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_pattern(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[pattern] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_pattern(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_stmt(handle: u64, depth: int) -> list[stmt] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[stmt] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_stmt(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_stmt(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[stmt] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_stmt(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_str(handle: u64, depth: int) -> list[str] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[str] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_str(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_str(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[str] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_str(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_type_ignore(handle: u64, depth: int) -> list[type_ignore] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[type_ignore] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_type_ignore(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_type_ignore(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[type_ignore] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_type_ignore(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_type_param(handle: u64, depth: int) -> list[type_param] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[type_param] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_type_param(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_type_param(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[type_param] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_type_param(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_list_withitem(handle: u64, depth: int) -> list[withitem] {
    if jacpy_is_list(handle) == 0 {
        raise TypeError("AST field must be a list");
    }
    result: list[withitem] = [];
    for index in range(int(jacpy_sequence_size(handle))) {
        item = jacpy_sequence_item(handle, i64(index));
        if item == 0 {
            raise runtime_failure();
        }
        try {
            result.append(read_withitem(item, depth + 1));
        } finally {
            jacpy_release(item);
        }
    }
    return result;
}

def field_list_withitem(
    handle: u64, name: str, depth: int, optional: bool = False
) -> list[withitem] {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_list_withitem(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_match_case(handle: u64, depth: int) -> match_case {
    result = read_node(handle, depth);
    if not isinstance(result, match_case) {
        raise TypeError("AST field requires match_case");
    }
    return result as match_case;
}

def field_match_case(
    handle: u64, name: str, depth: int, optional: bool = False
) -> match_case {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_match_case(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_operator(handle: u64, depth: int) -> operator {
    result = read_node(handle, depth);
    if not isinstance(result, operator) {
        raise TypeError("AST field requires operator");
    }
    return result as operator;
}

def field_operator(
    handle: u64, name: str, depth: int, optional: bool = False
) -> operator {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_operator(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_pattern(handle: u64, depth: int) -> pattern {
    result = read_node(handle, depth);
    if not isinstance(result, pattern) {
        raise TypeError("AST field requires pattern");
    }
    return result as pattern;
}

def field_pattern(
    handle: u64, name: str, depth: int, optional: bool = False
) -> pattern {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_pattern(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_pattern_optional(handle: u64, depth: int) -> pattern | None {
    if jacpy_value_kind(handle) == 0 {
        return None;
    }
    return read_pattern(handle, depth);
}

def field_pattern_optional(
    handle: u64, name: str, depth: int, optional: bool = False
) -> pattern | None {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_pattern_optional(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_stmt(handle: u64, depth: int) -> stmt {
    result = read_node(handle, depth);
    if not isinstance(result, stmt) {
        raise TypeError("AST field requires stmt");
    }
    return result as stmt;
}

def field_stmt(handle: u64, name: str, depth: int, optional: bool = False) -> stmt {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_stmt(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_str(handle: u64, depth: int) -> str {
    if jacpy_value_kind(handle) != 6 {
        raise TypeError("identifier must be of type str");
    }
    return bytes(take_buffer(jacpy_utf8(handle))).decode("utf-8", "surrogatepass");
}

def field_str(handle: u64, name: str, depth: int, optional: bool = False) -> str {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_str(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_str_optional(handle: u64, depth: int) -> str | None {
    if jacpy_value_kind(handle) == 0 {
        return None;
    }
    return read_str(handle, depth);
}

def field_str_optional(
    handle: u64, name: str, depth: int, optional: bool = False
) -> str | None {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_str_optional(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_type_ignore(handle: u64, depth: int) -> type_ignore {
    result = read_node(handle, depth);
    if not isinstance(result, type_ignore) {
        raise TypeError("AST field requires type_ignore");
    }
    return result as type_ignore;
}

def field_type_ignore(
    handle: u64, name: str, depth: int, optional: bool = False
) -> type_ignore {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_type_ignore(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_type_param(handle: u64, depth: int) -> type_param {
    result = read_node(handle, depth);
    if not isinstance(result, type_param) {
        raise TypeError("AST field requires type_param");
    }
    return result as type_param;
}

def field_type_param(
    handle: u64, name: str, depth: int, optional: bool = False
) -> type_param {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_type_param(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_unaryop(handle: u64, depth: int) -> unaryop {
    result = read_node(handle, depth);
    if not isinstance(result, unaryop) {
        raise TypeError("AST field requires unaryop");
    }
    return result as unaryop;
}

def field_unaryop(
    handle: u64, name: str, depth: int, optional: bool = False
) -> unaryop {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_unaryop(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_withitem(handle: u64, depth: int) -> withitem {
    result = read_node(handle, depth);
    if not isinstance(result, withitem) {
        raise TypeError("AST field requires withitem");
    }
    return result as withitem;
}

def field_withitem(
    handle: u64, name: str, depth: int, optional: bool = False
) -> withitem {
    value = jacpy_optional_field(handle, name)
        if optional
        else jacpy_field(handle, name);
    if value == 0 {
        raise runtime_failure();
    }
    try {
        return read_withitem(value, depth);
    } finally {
        jacpy_release(value);
    }
}

def read_node_Module(handle: u64, depth: int) -> Module {
    return Module(
        body=field_list_stmt(handle, "body", depth + 1),
        type_ignores=field_list_type_ignore(handle, "type_ignores", depth + 1)
    );
}

def read_node_Interactive(handle: u64, depth: int) -> Interactive {
    return Interactive(body=field_list_stmt(handle, "body", depth + 1));
}

def read_node_Expression(handle: u64, depth: int) -> Expression {
    return Expression(body=field_expr(handle, "body", depth + 1));
}

def read_node_FunctionType(handle: u64, depth: int) -> FunctionType {
    return FunctionType(
        argtypes=field_list_expr(handle, "argtypes", depth + 1),
        returns=field_expr(handle, "returns", depth + 1)
    );
}

def read_node_FunctionDef(handle: u64, depth: int) -> FunctionDef {
    return FunctionDef(
        name=field_str(handle, "name", depth + 1),
        args=field_arguments(handle, "args", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        decorator_list=field_list_expr(handle, "decorator_list", depth + 1),
        returns=field_expr_optional(handle, "returns", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        type_params=field_list_type_param(handle, "type_params", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_AsyncFunctionDef(handle: u64, depth: int) -> AsyncFunctionDef {
    return AsyncFunctionDef(
        name=field_str(handle, "name", depth + 1),
        args=field_arguments(handle, "args", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        decorator_list=field_list_expr(handle, "decorator_list", depth + 1),
        returns=field_expr_optional(handle, "returns", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        type_params=field_list_type_param(handle, "type_params", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_ClassDef(handle: u64, depth: int) -> ClassDef {
    return ClassDef(
        name=field_str(handle, "name", depth + 1),
        bases=field_list_expr(handle, "bases", depth + 1),
        keywords=field_list_keyword(handle, "keywords", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        decorator_list=field_list_expr(handle, "decorator_list", depth + 1),
        type_params=field_list_type_param(handle, "type_params", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Return(handle: u64, depth: int) -> Return {
    return Return(
        value=field_expr_optional(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Delete(handle: u64, depth: int) -> Delete {
    return Delete(
        targets=field_list_expr(handle, "targets", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Assign(handle: u64, depth: int) -> Assign {
    return Assign(
        targets=field_list_expr(handle, "targets", depth + 1),
        value=field_expr(handle, "value", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_TypeAlias(handle: u64, depth: int) -> TypeAlias {
    return TypeAlias(
        name=field_expr(handle, "name", depth + 1),
        type_params=field_list_type_param(handle, "type_params", depth + 1),
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_AugAssign(handle: u64, depth: int) -> AugAssign {
    return AugAssign(
        target=field_expr(handle, "target", depth + 1),
        op=field_operator(handle, "op", depth + 1),
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_AnnAssign(handle: u64, depth: int) -> AnnAssign {
    return AnnAssign(
        target=field_expr(handle, "target", depth + 1),
        annotation=field_expr(handle, "annotation", depth + 1),
        value=field_expr_optional(handle, "value", depth + 1),
        simple=field_int(handle, "simple", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_For(handle: u64, depth: int) -> For {
    return For(
        target=field_expr(handle, "target", depth + 1),
        iter=field_expr(handle, "iter", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        orelse=field_list_stmt(handle, "orelse", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_AsyncFor(handle: u64, depth: int) -> AsyncFor {
    return AsyncFor(
        target=field_expr(handle, "target", depth + 1),
        iter=field_expr(handle, "iter", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        orelse=field_list_stmt(handle, "orelse", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_While(handle: u64, depth: int) -> While {
    return While(
        `test=field_expr(handle, "test", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        orelse=field_list_stmt(handle, "orelse", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_If(handle: u64, depth: int) -> If {
    return If(
        `test=field_expr(handle, "test", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        orelse=field_list_stmt(handle, "orelse", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_With(handle: u64, depth: int) -> With {
    return With(
        items=field_list_withitem(handle, "items", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_AsyncWith(handle: u64, depth: int) -> AsyncWith {
    return AsyncWith(
        items=field_list_withitem(handle, "items", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Match(handle: u64, depth: int) -> Match {
    return Match(
        subject=field_expr(handle, "subject", depth + 1),
        cases=field_list_match_case(handle, "cases", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Raise(handle: u64, depth: int) -> Raise {
    return Raise(
        exc=field_expr_optional(handle, "exc", depth + 1),
        cause=field_expr_optional(handle, "cause", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Try(handle: u64, depth: int) -> Try {
    return Try(
        body=field_list_stmt(handle, "body", depth + 1),
        handlers=field_list_excepthandler(handle, "handlers", depth + 1),
        orelse=field_list_stmt(handle, "orelse", depth + 1),
        finalbody=field_list_stmt(handle, "finalbody", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_TryStar(handle: u64, depth: int) -> TryStar {
    return TryStar(
        body=field_list_stmt(handle, "body", depth + 1),
        handlers=field_list_excepthandler(handle, "handlers", depth + 1),
        orelse=field_list_stmt(handle, "orelse", depth + 1),
        finalbody=field_list_stmt(handle, "finalbody", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Assert(handle: u64, depth: int) -> Assert {
    return Assert(
        `test=field_expr(handle, "test", depth + 1),
        msg=field_expr_optional(handle, "msg", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Import(handle: u64, depth: int) -> Import {
    return Import(
        names=field_list_alias(handle, "names", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_ImportFrom(handle: u64, depth: int) -> ImportFrom {
    return ImportFrom(
        module=field_str_optional(handle, "module", depth + 1),
        names=field_list_alias(handle, "names", depth + 1),
        level=field_int_optional(handle, "level", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Global(handle: u64, depth: int) -> Global {
    return Global(
        names=field_list_str(handle, "names", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Nonlocal(handle: u64, depth: int) -> Nonlocal {
    return Nonlocal(
        names=field_list_str(handle, "names", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Expr(handle: u64, depth: int) -> Expr {
    return Expr(
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Pass(handle: u64, depth: int) -> Pass {
    return Pass(
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Break(handle: u64, depth: int) -> Break {
    return Break(
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Continue(handle: u64, depth: int) -> Continue {
    return Continue(
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_BoolOp(handle: u64, depth: int) -> BoolOp {
    return BoolOp(
        op=field_boolop(handle, "op", depth + 1),
        values=field_list_expr(handle, "values", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_NamedExpr(handle: u64, depth: int) -> NamedExpr {
    return NamedExpr(
        target=field_expr(handle, "target", depth + 1),
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_BinOp(handle: u64, depth: int) -> BinOp {
    return BinOp(
        left=field_expr(handle, "left", depth + 1),
        op=field_operator(handle, "op", depth + 1),
        right=field_expr(handle, "right", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_UnaryOp(handle: u64, depth: int) -> UnaryOp {
    return UnaryOp(
        op=field_unaryop(handle, "op", depth + 1),
        operand=field_expr(handle, "operand", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Lambda(handle: u64, depth: int) -> Lambda {
    return Lambda(
        args=field_arguments(handle, "args", depth + 1),
        body=field_expr(handle, "body", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_IfExp(handle: u64, depth: int) -> IfExp {
    return IfExp(
        `test=field_expr(handle, "test", depth + 1),
        body=field_expr(handle, "body", depth + 1),
        orelse=field_expr(handle, "orelse", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Dict(handle: u64, depth: int) -> Dict {
    return Dict(
        keys=field_list_expr_optional(handle, "keys", depth + 1),
        values=field_list_expr(handle, "values", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Set(handle: u64, depth: int) -> Set {
    return Set(
        elts=field_list_expr(handle, "elts", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_ListComp(handle: u64, depth: int) -> ListComp {
    return ListComp(
        elt=field_expr(handle, "elt", depth + 1),
        generators=field_list_comprehension(handle, "generators", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_SetComp(handle: u64, depth: int) -> SetComp {
    return SetComp(
        elt=field_expr(handle, "elt", depth + 1),
        generators=field_list_comprehension(handle, "generators", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_DictComp(handle: u64, depth: int) -> DictComp {
    return DictComp(
        key=field_expr(handle, "key", depth + 1),
        value=field_expr(handle, "value", depth + 1),
        generators=field_list_comprehension(handle, "generators", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_GeneratorExp(handle: u64, depth: int) -> GeneratorExp {
    return GeneratorExp(
        elt=field_expr(handle, "elt", depth + 1),
        generators=field_list_comprehension(handle, "generators", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Await(handle: u64, depth: int) -> Await {
    return Await(
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Yield(handle: u64, depth: int) -> Yield {
    return Yield(
        value=field_expr_optional(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_YieldFrom(handle: u64, depth: int) -> YieldFrom {
    return YieldFrom(
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Compare(handle: u64, depth: int) -> Compare {
    return Compare(
        left=field_expr(handle, "left", depth + 1),
        ops=field_list_cmpop(handle, "ops", depth + 1),
        comparators=field_list_expr(handle, "comparators", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Call(handle: u64, depth: int) -> Call {
    return Call(
        func=field_expr(handle, "func", depth + 1),
        args=field_list_expr(handle, "args", depth + 1),
        keywords=field_list_keyword(handle, "keywords", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_FormattedValue(handle: u64, depth: int) -> FormattedValue {
    return FormattedValue(
        value=field_expr(handle, "value", depth + 1),
        conversion=field_int(handle, "conversion", depth + 1),
        format_spec=field_expr_optional(handle, "format_spec", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Interpolation(handle: u64, depth: int) -> Interpolation {
    return Interpolation(
        value=field_expr(handle, "value", depth + 1),
        str=field_PyObj(handle, "str", depth + 1),
        conversion=field_int(handle, "conversion", depth + 1),
        format_spec=field_expr_optional(handle, "format_spec", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_JoinedStr(handle: u64, depth: int) -> JoinedStr {
    return JoinedStr(
        values=field_list_expr(handle, "values", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_TemplateStr(handle: u64, depth: int) -> TemplateStr {
    return TemplateStr(
        values=field_list_expr(handle, "values", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Constant(handle: u64, depth: int) -> Constant {
    return Constant(
        value=field_PyObj(handle, "value", depth + 1),
        kind=field_str_optional(handle, "kind", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Attribute(handle: u64, depth: int) -> Attribute {
    return Attribute(
        value=field_expr(handle, "value", depth + 1),
        attr=field_str(handle, "attr", depth + 1),
        ctx=field_expr_context(handle, "ctx", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Subscript(handle: u64, depth: int) -> Subscript {
    return Subscript(
        value=field_expr(handle, "value", depth + 1),
        slice=field_expr(handle, "slice", depth + 1),
        ctx=field_expr_context(handle, "ctx", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Starred(handle: u64, depth: int) -> Starred {
    return Starred(
        value=field_expr(handle, "value", depth + 1),
        ctx=field_expr_context(handle, "ctx", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Name(handle: u64, depth: int) -> Name {
    return Name(
        id=field_str(handle, "id", depth + 1),
        ctx=field_expr_context(handle, "ctx", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_List(handle: u64, depth: int) -> List {
    return List(
        elts=field_list_expr(handle, "elts", depth + 1),
        ctx=field_expr_context(handle, "ctx", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Tuple(handle: u64, depth: int) -> Tuple {
    return Tuple(
        elts=field_list_expr(handle, "elts", depth + 1),
        ctx=field_expr_context(handle, "ctx", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Slice(handle: u64, depth: int) -> Slice {
    return Slice(
        lower=field_expr_optional(handle, "lower", depth + 1),
        upper=field_expr_optional(handle, "upper", depth + 1),
        step=field_expr_optional(handle, "step", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_Load(handle: u64, depth: int) -> Load {
    return Load();
}

def read_node_Store(handle: u64, depth: int) -> Store {
    return Store();
}

def read_node_Del(handle: u64, depth: int) -> Del {
    return Del();
}

def read_node_And(handle: u64, depth: int) -> And {
    return And();
}

def read_node_Or(handle: u64, depth: int) -> Or {
    return Or();
}

def read_node_Add(handle: u64, depth: int) -> Add {
    return Add();
}

def read_node_Sub(handle: u64, depth: int) -> Sub {
    return Sub();
}

def read_node_Mult(handle: u64, depth: int) -> Mult {
    return Mult();
}

def read_node_MatMult(handle: u64, depth: int) -> MatMult {
    return MatMult();
}

def read_node_Div(handle: u64, depth: int) -> Div {
    return Div();
}

def read_node_Mod(handle: u64, depth: int) -> Mod {
    return Mod();
}

def read_node_Pow(handle: u64, depth: int) -> Pow {
    return Pow();
}

def read_node_LShift(handle: u64, depth: int) -> LShift {
    return LShift();
}

def read_node_RShift(handle: u64, depth: int) -> RShift {
    return RShift();
}

def read_node_BitOr(handle: u64, depth: int) -> BitOr {
    return BitOr();
}

def read_node_BitXor(handle: u64, depth: int) -> BitXor {
    return BitXor();
}

def read_node_BitAnd(handle: u64, depth: int) -> BitAnd {
    return BitAnd();
}

def read_node_FloorDiv(handle: u64, depth: int) -> FloorDiv {
    return FloorDiv();
}

def read_node_Invert(handle: u64, depth: int) -> Invert {
    return Invert();
}

def read_node_Not(handle: u64, depth: int) -> Not {
    return Not();
}

def read_node_UAdd(handle: u64, depth: int) -> UAdd {
    return UAdd();
}

def read_node_USub(handle: u64, depth: int) -> USub {
    return USub();
}

def read_node_Eq(handle: u64, depth: int) -> Eq {
    return Eq();
}

def read_node_NotEq(handle: u64, depth: int) -> NotEq {
    return NotEq();
}

def read_node_Lt(handle: u64, depth: int) -> Lt {
    return Lt();
}

def read_node_LtE(handle: u64, depth: int) -> LtE {
    return LtE();
}

def read_node_Gt(handle: u64, depth: int) -> Gt {
    return Gt();
}

def read_node_GtE(handle: u64, depth: int) -> GtE {
    return GtE();
}

def read_node_Is(handle: u64, depth: int) -> Is {
    return Is();
}

def read_node_IsNot(handle: u64, depth: int) -> IsNot {
    return IsNot();
}

def read_node_In(handle: u64, depth: int) -> In {
    return In();
}

def read_node_NotIn(handle: u64, depth: int) -> NotIn {
    return NotIn();
}

def read_node_comprehension(handle: u64, depth: int) -> comprehension {
    return comprehension(
        target=field_expr(handle, "target", depth + 1),
        iter=field_expr(handle, "iter", depth + 1),
        ifs=field_list_expr(handle, "ifs", depth + 1),
        is_async=field_int(handle, "is_async", depth + 1)
    );
}

def read_node_ExceptHandler(handle: u64, depth: int) -> ExceptHandler {
    return ExceptHandler(
        type=field_expr_optional(handle, "type", depth + 1),
        name=field_str_optional(handle, "name", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_arguments(handle: u64, depth: int) -> arguments {
    return arguments(
        posonlyargs=field_list_arg(handle, "posonlyargs", depth + 1),
        args=field_list_arg(handle, "args", depth + 1),
        vararg=field_arg_optional(handle, "vararg", depth + 1),
        kwonlyargs=field_list_arg(handle, "kwonlyargs", depth + 1),
        kw_defaults=field_list_expr_optional(handle, "kw_defaults", depth + 1),
        kwarg=field_arg_optional(handle, "kwarg", depth + 1),
        defaults=field_list_expr(handle, "defaults", depth + 1)
    );
}

def read_node_arg(handle: u64, depth: int) -> arg {
    return arg(
        arg=field_str(handle, "arg", depth + 1),
        annotation=field_expr_optional(handle, "annotation", depth + 1),
        type_comment=field_str_optional(handle, "type_comment", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_keyword(handle: u64, depth: int) -> keyword {
    return keyword(
        arg=field_str_optional(handle, "arg", depth + 1),
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_alias(handle: u64, depth: int) -> alias {
    return alias(
        name=field_str(handle, "name", depth + 1),
        asname=field_str_optional(handle, "asname", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_withitem(handle: u64, depth: int) -> withitem {
    return withitem(
        context_expr=field_expr(handle, "context_expr", depth + 1),
        optional_vars=field_expr_optional(handle, "optional_vars", depth + 1)
    );
}

def read_node_match_case(handle: u64, depth: int) -> match_case {
    return match_case(
        pattern=field_pattern(handle, "pattern", depth + 1),
        guard=field_expr_optional(handle, "guard", depth + 1),
        body=field_list_stmt(handle, "body", depth + 1)
    );
}

def read_node_MatchValue(handle: u64, depth: int) -> MatchValue {
    return MatchValue(
        value=field_expr(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchSingleton(handle: u64, depth: int) -> MatchSingleton {
    return MatchSingleton(
        value=field_PyObj(handle, "value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchSequence(handle: u64, depth: int) -> MatchSequence {
    return MatchSequence(
        patterns=field_list_pattern(handle, "patterns", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchMapping(handle: u64, depth: int) -> MatchMapping {
    return MatchMapping(
        keys=field_list_expr(handle, "keys", depth + 1),
        patterns=field_list_pattern(handle, "patterns", depth + 1),
        rest=field_str_optional(handle, "rest", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchClass(handle: u64, depth: int) -> MatchClass {
    return MatchClass(
        cls=field_expr(handle, "cls", depth + 1),
        patterns=field_list_pattern(handle, "patterns", depth + 1),
        kwd_attrs=field_list_str(handle, "kwd_attrs", depth + 1),
        kwd_patterns=field_list_pattern(handle, "kwd_patterns", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchStar(handle: u64, depth: int) -> MatchStar {
    return MatchStar(
        name=field_str_optional(handle, "name", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchAs(handle: u64, depth: int) -> MatchAs {
    return MatchAs(
        pattern=field_pattern_optional(handle, "pattern", depth + 1),
        name=field_str_optional(handle, "name", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_MatchOr(handle: u64, depth: int) -> MatchOr {
    return MatchOr(
        patterns=field_list_pattern(handle, "patterns", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_TypeIgnore(handle: u64, depth: int) -> TypeIgnore {
    return TypeIgnore(
        lineno=field_int(handle, "lineno", depth + 1),
        tag=field_str(handle, "tag", depth + 1)
    );
}

def read_node_TypeVar(handle: u64, depth: int) -> TypeVar {
    return TypeVar(
        name=field_str(handle, "name", depth + 1),
        bound=field_expr_optional(handle, "bound", depth + 1),
        default_value=field_expr_optional(handle, "default_value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_ParamSpec(handle: u64, depth: int) -> ParamSpec {
    return ParamSpec(
        name=field_str(handle, "name", depth + 1),
        default_value=field_expr_optional(handle, "default_value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node_TypeVarTuple(handle: u64, depth: int) -> TypeVarTuple {
    return TypeVarTuple(
        name=field_str(handle, "name", depth + 1),
        default_value=field_expr_optional(handle, "default_value", depth + 1),
        lineno=field_int(handle, "lineno", depth + 1),
        col_offset=field_int(handle, "col_offset", depth + 1),
        end_lineno=field_int_optional(handle, "end_lineno", depth + 1, True),
        end_col_offset=field_int_optional(handle, "end_col_offset", depth + 1, True)
    );
}

def read_node(handle: u64, depth: int = 0) -> ast_node {
    if depth > 1000 {
        raise RecursionError("maximum recursion depth exceeded during AST conversion");
    }
    if ast_instance(handle, "Module") {
        return read_node_Module(handle, depth);
    }
    if ast_instance(handle, "Interactive") {
        return read_node_Interactive(handle, depth);
    }
    if ast_instance(handle, "Expression") {
        return read_node_Expression(handle, depth);
    }
    if ast_instance(handle, "FunctionType") {
        return read_node_FunctionType(handle, depth);
    }
    if ast_instance(handle, "FunctionDef") {
        return read_node_FunctionDef(handle, depth);
    }
    if ast_instance(handle, "AsyncFunctionDef") {
        return read_node_AsyncFunctionDef(handle, depth);
    }
    if ast_instance(handle, "ClassDef") {
        return read_node_ClassDef(handle, depth);
    }
    if ast_instance(handle, "Return") {
        return read_node_Return(handle, depth);
    }
    if ast_instance(handle, "Delete") {
        return read_node_Delete(handle, depth);
    }
    if ast_instance(handle, "Assign") {
        return read_node_Assign(handle, depth);
    }
    if ast_instance(handle, "TypeAlias") {
        return read_node_TypeAlias(handle, depth);
    }
    if ast_instance(handle, "AugAssign") {
        return read_node_AugAssign(handle, depth);
    }
    if ast_instance(handle, "AnnAssign") {
        return read_node_AnnAssign(handle, depth);
    }
    if ast_instance(handle, "For") {
        return read_node_For(handle, depth);
    }
    if ast_instance(handle, "AsyncFor") {
        return read_node_AsyncFor(handle, depth);
    }
    if ast_instance(handle, "While") {
        return read_node_While(handle, depth);
    }
    if ast_instance(handle, "If") {
        return read_node_If(handle, depth);
    }
    if ast_instance(handle, "With") {
        return read_node_With(handle, depth);
    }
    if ast_instance(handle, "AsyncWith") {
        return read_node_AsyncWith(handle, depth);
    }
    if ast_instance(handle, "Match") {
        return read_node_Match(handle, depth);
    }
    if ast_instance(handle, "Raise") {
        return read_node_Raise(handle, depth);
    }
    if ast_instance(handle, "Try") {
        return read_node_Try(handle, depth);
    }
    if ast_instance(handle, "TryStar") {
        return read_node_TryStar(handle, depth);
    }
    if ast_instance(handle, "Assert") {
        return read_node_Assert(handle, depth);
    }
    if ast_instance(handle, "Import") {
        return read_node_Import(handle, depth);
    }
    if ast_instance(handle, "ImportFrom") {
        return read_node_ImportFrom(handle, depth);
    }
    if ast_instance(handle, "Global") {
        return read_node_Global(handle, depth);
    }
    if ast_instance(handle, "Nonlocal") {
        return read_node_Nonlocal(handle, depth);
    }
    if ast_instance(handle, "Expr") {
        return read_node_Expr(handle, depth);
    }
    if ast_instance(handle, "Pass") {
        return read_node_Pass(handle, depth);
    }
    if ast_instance(handle, "Break") {
        return read_node_Break(handle, depth);
    }
    if ast_instance(handle, "Continue") {
        return read_node_Continue(handle, depth);
    }
    if ast_instance(handle, "BoolOp") {
        return read_node_BoolOp(handle, depth);
    }
    if ast_instance(handle, "NamedExpr") {
        return read_node_NamedExpr(handle, depth);
    }
    if ast_instance(handle, "BinOp") {
        return read_node_BinOp(handle, depth);
    }
    if ast_instance(handle, "UnaryOp") {
        return read_node_UnaryOp(handle, depth);
    }
    if ast_instance(handle, "Lambda") {
        return read_node_Lambda(handle, depth);
    }
    if ast_instance(handle, "IfExp") {
        return read_node_IfExp(handle, depth);
    }
    if ast_instance(handle, "Dict") {
        return read_node_Dict(handle, depth);
    }
    if ast_instance(handle, "Set") {
        return read_node_Set(handle, depth);
    }
    if ast_instance(handle, "ListComp") {
        return read_node_ListComp(handle, depth);
    }
    if ast_instance(handle, "SetComp") {
        return read_node_SetComp(handle, depth);
    }
    if ast_instance(handle, "DictComp") {
        return read_node_DictComp(handle, depth);
    }
    if ast_instance(handle, "GeneratorExp") {
        return read_node_GeneratorExp(handle, depth);
    }
    if ast_instance(handle, "Await") {
        return read_node_Await(handle, depth);
    }
    if ast_instance(handle, "Yield") {
        return read_node_Yield(handle, depth);
    }
    if ast_instance(handle, "YieldFrom") {
        return read_node_YieldFrom(handle, depth);
    }
    if ast_instance(handle, "Compare") {
        return read_node_Compare(handle, depth);
    }
    if ast_instance(handle, "Call") {
        return read_node_Call(handle, depth);
    }
    if ast_instance(handle, "FormattedValue") {
        return read_node_FormattedValue(handle, depth);
    }
    if ast_instance(handle, "Interpolation") {
        return read_node_Interpolation(handle, depth);
    }
    if ast_instance(handle, "JoinedStr") {
        return read_node_JoinedStr(handle, depth);
    }
    if ast_instance(handle, "TemplateStr") {
        return read_node_TemplateStr(handle, depth);
    }
    if ast_instance(handle, "Constant") {
        return read_node_Constant(handle, depth);
    }
    if ast_instance(handle, "Attribute") {
        return read_node_Attribute(handle, depth);
    }
    if ast_instance(handle, "Subscript") {
        return read_node_Subscript(handle, depth);
    }
    if ast_instance(handle, "Starred") {
        return read_node_Starred(handle, depth);
    }
    if ast_instance(handle, "Name") {
        return read_node_Name(handle, depth);
    }
    if ast_instance(handle, "List") {
        return read_node_List(handle, depth);
    }
    if ast_instance(handle, "Tuple") {
        return read_node_Tuple(handle, depth);
    }
    if ast_instance(handle, "Slice") {
        return read_node_Slice(handle, depth);
    }
    if ast_instance(handle, "Load") {
        return read_node_Load(handle, depth);
    }
    if ast_instance(handle, "Store") {
        return read_node_Store(handle, depth);
    }
    if ast_instance(handle, "Del") {
        return read_node_Del(handle, depth);
    }
    if ast_instance(handle, "And") {
        return read_node_And(handle, depth);
    }
    if ast_instance(handle, "Or") {
        return read_node_Or(handle, depth);
    }
    if ast_instance(handle, "Add") {
        return read_node_Add(handle, depth);
    }
    if ast_instance(handle, "Sub") {
        return read_node_Sub(handle, depth);
    }
    if ast_instance(handle, "Mult") {
        return read_node_Mult(handle, depth);
    }
    if ast_instance(handle, "MatMult") {
        return read_node_MatMult(handle, depth);
    }
    if ast_instance(handle, "Div") {
        return read_node_Div(handle, depth);
    }
    if ast_instance(handle, "Mod") {
        return read_node_Mod(handle, depth);
    }
    if ast_instance(handle, "Pow") {
        return read_node_Pow(handle, depth);
    }
    if ast_instance(handle, "LShift") {
        return read_node_LShift(handle, depth);
    }
    if ast_instance(handle, "RShift") {
        return read_node_RShift(handle, depth);
    }
    if ast_instance(handle, "BitOr") {
        return read_node_BitOr(handle, depth);
    }
    if ast_instance(handle, "BitXor") {
        return read_node_BitXor(handle, depth);
    }
    if ast_instance(handle, "BitAnd") {
        return read_node_BitAnd(handle, depth);
    }
    if ast_instance(handle, "FloorDiv") {
        return read_node_FloorDiv(handle, depth);
    }
    if ast_instance(handle, "Invert") {
        return read_node_Invert(handle, depth);
    }
    if ast_instance(handle, "Not") {
        return read_node_Not(handle, depth);
    }
    if ast_instance(handle, "UAdd") {
        return read_node_UAdd(handle, depth);
    }
    if ast_instance(handle, "USub") {
        return read_node_USub(handle, depth);
    }
    if ast_instance(handle, "Eq") {
        return read_node_Eq(handle, depth);
    }
    if ast_instance(handle, "NotEq") {
        return read_node_NotEq(handle, depth);
    }
    if ast_instance(handle, "Lt") {
        return read_node_Lt(handle, depth);
    }
    if ast_instance(handle, "LtE") {
        return read_node_LtE(handle, depth);
    }
    if ast_instance(handle, "Gt") {
        return read_node_Gt(handle, depth);
    }
    if ast_instance(handle, "GtE") {
        return read_node_GtE(handle, depth);
    }
    if ast_instance(handle, "Is") {
        return read_node_Is(handle, depth);
    }
    if ast_instance(handle, "IsNot") {
        return read_node_IsNot(handle, depth);
    }
    if ast_instance(handle, "In") {
        return read_node_In(handle, depth);
    }
    if ast_instance(handle, "NotIn") {
        return read_node_NotIn(handle, depth);
    }
    if ast_instance(handle, "comprehension") {
        return read_node_comprehension(handle, depth);
    }
    if ast_instance(handle, "ExceptHandler") {
        return read_node_ExceptHandler(handle, depth);
    }
    if ast_instance(handle, "arguments") {
        return read_node_arguments(handle, depth);
    }
    if ast_instance(handle, "arg") {
        return read_node_arg(handle, depth);
    }
    if ast_instance(handle, "keyword") {
        return read_node_keyword(handle, depth);
    }
    if ast_instance(handle, "alias") {
        return read_node_alias(handle, depth);
    }
    if ast_instance(handle, "withitem") {
        return read_node_withitem(handle, depth);
    }
    if ast_instance(handle, "match_case") {
        return read_node_match_case(handle, depth);
    }
    if ast_instance(handle, "MatchValue") {
        return read_node_MatchValue(handle, depth);
    }
    if ast_instance(handle, "MatchSingleton") {
        return read_node_MatchSingleton(handle, depth);
    }
    if ast_instance(handle, "MatchSequence") {
        return read_node_MatchSequence(handle, depth);
    }
    if ast_instance(handle, "MatchMapping") {
        return read_node_MatchMapping(handle, depth);
    }
    if ast_instance(handle, "MatchClass") {
        return read_node_MatchClass(handle, depth);
    }
    if ast_instance(handle, "MatchStar") {
        return read_node_MatchStar(handle, depth);
    }
    if ast_instance(handle, "MatchAs") {
        return read_node_MatchAs(handle, depth);
    }
    if ast_instance(handle, "MatchOr") {
        return read_node_MatchOr(handle, depth);
    }
    if ast_instance(handle, "TypeIgnore") {
        return read_node_TypeIgnore(handle, depth);
    }
    if ast_instance(handle, "TypeVar") {
        return read_node_TypeVar(handle, depth);
    }
    if ast_instance(handle, "ParamSpec") {
        return read_node_ParamSpec(handle, depth);
    }
    if ast_instance(handle, "TypeVarTuple") {
        return read_node_TypeVarTuple(handle, depth);
    }
    raise TypeError("Expected a concrete AST node");
}
