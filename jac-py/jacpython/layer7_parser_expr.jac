# P0.7 generated-parser expression slice tests (PLAN.md).
#
# Tokenizer output -> generated PEG rules (parser_expr.jac) -> ast_nodes.jac.
# Compares parse trees against compiler_slice hand-built fixtures.

import from ast_nodes {
    expr,
    mod,
    Expression,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Tuple,
    Add,
    Mult,
    USub,
    Lt,
    Load,
}
import from objects { PyInt }
import from parser { parse_eval_expr }
import from compiler_slice {
    ast_one_plus_one,
    ast_neg_x,
    ast_add_mul,
    ast_call_fx1,
    ast_cmp_chain,
}

def expr_lineno(e: expr) -> int {
    if isinstance(e, BinOp) {
        return (e as BinOp).lineno;
    }
    if isinstance(e, Constant) {
        return (e as Constant).lineno;
    }
    if isinstance(e, Name) {
        return (e as Name).lineno;
    }
    if isinstance(e, UnaryOp) {
        return (e as UnaryOp).lineno;
    }
    if isinstance(e, Call) {
        return (e as Call).lineno;
    }
    if isinstance(e, Compare) {
        return (e as Compare).lineno;
    }
    return -1;
}

def same_constant(a: Constant, b: Constant) -> bool {
    if a.lineno != b.lineno or a.col_offset != b.col_offset {
        return False;
    }
    if a.end_lineno != b.end_lineno or a.end_col_offset != b.end_col_offset {
        return False;
    }
    if not isinstance(a.value, PyInt) or not isinstance(b.value, PyInt) {
        return False;
    }
    return (a.value as PyInt).val == (b.value as PyInt).val;
}

def same_name(a: Name, b: Name) -> bool {
    return (
        a.id == b.id
        and a.lineno == b.lineno
        and a.col_offset == b.col_offset
        and a.end_lineno == b.end_lineno
        and a.end_col_offset == b.end_col_offset
    );
}

def same_expr(a: expr, b: expr) -> bool {
    if isinstance(a, Constant) and isinstance(b, Constant) {
        return same_constant(a as Constant, b as Constant);
    }
    if isinstance(a, Name) and isinstance(b, Name) {
        return same_name(a as Name, b as Name);
    }
    if isinstance(a, UnaryOp) and isinstance(b, UnaryOp) {
        ua = a as UnaryOp;
        ub = b as UnaryOp;
        return (
            ua.lineno == ub.lineno
            and ua.col_offset == ub.col_offset
            and same_expr(ua.operand, ub.operand)
        );
    }
    if isinstance(a, BinOp) and isinstance(b, BinOp) {
        ba = a as BinOp;
        bb = b as BinOp;
        return (
            ba.lineno == bb.lineno
            and ba.col_offset == bb.col_offset
            and same_expr(ba.left, bb.left)
            and same_expr(ba.right, bb.right)
        );
    }
    if isinstance(a, Call) and isinstance(b, Call) {
        ca = a as Call;
        cb = b as Call;
        if not same_name(ca.func as Name, cb.func as Name) {
            return False;
        }
        if len(ca.args) != len(cb.args) {
            return False;
        }
        i = 0;
        while i < len(ca.args) {
            if not same_expr(ca.args[i], cb.args[i]) {
                return False;
            }
            i = i + 1;
        }
        return ca.lineno == cb.lineno and ca.col_offset == cb.col_offset;
    }
    if isinstance(a, Compare) and isinstance(b, Compare) {
        ca = a as Compare;
        cb = b as Compare;
        if len(ca.ops) != len(cb.ops) or len(ca.comparators) != len(cb.comparators) {
            return False;
        }
        if not same_name(ca.left as Name, cb.left as Name) {
            return False;
        }
        i = 0;
        while i < len(ca.comparators) {
            if not same_name(ca.comparators[i] as Name, cb.comparators[i] as Name) {
                return False;
            }
            i = i + 1;
        }
        return ca.lineno == cb.lineno and ca.col_offset == cb.col_offset;
    }
    return False;
}

def assert_parse_matches(source: str, expected: expr) {
    got = parse_eval_expr(source, "<parser-test>");
    assert got is not None;
    assert same_expr(got, expected);
}

test "parser_expr: 1+1 matches hand-built AST" {
    assert_parse_matches("1+1", ast_one_plus_one());
}

test "parser_expr: -x matches hand-built AST" {
    assert_parse_matches("-x", ast_neg_x());
}

test "parser_expr: a*b+c matches hand-built AST" {
    assert_parse_matches("a*b+c", ast_add_mul());
}

test "parser_expr: f(x,1) matches hand-built AST" {
    assert_parse_matches("f(x,1)", ast_call_fx1());
}

test "parser_expr: x<y<z matches hand-built AST" {
    assert_parse_matches("x<y<z", ast_cmp_chain());
}

test "parser_expr: singleton tuple (0,) parses" {
    got = parse_eval_expr("(0,)", "<parser-test>");
    assert got is not None;
    assert isinstance(got, Tuple);
    tu = got as Tuple;
    assert len(tu.elts) == 1;
    assert isinstance(tu.elts[0], Constant);
    c = tu.elts[0] as Constant;
    assert isinstance(c.value, PyInt);
    assert (c.value as PyInt).val == 0;
}

test "parser_expr: multi-element tuple (0, 1) parses" {
    got = parse_eval_expr("(0, 1)", "<parser-test>");
    assert got is not None;
    assert isinstance(got, Tuple);
    tu = got as Tuple;
    assert len(tu.elts) == 2;
}

def call_keyword_sig(e: expr) -> list[str] {
    assert isinstance(e, Call);
    c = e as Call;
    sig: list[str] = [];
    for k in c.keywords {
        kw = k as keyword;
        if kw.arg is not None {
            sig.append(kw.arg);
        } else {
            sig.append("**");
        }
    }
    return sig;
}

test "parser_expr: trailing **kwargs after named kwarg is kept (8473)" {
    got = parse_eval_expr("g(a=1, **d)", "<parser-test>");
    assert got is not None;
    assert call_keyword_sig(got) == ["a", "**"];
}

test "parser_expr: trailing **kwargs after star and named kwarg is kept (8473)" {
    got = parse_eval_expr("g(*a, b=1, **d)", "<parser-test>");
    assert got is not None;
    assert len((got as Call).args) == 1;
    assert call_keyword_sig(got) == ["b", "**"];
}

test "parser_expr: mixed star and double-star kwargs variants" {
    got = parse_eval_expr("g(a=1, *b, **d)", "<parser-test>");
    assert got is not None;
    assert len((got as Call).args) == 1;
    assert call_keyword_sig(got) == ["a", "**"];
    got = parse_eval_expr("g(a=1, **d,)", "<parser-test>");
    assert got is not None;
    assert call_keyword_sig(got) == ["a", "**"];
    got = parse_eval_expr("g(**d, **e)", "<parser-test>");
    assert got is not None;
    assert call_keyword_sig(got) == ["**", "**"];
}
