# P0.7 parser action helpers (PLAN.md).
#
# Lowers CPython grammar actions (_PyAST_*, _PyPegen_*) into ast_nodes.jac
# objects. Generated parser rules call these helpers; this file is hand-written
# and grows with each grammar profile.

import from jaclang.runtime.python.objects {
    PyObj,
    PyInt,
    PyBool,
    PyStr,
    PyBytes,
    PyFloat,
    PyComplex,
    PyEllipsis,
    py_none
}
import from jaclang.compiler.frontend.python.ast_nodes {
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
    List,
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
    ClassDef,
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
    MatchSingleton,
    ImportFrom,
    JoinedStr,
    TemplateStr,
    Interpolation,
    FormattedValue,
}
import from jaclang.compiler.frontend.python.peg_runtime {
    peg_parser,
    peg_token,
    peg_has_error,
    peg_raise_syntax_error
}

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
    identifier = tok.spelling;
    if not identifier.isascii() {
        import unicodedata;
        identifier = unicodedata.normalize("NFKC", identifier);
    }
    if not isinstance(identifier, str) {
        raise TypeError("identifier must be of type str");
    }
    if identifier in ("True", "False", "None") {
        raise ValueError(f"identifier field can't represent '{identifier}' constant");
    }
    return Name(
        id=identifier,
        ctx=Load(),
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_warn_escape(escape: str, tok: peg_token | None) {
    if tok is not None and tok.warned {
        return;
    }
    if tok is not None {
        tok.warned = True;
    }
    import warnings;
    kind = "octal escape sequence" if len(escape) == 3 else "escape sequence";
    escaped = "\\" + escape;
    message = '"'
        + escaped
        + '" is an invalid '
        + kind
        + '. Such sequences will not work in the future. Did you mean "\\'
        + escaped
        + '"? A raw string is also an option.';
    try {
        warnings.warn_explicit(
            message,
            SyntaxWarning,
            tok.filename if tok is not None else "<unknown>",
            tok.lineno if tok is not None else 1
        );
    } except SyntaxWarning as error {
        raise SyntaxError(str(error));
    }
}

# Escape decoding uses the retained string/bytes object runtime, just as
# CPython's string_parser.c does. No parser or compiler API is called here.
def pa_decode_escape_body(body: str, tok: peg_token | None = None) -> str {
    import codecs;
    encoded: list[str] = [];
    i = 0;
    while i < len(body) {
        ch = body[i];
        if ch == "\\" and i + 1 < len(body) {
            following = body[i + 1];
            if ord(following) < 128 {
                if following not in "\\\"'abfnrtv\n\r01234567xuUN" {
                    pa_warn_escape(following, tok);
                } elif following in "4567"
                    and len(body[i + 1:i + 4]) == 3
                    and all(c in "01234567" for c in body[i + 1:i + 4]) {
                    pa_warn_escape(body[i + 1:i + 4], tok);
                }
                encoded.append(ch + following);
                i += 2;
                continue;
            }
            # A backslash before a literal non-ASCII character must not consume
            # the escape we introduce when encoding that character below.
            encoded.append("\\u005c");
        } elif ord(ch) >= 128 {
            encoded.append("\\U" + format(ord(ch), "08x"));
        } else {
            encoded.append(ch);
        }
        i += 1;
    }
    try {
        import warnings;
        with warnings.catch_warnings() {
            warnings.simplefilter("ignore", DeprecationWarning);
            # Invoke the retained Unicode decoder directly. Codec lookup can
            # import encodings.unicode_escape while its source is being parsed
            # during a cold compiler startup.
            return codecs.unicode_escape_decode("".join(encoded).encode("ascii"))[0];
        }
    } except UnicodeError as error {
        raise SyntaxError("(unicode error) " + str(error));
    }
}

def pa_decode_bytes_escape_body(body: str, raw: bool) -> list[int] {
    import codecs;
    try {
        data = body.encode("ascii");
    } except UnicodeEncodeError {
        raise SyntaxError("bytes can only contain ASCII literal characters");
    }
    if raw {
        return list(data);
    }
    try {
        return list(codecs.escape_decode(data)[0]);
    } except ValueError as error {
        raise SyntaxError(str(error));
    }
}

def pa_decode_string_literal_spelling(
    spelling: str, tok: peg_token | None = None
) -> str | list[int] | None {
    if len(spelling) == 0 {
        return None;
    }
    i = 0;
    raw = False;
    is_bytes = False;
    while i < len(spelling) {
        c = spelling[i];
        if c == "r" or c == "R" {
            raw = True;
            i = i + 1;
            continue;
        }
        if c == "b" or c == "B" {
            is_bytes = True;
            i = i + 1;
            continue;
        }
        if c == "u" or c == "U" or c == "f" or c == "F" {
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
    if is_bytes {
        return pa_decode_bytes_escape_body(body, raw);
    }
    if raw {
        return body;
    }
    return pa_decode_escape_body(body, tok);
}

def pa_constant_from_fstring_middle(
    tok: peg_token | None, raw: bool
) -> Constant | None {
    if tok is None {
        return None;
    }
    body = tok.spelling;
    if tok.metadata is not None and tok.metadata.startswith("escape:") {
        pa_warn_escape(tok.metadata[7:], tok);
        body += "\\";
    }
    if raw or tok.metadata == "raw" {
        decoded = body;
    } else {
        decoded = pa_decode_escape_body(body, tok);
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

def pa_constant_from_string(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    decoded = pa_decode_string_literal_spelling(tok.spelling, tok);
    if decoded is None {
        return None;
    }
    value: PyObj;
    if isinstance(decoded, list) {
        value = PyBytes(t="bytes", val=decoded);
    } else {
        value = PyStr(t="str", val=decoded);
    }
    return Constant(
        value=value,
        kind="u" if tok.spelling.startswith("u") else None,
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
    byte_parts = [
        part
        for part in parts
        if isinstance(part, Constant) and isinstance(part.value, PyBytes)
    ];
    if byte_parts {
        if len(byte_parts) != len(parts) {
            raise SyntaxError("cannot mix bytes and nonbytes literals");
        }
        first = byte_parts[0];
        last = byte_parts[-1];
        data: list[int] = [];
        for part in byte_parts {
            data.extend((part.value as PyBytes).val);
        }
        return Constant(
            value=PyBytes(t="bytes", val=data),
            kind=None,
            lineno=first.lineno,
            col_offset=first.col_offset,
            end_lineno=last.end_lineno,
            end_col_offset=last.end_col_offset
        );
    }
    has_fstring = False;
    i = 0;
    while i < len(parts) {
        if isinstance(parts[i], JoinedStr) {
            has_fstring = True;
        }
        i = i + 1;
    }
    if not has_fstring {
        # All-literal concatenation: fold into one Constant.
        if len(parts) == 1 {
            return parts[0] as Constant;
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
            kind=first.kind,
            lineno=first.lineno,
            col_offset=first.col_offset,
            end_lineno=last.end_lineno,
            end_col_offset=last.end_col_offset
        );
    }
    # Mixed literal/f-string concatenation (CP concatenate_strings semantics):
    # flatten every part into JoinedStr figures -- constants stay literal
    # figures, each f-string contributes its own values in place.
    figures: list[expr] = [];
    i = 0;
    while i < len(parts) {
        c = parts[i];
        if isinstance(c, Constant) {
            figures.append(c as expr);
        } elif isinstance(c, JoinedStr) {
            js = c as JoinedStr;
            vals = js.values if js.values is not None else [];
            j = 0;
            while j < len(vals) {
                figures.append(vals[j]);
                j = j + 1;
            }
        } else {
            return None;
        }
        i = i + 1;
    }
    # Merge adjacent literal figures (CPython concatenates neighboring
    # Constants when gluing implicitly-joined strings into one JoinedStr).
    merged: list[expr] = [];
    k = 0;
    while k < len(figures) {
        fig = figures[k];
        if isinstance(fig, Constant)
            and len(merged) > 0
            and isinstance(merged[len(merged) - 1], Constant) {
            prev = merged[len(merged) - 1] as Constant;
            pc = fig as Constant;
            if isinstance(prev.value, PyStr) and isinstance(pc.value, PyStr) {
                merged[len(merged) - 1] = Constant(
                    value=PyStr(
                        t="str", val=(prev.value as PyStr).val + (pc.value as PyStr).val
                    ),
                    kind=prev.kind,
                    lineno=prev.lineno,
                    col_offset=prev.col_offset,
                    end_lineno=pc.end_lineno,
                    end_col_offset=pc.end_col_offset
                );
                k = k + 1;
                continue;
            }
        }
        merged.append(fig as expr);
        k = k + 1;
    }
    figures = merged;
    fpart = parts[0];
    lpart = parts[len(parts) - 1];
    fl: int | None = 0;
    fc: int | None = 0;
    ll: int | None = 0;
    lc: int | None = 0;
    if isinstance(fpart, Constant) {
        fc0 = fpart as Constant;
        fl = fc0.lineno;
        fc = fc0.col_offset;
    } else {
        f0 = fpart as JoinedStr;
        fl = f0.lineno;
        fc = f0.col_offset;
    }
    if isinstance(lpart, Constant) {
        lc0 = lpart as Constant;
        ll = lc0.end_lineno;
        lc = lc0.end_col_offset;
    } else {
        l0 = lpart as JoinedStr;
        ll = l0.end_lineno;
        lc = l0.end_col_offset;
    }
    return JoinedStr(
        values=figures, lineno=fl, col_offset=fc, end_lineno=ll, end_col_offset=lc
    );
}

def pa_constant_from_token(tok: peg_token | None) -> Constant | None {
    return pa_constant_from_fstring_middle(tok, False);
}

def pa_decoded_constant_from_token(tok: peg_token | None) -> Constant | None {
    return pa_constant_from_fstring_middle(tok, False);
}

def _is_prefixed_int(s: str) -> bool {
    return len(s) >= 3
        and s[0] == "0"
        and (
            s[1] == "x"
            or s[1] == "X"
            or s[1] == "o"
            or s[1] == "O"
            or s[1] == "b"
            or s[1] == "B"
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

def pa_py_number_from_spelling(spelling: str) -> PyObj {
    # Number conversion belongs to the retained numeric object runtime. Keep
    # underscores intact so its converters reject invalid literal spellings.
    try {
        if _is_prefixed_int(spelling) {
            return PyInt(t="int", val=int(spelling, 0));
        }
        if spelling.endswith(("j", "J")) {
            return PyComplex(t="complex", real=0.0, imag=float(spelling[:-1]));
        }
        if _has_float_marker(spelling) {
            return PyFloat(t="float", val=float(spelling));
        }
        return PyInt(t="int", val=int(spelling, 0));
    } except ValueError as error {
        message = str(error);
        if message.startswith("Exceeds the limit ") {
            message += " Consider hexadecimal for huge integer literals to avoid decimal conversion limits.";
        }
        raise SyntaxError(message);
    }
}

def pa_number_from_token(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    try {
        val = pa_py_number_from_spelling(tok.spelling);
    } except SyntaxError as error {
        raise SyntaxError(
            error.msg,
            (
                None,
                tok.lineno,
                tok.col_offset + 1,
                None,
                tok.end_lineno,
                tok.end_col_offset + 1
            )
        );
    }
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

def pa_constant_ellipsis(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=PyEllipsis(t="ellipsis"),
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

def pa_match_singleton(
    val: object, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> MatchSingleton {
    pyval: PyObj;
    if val is True {
        pyval = PyBool(t="bool", val=True);
    } elif val is False {
        pyval = PyBool(t="bool", val=False);
    } else {
        pyval = py_none();
    }
    return MatchSingleton(
        value=pyval,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_pattern_list(patterns: object) -> list[pattern] {
    if patterns is None {
        return [];
    }
    src = patterns as list[pattern | None];
    out: list[pattern] = [];
    i = 0;
    while i < len(src) {
        p = src[i];
        if p is not None {
            out.append(p);
        }
        i = i + 1;
    }
    return out;
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
    keywords: list[keyword] | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    kws = keywords if keywords is not None else [];
    return Call(
        func=func,
        args=args,
        keywords=kws,
        lineno=func.lineno,
        col_offset=func.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_starred(
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int,
    ctx: expr_context | None = None
) -> Starred {
    return Starred(
        value=value,
        ctx=ctx if ctx is not None else Load(),
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

def pa_singleton_seq(item: object) -> list[object] {
    return [item];
}

def pa_seq_insert_front(head: object, tail: object | None) -> list[object] {
    if tail is None {
        return pa_singleton_seq(head);
    }
    tail_list = tail as list[object];
    out: list[object] = [head];
    i = 0;
    while i < len(tail_list) {
        out.append(tail_list[i]);
        i = i + 1;
    }
    return out;
}


def pa_singleton_seq_expr(item: expr) -> list[expr] {
    return [item];
}

def pa_seq_insert_front_expr(head: expr, tail: list[expr] | None) -> list[expr] {
    if tail is None {
        return pa_singleton_seq_expr(head);
    }
    out: list[expr] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_pattern(item: pattern) -> list[pattern] {
    return [item];
}

def pa_seq_insert_front_pattern(
    head: pattern, tail: list[pattern] | None
) -> list[pattern] {
    if tail is None {
        return pa_singleton_seq_pattern(head);
    }
    out: list[pattern] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_stmt(item: stmt) -> list[stmt] {
    return [item];
}

def pa_seq_insert_front_stmt(head: stmt, tail: list[stmt] | None) -> list[stmt] {
    if tail is None {
        return pa_singleton_seq_stmt(head);
    }
    out: list[stmt] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_alias(item: alias) -> list[alias] {
    return [item];
}

def pa_seq_insert_front_alias(head: alias, tail: list[alias] | None) -> list[alias] {
    if tail is None {
        return pa_singleton_seq_alias(head);
    }
    out: list[alias] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_type_param(item: type_param) -> list[type_param] {
    return [item];
}

def pa_seq_insert_front_type_param(
    head: type_param, tail: list[type_param] | None
) -> list[type_param] {
    if tail is None {
        return pa_singleton_seq_type_param(head);
    }
    out: list[type_param] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_withitem(item: withitem) -> list[withitem] {
    return [item];
}

def pa_seq_insert_front_withitem(
    head: withitem, tail: list[withitem] | None
) -> list[withitem] {
    if tail is None {
        return pa_singleton_seq_withitem(head);
    }
    out: list[withitem] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_arg(item: arg) -> list[arg] {
    return [item];
}

def pa_seq_insert_front_arg(head: arg, tail: list[arg] | None) -> list[arg] {
    if tail is None {
        return pa_singleton_seq_arg(head);
    }
    out: list[arg] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_kw_or_starred(
    item: keyword_or_starred_node
) -> list[keyword_or_starred_node] {
    return [item];
}

def pa_seq_insert_front_kw_or_starred(
    head: keyword_or_starred_node, tail: list[keyword_or_starred_node] | None
) -> list[keyword_or_starred_node] {
    if tail is None {
        return pa_singleton_seq_kw_or_starred(head);
    }
    out: list[keyword_or_starred_node] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_kvpair(item: kv_pair) -> list[kv_pair] {
    return [item];
}

def pa_seq_insert_front_kvpair(
    head: kv_pair, tail: list[kv_pair] | None
) -> list[kv_pair] {
    if tail is None {
        return pa_singleton_seq_kvpair(head);
    }
    out: list[kv_pair] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_kvpattern(item: kp_pair) -> list[kp_pair] {
    return [item];
}

def pa_seq_insert_front_kvpattern(
    head: kp_pair, tail: list[kp_pair] | None
) -> list[kp_pair] {
    if tail is None {
        return pa_singleton_seq_kvpattern(head);
    }
    out: list[kp_pair] = [head];
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

def pa_check(body: object) -> object {
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

# Rebuild assignment/deletion targets without changing memoized load expressions.
def pa_set_context(target: expr, ctx: expr_context) -> expr {
    if isinstance(target, Starred) {
        return Starred(
            value=pa_set_context(target.value, ctx),
            ctx=ctx,
            lineno=target.lineno,
            col_offset=target.col_offset,
            end_lineno=target.end_lineno,
            end_col_offset=target.end_col_offset
        );
    }
    if isinstance(target, (List, Tuple)) {
        items = [pa_set_context(item, ctx) for item in target.elts];
        if isinstance(target, List) {
            return List(
                elts=items,
                ctx=ctx,
                lineno=target.lineno,
                col_offset=target.col_offset,
                end_lineno=target.end_lineno,
                end_col_offset=target.end_col_offset
            );
        }
        return Tuple(
            elts=items,
            ctx=ctx,
            lineno=target.lineno,
            col_offset=target.col_offset,
            end_lineno=target.end_lineno,
            end_col_offset=target.end_col_offset
        );
    }
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

# star_targets '=' annotated_rhs -> Assign.
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
    elts: list[expr] | None,
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
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_seq_append_to_end(head: object | None, item: object) -> list[object] {
    if head is None {
        return pa_singleton_seq(item);
    }
    head_list = head as list[object];
    out: list[object] = [];
    i = 0;
    while i < len(head_list) {
        out.append(head_list[i]);
        i = i + 1;
    }
    out.append(item);
    return out;
}

def pa_seq_append_to_end_expr(head: list[expr] | None, item: expr) -> list[expr] {
    if head is None {
        return pa_singleton_seq_expr(item);
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

def pa_seq_append_to_end_stmt(head: list[stmt] | None, item: stmt) -> list[stmt] {
    if head is None {
        return pa_singleton_seq_stmt(item);
    }
    out: list[stmt] = [];
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

def pa_seq_count_dots(seq: object) -> int {
    return sum(len(token.spelling) for token in (seq as list[peg_token]));
}

def pa_body_end_span(body: list[stmt]) -> tuple[int, int] {
    last = body[len(body) - 1];
    end_lineno: int = last.lineno;
    end_col_offset: int = last.col_offset;
    if last.end_lineno is not None {
        end_lineno = last.end_lineno as int;
    }
    if last.end_col_offset is not None {
        end_col_offset = last.end_col_offset as int;
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
    defaults: list[expr] = [];
    if slash_with_default is not None {
        split = slash_with_default as tuple;
        posonlyargs = pa_args_from_list(split[0]);
        (posonlyargs, defaults) = pa_append_args_from_pairs(
            posonlyargs, defaults, split[1]
        );
    }
    args = pa_args_from_list(plain_names);
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

def pa_aug_op(op: operator) -> operator {
    return op;
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

def pa_comp_field(`node: object, field: str) -> expr {
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
    if len(patterns) == 1 {
        return patterns[0];
    }
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
    v = `node.end_col_offset;
    if v is not None {
        return v as int;
    }
    return `node.col_offset;
}

def pa_expr_end_lineno(`node: expr) -> int {
    v = `node.end_lineno;
    if v is not None {
        return v as int;
    }
    return `node.lineno;
}

def pa_raise_syntax(p: peg_parser, on_next: bool, message: str) -> None {
    if peg_has_error(p) {
        return None;
    }
    peg_raise_syntax_error(p, on_next, message);
    return None;
}

def pa_raise_syntax_known_expr(
    p: peg_parser, on_next: bool, `node: object | None, message: str
) -> None {
    return pa_raise_syntax(p, on_next, message);
}

def pa_raise_syntax_known_range(
    p: peg_parser, on_next: bool, a: object | None, b: object | None, message: str
) -> None {
    return pa_raise_syntax(p, on_next, message);
}

def pa_raise_invalid_target(p: peg_parser, kind: object, `node: object | None) -> None {
    return pa_raise_syntax(p, False, "invalid assignment target");
}

def pa_raise_type_param_error(
    p: peg_parser, colon: object, value: expr, is_tuple: bool
) -> None {
    kind = "TypeVarTuple" if is_tuple else "ParamSpec";
    restriction = "constraints" if isinstance(value, Tuple) else "bound";
    return pa_raise_syntax_known_range(
        p, False, colon, value, "cannot use " + restriction + " with " + kind
    );
}

def pa_raise_kvpair_error(p: peg_parser, `node: expr) -> None {
    return pa_raise_syntax(p, False, "':' expected after dictionary key");
}

def pa_check_legacy_stmt_or_raise(p: peg_parser, a: object, b: object) -> None {
    if isinstance(a, Name) and a.id in ("print", "exec") {
        return None;
    }
    if p.mark > 0 and p.tokens[p.mark - 1].level > 0 {
        return pa_raise_syntax_known_range(
            p, False, a, b, "invalid syntax. Perhaps you forgot a comma?"
        );
    }
    return None;
}

def pa_checked_future_import(
    p: peg_parser,
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
    if mod == "__future__" and not lvl {
        for item in alist {
            if item.name == "barry_as_FLUFL" {
                p.flags |= 0x400000;
            }
        }
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
    strings: list[object] = [];
    for part in parts {
        if not isinstance(part, TemplateStr) {
            return None;
        }
        strings.append(
            JoinedStr(
                values=part.values,
                lineno=part.lineno,
                col_offset=part.col_offset,
                end_lineno=part.end_lineno,
                end_col_offset=part.end_col_offset
            )
        );
    }
    joined = pa_concatenate_strings(strings);
    if not isinstance(joined, JoinedStr) {
        return None;
    }
    return TemplateStr(
        values=joined.values,
        lineno=joined.lineno,
        col_offset=joined.col_offset,
        end_lineno=joined.end_lineno,
        end_col_offset=joined.end_col_offset
    );
}

def pa_ensure_imaginary(p: peg_parser, value: expr) -> expr | None {
    if not isinstance(value, Constant) or not isinstance(value.value, PyComplex) {
        peg_raise_syntax_error(
            p, False, "imaginary number required in complex literal"
        );
        return None;
    }
    return value;
}

def pa_ensure_real(p: peg_parser, value: expr) -> expr | None {
    if isinstance(value, Constant) and isinstance(value.value, PyComplex) {
        peg_raise_syntax_error(p, False, "real number required in complex literal");
        return None;
    }
    return value;
}

def pa_get_expr_name(`node: expr) -> str {
    return "";
}

def pa_get_last_comprehension_item(`node: object) -> object {
    return None;
}

def pa_join_names_with_dot(a: expr, b: expr) -> expr {
    return Name(
        id=pa_name_id(a) + "." + pa_name_id(b),
        ctx=Load(),
        lineno=a.lineno,
        col_offset=a.col_offset,
        end_lineno=b.end_lineno,
        end_col_offset=b.end_col_offset
    );
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

def pa_join_sequences_kw_or_starred(
    a: list[keyword_or_starred_node], b: list[keyword_or_starred_node]
) -> list[keyword_or_starred_node] {
    out: list[keyword_or_starred_node] = [];
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

def pa_join_sequences_expr(a: list[expr], b: list[expr]) -> list[expr] {
    out: list[expr] = [];
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

def pa_join_sequences_stmt(a: list[stmt], b: list[stmt]) -> list[stmt] {
    out: list[stmt] = [];
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

def pa_join_sequences_alias(a: list[alias], b: list[alias]) -> list[alias] {
    out: list[alias] = [];
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

def pa_join_sequences_pattern(a: list[pattern], b: list[pattern]) -> list[pattern] {
    out: list[pattern] = [];
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
    if isinstance(comment, peg_token) {
        arg.type_comment = comment.spelling;
    }
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

def pa_setup_full_format_spec(
    colon: peg_token,
    spec: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return JoinedStr(
        values=pa_resize_fstring_parts(colon, spec),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_check_fstring_conversion(
    p: peg_parser, conv_token: peg_token, conv: Name
) -> Name | None {
    kind = conv_token.metadata or "f-string";
    message = "";
    if conv_token.lineno != conv.lineno
        or conv_token.end_col_offset != conv.col_offset {
        message = kind + ": conversion type must come right after the exclamation mark";
    } elif conv.id not in ("s", "r", "a") {
        message = kind
            + ": invalid conversion character "
            + repr(conv.id)
            + ": expected 's', 'r', or 'a'";
    }
    if message {
        raise SyntaxError(message, (p.filename, conv.lineno, conv.col_offset + 1, ""));
    }
    return conv;
}

def _fstring_prefix_is_raw(start: peg_token) -> bool {
    s = start.spelling;
    i = 0;
    while i < len(s) {
        c = s[i];
        if c == "r" or c == "R" {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def interpolation_text(
    p: peg_parser,
    lineno: int,
    col_offset: int,
    conversion: object,
    format: object,
    closing_brace: peg_token
) -> str {
    end_line = closing_brace.lineno;
    end_col = closing_brace.col_offset;
    if isinstance(conversion, Name) {
        end_line = conversion.lineno;
        end_col = conversion.col_offset - 1;
    } elif isinstance(format, JoinedStr) {
        end_line = format.lineno;
        end_col = format.col_offset;
    }
    if not p.source_lines {
        p.source_lines = p.tok.source.encode("utf-8").splitlines(keepends=True);
    }
    lines = p.source_lines;
    fragments: list[bytes] = [];
    for line in range(lineno, end_line + 1) {
        start = col_offset + 1 if line == lineno else 0;
        end = end_col if line == end_line else len(lines[line - 1]);
        for (comment_start, comment_end) in p.tok.comments.get(line, []) {
            if comment_end <= start or comment_start >= end {
                continue;
            }
            fragments.append(lines[line - 1][start:max(start, comment_start)]);
            start = min(end, comment_end);
        }
        fragments.append(lines[line - 1][start:end]);
    }
    return b"".join(fragments).decode("utf-8");
}

def _interpolation_conversion(
    debug_expr: object, conversion: object, format: object
) -> int {
    if conversion is not None {
        conv = conversion as Name;
        return ord(conv.id[0]);
    }
    if debug_expr is not None and format is None {
        return ord("r");
    }
    return -1;
}

def pa_resize_fstring_parts(start: peg_token, parts: list[expr]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(parts) {
        item = parts[i];
        if isinstance(item, JoinedStr) {
            js = item as JoinedStr;
            vals = js.values if js.values is not None else [];
            if len(vals) == 2 {
                out.append(vals[0]);
                out.append(vals[1]);
            } else {
                out.append(item);
            }
            i = i + 1;
            continue;
        }
        if isinstance(item, Constant) {
            c = item as Constant;
            if isinstance(c.value, PyStr) and len((c.value as PyStr).val) == 0 {
                i = i + 1;
                continue;
            }
        }
        out.append(item);
        i = i + 1;
    }
    return out;
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
    # Mirrors _PyPegen_class_def_decorators: attach the decorators to the
    # ClassDef produced by class_def_raw. Node spans stay anchored on the
    # `class` keyword (CPython never extends them over the decorator lines).
    if isinstance(stmt, ClassDef) {
        cd = stmt as ClassDef;
        return ClassDef(
            name=cd.name,
            bases=cd.bases,
            keywords=cd.keywords,
            body=cd.body,
            decorator_list=decs,
            type_params=cd.type_params,
            lineno=cd.lineno,
            col_offset=cd.col_offset,
            end_lineno=cd.end_lineno,
            end_col_offset=cd.end_col_offset
        );
    }
    return stmt;
}

def pa_key_value_pair(
    key: object | None,
    value: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> kv_pair {
    return kv_pair(key=key as expr, value=value as expr);
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
    return (a, b);
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
    start = a as peg_token;
    end = c as peg_token;
    vals = pa_resize_fstring_parts(start, b);
    return JoinedStr(
        values=vals,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end.end_lineno,
        end_col_offset=end.end_col_offset
    );
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
    start = a as peg_token;
    end = c as peg_token;
    return TemplateStr(
        values=pa_resize_fstring_parts(start, b),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end.end_lineno,
        end_col_offset=end.end_col_offset
    );
}

def pa_formatted_value(
    p: peg_parser,
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
    expression = a as expr;
    debug_expr = b;
    conversion = c;
    format = d;
    closing_brace = e as peg_token;
    conv_val = _interpolation_conversion(debug_expr, conversion, format);
    format_spec: expr | None = None;
    if format is not None {
        format_spec = format as expr;
    }
    fv = FormattedValue(
        value=expression,
        conversion=conv_val,
        format_spec=format_spec,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
    if debug_expr is None {
        return fv;
    }
    debug_end_lineno = end_lineno;
    debug_end_col = end_col_offset;
    if conversion is not None {
        conv = conversion as Name;
        debug_end_lineno = conv.lineno;
        debug_end_col = conv.col_offset;
    } elif format is not None {
        if isinstance(format, JoinedStr) {
            fs = format as JoinedStr;
            debug_end_lineno = fs.lineno;
            debug_end_col = fs.col_offset + 1;
        }
    } else {
        debug_end_lineno = closing_brace.end_lineno;
        debug_end_col = closing_brace.end_col_offset;
    }
    dbg_const = Constant(
        value=PyStr(
            t="str",
            val=interpolation_text(
                p, lineno, col_offset, conversion, format, closing_brace
            )
        ),
        kind=None,
        lineno=lineno,
        col_offset=col_offset + 1,
        end_lineno=debug_end_lineno,
        end_col_offset=debug_end_col - 1
    );
    return JoinedStr(
        values=[dbg_const, fv],
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=debug_end_lineno,
        end_col_offset=debug_end_col
    );
}

def pa_interpolation(
    p: peg_parser,
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
    expression = a as expr;
    closing = e as peg_token;
    text = interpolation_text(p, lineno, col_offset, c, d, closing);
    interpolation = Interpolation(
        value=expression,
        str=PyStr(t="str", val=text.rstrip("= \t\r\n\f")),
        conversion=_interpolation_conversion(b, c, d),
        format_spec=d as expr if d is not None else None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
    if b is None {
        return interpolation;
    }
    debug = pa_formatted_value(
        p, a, b, c, d, e, lineno, col_offset, end_lineno, end_col_offset
    ) as JoinedStr;
    debug.values[-1] = interpolation;
    return debug;
}
