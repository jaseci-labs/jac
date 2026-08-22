# P0.7 parser action helpers (PLAN.md).
#
# Lowers CPython grammar actions (_PyAST_*, _PyPegen_*) into ast_nodes.jac
# objects. Generated parser rules call these helpers; this file is hand-written
# and grows with each grammar profile.

import from objects { PyObj, PyInt, PyBool, PyStr, PyFloat, PyComplex, py_none }
import from ast_nodes {
    ast_node,
    expr,
    mod,
    stmt,
    operator,
    unaryop,
    boolop,
    cmpop,
    expr_context,
    Expression,
    Module,
    Constant,
    Name,
    Load,
    Store,
    Del,
    Attribute,
    Subscript,
    Slice,
    AugAssign,
    Delete,
    BinOp,
    UnaryOp,
    BoolOp,
    Compare,
    Call,
    IfExp,
    Starred,
    Assign,
    AnnAssign,
    Expr,
    Return,
    Pass,
    Tuple,
    Add,
    Sub,
    Mult,
    Div,
    FloorDiv,
    Mod,
    MatMult,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    USub,
    UAdd,
    Invert,
    Not,
    And,
    Or,
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
    cmpop,
    keyword,
    Break,
    Continue,
    FunctionDef,
    AsyncFunctionDef,
    pattern,
    arguments,
    alias,
    arg,
    comprehension,
    excepthandler,
    match_case,
    type_param,
    withitem,
    MatchOr,
    ImportFrom,
}
import from peg_runtime { peg_parser, peg_token, peg_has_error, peg_raise_syntax_error }

obj pa_cmpop_expr_pair {
    has cmpop: cmpop,
        expr: expr;
}

obj kv_pair {
    has key: expr,
        value: expr;
}

obj kp_pair {
    has key: expr,
        pattern: pattern;
}

obj keyword_or_starred_node {
    has element: object,
        is_keyword: bool;
}

