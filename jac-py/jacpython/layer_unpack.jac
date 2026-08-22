# Band 9 slice: sequence-unpacking assignment targets + tuple/list displays.
# Byte-exact PyCode parity against the CPython 3.14.6 oracle, plus VM execution.

import from objects { PyObj, PyCode, PyInt, expect_int, is_error }
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

def product_exec(source: str, filename: str = "<f>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
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
    assert act.exceptiontable == exp.exceptiontable;
}

def run_module(source: str) -> dict[str, PyObj] {
    co = product_exec(source);
    assert not is_error(co);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    return ns;
}

# ---------------- byte-exact: tuple/list assignment targets ----------------

test "unpack: two-name literal swap" {
    assert_matches_oracle("a, b = b, a + b\n");
}

test "unpack: two-const literal" {
    assert_matches_oracle("a, b = 1, 2\n");
}

test "unpack: three-name literal" {
    assert_matches_oracle("a, b, c = x, y, z\n");
}

test "unpack: four-name literal build+unpack" {
    assert_matches_oracle("a, b, c, d = e, f, g, h\n");
}

test "unpack: one-tuple literal" {
    assert_matches_oracle("(a,) = (b,)\n");
}

test "unpack: call rhs unpack_sequence" {
    assert_matches_oracle("a, b = f()\n");
}

test "unpack: star tail" {
    assert_matches_oracle("first, *rest = it\n");
}

test "unpack: star head" {
    assert_matches_oracle("*a, b = it\n");
}

test "unpack: star middle" {
    assert_matches_oracle("a, *b, c = it\n");
}

test "unpack: nested targets" {
    assert_matches_oracle("(a, (b, c)) = x\n");
}

test "unpack: list target" {
    assert_matches_oracle("[a, b] = y\n");
}

# ---------------- byte-exact: non-constant tuple/list displays ----------------
# All-constant displays fold to a const, but CPython leaves a ghost first-element
# const in the pool during folding (co_consts=(1, None, (1,2)) for `x = (1,2)`);
# reproducing that const-pool artifact is deferred, so all-const folds are
# verified by execution below rather than byte-exact PyCode parity.

test "display: name tuple build" {
    assert_matches_oracle("x = (a, b)\n");
}

test "display: singleton tuple" {
    assert_matches_oracle("x = (a,)\n");
}

test "display: name list" {
    assert_matches_oracle("x = [a, b]\n");
}

test "display: empty list" {
    assert_matches_oracle("x = []\n");
}

test "exec: empty tuple/list" {
    ns = run_module("t = ()\nxs = []\nr = len(t) + len(xs)\n");
    assert expect_int(ns["r"]) == 0;
}

# ---------------- execution: all-const display folds ----------------

test "exec: const tuple value" {
    ns = run_module("t = (1, 2, 3)\nr = t[0] + t[1] + t[2]\n");
    assert expect_int(ns["r"]) == 6;
}

test "exec: const list value" {
    ns = run_module("xs = [10, 20, 30]\nr = xs[0] + xs[2]\n");
    assert expect_int(ns["r"]) == 40;
}

test "exec: name tuple/list build" {
    ns = run_module("a = 5\nb = 7\nt = (a, b)\nxs = [a, b, a]\nr = t[1] + xs[2]\n");
    assert expect_int(ns["r"]) == 12;
}

# ---------------- execution ----------------

test "exec: iterative fib via swap" {
    ns = run_module(
        "a = 0\nb = 1\ni = 0\nwhile i < 10:\n    a, b = b, a + b\n    i = i + 1\nr = a\n"
    );
    assert expect_int(ns["r"]) == 55;
}

test "exec: star unpack values" {
    ns = run_module(
        "first, *rest, last = [1, 2, 3, 4, 5]\nr = first + last\nm = rest[1]\n"
    );
    assert expect_int(ns["r"]) == 6;
    assert expect_int(ns["m"]) == 3;
}

test "exec: nested unpack" {
    ns = run_module("(a, (b, c)) = (1, (2, 3))\nr = a + b + c\n");
    assert expect_int(ns["r"]) == 6;
}

# ---------------- byte-exact: set/dict/starred displays ----------------

test "display: set build" {
    assert_matches_oracle("x = {a, b, c}\n");
}

test "display: dict build" {
    assert_matches_oracle("x = {a: b, c: d}\n");
}

test "display: starred list" {
    assert_matches_oracle("x = [*a, b]\n");
}

test "display: starred tuple" {
    assert_matches_oracle("x = (*a, b)\n");
}

test "display: set update" {
    assert_matches_oracle("x = {*a, b}\n");
}

test "display: dict merge starred" {
    assert_matches_oracle("x = {**a, 'k': v}\n");
}

test "display: dict merge double" {
    assert_matches_oracle("x = {**a, **b}\n");
}

test "display: dict merge mixed" {
    assert_matches_oracle("x = {'j': w, **a, 'k': v}\n");
}

# ---------------- execution: set/dict/starred displays ----------------

test "exec: set build value" {
    ns = run_module("a = 1\nb = 2\nc = 3\ns = {a, b, c}\nr = len(s)\n");
    assert expect_int(ns["r"]) == 3;
}

test "exec: dict build value" {
    ns = run_module("a = 1\nb = 2\nc = 3\nd = 4\nm = {a: b, c: d}\nr = m[a] + m[c]\n");
    assert expect_int(ns["r"]) == 6;
}

test "exec: starred list value" {
    ns = run_module("a = [1, 2]\nb = 3\nxs = [*a, b]\nr = xs[0] + xs[1] + xs[2]\n");
    assert expect_int(ns["r"]) == 6;
}

test "exec: starred tuple value" {
    ns = run_module("a = [1, 2]\nb = 3\nt = (*a, b)\nr = t[0] + t[2]\n");
    assert expect_int(ns["r"]) == 4;
}

test "exec: starred set update value" {
    ns = run_module("a = [1, 2]\nb = 3\ns = {*a, b}\nr = len(s)\n");
    assert expect_int(ns["r"]) == 3;
}

test "exec: dict merge starred value" {
    ns = run_module("a = {'x': 1}\nv = 2\nm = {**a, 'k': v}\nr = m['x'] + m['k']\n");
    assert expect_int(ns["r"]) == 3;
}

test "exec: dict merge double value" {
    ns = run_module(
        "a = {'x': 1}\nb = {'y': 2}\nm = {**a, **b}\nr = m['x'] + m['y']\n"
    );
    assert expect_int(ns["r"]) == 3;
}

test "exec: dict merge mixed override value" {
    ns = run_module(
        "w = 1\na = {'k': 5}\nv = 9\nm = {'j': w, **a, 'k': v}\nr = m['j'] + m['k']\n"
    );
    assert expect_int(ns["r"]) == 10;
}
