# Layer 10 product control-flow slice (PLAN.md P0.12 band 3).
#
# Source -> PyCode for if / while / for via native compile_exec, byte-exact
# against the host oracle plus VM execution smoke tests.

import from objects { PyObj, PyCode, PyInt, PyTuple, expect_int, expect_str, is_error }
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

def product_exec(source: str, filename: str = "<f>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
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

def assert_matches_oracle(source: str, filename: str = "<f>") {
    actual = product_exec(source, filename);
    assert not is_error(actual);
    assert isinstance(actual, PyCode);
    expected = oracle_exec(source, filename);
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.linetable == exp.linetable;
    assert act.names == exp.names;
    assert consts_equal(act.consts, exp.consts);
    assert act.stacksize == exp.stacksize;
    assert act.filename == exp.filename;
    assert act.name == exp.name;
    assert act.qualname == exp.qualname;
    assert act.firstlineno == exp.firstlineno;
    assert act.exceptiontable == exp.exceptiontable;
}

# ---------------- byte-exact oracle parity ----------------

test "layer10: if without else matches oracle" {
    assert_matches_oracle("if x: a = 1\n");
}

test "layer10: if with else matches oracle" {
    assert_matches_oracle("if x: a = 1\nelse: a = 2\n");
}

test "layer10: if then following stmt matches oracle" {
    assert_matches_oracle("if x: a = 1\nz = 2\n");
}

test "layer10: while loop matches oracle" {
    assert_matches_oracle("while x: pass\n");
}

test "layer10: while with body matches oracle" {
    assert_matches_oracle("while x: y = 1\n");
}

test "layer10: while indented body matches oracle" {
    assert_matches_oracle("while x:\n    y = 1\n");
}

test "layer10: for loop matches oracle" {
    assert_matches_oracle("for x in y: pass\n");
}

test "layer10: for with body matches oracle" {
    assert_matches_oracle("for x in y: z = 1\n");
}

test "layer10: for indented body matches oracle" {
    assert_matches_oracle("for x in y:\n    z = 1\n");
}

test "layer10: while break matches oracle" {
    assert_matches_oracle("while x: break\n");
}

test "layer10: while continue matches oracle" {
    assert_matches_oracle("while x: continue\n");
}

test "layer10: for continue matches oracle" {
    assert_matches_oracle("for x in y: continue\n");
}

test "layer10: while body break matches oracle" {
    assert_matches_oracle("while x:\n    break\n");
}

test "layer10: nested if then following stmt matches oracle" {
    assert_matches_oracle("if x:\n    if y: a = 1\nb = 2\n");
}

test "layer10: while else then following stmt matches oracle" {
    assert_matches_oracle("while x: pass\nelse: z = 1\na = 2\n");
}

test "layer10: for else then following stmt matches oracle" {
    assert_matches_oracle("for x in y: pass\nelse: z = 1\na = 2\n");
}

test "layer10: list comprehension assign matches oracle" {
    assert_matches_oracle("result = [x for x in y]\n");
}

test "layer10: list comprehension filter with nontrivial expr matches oracle" {
    assert_matches_oracle("result = [x for x in y if x + 1 > 0]\n");
}

test "layer10: dict comprehension assign matches oracle" {
    assert_matches_oracle("result = {c: c + c for c in z}\n");
}

test "layer10: dict comprehension filter matches oracle" {
    assert_matches_oracle("result = {x: x + 1 for x in y if x > 0}\n");
}

test "layer10: dict comprehension tuple target matches oracle" {
    assert_matches_oracle("result = {k: v for k, v in pairs}\n");
}

test "layer10: set comprehension assign matches oracle" {
    assert_matches_oracle("result = {x for x in y}\n");
}

test "layer10: set comprehension filter matches oracle" {
    assert_matches_oracle("result = {x for x in y if x > 0}\n");
}

# ---- multi-reference loop var: STORE_FAST_LOAD_FAST + LOAD_FAST_BORROW ----

test "layer10: list comprehension multi-ref element matches oracle" {
    assert_matches_oracle("result = [x * x for x in y]\n");
}

test "layer10: list comprehension triple-ref element matches oracle" {
    assert_matches_oracle("result = [x * x * x for x in y]\n");
}

test "layer10: list comprehension leading-nonloopvar matches oracle" {
    assert_matches_oracle("result = [w * x for x in y]\n");
}

test "layer10: list comprehension tuple element matches oracle" {
    assert_matches_oracle("result = [(x, x) for x in y]\n");
}

test "layer10: list comprehension call element matches oracle" {
    assert_matches_oracle("result = [f(x, x) for x in y]\n");
}

test "layer10: list comprehension multi-ref with filter matches oracle" {
    assert_matches_oracle("result = [x + z for x in y if x * x > z]\n");
}

test "layer10: set comprehension multi-ref element matches oracle" {
    assert_matches_oracle("result = {x * x for x in y}\n");
}

test "layer10: dict comprehension multi-ref value matches oracle" {
    assert_matches_oracle("result = {x: x * x for x in y}\n");
}

test "layer10: dict comprehension both-name kv matches oracle" {
    assert_matches_oracle("result = {x: x for x in y}\n");
}

test "layer10: dict comprehension multi-ref value with filter matches oracle" {
    assert_matches_oracle("result = {x: x * x for x in y if x > 0}\n");
}

# ---------------- Band 8 slice 1: match literal int ----------------

test "layer10: band8 match literal int nested f matches oracle co_code" {
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
    actual = product_exec(src, "<f>");
    assert not is_error(actual);
    assert isinstance(actual, PyCode);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    act_fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert act_fn.co_code == exp_fn.co_code;
    assert act_fn.exceptiontable == exp_fn.exceptiontable;
    assert act_fn.stacksize == exp_fn.stacksize;
    assert act_fn.argcount == 1;
    assert act_fn.varnames == ["x"];
}

test "layer10: band8 match literal int executes in ceval" {
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
    co = product_exec(src, "<f>");
    assert not is_error(co);
    assert isinstance(co, PyCode);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "other";
}

# ---------------- Band 8: MATCH_CLASS / MATCH_MAPPING ----------------

# Compare only the nested function's byte-exact code (co_code / exception table /
# stacksize), matching the band8 slice-3 convention. The module const pool is
# not compared: the reimpl retains folded small-int consts that CPython prunes.
def assert_nested_oracle(src: str) {
    actual = product_exec(src, "<f>");
    assert not is_error(actual);
    assert isinstance(actual, PyCode);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = first_nested_code(actual as PyCode);
    exp = first_nested_code(expected as PyCode);
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

def match_arm_src(body_case: str) -> str {
    return (
        "def f(x):\n"
        + "    match x:\n"
        + body_case
        + "        case _:\n"
        + "            return 0\n"
    );
}

test "layer10: band8 match class no-args matches oracle co_code" {
    assert_nested_oracle(match_arm_src("        case C():\n            return 1\n"));
}

test "layer10: band8 match class positional literal matches oracle co_code" {
    assert_nested_oracle(match_arm_src("        case C(0):\n            return 1\n"));
}

test "layer10: band8 match class positional captures matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case Point(a, b):\n            return a + b\n")
    );
}

