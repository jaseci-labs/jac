# P0.10 compiler slice tests (PLAN.md): hand-built AST -> codegen -> assembler.
#
# Differential against the host oracle (byte-exact PyCode) plus VM execution for
# expression fixtures: -x, a*b+c, f(x,1), x<y<z, 1+1.
#
# Test harness only: may import host_oracle for expected PyCode bytes.

import from objects {
    PyObj,
    PyCode,
    PyInt,
    PyBool,
    expect_int,
    expect_str,
    is_error,
    PyError,
    py_none
}
import from ast_nodes {
    expr,
    stmt,
    Constant,
    Name,
    BinOp,
    UnaryOp,
    Call,
    Compare,
    Assign,
    Return,
    BoolOp,
    And,
    Attribute,
    Subscript,
    FunctionDef,
    arguments,
    arg,
    Lt,
    Load,
    Store,
    Add,
    Mult,
    USub,
}
import from parser { parse_file }
import from ast_nodes { Module }
import from compiler_codegen { compile_eval, compile_exec }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_validate { validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_kind, compiler_diag_message }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, gen_send, py_subscript, PyGenerator }

def oracle_eval(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "eval", 0));
}

def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

def compile_handbuilt(e: expr, filename: str = "<f>") -> PyCode {
    u = compile_eval(e, filename, "<module>", 1);
    assert u.diag is None;
    return assemble(verify_cfg(u));
}

def compile_parsed_exec(source: str, filename: str = "<f>") -> PyCode {
    m = parse_file(source, filename);
    assert m is not None;
    body = (m as Module).body;
    vr = validate_module_body(body);
    assert vr.diag is None;
    sr = build_module_symtable(body);
    assert sr.diag is None;
    u = compile_exec(body, filename, "<module>", 1, sr.top);
    assert u.diag is None;
    return assemble(verify_cfg(u));
}

def compile_handbuilt_exec(body: list[stmt], filename: str = "<f>") -> PyCode {
    vr = validate_module_body(body);
    assert vr.diag is None;
    sr = build_module_symtable(body);
    assert sr.diag is None;
    u = compile_exec(body, filename, "<module>", 1, sr.top);
    assert u.diag is None;
    return assemble(verify_cfg(u));
}

def first_nested_code(co: PyCode) -> PyCode {
    ci = 0;
    while ci < len(co.consts) {
        c = co.consts[ci];
        if isinstance(c, PyCode) {
            return c as PyCode;
        }
        ci = ci + 1;
    }
    assert False;
    return co;
}

def nested_code_by_name(co: PyCode, name: str) -> PyCode {
    ci = 0;
    while ci < len(co.consts) {
        c = co.consts[ci];
        if isinstance(c, PyCode) {
            nested = c as PyCode;
            if nested.name == name {
                return nested;
            }
        }
        ci = ci + 1;
    }
    assert False;
    return co;
}

def ast_chained_assign -> list[stmt] {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=9
    );
    return [
        Assign(
            targets=[x, y],
            value=one,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=9
        )
    ];
}

def ast_chained_compare_assign_false -> list[stmt] {
    a = Name(
        id="a", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    five = Constant(
        value=PyInt(t="int", val=5),
        kind=None,
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=9
    );
    three = Constant(
        value=PyInt(t="int", val=3),
        kind=None,
        lineno=1,
        col_offset=12,
        end_lineno=1,
        end_col_offset=13
    );
    cmp = Compare(
        left=one,
        ops=[Lt(), Lt()],
        comparators=[five, three],
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=13
    );
    return [
        Assign(
            targets=[a],
            value=cmp,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=13
        )
    ];
}

def consts_equal(a: list[PyObj], b: list[PyObj]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    i = 0;
    while i < len(a) {
        if a[i].tp_hashkey() != b[i].tp_hashkey() {
            return False;
        }
        i = i + 1;
    }
    return True;
}

def assert_matches_oracle(e: expr, source: str, filename: str = "<f>") {
    actual = compile_handbuilt(e, filename);
    expected = oracle_eval(source, filename);
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    # Byte-exact slice: co_code, tables, stack depth, PEP 626 linetable. Oracle
    # marshal currently mis-loads co_flags (pyc_first read_code); skip flags
    # until that lands.
    assert actual.co_code == exp.co_code;
    assert actual.linetable == exp.linetable;
    assert actual.names == exp.names;
    assert consts_equal(actual.consts, exp.consts);
    assert actual.stacksize == exp.stacksize;
    assert actual.filename == exp.filename;
    assert actual.name == exp.name;
    assert actual.qualname == exp.qualname;
    assert actual.firstlineno == exp.firstlineno;
    assert actual.exceptiontable == exp.exceptiontable;
}

# AST trees with CPython 3.14-exact source spans (verified via co_positions).

def ast_neg_x -> expr {
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=1, end_lineno=1, end_col_offset=2
    );
    return UnaryOp(
        op=USub(), operand=x, lineno=1, col_offset=0, end_lineno=1, end_col_offset=2
    );
}