obj name_default_pair {
    has arg: arg,
        `default: expr | None;
}

obj star_etc_node {
    has vararg: arg | None = None,
        kwonlyargs: list[arg] = [],
        kw_defaults: list[expr | None] = [],
        kwarg: arg | None = None;
}

def pa_extra(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> tuple[int, int, int, int] {
    return (lineno, col_offset, end_lineno, end_col_offset);
}

def pa_name_id(ast_name: expr) -> str {
    if isinstance(ast_name, Name) {
        n = ast_name as Name;
        return n.id;
    }
    return "";
}

def pa_name_from_token(tok: peg_token | None) -> Name | None {
    if tok is None {
        return None;
    }
    return Name(
        id=tok.spelling,
        ctx=Load(),
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def _digit_val(c: str) -> int {
    if c >= "0" and c <= "9" {
        return ord(c) - ord("0");
    }
    return -1;
}

def _strip_underscores(spelling: str) -> str {
    out = "";
    i = 0;
    while i < len(spelling) {
        if spelling[i] != "_" {
            out = out + spelling[i];
        }
        i = i + 1;
    }
    return out;
}

def _digit_val_base(c: str, base: int) -> int {
    d = -1;
    if c >= "0" and c <= "9" {
        d = ord(c) - ord("0");
    } elif base == 16 {
        if c >= "a" and c <= "f" {
            d = ord(c) - ord("a") + 10;
        } elif c >= "A" and c <= "F" {
            d = ord(c) - ord("A") + 10;
        }
    }
    if d < 0 or d >= base {
        return -1;
    }
    return d;
}

def _fold_radix(s: str, start: int, base: int) -> int {
    # Tokenizer-guaranteed valid spellings; a bad digit means a lexer bug.
    n = 0;
    i = start;
    while i < len(s) {
        d = _digit_val_base(s[i], base);
        if d < 0 {
            return -1;
        }
        n = n * base + d;
        i = i + 1;
    }
    return n;
}

def pa_parse_int_spelling(spelling: str) -> int {
    s = _strip_underscores(spelling);
    if len(s) >= 3 and s[0] == "0" and (s[1] == "x" or s[1] == "X") {
        return _fold_radix(s, 2, 16);
    }
    if len(s) >= 3 and s[0] == "0" and (s[1] == "o" or s[1] == "O") {
        return _fold_radix(s, 2, 8);
    }
    if len(s) >= 3 and s[0] == "0" and (s[1] == "b" or s[1] == "B") {
        return _fold_radix(s, 2, 2);
    }
    return _fold_radix(s, 0, 10);
}

def _hex_digit_val(c: str) -> int {
    d = _digit_val(c);
    if d >= 0 {
        return d;
    }
    if c >= "a" and c <= "f" {
        return ord(c) - ord("a") + 10;
    }
    if c >= "A" and c <= "F" {
        return ord(c) - ord("A") + 10;
    }
    return -1;
}

def pa_decode_escape_body(body: str) -> str {
    out = "";
    i = 0;
    while i < len(body) {
        c = body[i];
        if c != "\\" {
            out = out + c;
            i = i + 1;
            continue;
        }
        i = i + 1;
        if i >= len(body) {
            out = out + "\\";
            break;
        }
        e = body[i];
        if e == "n" {
            out = out + "\n";
            i = i + 1;
            continue;
        }
        if e == "t" {
            out = out + "\t";
            i = i + 1;
            continue;
        }
        if e == "r" {
            out = out + "\r";
            i = i + 1;
            continue;
        }
        if e == "\\" {
            out = out + "\\";
            i = i + 1;
            continue;
        }
        if e == "'" {
            out = out + "'";
            i = i + 1;
            continue;
        }
        if e == "\"" {
            out = out + "\"";
            i = i + 1;
            continue;
        }
        if e == "x" and i + 2 < len(body) {
            h1 = _hex_digit_val(body[i + 1]);
            h2 = _hex_digit_val(body[i + 2]);
            if h1 >= 0 and h2 >= 0 {
                out = out + chr(h1 * 16 + h2);
                i = i + 3;
                continue;
            }
        }
        out = out + e;
        i = i + 1;
    }
    return out;
}

def pa_decode_string_literal_spelling(spelling: str) -> str | None {
    if len(spelling) == 0 {
        return None;
    }
    i = 0;
    raw = False;
    while i < len(spelling) {
        c = spelling[i];
        if c == "r" or c == "R" {
            raw = True;
            i = i + 1;
            continue;
        }
        if c == "b" or c == "B" or c == "u" or c == "U" or c == "f" or c == "F" {
            i = i + 1;
            continue;
        }
        break;
    }
    if i >= len(spelling) {
        return None;
    }
    quote = spelling[i];
    if quote != "'" and quote != "\"" {
        return None;
    }
    # Delimiter is 1 or 3 quotes (Python has no 2-quote delimiter). `''`/`""`
    # is an EMPTY single-quoted string, not a 2-char opener.
    qlen = 1;
    if i + 2 < len(spelling)
        and spelling[i + 1] == quote
        and spelling[i + 2] == quote {
        qlen = 3;
    }
    start = i + qlen;
    end = len(spelling) - qlen;
    if end < start {
        return None;
    }
    body = spelling[start:end];
    if raw {
        return body;
    }
    return pa_decode_escape_body(body);
}

def pa_constant_from_string(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    decoded = pa_decode_string_literal_spelling(tok.spelling);
    if decoded is None {
        return None;
    }
    return Constant(
        value=PyStr(t="str", val=decoded),
        kind=None,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_concatenate_strings(parts: list[object]) -> expr | None {
    if len(parts) == 0 {
        return None;
    }
    if len(parts) == 1 {
        c = parts[0];
        if isinstance(c, Constant) {
            return c as Constant;
        }
        return None;
    }
    out = "";
    i = 0;
    while i < len(parts) {
        c = parts[i];
        if not isinstance(c, Constant) {
            return None;
        }
        cc = c as Constant;
        if not isinstance(cc.value, PyStr) {
            return None;
        }
        out = out + (cc.value as PyStr).val;
        i = i + 1;
    }
    first = parts[0] as Constant;
    last = parts[len(parts) - 1] as Constant;
    return Constant(
        value=PyStr(t="str", val=out),
        kind=None,
        lineno=first.lineno,
        col_offset=first.col_offset,
        end_lineno=last.end_lineno,
        end_col_offset=last.end_col_offset
    );
}

def pa_constant_from_token(tok: peg_token | None) -> Constant | None {
    return pa_constant_from_string(tok);
}

def pa_decoded_constant_from_token(tok: peg_token | None) -> Constant | None {
    return pa_constant_from_string(tok);
}

def _is_prefixed_int(s: str) -> bool {
    return len(s) >= 3 and s[0] == "0" and (
        s[1] == "x" or s[1] == "X" or
        s[1] == "o" or s[1] == "O" or
        s[1] == "b" or s[1] == "B"
    );
}

def _has_float_marker(s: str) -> bool {
    # Only meaningful for non-prefixed spellings (hex digits include e/E).
    i = 0;
    while i < len(s) {
        c = s[i];
        if c == "." or c == "e" or c == "E" {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def _parse_decimal_float(s: str) -> float {
    # strtod-equivalent for tokenizer-valid non-prefixed spellings
    # (optional sign, digits, optional fraction, optional exponent).
    # NOTE: accumulate-and-scale rounding may differ from correctly-rounded
    # strtod by <=1 ULP on adversarially long literals.
    val = 0.0;
    i = 0;
    neg = False;
    if s[i] == "+" or s[i] == "-" {
        neg = s[i] == "-";
        i = i + 1;
    }
    while i < len(s) and s[i] >= "0" and s[i] <= "9" {
        val = val * 10.0 + (ord(s[i]) - ord("0"));
        i = i + 1;
    }
    if i < len(s) and s[i] == "." {
        i = i + 1;
        scale = 0.1;
        while i < len(s) and s[i] >= "0" and s[i] <= "9" {
            val = val + (ord(s[i]) - ord("0")) * scale;
            scale = scale / 10.0;
            i = i + 1;
        }
    }
    e = 0;
    if i < len(s) and (s[i] == "e" or s[i] == "E") {
        i = i + 1;
        exp_neg = False;
        if i < len(s) and (s[i] == "+" or s[i] == "-") {
            exp_neg = s[i] == "-";
            i = i + 1;
        }
        while i < len(s) and s[i] >= "0" and s[i] <= "9" {
            e = e * 10 + (ord(s[i]) - ord("0"));
            i = i + 1;
        }
        if exp_neg {
            e = -e;
        }
    }
    if e >= 0 {
        k = 0;
        while k < e {
            val = val * 10.0;
            k = k + 1;
        }
    } else {
        k = 0;
        while k > e {
            val = val / 10.0;
            k = k - 1;
        }
    }
    if neg {
        return -val;
    }
    return val;
}

def pa_py_number_from_spelling(spelling: str) -> PyObj {
    # Mirrors CPython pegen number_token: prefixed ints first (they never
    # carry a j suffix or float markers), then imaginary, then float.
    s = _strip_underscores(spelling);
    if _is_prefixed_int(s) {
        return PyInt(t="int", val=pa_parse_int_spelling(s));
    }
    last = s[len(s) - 1];
    if last == "j" or last == "J" {
        body = "";
        i = 0;
        while i < len(s) - 1 {
            body = body + s[i];
            i = i + 1;
        }
        return PyComplex(t="complex", real=0.0, imag=_parse_decimal_float(body));
    }
    if _has_float_marker(s) {
        return PyFloat(t="float", val=_parse_decimal_float(s));
    }
    return PyInt(t="int", val=pa_parse_int_spelling(s));
}

def pa_number_from_token(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    val = pa_py_number_from_spelling(tok.spelling);
    return Constant(
        value=val,
        kind=None,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_constant_none(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=py_none(),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_constant_bool(
    val: bool, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=PyBool(t="bool", val=val),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_expression(body: expr) -> Expression {
    return Expression(body=body);
}

def pa_ast_binop(
    left: expr,
    op: operator,
    right: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> BinOp {
    return BinOp(
        left=left,
        op=op,
        right=right,
        lineno=left.lineno,
        col_offset=left.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_unaryop(
    op: unaryop,
    operand: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> UnaryOp {
    return UnaryOp(
        op=op,
        operand=operand,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_boolop(
    op: boolop,
    values: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> BoolOp {
    start_lineno = lineno;
    start_col = col_offset;
    if len(values) > 0 {
        start_lineno = values[0].lineno;
        start_col = values[0].col_offset;
    }
    return BoolOp(
        op=op,
        values=values,
        lineno=start_lineno,
        col_offset=start_col,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_compare(
    left: expr,
    ops: list[cmpop],
    comparators: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Compare {
    return Compare(
        left=left,
        ops=ops,
        comparators=comparators,
        lineno=left.lineno,
        col_offset=left.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_call(
    func: expr,
    args: list[expr],
    keywords: list[keyword],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    return Call(
        func=func,
        args=args,
        keywords=keywords,
        lineno=func.lineno,
        col_offset=func.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_starred(
    value: expr, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Starred {
    return Starred(
        value=value,
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_ifexp(
    test_expr: expr,
    body: expr,
    orelse: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> IfExp {
    return IfExp(
        `test=test_expr,
        body=body,
        orelse=orelse,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_singleton_seq(item: expr) -> list[expr] {
    return [item];
}

def pa_seq_insert_front(head: expr, tail: list[expr] | None) -> list[expr] {
    if tail is None {
        return pa_singleton_seq(head);
    }
    out: list[expr] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_make_cmpop_pair(op: cmpop, rhs: expr) -> pa_cmpop_expr_pair {
    return pa_cmpop_expr_pair(cmpop=op, expr=rhs);
}

def pa_get_cmpops(pairs: list[pa_cmpop_expr_pair]) -> list[cmpop] {
    out: list[cmpop] = [];
    i = 0;
    while i < len(pairs) {
        out.append(pairs[i].cmpop);
        i = i + 1;
    }
    return out;
}

def pa_get_exprs(pairs: list[pa_cmpop_expr_pair]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(pairs) {
        out.append(pairs[i].expr);
        i = i + 1;
    }
    return out;
}

def pa_collect_call_seqs(
    args: list[expr],
    kwargs: object | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    dummy = Name(
        id="",
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
    if kwargs is None {
        return pa_ast_call(
            dummy, args, [], lineno, col_offset, end_lineno, end_col_offset
        );
    }
    if isinstance(kwargs, Call) {
        c = kwargs as Call;
        return pa_ast_call(
            c.func, args, c.keywords, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    kw_list = kwargs as list[object];
    starred = pa_seq_extract_starred_exprs(kw_list);
    keywords = pa_seq_delete_starred_exprs(kw_list);
    merged: list[expr] = args;
    si = 0;
    while si < len(starred) {
        merged.append(starred[si]);
        si = si + 1;
    }
    return pa_ast_call(
        dummy, merged, keywords, lineno, col_offset, end_lineno, end_col_offset
    );
}

def pa_call_from_optional_args(
    func: expr,
    args_expr: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    args: list[expr] = [];
    keywords: list[keyword] = [];
    if args_expr is not None and isinstance(args_expr, Call) {
        c = args_expr as Call;
        args = c.args;
        keywords = c.keywords;
    }
    return pa_ast_call(
        func, args, keywords, lineno, col_offset, end_lineno, end_col_offset
    );
}

def pa_check(body: expr) -> expr {
    return body;
}

def pa_stmt_list_or_empty(xs: list[stmt] | None) -> list[stmt] {
    if xs is None {
        return [];
    }
    return xs;
}

def pa_unsupported_action(p: peg_parser, label: str) -> None {
    if peg_has_error(p) {
        return None;
    }
    peg_raise_syntax_error(p, False, f"unsupported grammar action: {label}");
    return None;
}

# ---------------- statement actions (file/exec profile, P0.12 band 2) ----------------
# These lower the straight-line statement grammar actions into ast_nodes.jac
# objects. Locations arrive as the EXTRA quad (start_lineno, start_col_offset,
# end_lineno, end_col_offset). Type comments are disabled (None).

# file -> Module. _PyPegen_make_module wraps the flattened statement list. A
# missing statement list (empty file) yields an empty module body.
def pa_make_module(body: list[stmt] | None) -> Module {
    stmts: list[stmt] = [];
    if body is not None {
        stmts = body;
    }
    return Module(body=stmts, type_ignores=[]);
}

# statements: statement+ -> flatten list[list[stmt]] into list[stmt]. Each
# `statement` result is itself a seq (compound -> singleton, simple_stmts -> the
# ';' separated list). _PyPegen_seq_flatten concatenates them in source order.
def pa_seq_flatten(parts: list[object]) -> list[stmt] {
    out: list[stmt] = [];
    i = 0;
    while i < len(parts) {
        chunk = parts[i];
        if isinstance(chunk, list) {
            inner = chunk as list[object];
            j = 0;
            while j < len(inner) {
                s = inner[j];
                if isinstance(s, stmt) {
                    out.append(s as stmt);
                }
                j = j + 1;
            }
        }
        i = i + 1;
    }
    return out;
}

# target / RHS context switch: _PyPegen_set_expr_context rewrites a Name's ctx.
# Jac values are immutable, so rebuild the Name with the requested context.
def pa_set_context(target: expr, ctx: expr_context) -> expr {
    if isinstance(target, Name) {
        n = target as Name;
        return Name(
            id=n.id,
            ctx=ctx,
            lineno=n.lineno,
            col_offset=n.col_offset,
            end_lineno=n.end_lineno,
            end_col_offset=n.end_col_offset
        );
    }
    if isinstance(target, Attribute) {
        a = target as Attribute;
        return Attribute(
            value=a.value,
            attr=a.attr,
            ctx=ctx,
            lineno=a.lineno,
            col_offset=a.col_offset,
            end_lineno=a.end_lineno,
            end_col_offset=a.end_col_offset
        );
    }
    if isinstance(target, Subscript) {
        s = target as Subscript;
        return Subscript(
            value=s.value,
            slice=s.slice,
            ctx=ctx,
            lineno=s.lineno,
            col_offset=s.col_offset,
            end_lineno=s.end_lineno,
            end_col_offset=s.end_col_offset
        );
    }
    return target;
}

# star_expressions as a statement -> Expr (expression statement).
def pa_ast_expr_stmt(
    value: expr, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Expr {
    return Expr(
        value=value,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# star_targets '=' annotated_rhs -> Assign. NEW_TYPE_COMMENT is lowered to None
# (type comments disabled).
def pa_ast_assign(
    targets: list[expr],
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Assign {
    return Assign(
        targets=targets,
        value=value,
        type_comment=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# NAME ':' expression ['=' rhs] -> AnnAssign. Faithful AST build; codegen for
# annotated assignment lands in a later P0.12 band and fails loud if hit first.
def pa_ast_annassign(
    target: expr,
    annotation: expr,
    value: expr | None,
    simple: int,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> AnnAssign {
    return AnnAssign(
        target=target,
        annotation=annotation,
        value=value,
        simple=simple,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# return [expr] -> Return.
def pa_ast_return(
    value: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Return {
    return Return(
        value=value,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# pass -> Pass.
def pa_ast_pass(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Pass {
    return Pass(
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# tuple literal / target -> Tuple. ctx is Load (RHS) or Store (multi-target).
def pa_ast_tuple(
    elts: list[expr],
    ctx: expr_context,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Tuple {
    return Tuple(
        elts=elts if elts is not None else [],
        ctx=ctx,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_attribute(
    value: expr,
    attr_name: str,
    ctx: expr_context,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Attribute {
    return Attribute(
        value=value,
        attr=attr_name,
        ctx=ctx,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_subscript(
    value: expr,
    slice_expr: expr,
    ctx: expr_context,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Subscript {
    return Subscript(
        value=value,
        slice=slice_expr,
        ctx=ctx,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_slice(
    lower: expr | None,
    upper: expr | None,
    step: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Slice {
    return Slice(
        lower=lower,
        upper=upper,
        step=step,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_augassign(
    target: expr,
    op: operator,
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> AugAssign {
    return AugAssign(
        target=target,
        op=op,
        value=value,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_delete(
    targets: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Delete {
    return Delete(
        targets=targets,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# ---------------- full-grammar parser action helpers (Phase 1) ----------------

def pa_ast_break(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Break {
    return Break(
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_continue(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Continue {
    return Continue(
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_constant_from_expr(
    value: expr, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=py_none(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_seq_append_to_end(head: list[expr] | None, item: expr) -> list[expr] {
    if head is None {
        return pa_singleton_seq(item);
    }
    out: list[expr] = [];
    i = 0;
    while i < len(head) {
        out.append(head[i]);
        i = i + 1;
    }
    out.append(item);
    return out;
}

def pa_get_keys(pairs: list[object] | None) -> list[expr] {
    out: list[expr] = [];
    if pairs is None {
        return out;
    }
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kv_pair).key);
        i = i + 1;
    }
    return out;
}

def pa_get_values(pairs: list[object] | None) -> list[expr] {
    out: list[expr] = [];
    if pairs is None {
        return out;
    }
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kv_pair).value);
        i = i + 1;
    }
    return out;
}

def pa_get_patterns(pairs: list[object]) -> list[pattern] {
    out: list[pattern] = [];
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kp_pair).pattern);
        i = i + 1;
    }
    return out;
}

def pa_get_pattern_keys(pairs: list[object]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kp_pair).key);
        i = i + 1;
    }
    return out;
}

def pa_map_names_to_ids(names: list[expr]) -> list[str] {
    out: list[str] = [];
    i = 0;
    while i < len(names) {
        out.append(pa_name_id(names[i]));
        i = i + 1;
    }
    return out;
}

def pa_seq_count_dots(name: expr) -> int {
    return 0;
}

def pa_body_end_span(body: list[stmt]) -> tuple[int, int] {
    last = body[len(body) - 1];
    end_lineno = last.lineno;
    end_col_offset = last.col_offset;
    if last.end_lineno is not None {
        end_lineno = last.end_lineno;
    }
    if last.end_col_offset is not None {
        end_col_offset = last.end_col_offset;
    }
    return (end_lineno, end_col_offset);
}

def pa_empty_arguments -> arguments {
    return arguments(
        posonlyargs=[],
        args=[],
        vararg=None,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[]
    );
}

def pa_args_from_list(seq: object | None) -> list[arg] {
    if seq is None {
        return [];
    }
    out: list[arg] = [];
    raw = seq as list[object];
    i = 0;
    while i < len(raw) {
        out.append(raw[i] as arg);
        i = i + 1;
    }
    return out;
}

def pa_append_args_from_pairs(
    args: list[arg], defaults: list[expr], pairs: object | None
) -> tuple[list[arg], list[expr]] {
    if pairs is None {
        return (args, defaults);
    }
    raw = pairs as list[object];
    if len(raw) == 0 {
        return (args, defaults);
    }
    i = 0;
    while i < len(raw) {
        pair = raw[i] as name_default_pair;
        args.append(pair.arg);
        if pair.`default is not None {
            defaults.append(pair.`default as expr);
        }
        i = i + 1;
    }
    return (args, defaults);
}

def pa_make_arguments(
    slash_no_default: object,
    slash_with_default: object,
    plain_names: object,
    names_with_default: object,
    star_etc: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> arguments {
    posonlyargs = pa_args_from_list(slash_no_default);
    args = pa_args_from_list(plain_names);
    defaults: list[expr] = [];
    (args, defaults) = pa_append_args_from_pairs(args, defaults, names_with_default);
    vararg: arg | None = None;
    kwonlyargs: list[arg] = [];
    kw_defaults: list[expr | None] = [];
    kwarg: arg | None = None;
    if star_etc is not None {
        se = star_etc as star_etc_node;
        vararg = se.vararg;
        kwonlyargs = se.kwonlyargs;
        kw_defaults = se.kw_defaults;
        kwarg = se.kwarg;
    }
    return arguments(
        posonlyargs=posonlyargs,
        args=args,
        vararg=vararg,
        kwonlyargs=kwonlyargs,
        kw_defaults=kw_defaults,
        kwarg=kwarg,
        defaults=defaults
    );
}

def pa_dummy_name(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Name {
    return Name(
        id="_",
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_interactive_exit(p: peg_parser) -> list[stmt] {
    return [];
}

def pa_aug_op(target: expr) -> operator {
    return Add();
}

# arguments rule returns a dummy Call from pa_collect_call_seqs; peel args/keywords.
def pa_call_args(`node: expr) -> list[expr] {
    if `node is None {
        return [];
    }
    if isinstance(`node, Call) {
        return (`node as Call).args;
    }
    return [];
}

def pa_call_keywords(`node: expr) -> list[keyword] {
    if `node is None {
        return [];
    }
    if isinstance(`node, Call) {
        return (`node as Call).keywords;
    }
    return [];
}

def pa_comp_field(`node: expr, field: str) -> expr {
    pair = `node as kv_pair;
    if field == "key" {
        return pair.key;
    }
    return pair.value;
}

def pa_seq_first(seq: list[object]) -> expr | None {
    return None;
}

def pa_seq_last(seq: list[object]) -> expr | None {
    return None;
}

def pa_seq_len(seq: list[object]) -> int {
    return len(seq);
}

def pa_seq_get(seq: list[object], index: int) -> object | None {
    return None;
}

def pa_or_pattern_singleton(
    patterns: list[pattern],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> pattern {
    return MatchOr(
        patterns=patterns,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_err_occurred(p: peg_parser) -> bool {
    return peg_has_error(p);
}

def pa_expr_lineno(`node: expr) -> int {
    return `node.lineno;
}

def pa_expr_end_col_offset(`node: expr) -> int {
    return `node.end_col_offset;
}

def pa_expr_end_lineno(`node: expr) -> int {
    return `node.end_lineno;
}

def pa_raise_syntax(p: peg_parser, on_next: bool, message: str) -> None {
    if peg_has_error(p) {
        return None;
    }
    peg_raise_syntax_error(p, on_next, message);
    return None;
}

def pa_raise_syntax_known_expr(
    p: peg_parser, on_next: bool, `node: expr, message: str
) -> None {
    return pa_raise_syntax(p, on_next, message);
}

def pa_raise_syntax_known_range(
    p: peg_parser, on_next: bool, a: expr, b: expr, message: str
) -> None {
    return pa_raise_syntax(p, on_next, message);
}

def pa_raise_invalid_target(p: peg_parser, kind: object, `node: expr) -> None {
    return pa_raise_syntax(p, False, "invalid assignment target");
}

def pa_raise_type_param_error(colon: object, `node: expr, is_tuple: bool) -> None {
    return None;
}

def pa_raise_kvpair_error(p: peg_parser, `node: expr) -> None {
    return pa_raise_syntax(p, False, "':' expected after dictionary key");
}

def pa_check_legacy_stmt_or_raise(p: peg_parser, a: object, b: object) -> None {
    return None;
}

def pa_checked_future_import(
    module: object,
    names: object,
    level: object,
    lineno: int,
    col_offset: int,
    end_lineno: int | None,
    end_col_offset: int | None
) -> ImportFrom {
    mod: str | None = None;
    if isinstance(module, str) {
        mod = module as str;
    }
    lvl: int | None = None;
    if isinstance(level, int) {
        lvl = level as int;
    }
    alist: list[alias] = [];
    if isinstance(names, list) {
        alist = names as list[alias];
    }
    return ImportFrom(
        module=mod,
        names=alist,
        level=lvl,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_nonparen_genexp_in_call(a: object, b: object) -> object {
    return None;
}

def pa_arguments_parsing_error(`node: object) -> object {
    return None;
}

def pa_check_legacy_stmt(p: peg_parser, `node: object) -> bool {
    return False;
}

def pa_concatenate_tstrings(parts: list[object]) -> expr | None {
    return None;
}

def pa_ensure_imaginary(`node: expr) -> expr {
    return `node;
}

def pa_ensure_real(`node: expr) -> expr {
    return `node;
}

def pa_get_expr_name(`node: expr) -> str {
    return "";
}

def pa_get_last_comprehension_item(`node: object) -> object {
    return None;
}

def pa_join_names_with_dot(a: expr, b: expr) -> expr {
    return a;
}

def pa_join_sequences(a: list[object], b: list[object]) -> list[object] {
    out: list[object] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_alias_for_star(
    lineno: int, col_offset: int, end_lineno: int | None, end_col_offset: int | None
) -> alias | None {
    return alias(
        name="*",
        asname=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_add_type_comment_to_arg(arg: arg, comment: object) -> arg {
    return arg;
}

def pa_seq_number_of_starred_exprs(seq: list[object]) -> int {
    n = 0;
    i = 0;
    while i < len(seq) {
        k = seq[i] as keyword_or_starred_node;
        if not k.is_keyword {
            n = n + 1;
        }
        i = i + 1;
    }
    return n;
}

def pa_seq_delete_starred_exprs(seq: list[object]) -> list[keyword] {
    new_len = len(seq) - pa_seq_number_of_starred_exprs(seq);
    if new_len == 0 {
        return [];
    }
    out: list[keyword] = [];
    i = 0;
    while i < len(seq) {
        k = seq[i] as keyword_or_starred_node;
        if k.is_keyword {
            out.append(k.element as keyword);
        }
        i = i + 1;
    }
    return out;
}

def pa_seq_extract_starred_exprs(seq: list[object]) -> list[expr] {
    new_len = pa_seq_number_of_starred_exprs(seq);
    if new_len == 0 {
        return [];
    }
    out: list[expr] = [];
    i = 0;
    while i < len(seq) {
        k = seq[i] as keyword_or_starred_node;
        if not k.is_keyword {
            out.append(k.element as expr);
        }
        i = i + 1;
    }
    return out;
}

def pa_setup_full_format_spec(`node: object) -> object {
    return `node;
}

def pa_check_fstring_conversion(a: object, b: object) -> object {
    return a;
}

def pa_function_def_decorators(decs: list[expr], stmt: stmt) -> stmt {
    if isinstance(stmt, FunctionDef) {
        fd = stmt as FunctionDef;
        return FunctionDef(
            name=fd.name,
            args=fd.args,
            body=fd.body,
            decorator_list=decs,
            returns=fd.returns,
            type_comment=fd.type_comment,
            type_params=fd.type_params,
            lineno=fd.lineno,
            col_offset=fd.col_offset,
            end_lineno=fd.end_lineno,
            end_col_offset=fd.end_col_offset
        );
    }
    if isinstance(stmt, AsyncFunctionDef) {
        afd = stmt as AsyncFunctionDef;
        return AsyncFunctionDef(
            name=afd.name,
            args=afd.args,
            body=afd.body,
            decorator_list=decs,
            returns=afd.returns,
            type_comment=afd.type_comment,
            type_params=afd.type_params,
            lineno=afd.lineno,
            col_offset=afd.col_offset,
            end_lineno=afd.end_lineno,
            end_col_offset=afd.end_col_offset
        );
    }
    return stmt;
}

def pa_class_def_decorators(decs: list[expr], stmt: stmt) -> stmt {
    return stmt;
}

def pa_key_value_pair(
    key: expr,
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> kv_pair {
    return kv_pair(key=key, value=value);
}

def pa_key_pattern_pair(
    key: expr,
    pat: pattern,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> kp_pair {
    return kp_pair(key=key, pattern=pat);
}

def pa_name_default_pair(
    arg: arg,
    `default: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> name_default_pair {
    return name_default_pair(arg=arg, `default=`default);
}

def pa_keyword_or_starred(
    element: object,
    is_keyword: int,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> keyword_or_starred_node {
    return keyword_or_starred_node(element=element, is_keyword=is_keyword != 0);
}

def pa_star_etc(
    a: object,
    b: object,
    c: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> star_etc_node | None {
    if a is None and b is None and c is None {
        return None;
    }
    vararg: arg | None = None;
    if a is not None {
        vararg = a as arg;
    }
    kwonlyargs: list[arg] = [];
    kw_defaults: list[expr | None] = [];
    if b is not None {
        raw = b as list[object];
        pi = 0;
        while pi < len(raw) {
            pair = raw[pi] as name_default_pair;
            kwonlyargs.append(pair.arg);
            kw_defaults.append(pair.`default);
            pi = pi + 1;
        }
    }
    kwarg: arg | None = None;
    if c is not None {
        kwarg = c as arg;
    }
    return star_etc_node(
        vararg=vararg, kwonlyargs=kwonlyargs, kw_defaults=kw_defaults, kwarg=kwarg
    );
}

def pa_slash_with_default(
    a: object,
    b: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> object {
    return None;
}

def pa_joined_str(
    a: object,
    b: list[expr],
    c: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return None;
}

def pa_template_str(
    a: object,
    b: list[expr],
    c: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return None;
}

def pa_formatted_value(
    a: object,
    b: object,
    c: object,
    d: object,
    e: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return None;
}

def pa_interpolation(
    a: object,
    b: object,
    c: object,
    d: object,
    e: object,
    f: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return None;
}