test "layer10: band8 match class keyword capture matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case C(0, y=v):\n            return v + 1\n")
    );
}

test "layer10: band8 match class positional+keyword matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case C(a, b, c=1, d=2):\n            return a + b\n")
    );
}

test "layer10: band8 match class nested sequence matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case Point(x=[a, b]):\n            return a + b\n")
    );
}

test "layer10: band8 match mapping literal value matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case {'a': 1, 'b': v}:\n            return v + 1\n")
    );
}

test "layer10: band8 match mapping captures matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case {'a': v, 'b': w}:\n            return v + w\n")
    );
}

test "layer10: band8 match mapping double-star rest matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case {'a': v, **rest}:\n            return v + 1\n")
    );
}

test "layer10: band8 match mapping empty matches oracle co_code" {
    assert_nested_oracle(match_arm_src("        case {}:\n            return 1\n"));
}

test "layer10: band8 match mapping nested sequence matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case {'p': [a, b]}:\n            return a + b\n")
    );
}

# Note: a class pattern nested inside a mapping pattern (e.g.
# `case {'p': Point(a, b)}`) is not yet byte-exact. CPython interns the class
# attr-name tuple before folding the mapping key tuple (which lands last), while
# the reimpl emits the key tuple at its use site; matching that needs CPython's
# global tuple-const fold + remove_unused_consts. Execution is still correct.