def ast_add_mul -> expr {
    a = Name(
        id="a", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    b = Name(
        id="b", ctx=Load(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    c = Name(
        id="c", ctx=Load(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
    );
    prod = BinOp(
        left=a,
        op=Mult(),
        right=b,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=3
    );
    return BinOp(
        left=prod,
        op=Add(),
        right=c,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=5
    );
}

def ast_call_fx1 -> expr {
    f = Name(
        id="f", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    return Call(
        func=f,
        args=[x, one],
        keywords=[],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=6
    );
}

def ast_cmp_chain -> expr {
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Load(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    z = Name(
        id="z", ctx=Load(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
    );
    return Compare(
        left=x,
        ops=[Lt(), Lt()],
        comparators=[y, z],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=5
    );
}

def ast_cmp_in_call -> expr {
    f = Name(
        id="f", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    return Call(
        func=f,
        args=[ast_cmp_chain()],
        keywords=[],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=10
    );
}

def ast_cmp_and_q -> expr {
    q = Name(
        id="q", ctx=Load(), lineno=1, col_offset=13, end_lineno=1, end_col_offset=14
    );
    return BoolOp(
        op=And(),
        values=[ast_cmp_chain(), q],
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=14
    );
}

def ast_chained_side_effect_assign -> list[stmt] {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=1, col_offset=4, end_lineno=1, end_col_offset=5
    );
    rhs = Call(
        func=Name(
            id="side_effect",
            ctx=Load(),
            lineno=1,
            col_offset=8,
            end_lineno=1,
            end_col_offset=19
        ),
        args=[],
        keywords=[],
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=21
    );
    return [
        Assign(
            targets=[x, y],
            value=rhs,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=21
        )
    ];
}

def ast_chained_attr_subscript_assign -> list[stmt] {
    obj_ref = Name(
        id="obj", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=3
    );
    attr_tgt = Attribute(
        value=obj_ref,
        attr="x",
        ctx=Store(),
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=5
    );
    seq = Name(
        id="seq", ctx=Load(), lineno=1, col_offset=8, end_lineno=1, end_col_offset=11
    );
    index_call = Call(
        func=Name(
            id="index",
            ctx=Load(),
            lineno=1,
            col_offset=12,
            end_lineno=1,
            end_col_offset=17
        ),
        args=[],
        keywords=[],
        lineno=1,
        col_offset=12,
        end_lineno=1,
        end_col_offset=19
    );
    sub_tgt = Subscript(
        value=seq,
        slice=index_call,
        ctx=Store(),
        lineno=1,
        col_offset=8,
        end_lineno=1,
        end_col_offset=20
    );
    value_call = Call(
        func=Name(
            id="value",
            ctx=Load(),
            lineno=1,
            col_offset=23,
            end_lineno=1,
            end_col_offset=28
        ),
        args=[],
        keywords=[],
        lineno=1,
        col_offset=23,
        end_lineno=1,
        end_col_offset=30
    );
    return [
        Assign(
            targets=[attr_tgt, sub_tgt],
            value=value_call,
            type_comment=None,
            lineno=1,
            col_offset=0,
            end_lineno=1,
            end_col_offset=30
        )
    ];
}

def ast_one_plus_one -> expr {
    one_a = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=1
    );
    one_b = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=2,
        end_lineno=1,
        end_col_offset=3
    );
    return BinOp(
        left=one_a,
        op=Add(),
        right=one_b,
        lineno=1,
        col_offset=0,
        end_lineno=1,
        end_col_offset=3
    );
}

# ---------------- byte-exact oracle parity ----------------

test "compiler_slice: -x matches oracle PyCode" {
    assert_matches_oracle(ast_neg_x(), "-x");
}

test "compiler_slice: a*b+c matches oracle PyCode" {
    assert_matches_oracle(ast_add_mul(), "a*b+c");
}

test "compiler_slice: f(x,1) matches oracle PyCode" {
    assert_matches_oracle(ast_call_fx1(), "f(x,1)");
}

test "compiler_slice: x<y<z matches oracle PyCode" {
    assert_matches_oracle(ast_cmp_chain(), "x<y<z");
}

test "compiler_slice: f(x<y<z) matches oracle PyCode" {
    actual = compile_handbuilt(ast_cmp_in_call());
    expected = oracle_eval("f(x<y<z)", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: (x<y<z) and q matches oracle PyCode" {
    actual = compile_handbuilt(ast_cmp_and_q());
    expected = oracle_eval("(x < y < z) and q", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

# is / is not / in / not in in value context: IS_OP / CONTAINS_OP with the
# negation folded into oparg 1. Value-context identity against None is plain
# IS_OP (the jump peephole only fires in test context, handled in a later slice).
test "compiler_slice: is / is not / in / not in value context match oracle PyCode" {
    src = (
        "r1 = a is b\n"
        + "r2 = a is not b\n"
        + "r3 = a in xs\n"
        + "r4 = a not in xs\n"
        + "r5 = a is None\n"
        + "r6 = a is not None\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

# Membership / non-None identity in test (jump) context: CONTAINS_OP / IS_OP
# consumed by POP_JUMP_IF_FALSE. Each in its own single-`if` module so the
# operands stay LOAD_NAME (the LOAD_FAST_LOAD_FAST fuse and consecutive-`if`
# layout are separate pre-existing concerns, not the comparison lowering here).
test "compiler_slice: in / is test context match oracle co_code" {
    for src in [
        "if a in xs:\n    r = 1\n",
        "if a not in xs:\n    r = 1\n",
        "if a is b:\n    r = 1\n",
        "if a is not b:\n    r = 1\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        exp = expected as PyCode;
        assert actual.co_code == exp.co_code;
        assert actual.exceptiontable == exp.exceptiontable;
        assert actual.stacksize == exp.stacksize;
    }
}

# CONTAINS_OP in a comprehension filter (bool context). List comprehensions are
# inlined in 3.14, so the membership op lands directly in the module co_code.
test "compiler_slice: membership filter comprehension matches oracle PyCode" {
    src = "ys = [i for i in xs if i in seen]\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

# An `if` at a function tail whose branch(es) terminate (return/raise) must not
# synthesize dead code after the terminator. CPython duplicates the implicit
# `return None` into a non-terminating branch and lets a terminating branch stand
# alone. Checked via nested co_code (module co_code is blind to the bodies).
# Operands are constants / bool tests only -- returning a local would hit the
# separate LOAD_FAST_BORROW escape gap.
test "compiler_slice: if-at-tail with terminating branches matches oracle nested co_code" {
    for src in [
        "def f(x):\n    if x:\n        return 1\n",
        "def f(x):\n    if x:\n        return 1\n    else:\n        return 2\n",
        "def f(x):\n    if x:\n        raise ValueError\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        af = nested_code_by_name(actual, "f");
        ef = nested_code_by_name(expected as PyCode, "f");
        assert af.co_code == ef.co_code;
        assert af.exceptiontable == ef.exceptiontable;
        assert af.stacksize == ef.stacksize;
    }
}

# The symtable USE pass must visit expressions inside `raise` and `assert`, or
# their names never get scope-classified: a function-scope builtin/global (e.g.
# ValueError) mis-emits LOAD_NAME instead of LOAD_GLOBAL (and a closure var would
# miscompile). Verified via nested co_code.
test "compiler_slice: raise / assert register name USE for LOAD_GLOBAL" {
    for src in [
        "def f(x):\n    raise ValueError\n",
        "def f(e):\n    raise ValueError from e\n",
        "def f(x):\n    assert x, RuntimeError\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        af = nested_code_by_name(actual, "f");
        ef = nested_code_by_name(expected as PyCode, "f");
        assert af.co_code == ef.co_code;
        assert af.exceptiontable == ef.exceptiontable;
        assert af.stacksize == ef.stacksize;
    }
}

# A loop `else` that terminates (no break) makes the statements after the loop
# unreachable -- normal completion always runs the else. CPython drops them (DCE);
# native must not emit them, or it crashes with dead code after a terminator.
test "compiler_slice: loop-else that terminates drops unreachable trailing code" {
    for src in [
        "def f(x):\n    for i in x:\n        pass\n    else:\n        return 1\n    return 2\n",
        "def f(x):\n    while x:\n        pass\n    else:\n        return 1\n    return 2\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        af = nested_code_by_name(actual, "f");
        ef = nested_code_by_name(expected as PyCode, "f");
        assert af.co_code == ef.co_code;
        assert af.exceptiontable == ef.exceptiontable;
        assert af.stacksize == ef.stacksize;
    }
}

# Conditional expression (ternary) in embedded position -- value consumed by a
# surrounding operation -- uses CPython's branch+join shape and is byte-exact.
# (A statement-tail `x = a if c else b` is duplicated by CPython and is a separate
# slice; here every ifexp is embedded so the branch+join form matches.)
test "compiler_slice: embedded conditional expression matches oracle PyCode" {
    for src in [
        "r = (a if c else b) + 1\nz = 0\n",
        "r = f(a if c else b)\nz = 0\n",
        "r = [a if c else b]\nz = 0\n",
        "r = (a if c else b) * (d if e else g)\nz = 0\n",
        "r = -(a if c else b)\nz = 0\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        exp = expected as PyCode;
        assert actual.co_code == exp.co_code;
        assert actual.exceptiontable == exp.exceptiontable;
        assert actual.stacksize == exp.stacksize;
    }
}

# Non-constant slices: CPython 3.14 uses BINARY_SLICE (2-elt load) / STORE_SLICE
# (2-elt store), and BUILD_SLICE (2 or 3) for 3-elt and all deletes. Missing
# bounds fill with LOAD_CONST None. Constant slices stay folded (LOAD_CONST slice).
test "compiler_slice: non-constant slice subscript matches oracle PyCode" {
    for src in [
        "r = x[a:b]\n",
        "r = x[a:b:c]\n",
        "r = x[a:]\n",
        "r = x[:b]\n",
        "r = x[:]\n",
        "x[a:b] = v\n",
        "x[a:b:c] = v\n",
        "x[a:] = v\n",
        "del x[a:b]\n",
        "del x[a:b:c]\n",
        "r = x[1:2]\n",
        "x[1:2] = v\n",
        "del x[1:2]\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        exp = expected as PyCode;
        assert actual.co_code == exp.co_code;
        assert actual.exceptiontable == exp.exceptiontable;
        assert actual.stacksize == exp.stacksize;
    }
}

# global / nonlocal are scope declarations (no bytecode of their own); they
# retarget stores/deletes to STORE_GLOBAL / DELETE_GLOBAL / STORE_DEREF. Checked
# via nested function co_code (module co_code is blind to the bodies).
test "compiler_slice: global store / delete match oracle nested co_code" {
    src = (
        "def f():\n"
        + "    global x\n"
        + "    x = 1\n"
        + "    del x\n"
        + "    return x\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    af = nested_code_by_name(actual, "f");
    ef = nested_code_by_name(expected as PyCode, "f");
    assert af.co_code == ef.co_code;
    assert af.exceptiontable == ef.exceptiontable;
    assert af.stacksize == ef.stacksize;
}

test "compiler_slice: nonlocal store matches oracle nested co_code" {
    src = (
        "def o():\n"
        + "    y = 1\n"
        + "    def i():\n"
        + "        nonlocal y\n"
        + "        y = 2\n"
        + "        return y\n"
        + "    return i\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    ao = nested_code_by_name(actual, "o");
    eo = nested_code_by_name(expected as PyCode, "o");
    af = nested_code_by_name(ao, "i");
    ef = nested_code_by_name(eo, "i");
    assert af.co_code == ef.co_code;
    assert af.stacksize == ef.stacksize;
}

# Deleting a plain function local retargets to DELETE_FAST (was DELETE_NAME).
test "compiler_slice: delete local matches oracle nested co_code" {
    src = "def f():\n    x = 1\n    del x\n    return 0\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    af = nested_code_by_name(actual, "f");
    ef = nested_code_by_name(expected as PyCode, "f");
    assert af.co_code == ef.co_code;
}

# `x is None` / `x is not None` in if / while test context fold into the CPython
# jump peephole POP_JUMP_IF_NOT_NONE / POP_JUMP_IF_NONE (the LOAD_CONST None +
# IS_OP are dropped, but None keeps its co_consts slot).
test "compiler_slice: is-None jump peephole matches oracle PyCode" {
    for src in [
        "if a is None:\n    r = 1\n",
        "if a is not None:\n    r = 1\n",
        "if a is None:\n    r = 1\nelse:\n    r = 2\n",
        "while a is None:\n    a = f()\n",
        "while a is not None:\n    a = f()\n",
        "x = 1\nif a is None:\n    r = 2\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        exp = expected as PyCode;
        assert actual.co_code == exp.co_code;
        assert actual.exceptiontable == exp.exceptiontable;
        assert actual.stacksize == exp.stacksize;
        assert len(actual.consts) == len(exp.consts);
    }
}

# A loop (while/for) followed by more statements in a function body: the loop's
# tail-threaded continuation must propagate `terminated`, else compile_fn_cfg
# appends a second LOAD_CONST None; RETURN_VALUE after the tail's own return,
# producing dead code after a terminator (ValueError "Invalid CFG"). This asserts
# the crash is gone and the block structure matches (co_code length, except table,
# stacksize). Exact co_code still awaits the LOAD_FAST_BORROW escape-analysis pass
# (bare `return <local>` should upgrade the borrow to LOAD_FAST).
test "compiler_slice: loop then trailing statements compile with sound structure" {
    for src in [
        "def f(a):\n    while a:\n        pass\n    return a\n",
        "def f(a):\n    while a:\n        a = a.b\n    return a\n",
        "def f(a):\n    for x in a:\n        pass\n    return a\n",
        "def f(a):\n    for x in a:\n        y = x\n    z = 1\n    return z\n",
        "def f(a):\n    while a:\n        break\n    return a\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        af = nested_code_by_name(actual, "f");
        ef = nested_code_by_name(expected as PyCode, "f");
        assert len(af.co_code) == len(ef.co_code);
        assert af.exceptiontable == ef.exceptiontable;
        assert af.stacksize == ef.stacksize;
    }
}

test "compiler_slice: 1+1 matches oracle PyCode" {
    assert_matches_oracle(ast_one_plus_one(), "1+1");
}

test "compiler_slice: x = y = 1 matches oracle PyCode" {
    actual = compile_handbuilt_exec(ast_chained_assign());
    expected = oracle_exec("x = y = 1\n", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: x = y = side_effect() matches oracle PyCode" {
    actual = compile_handbuilt_exec(ast_chained_side_effect_assign());
    expected = oracle_exec("x = y = side_effect()\n", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: side_effect chained assignment evaluates RHS once" {
    setup = unmarshal(
        host_compile_marshal(
            "count = 0\n"
                + "def side_effect():\n"
                + "    global count\n"
                + "    count = count + 1\n"
                + "    return 42\n",
            "<setup>",
            "exec",
            0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    co = compile_handbuilt_exec(ast_chained_side_effect_assign());
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert expect_int(ns["x"]) == 42;
    assert expect_int(ns["y"]) == 42;
    assert expect_int(ns["count"]) == 1;
}

test "compiler_slice: obj.x = seq[index()] = value() matches oracle PyCode" {
    actual = compile_handbuilt_exec(ast_chained_attr_subscript_assign());
    expected = oracle_exec("obj.x = seq[index()] = value()\n", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: chained compare assign false short-circuit executes" {
    co = compile_handbuilt_exec(ast_chained_compare_assign_false());
    ns: dict[str, PyObj] = {};
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert "a" in ns;
    assert isinstance(ns["a"], PyBool);
    assert not (ns["a"] as PyBool).val;
}

test "compiler_slice: module return rejected by validation" {
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=7,
        end_lineno=1,
        end_col_offset=8
    );
    vr = validate_module_body(
        [Return(value=one, lineno=1, col_offset=0, end_lineno=1, end_col_offset=8)]
    );
    assert vr.diag is not None;
    assert compiler_diag_kind(vr.diag) == "SyntaxError";
    assert compiler_diag_message(vr.diag) == "'return' outside function";
}

# ---------------- VM execution ----------------

test "compiler_slice: -x executes in ceval" {
    co = compile_handbuilt(ast_neg_x());
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=7)};
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == -7;
}

test "compiler_slice: a*b+c executes in ceval" {
    co = compile_handbuilt(ast_add_mul());
    ns: dict[str, PyObj] = {
        "a": PyInt(t="int", val=2),
        "b": PyInt(t="int", val=3),
        "c": PyInt(t="int", val=4),

    };
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 10;
}

test "compiler_slice: f(x,1) executes in ceval" {
    setup = unmarshal(
        host_compile_marshal(
            "def f(x, y):\n    return x * 10 + y\n", "<setup>", "exec", 0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    ns["x"] = PyInt(t="int", val=3);
    co = compile_handbuilt(ast_call_fx1());
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 31;
}

test "compiler_slice: x<y<z executes in ceval (true chain)" {
    co = compile_handbuilt(ast_cmp_chain());
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),

    };
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyBool);
    assert (outcome as PyBool).val;
}

test "compiler_slice: x<y<z executes in ceval (short-circuit false)" {
    co = compile_handbuilt(ast_cmp_chain());
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=5),
        "z": PyInt(t="int", val=3),

    };
    outcome = exec_code(co, [], ns);
    assert not is_error(outcome);
    assert isinstance(outcome, PyBool);
    assert not (outcome as PyBool).val;
}

test "compiler_slice: 1+1 executes in ceval" {
    co = compile_handbuilt(ast_one_plus_one());
    outcome = exec_code(co, [], {});
    assert not is_error(outcome);
    assert isinstance(outcome, PyInt);
    assert expect_int(outcome) == 2;
}

def ast_band4_fn_call -> list[stmt] {
    xarg = arg(
        arg="x",
        annotation=None,
        type_comment=None,
        lineno=1,
        col_offset=5,
        end_lineno=1,
        end_col_offset=6
    );
    xload = Name(
        id="x", ctx=Load(), lineno=2, col_offset=11, end_lineno=2, end_col_offset=12
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=2,
        col_offset=15,
        end_lineno=2,
        end_col_offset=16
    );
    fbody = [
        Return(
            value=BinOp(
                left=xload,
                op=Add(),
                right=one,
                lineno=2,
                col_offset=11,
                end_lineno=2,
                end_col_offset=16
            ),
            lineno=2,
            col_offset=4,
            end_lineno=2,
            end_col_offset=16
        ),

    ];
    fdef = FunctionDef(
        name="f",
        args=arguments(
            posonlyargs=[],
            args=[xarg],
            vararg=None,
            kwonlyargs=[],
            kw_defaults=[],
            kwarg=None,
            defaults=[]
        ),
        body=fbody,
        decorator_list=[],
        returns=None,
        type_comment=None,
        type_params=[],
        lineno=1,
        col_offset=0,
        end_lineno=2,
        end_col_offset=16
    );
    result = Name(
        id="result", ctx=Store(), lineno=4, col_offset=0, end_lineno=4, end_col_offset=6
    );
    fload = Name(
        id="f", ctx=Load(), lineno=4, col_offset=9, end_lineno=4, end_col_offset=10
    );
    two = Constant(
        value=PyInt(t="int", val=2),
        kind=None,
        lineno=4,
        col_offset=11,
        end_lineno=4,
        end_col_offset=12
    );
    return [
        fdef,
        Assign(
            targets=[result],
            value=Call(
                func=fload,
                args=[two],
                keywords=[],
                lineno=4,
                col_offset=9,
                end_lineno=4,
                end_col_offset=13
            ),
            type_comment=None,
            lineno=4,
            col_offset=0,
            end_lineno=4,
            end_col_offset=13
        ),

    ];
}

test "compiler_slice: band4 def f(x) return x+1 call matches oracle" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    actual = compile_handbuilt_exec(ast_band4_fn_call());
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = actual.consts[0] as PyCode;
    exp_fn = exp.consts[0] as PyCode;
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 parsed source executes in ceval" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 def f(x) return x+1 call executes in ceval" {
    co = compile_handbuilt_exec(ast_band4_fn_call());
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 recursive fact parsed matches oracle nested co_code" {
    src = (
        "def fact(n):\n"
        + "    if n <= 1:\n"
        + "        return 1\n"
        + "    return n * fact(n - 1)\n\n"
        + "result = fact(5)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = actual.consts[0] as PyCode;
    exp_fn = exp.consts[0] as PyCode;
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["n"];
    assert fn.flags == 3;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 recursive fact parsed executes in ceval" {
    src = (
        "def fact(n):\n"
        + "    if n <= 1:\n"
        + "        return 1\n"
        + "    return n * fact(n - 1)\n\n"
        + "result = fact(5)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 120;
}

# ---------------- Band 4: lambdas slice ----------------

test "compiler_slice: band4 lambda assign parsed matches oracle nested co_code" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = actual.consts[0] as PyCode;
    exp_fn = exp.consts[0] as PyCode;
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 lambda assign parsed executes in ceval" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 inline lambda call parsed executes in ceval" {
    src = "result = (lambda x: x + 1)(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: closures slice ----------------

test "compiler_slice: band4 closure parsed matches oracle nested inner co_code" {
    src = (
        "def outer(x):\n"
        + "    def inner():\n"
        + "        return x\n"
        + "    return inner()\n\n"
        + "result = outer(42)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    outer = actual.consts[0] as PyCode;
    exp_outer = exp.consts[0] as PyCode;
    inner = outer.consts[0] as PyCode;
    exp_inner = exp_outer.consts[0] as PyCode;
    assert inner.co_code == exp_inner.co_code;
    assert inner.stacksize == exp_inner.stacksize;
    assert len(inner.freevars) == 1;
    assert inner.freevars[0] == "x";
    assert len(outer.cellvars) == 1;
    assert outer.cellvars[0] == "x";
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 closure parsed executes in ceval" {
    src = (
        "def outer(x):\n"
        + "    def inner():\n"
        + "        return x\n"
        + "    return inner()\n\n"
        + "result = outer(42)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 42;
}

test "compiler_slice: band4 lambda closure parsed executes in ceval" {
    src = "def outer(x):\n    return lambda: x\n\nresult = outer(7)()\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
}

# ---------------- Band 4: default arguments slice ----------------

test "compiler_slice: parse default args ast" {
    src0 = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    m0 = parse_file(src0, "<f>");
    assert m0 is not None;
    assert len((m0 as Module).body) == 2;
    src1 = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    m1 = parse_file(src1, "<f>");
    assert m1 is not None;
    assert len((m1 as Module).body) == 2;
    fd = (m1 as Module).body[0] as FunctionDef;
    assert len(fd.args.defaults) == 1;
    assert len(fd.args.args) == 2;
}

test "compiler_slice: band4 default args parsed matches oracle nested f co_code" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 2;
    assert fn.varnames == ["x", "y"];
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band4 default args parsed executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "compiler_slice: band4 default args explicit call executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2, 3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 5;
}

test "compiler_slice: band4 lambda default args parsed executes in ceval" {
    src = "g = lambda x, y=1: x + y\nresult = g(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: *args / **kwargs / kw-only slice ----------------

test "compiler_slice: parse varargs ast" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    m = parse_file(src, "<f>");
    assert m is not None;
    fd = (m as Module).body[0] as FunctionDef;
    assert fd.args.vararg is not None;
    assert (fd.args.vararg as arg).arg == "args";
    assert len(fd.args.args) == 1;
}

test "compiler_slice: band4 varargs parsed matches oracle nested f co_code" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.kwonlyargcount == 0;
    assert fn.varnames == ["a", "args"];
    assert (fn.flags & 4) != 0;
}

test "compiler_slice: band4 varargs parsed executes in ceval" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 varkw parsed matches oracle co_code" {
    src = "def f(a, **kwargs):\n    return a + len(kwargs)\n\nresult = f(1, b=2, c=3)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    assert actual.co_code == (expected as PyCode).co_code;
    assert actual.stacksize == (expected as PyCode).stacksize;
}

test "compiler_slice: band4 varkw parsed executes in ceval" {
    src = "def f(a, **kwargs):\n    return a + len(kwargs)\n\nresult = f(1, b=2, c=3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 kwonly default parsed matches oracle nested f co_code" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.kwonlyargcount == 1;
    assert fn.varnames == ["a", "b"];
}

test "compiler_slice: band4 kwonly default parsed executes in ceval" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "compiler_slice: band4 varargs kwonly default parsed executes in ceval" {
    src = "def f(a, *args, b=1):\n    return a + len(args) + b\n\nresult = f(1, 2, 3)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 4;
}

# ---------------- Band 4: decorators slice ----------------

test "compiler_slice: band4 decorator parse attaches decorator_list" {
    src = (
        "def deco(fn):\n"
        + "    return fn\n\n"
        + "@deco\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    m = parse_file(src, "<f>");
    assert m is not None;
    fd = (m as Module).body[1] as FunctionDef;
    assert len(fd.decorator_list) == 1;
    dec = fd.decorator_list[0] as Name;
    assert dec.id == "deco";
}

test "compiler_slice: band4 decorator parsed matches oracle co_code" {
    src = (
        "def deco(fn):\n"
        + "    return fn\n\n"
        + "@deco\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    fn = nested_code_by_name(actual, "f");
    exp_fn = nested_code_by_name(exp, "f");
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
}

test "compiler_slice: band4 decorator parsed executes in ceval" {
    src = (
        "def deco(fn):\n"
        + "    return fn\n\n"
        + "@deco\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band4 multiple decorators parsed executes in ceval" {
    src = (
        "def d1(fn):\n"
        + "    return fn\n\n"
        + "def d2(fn):\n"
        + "    return fn\n\n"
        + "@d1\n"
        + "@d2\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 5 slice 1: basic class body ----------------

test "compiler_slice: band5 empty class parsed matches oracle co_code" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    nested = nested_code_by_name(actual, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == exp_nested.co_code;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.argcount == 0;
}

test "compiler_slice: band5 empty class parsed executes in ceval" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "C";
}

# CPython 3.14.6 co_code for `class C: def m(self): return 1` body (with __classdict__).
glob BAND5_CLASS_C_CO_CODE: list[int] = [
         97,
         0,
         128,
         0,
         93,
         0,
         116,
         1,
         82,
         0,
         116,
         2,
         94,
         1,
         116,
         3,
         22,
         0,
         111,
         0,
         82,
         1,
         23,
         0,
         116,
         4,
         82,
         2,
         116,
         5,
         86,
         0,
         116,
         6,
         82,
         3,
         35,
         0,

     ];

test "compiler_slice: band5 class method parsed matches oracle co_code" {
    src = (
        "class C:\n"
        + "    def m(self):\n"
        + "        return 1\n\n"
        + "result = C().m()\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    nested = nested_code_by_name(actual, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == BAND5_CLASS_C_CO_CODE;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.cellvars == ["__classdict__"];
    method = nested_code_by_name(nested, "m");
    exp_method = nested_code_by_name(exp_nested, "m");
    assert method.co_code == exp_method.co_code;
    assert method.argcount == 1;
    assert method.varnames == ["self"];
}

test "compiler_slice: band5 class method parsed executes in ceval" {
    src = (
        "class C:\n"
        + "    def m(self):\n"
        + "        return 1\n\n"
        + "result = C().m()\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

# ---------------- Band 5: imports slice ----------------

test "compiler_slice: import math matches oracle" {
    src = "import math\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    assert actual.names == exp.names;
}

test "compiler_slice: from operator import add matches oracle" {
    src = "from operator import add\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    assert actual.names == exp.names;
}

test "compiler_slice: from operator import add as plus matches oracle" {
    src = "from operator import add as plus\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    assert actual.names == exp.names;
}

test "compiler_slice: import math executes in ceval" {
    src = "import math\nresult = math.pi > 3\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert isinstance(ns["result"], PyBool);
    assert (ns["result"] as PyBool).val;
}

test "compiler_slice: from operator import add executes in ceval" {
    src = "from operator import add\nresult = add(1, 2)\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 5 slice 3: name mangling (__private) ----------------

test "compiler_slice: band5 class private attr parsed matches oracle co_code" {
    src = (
        "class C:\n"
        + "    __x = 1\n"
        + "    def m(self):\n"
        + "        return self.__x\n"
        + "result = C().m()\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    cls = nested_code_by_name(actual, "C");
    exp_cls = nested_code_by_name(exp, "C");
    assert cls.co_code == exp_cls.co_code;
    assert cls.stacksize == exp_cls.stacksize;
    m = nested_code_by_name(cls, "m");
    exp_m = nested_code_by_name(exp_cls, "m");
    assert m.co_code == exp_m.co_code;
    assert m.stacksize == exp_m.stacksize;
}

test "compiler_slice: band5 class private attr parsed executes in ceval" {
    src = (
        "class C:\n"
        + "    __x = 1\n"
        + "    def m(self):\n"
        + "        return self.__x\n"
        + "result = C().m()\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

# ---------------- Band 5 slice 5: inheritance and nested classes ----------------

test "compiler_slice: band5 class inheritance parsed matches oracle co_code" {
    src = (
        "class Base:\n"
        + "    x = 1\n"
        + "class C(Base):\n"
        + "    pass\n"
        + "result = C().x\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    c_cls = nested_code_by_name(actual, "C");
    exp_c = nested_code_by_name(exp, "C");
    assert c_cls.co_code == exp_c.co_code;
}

test "compiler_slice: band5 class inheritance parsed executes in ceval" {
    src = (
        "class Base:\n"
        + "    x = 1\n"
        + "class C(Base):\n"
        + "    pass\n"
        + "result = C().x\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

test "compiler_slice: band5 nested class parsed matches oracle co_code" {
    src = (
        "class Outer:\n"
        + "    class Inner:\n"
        + "        x = 1\n"
        + "result = Outer.Inner.x\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.stacksize == exp.stacksize;
    outer = nested_code_by_name(actual, "Outer");
    exp_outer = nested_code_by_name(exp, "Outer");
    assert outer.co_code == exp_outer.co_code;
    inner = nested_code_by_name(outer, "Inner");
    exp_inner = nested_code_by_name(exp_outer, "Inner");
    assert inner.co_code == exp_inner.co_code;
    assert inner.qualname == "Outer.Inner";
}

test "compiler_slice: band5 nested class parsed executes in ceval" {
    src = (
        "class Outer:\n"
        + "    class Inner:\n"
        + "        x = 1\n"
        + "result = Outer.Inner.x\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

# ---------------- Band 6 slice 1: try/except typed handler ----------------

test "compiler_slice: band6 try except typed parsed matches oracle co_code" {
    src = (
        "try:\n" + "    1 // 0\n" + "except ZeroDivisionError:\n" + "    result = 99\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except typed parsed executes in ceval" {
    src = (
        "try:\n" + "    1 // 0\n" + "except ZeroDivisionError:\n" + "    result = 99\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 99;
}

test "compiler_slice: band6 bare except parsed matches oracle co_code" {
    src = "try:\n" + "    raise ValueError('x')\n" + "except:\n" + "    result = 7\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 bare except parsed executes in ceval" {
    src = "try:\n" + "    raise ValueError('x')\n" + "except:\n" + "    result = 7\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
}

test "compiler_slice: band6 typed-then-bare except parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except:\n"
        + "    result = 2\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 typed-then-bare except parsed executes in ceval" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except:\n"
        + "    result = 2\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 2;
}

test "compiler_slice: band6 bare except no-exception parsed matches oracle co_code" {
    src = "try:\n" + "    result = 5\n" + "except:\n" + "    result = 9\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 bare except no-exception executes in ceval" {
    src = "try:\n" + "    result = 5\n" + "except:\n" + "    result = 9\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 5;
}

test "compiler_slice: band6 try except else parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "else:\n"
        + "    result = 3\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except else no-exception runs else in ceval" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "else:\n"
        + "    result = 3\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band6 try except else exception skips else matches oracle co_code" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "else:\n"
        + "    result = 3\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except else exception skips else in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "else:\n"
        + "    result = 3\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 2;
}

# ---------------- Band 6 slice 2: raise ----------------

test "compiler_slice: band6 raise parsed matches oracle co_code" {
    src = "raise ValueError('bad')\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 raise parsed raises ValueError in ceval" {
    src = "raise ValueError('bad')\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == "bad";
}

test "compiler_slice: band6 try except re-raise parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    raise\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except re-raise parsed propagates in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    raise\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == "x";
}

test "compiler_slice: band6 raise from parsed matches oracle co_code" {
    src = "err = ValueError('cause')\nraise KeyError('k') from err\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 raise from parsed raises KeyError in ceval" {
    src = "err = ValueError('cause')\nraise KeyError('k') from err\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "KeyError";
}

# ---------------- Band 6 slice 3: except as ----------------

test "compiler_slice: band6 try except as parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    1 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except as parsed executes in ceval" {
    src = (
        "try:\n"
        + "    1 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "division by zero";
}

# ---------------- Band 6 slice 4: try/finally ----------------

test "compiler_slice: band6 try finally parsed matches oracle co_code" {
    src = (
        "count = 0\n"
        + "try:\n"
        + "    count = 1\n"
        + "finally:\n"
        + "    count = count + 10\n"
        + "result = count\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try finally parsed executes in ceval" {
    src = (
        "count = 0\n"
        + "try:\n"
        + "    count = 1\n"
        + "finally:\n"
        + "    count = count + 10\n"
        + "result = count\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 11;
}

test "compiler_slice: band6 try finally runs on exception path in ceval" {
    src = (
        "count = 0\n"
        + "try:\n"
        + "    try:\n"
        + "        1 // 0\n"
        + "    finally:\n"
        + "        count = count + 10\n"
        + "except ZeroDivisionError:\n"
        + "    result = count\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 10;
}

# -------- Band 6 slice 6: try/except[/else]/finally (flat) --------

test "compiler_slice: band6 try except finally normal parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except finally normal executes in ceval" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band6 try except finally caught parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except finally caught executes in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band6 try except finally uncaught parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except finally uncaught propagates but runs finally in ceval" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 try except else finally parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "else:\n"
        + "    result = 5\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except else finally executes in ceval" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "else:\n"
        + "    result = 5\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# -------- Band 6 slice 7: multi-handler try/except[/else]/finally --------

def _parity(src: str) {
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 two handlers finally caught by first parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except KeyError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "compiler_slice: band6 two handlers finally caught by first executes in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except KeyError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 two handlers finally caught by second parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except KeyError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    result = 3\n"
    );
}

test "compiler_slice: band6 two handlers finally caught by second executes in ceval" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except KeyError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    result = 3\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band6 two handlers finally uncaught parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise TypeError('t')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except KeyError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "compiler_slice: band6 two handlers finally uncaught propagates but runs finally in ceval" {
    src = (
        "try:\n"
        + "    raise TypeError('t')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except KeyError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "TypeError";
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 three handlers else finally no-exception parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "except KeyError:\n"
        + "    result = 3\n"
        + "except TypeError:\n"
        + "    result = 4\n"
        + "else:\n"
        + "    result = 5\n"
        + "finally:\n"
        + "    result = 6\n"
    );
}

test "compiler_slice: band6 three handlers else finally no-exception runs else then finally in ceval" {
    src = (
        "try:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "except KeyError:\n"
        + "    result = 3\n"
        + "except TypeError:\n"
        + "    result = 4\n"
        + "else:\n"
        + "    result = 5\n"
        + "finally:\n"
        + "    result = 6\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 6;
}

test "compiler_slice: band6 three handlers else finally exception skips else parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "except KeyError:\n"
        + "    result = 3\n"
        + "except TypeError:\n"
        + "    result = 4\n"
        + "else:\n"
        + "    result = 5\n"
        + "finally:\n"
        + "    result = 6\n"
    );
}

test "compiler_slice: band6 three handlers else finally exception skips else in ceval" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "except KeyError:\n"
        + "    result = 3\n"
        + "except TypeError:\n"
        + "    result = 4\n"
        + "else:\n"
        + "    result = 5\n"
        + "finally:\n"
        + "    result = 6\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 6;
}

test "compiler_slice: band6 typed bare chain finally parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "compiler_slice: band6 typed bare chain finally executes in ceval" {
    src = (
        "try:\n"
        + "    raise KeyError('k')\n"
        + "except ValueError:\n"
        + "    result = 1\n"
        + "except:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 2;
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 handler raise reaches finally then propagates parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    raise KeyError('k')\n"
        + "except TypeError:\n"
        + "    result = 4\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "compiler_slice: band6 handler raise reaches finally then propagates in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    raise KeyError('k')\n"
        + "except TypeError:\n"
        + "    result = 4\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "KeyError";
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 nested try inside handler parsed matches oracle co_code" {
    _parity(
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    try:\n"
        + "        1 // 0\n"
        + "    except ZeroDivisionError:\n"
        + "        result = 7\n"
        + "except TypeError:\n"
        + "    result = 8\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "compiler_slice: band6 nested try inside handler executes in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    try:\n"
        + "        1 // 0\n"
        + "    except ZeroDivisionError:\n"
        + "        result = 7\n"
        + "except TypeError:\n"
        + "    result = 8\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 first handler re-raises second catches parsed matches oracle co_code" {
    _parity(
        "err = ValueError('v')\n"
        + "try:\n"
        + "    try:\n"
        + "        raise err\n"
        + "    except ValueError:\n"
        + "        raise\n"
        + "except KeyError:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "compiler_slice: band6 first handler re-raises second catches in ceval" {
    src = (
        "err = ValueError('v')\n"
        + "try:\n"
        + "    try:\n"
        + "        raise err\n"
        + "    except ValueError:\n"
        + "        raise\n"
        + "except KeyError:\n"
        + "    result = 1\n"
        + "except ValueError:\n"
        + "    result = 2\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 2;
    assert expect_int(ns["marker"]) == 9;
}

# ---------------- Band 6 slice 5: with ----------------

test "compiler_slice: band6 with parsed matches oracle co_code" {
    src = (
        "class CM:\n"
        + "    def __enter__(self):\n"
        + "        return 42\n"
        + "    def __exit__(self, *a):\n"
        + "        pass\n"
        + "with CM() as x:\n"
        + "    result = x\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 with parsed executes in ceval" {
    src = (
        "class CM:\n"
        + "    def __enter__(self):\n"
        + "        return 42\n"
        + "    def __exit__(self, *a):\n"
        + "        pass\n"
        + "with CM() as x:\n"
        + "    result = x\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 42;
}

test "compiler_slice: band6 with no-as parsed matches oracle co_code" {
    src = (
        "class CM:\n"
        + "    def __enter__(self):\n"
        + "        return 42\n"
        + "    def __exit__(self, *a):\n"
        + "        pass\n"
        + "result = 0\n"
        + "with CM():\n"
        + "    result = 99\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 with no-as parsed executes in ceval" {
    src = (
        "class CM:\n"
        + "    def __enter__(self):\n"
        + "        return 42\n"
        + "    def __exit__(self, *a):\n"
        + "        pass\n"
        + "result = 0\n"
        + "with CM():\n"
        + "    result = 99\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 99;
}

test "compiler_slice: band6 with two items parsed matches oracle co_code" {
    src = (
        "class CM:\n"
        + "    def __init__(self, v):\n"
        + "        self.v = v\n"
        + "    def __enter__(self):\n"
        + "        return self.v\n"
        + "    def __exit__(self, *a):\n"
        + "        return False\n"
        + "with CM(1) as x, CM(2) as y:\n"
        + "    result = x + y\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 with two items parsed executes in ceval" {
    src = (
        "class CM:\n"
        + "    def __init__(self, v):\n"
        + "        self.v = v\n"
        + "    def __enter__(self):\n"
        + "        return self.v\n"
        + "    def __exit__(self, *a):\n"
        + "        return False\n"
        + "with CM(1) as x, CM(2) as y:\n"
        + "    result = x + y\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "compiler_slice: band6 with mixed no-as parsed matches oracle co_code" {
    src = (
        "class CM:\n"
        + "    def __init__(self, v):\n"
        + "        self.v = v\n"
        + "    def __enter__(self):\n"
        + "        return self.v\n"
        + "    def __exit__(self, *a):\n"
        + "        return False\n"
        + "with CM(1), CM(2) as y:\n"
        + "    result = y\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 with mixed no-as parsed executes in ceval" {
    src = (
        "class CM:\n"
        + "    def __init__(self, v):\n"
        + "        self.v = v\n"
        + "    def __enter__(self):\n"
        + "        return self.v\n"
        + "    def __exit__(self, *a):\n"
        + "        return False\n"
        + "with CM(1), CM(2) as y:\n"
        + "    result = y\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 2;
}

# ---------------- Band 6 slice 6: assert ----------------

test "compiler_slice: band6 assert parsed matches oracle co_code" {
    src = "x = 1\nassert x == 1\nresult = x\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 assert parsed executes in ceval" {
    src = "x = 1\nassert x == 1\nresult = x\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

test "compiler_slice: band6 assert failure parsed matches oracle co_code" {
    src = "x = 0\nassert x == 1, 'fail'\nresult = x\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 assert failure parsed raises AssertionError in ceval" {
    src = "x = 0\nassert x == 1, 'fail'\nresult = x\n";
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "AssertionError";
    assert err.exception.message == "fail";
}

# -------- Band 6 slice 8: except-as binding in combined try/except/finally --------

test "compiler_slice: band6 try except as finally caught parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    result = 10 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except as finally caught executes in ceval" {
    src = (
        "try:\n"
        + "    result = 10 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "division by zero";
    assert expect_int(ns["marker"]) == 9;
}

test "compiler_slice: band6 try except as finally handler raises parsed matches oracle co_code" {
    src = (
        "try:\n"
        + "    raise ValueError('v')\n"
        + "except ValueError as e:\n"
        + "    result = str(e)\n"
        + "    raise KeyError('k')\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert actual.co_code == exp.co_code;
    assert actual.exceptiontable == exp.exceptiontable;
    assert actual.stacksize == exp.stacksize;
}

test "compiler_slice: band6 try except as finally handler raises propagates in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('v')\n"
        + "except ValueError as e:\n"
        + "    result = str(e)\n"
        + "    raise KeyError('k')\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "KeyError";
    assert expect_str(ns["result"]) == "v";
    assert expect_int(ns["marker"]) == 9;
}

# ---------------- Band 7 slice 1: generator yield ----------------

test "compiler_slice: band7 generator yield parsed matches oracle nested gen co_code" {
    src = (
        "def gen():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "g = gen()\n"
        + "result = next(g) + next(g)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    gen_fn = nested_code_by_name(actual, "gen");
    exp_gen = nested_code_by_name(exp, "gen");
    assert gen_fn.co_code == exp_gen.co_code;
    assert gen_fn.exceptiontable == exp_gen.exceptiontable;
    assert gen_fn.stacksize == exp_gen.stacksize;
    assert gen_fn.flags == exp_gen.flags;
}

test "compiler_slice: band7 generator yield parsed executes in ceval" {
    src = (
        "def gen():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "g = gen()\n"
        + "result = next(g) + next(g)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 7 slice 2: yield from ----------------

test "compiler_slice: band7 yield from parsed matches oracle nested co_code" {
    src = (
        "def outer():\n"
        + "    yield from inner()\n"
        + "def inner():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "result = list(outer())\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    outer_fn = nested_code_by_name(actual, "outer");
    exp_outer = nested_code_by_name(exp, "outer");
    inner_fn = nested_code_by_name(actual, "inner");
    exp_inner = nested_code_by_name(exp, "inner");
    assert outer_fn.co_code == exp_outer.co_code;
    assert outer_fn.exceptiontable == exp_outer.exceptiontable;
    assert outer_fn.stacksize == exp_outer.stacksize;
    assert outer_fn.flags == exp_outer.flags;
    assert inner_fn.co_code == exp_inner.co_code;
    assert inner_fn.exceptiontable == exp_inner.exceptiontable;
    assert inner_fn.stacksize == exp_inner.stacksize;
    assert inner_fn.flags == exp_inner.flags;
}

test "compiler_slice: band7 yield from parsed executes in ceval" {
    src = (
        "def outer():\n"
        + "    yield from inner()\n"
        + "def inner():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "result = list(outer())\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    lst = ns["result"];
    assert expect_int(py_subscript(lst, PyInt(t="int", val=0))) == 1;
    assert expect_int(py_subscript(lst, PyInt(t="int", val=1))) == 2;
}

# ---------------- Band 7 slice 3: async def ----------------

test "compiler_slice: band7 async def parsed matches oracle nested co_code" {
    src = "async def f():\n  return 1\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
}

# ---------------- Band 7 slice 4: await ----------------

test "compiler_slice: band7 await parsed matches oracle nested co_code" {
    src = (
        "async def f():\n"
        + "    return await g()\n"
        + "async def g():\n"
        + "    return 1\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    g_fn = nested_code_by_name(actual, "g");
    exp_g = nested_code_by_name(exp, "g");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
    assert g_fn.co_code == exp_g.co_code;
    assert g_fn.exceptiontable == exp_g.exceptiontable;
    assert g_fn.stacksize == exp_g.stacksize;
    assert g_fn.flags == exp_g.flags;
}

test "compiler_slice: band7 await parsed executes in ceval" {
    src = (
        "async def f():\n"
        + "    return await g()\n"
        + "async def g():\n"
        + "    return 1\n"
        + "c = f()\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 1;
}

# ---------------- Band 7 slice 5: async for ----------------

test "compiler_slice: band7 async for parsed matches oracle nested co_code" {
    src = (
        "class AI:\n"
        + "    def __aiter__(self):\n"
        + "        return self\n"
        + "    async def __anext__(self):\n"
        + "        if getattr(self, 'done', False):\n"
        + "            raise StopAsyncIteration\n"
        + "        self.done = True\n"
        + "        return 42\n"
        + "\n"
        + "async def f():\n"
        + "    total = 0\n"
        + "    async for x in AI():\n"
        + "        total = total + x\n"
        + "    return total\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
}

test "compiler_slice: band7 async for parsed executes in ceval" {
    src = (
        "class AI:\n"
        + "    def __aiter__(self):\n"
        + "        return self\n"
        + "    async def __anext__(self):\n"
        + "        if getattr(self, 'done', False):\n"
        + "            raise StopAsyncIteration\n"
        + "        self.done = True\n"
        + "        return 42\n"
        + "\n"
        + "async def f():\n"
        + "    total = 0\n"
        + "    async for x in AI():\n"
        + "        total = total + x\n"
        + "    return total\n"
        + "c = f()\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 42;
}

# ---------------- Band 7 slice 5b: async list comprehension ----------------

test "compiler_slice: band7 async list comprehension parsed matches oracle nested co_code" {
    src = "async def f(ait):\n    return [x async for x in ait]\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
}

test "compiler_slice: band7 async list comprehension parsed executes in ceval" {
    src = (
        "class AI:\n"
        + "    def __aiter__(self):\n"
        + "        return self\n"
        + "    async def __anext__(self):\n"
        + "        if getattr(self, 'done', False):\n"
        + "            raise StopAsyncIteration\n"
        + "        self.done = True\n"
        + "        return 42\n"
        + "\n"
        + "async def f(ait):\n"
        + "    return [x async for x in ait]\n"
        + "c = f(AI())\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    result = finished.value as PyObj;
    assert result.t == "list";
    items = (result as PyList).items;
    assert len(items) == 1;
    assert expect_int(items[0]) == 42;
}

test "compiler_slice: band7 async set comprehension parsed matches oracle nested co_code" {
    src = "async def f(ait):\n    return {x async for x in ait}\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
}

test "compiler_slice: band7 async set comprehension executes in ceval" {
    src = (
        "class AI:\n"
        + "    def __aiter__(self):\n"
        + "        return self\n"
        + "    async def __anext__(self):\n"
        + "        if getattr(self, 'done', False):\n"
        + "            raise StopAsyncIteration\n"
        + "        self.done = True\n"
        + "        return 42\n"
        + "\n"
        + "async def f(ait):\n"
        + "    return {x async for x in ait}\n"
        + "c = f(AI())\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    result = finished.value as PyObj;
    assert result.t == "set";
    sitems = (result as PySet).items;
    assert len(sitems) == 1;
    for hk in sitems {
        assert expect_int(sitems[hk]) == 42;
    }
}

test "compiler_slice: band7 async dict comprehension parsed matches oracle nested co_code" {
    src = "async def f(ait):\n    return {x: x async for x in ait}\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
}

test "compiler_slice: band7 async dict comprehension executes in ceval" {
    src = (
        "class AI:\n"
        + "    def __aiter__(self):\n"
        + "        return self\n"
        + "    async def __anext__(self):\n"
        + "        if getattr(self, 'done', False):\n"
        + "            raise StopAsyncIteration\n"
        + "        self.done = True\n"
        + "        return 42\n"
        + "\n"
        + "async def f(ait):\n"
        + "    return {x: x async for x in ait}\n"
        + "c = f(AI())\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    result = finished.value as PyObj;
    assert result.t == "dict";
    ditems = (result as PyDict).items;
    assert len(ditems) == 1;
    for hk in ditems {
        assert expect_int(ditems[hk].key) == 42;
        assert expect_int(ditems[hk].value) == 42;
    }
}

# ---------------- Band 7 slice 6: async with ----------------

test "compiler_slice: band7 async with parsed matches oracle nested co_code" {
    src = (
        "class CM:\n"
        + "    async def __aenter__(self):\n"
        + "        return 42\n"
        + "    async def __aexit__(self, *a):\n"
        + "        pass\n"
        + "\n"
        + "async def f():\n"
        + "    async with CM() as x:\n"
        + "        result = x\n"
        + "    return result\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    f_fn = nested_code_by_name(actual, "f");
    exp_f = nested_code_by_name(exp, "f");
    assert f_fn.co_code == exp_f.co_code;
    assert f_fn.exceptiontable == exp_f.exceptiontable;
    assert f_fn.stacksize == exp_f.stacksize;
    assert f_fn.flags == exp_f.flags;
}

test "compiler_slice: band7 async with parsed executes in ceval" {
    src = (
        "class CM:\n"
        + "    async def __aenter__(self):\n"
        + "        return 42\n"
        + "    async def __aexit__(self, *a):\n"
        + "        pass\n"
        + "\n"
        + "async def f():\n"
        + "    async with CM() as x:\n"
        + "        result = x\n"
        + "    return result\n"
        + "c = f()\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 42;
}

# ---------------- Band 7 slice 7: async generator ----------------

test "compiler_slice: band7 async generator minimal parsed matches oracle nested co_code" {
    src = "async def ag():\n    yield 1\n";
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<ag>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    ag_fn = nested_code_by_name(actual, "ag");
    exp_ag = nested_code_by_name(exp, "ag");
    # CO_ASYNC_GENERATOR (0x0200) set; CO_GENERATOR (0x20) / CO_COROUTINE (0x80) clear.
    assert (exp_ag.flags & 512) != 0;
    assert (exp_ag.flags & 32) == 0;
    assert (exp_ag.flags & 128) == 0;
    assert ag_fn.co_code == exp_ag.co_code;
    assert ag_fn.exceptiontable == exp_ag.exceptiontable;
    assert ag_fn.stacksize == exp_ag.stacksize;
    assert ag_fn.flags == exp_ag.flags;
}

test "compiler_slice: band7 async generator parsed matches oracle nested co_code" {
    src = (
        "async def something():\n"
        + "    return 7\n"
        + "async def ag():\n"
        + "    yield 1\n"
        + "    x = await something()\n"
        + "    yield x\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<ag>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    ag_fn = nested_code_by_name(actual, "ag");
    exp_ag = nested_code_by_name(exp, "ag");
    assert (exp_ag.flags & 512) != 0;
    assert (exp_ag.flags & 32) == 0;
    assert (exp_ag.flags & 128) == 0;
    assert ag_fn.co_code == exp_ag.co_code;
    assert ag_fn.exceptiontable == exp_ag.exceptiontable;
    assert ag_fn.stacksize == exp_ag.stacksize;
    assert ag_fn.flags == exp_ag.flags;
}

# ---------------- Band 8 slice 1: match literal int ----------------

test "compiler_slice: band8 match literal int parsed matches oracle nested f co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
        + "\n"
        + "result = f(1)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.exceptiontable == exp_fn.exceptiontable;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
}

test "compiler_slice: band8 match literal int parsed executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
        + "\n"
        + "result = f(1)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "one";
}

test "compiler_slice: band8 match literal int wildcard executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
        + "\n"
        + "result = f(2)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "other";
}

# ---------------- Band 8 slice 2: match guards ----------------

test "compiler_slice: band8 match guard parsed matches oracle nested f co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1 if x > 0:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
        + "\n"
        + "result = f(1)\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.exceptiontable == exp_fn.exceptiontable;
    assert fn.stacksize == exp_fn.stacksize;
}

test "compiler_slice: band8 match guard executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1 if x > 0:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
        + "\n"
        + "result = f(1)\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "one";
}

# ---------------- Band 8 slice 3: match sequence ----------------

test "compiler_slice: band8 match sequence parsed matches oracle nested f co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, b]:\n"
        + "            return a + b\n"
        + "        case _:\n"
        + "            return 0\n"
    );
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.exceptiontable == exp_fn.exceptiontable;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.varnames == ["x", "a", "b"];
}

test "compiler_slice: band8 match sequence executes in ceval" {
    setup = unmarshal(
        host_compile_marshal("def make():\n    return [1, 2]\n", "<setup>", "exec", 0)
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, b]:\n"
        + "            return a + b\n"
        + "        case _:\n"
        + "            return 0\n"
        + "\n"
        + "result = f(make())\n"
    );
    co = compile_parsed_exec(src);
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 8 slice 3b: star sequence patterns ----------------

def _star_assert_fn_matches(src: str) {
    actual = compile_parsed_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    fn = first_nested_code(actual);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.exceptiontable == exp_fn.exceptiontable;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.varnames == exp_fn.varnames;
    assert fn.names == exp_fn.names;
}

test "compiler_slice: band8 star seq [a, *rest] matches oracle co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *rest]:\n"
        + "            return a + rest\n"
        + "        case _:\n"
        + "            return 0\n"
    );
    _star_assert_fn_matches(src);
}

test "compiler_slice: band8 star seq [*rest] matches oracle co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [*rest]:\n"
        + "            return rest + rest\n"
        + "        case _:\n"
        + "            return 0\n"
    );
    _star_assert_fn_matches(src);
}

test "compiler_slice: band8 star seq [a, *mid, b] matches oracle co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *mid, b]:\n"
        + "            return a + b\n"
        + "        case _:\n"
        + "            return 0\n"
    );
    _star_assert_fn_matches(src);
}

test "compiler_slice: band8 star seq [a, *_] matches oracle co_code" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *_]:\n"
        + "            return a + a\n"
        + "        case _:\n"
        + "            return 0\n"
    );
    _star_assert_fn_matches(src);
}

test "compiler_slice: band8 star seq [a, *rest] executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *rest]:\n"
        + "            return a * 100 + rest[0] * 10 + rest[1]\n"
        + "        case _:\n"
        + "            return -1\n"
        + "\n"
        + "result = f([1, 2, 3])\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 123;
}

test "compiler_slice: band8 star seq [*rest] executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [*rest]:\n"
        + "            return rest[0] * 100 + rest[1] * 10 + rest[2]\n"
        + "\n"
        + "result = f([1, 2, 3])\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 123;
}

test "compiler_slice: band8 star seq [a, *mid, b] executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *mid, b]:\n"
        + "            return a * 1000 + mid[0] * 100 + mid[1] * 10 + b\n"
        + "        case _:\n"
        + "            return -1\n"
        + "\n"
        + "result = f([1, 2, 3, 4])\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1234;
}

test "compiler_slice: band8 star seq [a, *_] executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *_]:\n"
        + "            return a\n"
        + "        case _:\n"
        + "            return -1\n"
        + "\n"
        + "result = f([7, 2, 3])\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
}

test "compiler_slice: band8 star seq no-match falls through to default" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, *rest]:\n"
        + "            return a\n"
        + "        case _:\n"
        + "            return -1\n"
        + "\n"
        + "result = f([])\n"
    );
    co = compile_parsed_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == -1;
}

# ---- LOAD_FAST_BORROW strength reduction (flowgraph.optimize_load_fast) ----
# Codegen emits owned LOAD_FAST for every fast-local load; the flowgraph pass
# downgrades a load to LOAD_FAST_BORROW when it proves the borrow outlives the
# value (consumed before the frame slot dies), and insert_superinstructions fuses
# adjacent owned pairs first -- so a binop over two params fuses to
# LOAD_FAST_BORROW_LOAD_FAST_BORROW, while a value stored back into a local stays
# an owned LOAD_FAST. Verified against the oracle via nested function co_code
# (the module body is blind to the bodies). Byte-exact for all of these.
test "compiler_slice: fast-local load borrow/own strength reduction matches oracle" {
    for src in [
        # Fully-consumed operand pairs fuse to a borrowed pair load.
        "def f(a, b):\n    return a + b\n",
        "def f(a, b):\n    return (a, b)\n",
        "def f(a, b, c):\n    return [a, b, c]\n",
        "def f(a, b):\n    return {a: b}\n",
        "def f(a, b):\n    return a < b\n",
        "def f(a, b):\n    a += b\n    return a\n",
        # A value stored back into a local escapes -> stays an owned LOAD_FAST.
        "def f(x):\n    y = x\n    return y\n",
        "def f(a, b):\n    c = a\n    return c + b\n",
        # Loads separated by a consuming op do not fuse (each a single borrow).
        "def f(x, lst):\n    lst.append(x)\n    return lst\n",
        "def f(g, a, b):\n    return g(a, b)\n",
        "def f(g, h, a, b):\n    return g(a) + h(b)\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        af = nested_code_by_name(actual, "f");
        ef = nested_code_by_name(expected as PyCode, "f");
        assert af.co_code == ef.co_code;
        assert af.exceptiontable == ef.exceptiontable;
        assert af.stacksize == ef.stacksize;
    }
}

# Band 11: function-local annotated assignment (PEP 649). The host oracle
# emits ONLY the assignment side at local scope (annotations are deferred to
# module/class __annotate__ plumbing, a separate slice); bare locals emit
# nothing. Byte-exact against the oracle for value stores on name, attribute,
# and subscript targets, plus the no-op bare form.
test "compiler_slice: band-11 local AnnAssign matches oracle bytes" {
    for src in [
        "def f():\n    q: int = 3\n    return q\n",
        "def f(o):\n    o.k: int = 1\n    return o\n",
        "def f(d):\n    d['k']: int = 1\n    return d\n",
        "def f(x):\n    (x): int = 4\n    return x\n",
        "def f():\n    z: float\n",
        # Annotation referencing an undefined name must not fail at compile
        # time (laziness): the annotation is dropped locally.
        "def f():\n    r: LaterAlias = Q()\n    return r\n"
    ] {
        actual = compile_parsed_exec(src);
        expected = oracle_exec(src, "<f>");
        assert isinstance(expected, PyCode);
        af = nested_code_by_name(actual, "f");
        ef = nested_code_by_name(expected as PyCode, "f");
        assert af.co_code == ef.co_code;
        assert af.exceptiontable == ef.exceptiontable;
        assert af.stacksize == ef.stacksize;
    }
}

# Band 11 guard: module/class-scope annotated assignment still requires the
# deferred __annotate__ machinery -- it must FAIL LOUDLY, never emit
# silently-wrong bytes (missing annotations at runtime).
test "compiler_slice: band-11 module/class AnnAssign traps until __annotate__ lands" {
    m = parse_file("x: int = 5\n", "<f>");
    assert m is not None;
    body_m = (m as Module).body;
    sr = build_module_symtable(body_m);
    u = compile_exec(body_m, "<f>", "<module>", 1, sr.top);
    assert u.diag is not None;
    assert u.diag.kind == "NotImplementedError";

    cls_src = parse_file("class C:\n    y: str = 'a'\n", "<f>");
    assert cls_src is not None;
    cdef = ((cls_src as Module).body[0] as ClassDef);
    vr = validate_module_body([cdef]);
    assert vr.diag is None;
}