test "layer10: band8 match mixed sequence literal+capture matches oracle co_code" {
    assert_nested_oracle(
        match_arm_src("        case [a, 1, b]:\n            return a + b\n")
    );
}

# Dict/tuple display literals are not yet compilable natively, so the subject
# is built by a host-compiled setup (as in the band8 sequence exec test) and
# the native match arm is exercised over it.
def exec_with_subject(setup_src: str, match_src: str) -> dict[str, PyObj] {
    setup = unmarshal(host_compile_marshal(setup_src, "<setup>", "exec", 0));
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    co = product_exec(match_src, "<f>");
    assert not is_error(co);
    assert isinstance(co, PyCode);
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    return ns;
}

test "layer10: band8 match mapping executes in ceval" {
    ns = exec_with_subject(
        "d = {'a': 10, 'b': 20}\n",
        "def f(d):\n"
            + "    match d:\n"
            + "        case {'a': v, 'b': w}:\n"
            + "            return v + w\n"
            + "        case _:\n"
            + "            return -1\n"
            + "\n"
            + "result = f(d)\n"
    );
    assert expect_int(ns["result"]) == 30;
}

test "layer10: band8 match mapping rest executes in ceval" {
    ns = exec_with_subject(
        "d = {'a': 5, 'b': 1, 'c': 2}\n",
        "def f(d):\n"
            + "    match d:\n"
            + "        case {'a': v, **rest}:\n"
            + "            return v + len(rest)\n"
            + "        case _:\n"
            + "            return -1\n"
            + "\n"
            + "result = f(d)\n"
    );
    assert expect_int(ns["result"]) == 7;
}

test "layer10: band8 match class executes in ceval" {
    ns = exec_with_subject(
        "class Point:\n"
            + "    __match_args__ = ('x', 'y')\n"
            + "    def __init__(self, x, y):\n"
            + "        self.x = x\n"
            + "        self.y = y\n"
            + "p = Point(3, 4)\n",
        "def f(p):\n"
            + "    match p:\n"
            + "        case Point(a, b):\n"
            + "            return a + b\n"
            + "        case _:\n"
            + "            return -1\n"
            + "\n"
            + "result = f(p)\n"
    );
    assert expect_int(ns["result"]) == 7;
}

test "layer10: band8 match mapping no-match falls through in ceval" {
    ns = exec_with_subject(
        "d = {'x': 1}\n",
        "def f(d):\n"
            + "    match d:\n"
            + "        case {'a': v}:\n"
            + "            return v\n"
            + "        case _:\n"
            + "            return -1\n"
            + "\n"
            + "result = f(d)\n"
    );
    assert expect_int(ns["result"]) == -1;
}

# ---------------- VM execution ----------------

test "layer10: while loop executes in ceval" {
    co = product_exec("while x: x = 0\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=1)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 0;
}

test "layer10: for loop executes in ceval" {
    co = product_exec("total = 0\nfor x in y:\n    total = total + x\n");
    assert not is_error(co);
    assert isinstance(co, PyCode);
    ns: dict[str, PyObj] = {
        "y": PyTuple(
            t="tuple",
            items=[
                PyInt(t="int", val=1),
                PyInt(t="int", val=2),
                PyInt(t="int", val=3),

            ],
        ),
        "total": PyInt(t="int", val=0),

    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["total"]) == 6;
}
