# Layer 9 product exec slice (PLAN.md P0.12 band 2 / P0.13 exec path).
#
# Closes the statement-expansion vertical slice: source string -> PyCode for
# exec mode, entirely via the native front end (parse_file -> compile_exec ->
# assemble), with no host_oracle / marshal / host-ast on the product path.
#
# Differential against the host oracle (byte-exact PyCode) plus VM execution for
# the band-2 straight-line fixtures: name assign, load expr-statement (including
# attribute/subscript loads), pass, and name augassign. Attribute/subscript
# store and augassign are covered when the parser emits Store targets.
# Multi-distinct-small-int literals and constant-only expr-statements depend on
# CPython peephole passes (small-int const pruning, dead-expr elimination)
# tracked separately under P0.11.
#
# Test harness only: host_oracle is used solely to produce the expected PyCode.

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
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code, gen_send, py_subscript, PyGenerator }

def oracle_eval(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "eval", 0));
}

# Oracle PyCode from the host compiler (marshal transport, test-only).
def oracle_exec(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "exec", 0));
}

# Product PyCode from the fully native front end.
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

# Byte-exact slice: co_code, tables, stack depth, PEP 626 linetable. Oracle
# marshal currently mis-loads co_flags (pyc_first read_code); skip flags until
# that lands -- same carve-out as layer8.assert_matches_oracle.
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

test "layer9: x = 1 product PyCode matches oracle" {
    assert_matches_oracle("x = 1\n");
}

test "layer9: x = 1000 product PyCode matches oracle" {
    assert_matches_oracle("x = 1000\n");
}

test "layer9: pass product PyCode matches oracle" {
    assert_matches_oracle("pass\n");
}

test "layer9: name expr-statement matches oracle" {
    assert_matches_oracle("x\n");
}

test "layer9: three-statement module matches oracle" {
    assert_matches_oracle("a = x\nb = y\nc = a + b\n");
}

test "layer9: attribute load expr-statement matches oracle" {
    assert_matches_oracle("x.y\n");
}

test "layer9: subscript load expr-statement matches oracle" {
    assert_matches_oracle("x[0]\n");
}

test "layer9: name augassign matches oracle" {
    assert_matches_oracle("x += 1\n");
}

test "layer9: attribute store matches oracle" {
    assert_matches_oracle("x.y = 1\n");
}

test "layer9: subscript store matches oracle" {
    assert_matches_oracle("x[0] = 1\n");
}

test "layer9: attribute augassign matches oracle" {
    assert_matches_oracle("x.y += 1\n");
}

test "layer9: subscript augassign matches oracle" {
    assert_matches_oracle("x[0] += 1\n");
}

test "layer9: chained assignment matches oracle" {
    assert_matches_oracle("x = y = 1\n");
}

test "layer9: x = y = side_effect() matches oracle" {
    assert_matches_oracle("x = y = side_effect()\n");
}

test "layer9: obj.x = seq[index()] = value() matches oracle" {
    assert_matches_oracle("obj.x = seq[index()] = value()\n");
}

test "layer9: a = x < y < z matches oracle" {
    assert_matches_oracle("a = x < y < z\n");
}

test "layer9: compare assign then statement matches oracle" {
    assert_matches_oracle("a = x < y < z\nb = 1\n");
}

test "layer9: compare assign then statement executes both" {
    co = product_exec("a = x < y < z\nb = 1\n");
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),

    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(ns["a"], PyBool);
    assert (ns["a"] as PyBool).val;
    assert expect_int(ns["b"]) == 1;
}

test "layer9: eval (x < y < z) and q matches oracle" {
    co = compile_source("(x < y < z) and q", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    expected = oracle_eval("(x < y < z) and q", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    act = co as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
}

test "layer9: f(x<y<z) matches oracle" {
    co = compile_source("f(x<y<z)", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    expected = oracle_eval("f(x<y<z)", "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    act = co as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
}

test "layer9: f(x<y<z) executes in ceval" {
    setup = unmarshal(
        host_compile_marshal(
            "def f(x):\n    return 1 if x else 0\n", "<setup>", "exec", 0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    ns["x"] = PyInt(t="int", val=1);
    ns["y"] = PyInt(t="int", val=2);
    ns["z"] = PyInt(t="int", val=3);
    co = compile_source("f(x<y<z)", "<f>", "eval", 0);
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyInt);
    assert expect_int(out) == 1;
}

test "layer9: chained assignment executes in ceval" {
    co = product_exec("x = y = 5\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 5;
    assert expect_int(ns["y"]) == 5;
}

# ---------------- Band 4: thin function slice ----------------

test "layer9: def f(x) return x+1 and call matches oracle" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    assert_matches_oracle(src);
}

test "layer9: def f(x) return x+1 and call executes in ceval" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: nested function PyCode has fast locals and argcount" {
    src = "def f(x):\n    return x + 1\n\nresult = f(2)\n";
    co = product_exec(src);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    assert len(mod.consts) >= 1;
    assert isinstance(mod.consts[0], PyCode);
    fn = mod.consts[0] as PyCode;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
}

# ---------------- Band 4: recursion slice ----------------

test "layer9: if return in function compiles" {
    src = "def f(n):\n    if n <= 1:\n        return 1\n    return 0\n";
    co = product_exec(src);
    assert not is_error(co);
}

test "layer9: recursive fact(n) matches oracle" {
    src = (
        "def fact(n):\n"
        + "    if n <= 1:\n"
        + "        return 1\n"
        + "    return n * fact(n - 1)\n\n"
        + "result = fact(5)\n"
    );
    assert_matches_oracle(src);
}

test "layer9: recursive fact(n) executes in ceval" {
    src = (
        "def fact(n):\n"
        + "    if n <= 1:\n"
        + "        return 1\n"
        + "    return n * fact(n - 1)\n\n"
        + "result = fact(5)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 120;
}

# ---------------- Band 4: lambdas slice ----------------

test "layer9: lambda assign matches oracle" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    assert_matches_oracle(src);
}

test "layer9: lambda assign executes in ceval" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: nested lambda PyCode has fast locals and argcount" {
    src = "f = lambda x: x + 1\nresult = f(2)\n";
    co = product_exec(src);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    assert len(mod.consts) >= 1;
    assert isinstance(mod.consts[0], PyCode);
    fn = mod.consts[0] as PyCode;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
    assert fn.flags == 3;
}

test "layer9: inline lambda call executes in ceval" {
    src = "result = (lambda x: x + 1)(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: closures slice ----------------

test "layer9: nested closure capture matches oracle" {
    src = (
        "def outer(x):\n"
        + "    def inner():\n"
        + "        return x\n"
        + "    return inner()\n\n"
        + "result = outer(42)\n"
    );
    assert_matches_oracle(src);
}

test "layer9: nested closure capture executes in ceval" {
    src = (
        "def outer(x):\n"
        + "    def inner():\n"
        + "        return x\n"
        + "    return inner()\n\n"
        + "result = outer(42)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 42;
}

test "layer9: nested inner PyCode has freevars and cellvars metadata" {
    src = (
        "def outer(x):\n"
        + "    def inner():\n"
        + "        return x\n"
        + "    return inner()\n\n"
        + "result = outer(42)\n"
    );
    co = product_exec(src);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    mod = co as PyCode;
    outer_co = mod.consts[0] as PyCode;
    inner_co = outer_co.consts[0] as PyCode;
    assert len(outer_co.cellvars) == 1;
    assert outer_co.cellvars[0] == "x";
    assert len(inner_co.freevars) == 1;
    assert inner_co.freevars[0] == "x";
    exp = oracle_exec(src, "<f>");
    assert isinstance(exp, PyCode);
    exp_outer = (exp as PyCode).consts[0] as PyCode;
    exp_inner = exp_outer.consts[0] as PyCode;
    assert inner_co.co_code == exp_inner.co_code;
}

test "layer9: lambda closure executes in ceval" {
    src = "def outer(x):\n    return lambda: x\n\nresult = outer(7)()\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 7;
}

# ---------------- Band 4: default arguments slice ----------------

test "layer9: default args matches oracle" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 2;
    assert fn.varnames == ["x", "y"];
    assert act.stacksize == exp.stacksize;
}

test "layer9: default args executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "layer9: default args explicit call executes in ceval" {
    src = "def f(x, y=10):\n    return x + y\n\nresult = f(2, 3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 5;
}

test "layer9: lambda default args executes in ceval" {
    src = "g = lambda x, y=1: x + y\nresult = g(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 4: *args / **kwargs / kw-only slice ----------------

test "layer9: varargs matches oracle" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["a", "args"];
}

test "layer9: varargs executes in ceval" {
    src = "def f(a, *args):\n    return a + len(args)\n\nresult = f(1, 2, 3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: varkw executes in ceval" {
    src = "def f(a, **kwargs):\n    return a + len(kwargs)\n\nresult = f(1, b=2, c=3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: kwonly default matches oracle" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    fn = first_nested_code(act);
    exp_fn = first_nested_code(exp);
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.kwonlyargcount == 1;
    assert fn.varnames == ["a", "b"];
}

test "layer9: kwonly default executes in ceval" {
    src = "def f(a, *, b=10):\n    return a + b\n\nresult = f(2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 12;
}

test "layer9: varargs kwonly default executes in ceval" {
    src = "def f(a, *args, b=1):\n    return a + len(args) + b\n\nresult = f(1, 2, 3)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 4;
}

# ---------------- Band 4: decorators slice ----------------

test "layer9: decorator matches oracle" {
    src = (
        "def deco(fn):\n"
        + "    return fn\n\n"
        + "@deco\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    fn = nested_code_by_name(act, "f");
    exp_fn = nested_code_by_name(exp, "f");
    assert fn.co_code == exp_fn.co_code;
    assert fn.stacksize == exp_fn.stacksize;
    assert fn.argcount == 1;
    assert fn.varnames == ["x"];
}

test "layer9: decorator executes in ceval" {
    src = (
        "def deco(fn):\n"
        + "    return fn\n\n"
        + "@deco\n"
        + "def f(x):\n"
        + "    return x + 1\n\n"
        + "result = f(2)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: multiple decorators executes in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 5: imports slice ----------------

test "layer9: import math matches oracle" {
    assert_matches_oracle("import math\n");
}

test "layer9: from operator import add matches oracle" {
    assert_matches_oracle("from operator import add\n");
}

test "layer9: from operator import add as plus matches oracle" {
    assert_matches_oracle("from operator import add as plus\n");
}

test "layer9: import math executes in ceval" {
    src = "import math\nresult = math.pi > 3\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(ns["result"], PyBool);
    assert (ns["result"] as PyBool).val;
}

test "layer9: from operator import add executes in ceval" {
    src = "from operator import add\nresult = add(1, 2)\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 5 slice 1: basic class body ----------------

test "layer9: band5 empty class matches oracle" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    nested = nested_code_by_name(act, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == exp_nested.co_code;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.argcount == 0;
}

test "layer9: band5 empty class executes in ceval" {
    src = "class C:\n    pass\n\nresult = C.__name__\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
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

test "layer9: band5 class method matches oracle" {
    src = (
        "class C:\n"
        + "    def m(self):\n"
        + "        return 1\n\n"
        + "result = C().m()\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    nested = nested_code_by_name(act, "C");
    exp_nested = nested_code_by_name(exp, "C");
    assert nested.co_code == BAND5_CLASS_C_CO_CODE;
    assert nested.stacksize == exp_nested.stacksize;
    assert nested.cellvars == ["__classdict__"];
}

test "layer9: band5 class method executes in ceval" {
    src = (
        "class C:\n"
        + "    def m(self):\n"
        + "        return 1\n\n"
        + "result = C().m()\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

test "layer9: band5 class inheritance matches oracle" {
    src = (
        "class Base:\n"
        + "    x = 1\n"
        + "class C(Base):\n"
        + "    pass\n"
        + "result = C().x\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    c_cls = nested_code_by_name(act, "C");
    exp_c = nested_code_by_name(exp, "C");
    assert c_cls.co_code == exp_c.co_code;
}

test "layer9: band5 class inheritance executes in ceval" {
    src = (
        "class Base:\n"
        + "    x = 1\n"
        + "class C(Base):\n"
        + "    pass\n"
        + "result = C().x\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

test "layer9: band5 nested class matches oracle" {
    src = (
        "class Outer:\n"
        + "    class Inner:\n"
        + "        x = 1\n"
        + "result = Outer.Inner.x\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    outer = nested_code_by_name(act, "Outer");
    exp_outer = nested_code_by_name(exp, "Outer");
    assert outer.co_code == exp_outer.co_code;
    inner = nested_code_by_name(outer, "Inner");
    exp_inner = nested_code_by_name(exp_outer, "Inner");
    assert inner.co_code == exp_inner.co_code;
    assert inner.qualname == "Outer.Inner";
}

test "layer9: band5 nested class executes in ceval" {
    src = (
        "class Outer:\n"
        + "    class Inner:\n"
        + "        x = 1\n"
        + "result = Outer.Inner.x\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

# ---------------- Band 6 slice 1: try/except typed handler ----------------

test "layer9: band6 try except typed matches oracle" {
    src = (
        "try:\n" + "    1 // 0\n" + "except ZeroDivisionError:\n" + "    result = 99\n"
    );
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 try except typed executes in ceval" {
    src = (
        "try:\n" + "    1 // 0\n" + "except ZeroDivisionError:\n" + "    result = 99\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 99;
}

# ---------------- Band 6 slice 2: raise ----------------

test "layer9: band6 raise matches oracle" {
    src = "raise ValueError('bad')\n";
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 raise raises ValueError in ceval" {
    src = "raise ValueError('bad')\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == "bad";
}

test "layer9: band6 try except re-raise matches oracle" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    raise\n"
    );
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 try except re-raise propagates in ceval" {
    src = (
        "try:\n"
        + "    raise ValueError('x')\n"
        + "except ValueError:\n"
        + "    raise\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "ValueError";
    assert err.exception.message == "x";
}

# ---------------- Band 6 slice 3: except as ----------------

test "layer9: band6 try except as matches oracle" {
    src = (
        "try:\n"
        + "    1 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
    );
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 try except as executes in ceval" {
    src = (
        "try:\n"
        + "    1 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "division by zero";
}

# ---------------- Band 6 slice 4: try/finally ----------------

test "layer9: band6 try finally matches oracle" {
    src = (
        "count = 0\n"
        + "try:\n"
        + "    count = 1\n"
        + "finally:\n"
        + "    count = count + 10\n"
        + "result = count\n"
    );
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 try finally executes in ceval" {
    src = (
        "count = 0\n"
        + "try:\n"
        + "    count = 1\n"
        + "finally:\n"
        + "    count = count + 10\n"
        + "result = count\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 11;
}

test "layer9: band6 try finally runs on exception path in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 10;
}

# ---------------- Band 6 slice 5: with ----------------

test "layer9: band6 with matches oracle" {
    src = (
        "class CM:\n"
        + "    def __enter__(self):\n"
        + "        return 42\n"
        + "    def __exit__(self, *a):\n"
        + "        pass\n"
        + "with CM() as x:\n"
        + "    result = x\n"
    );
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 with executes in ceval" {
    src = (
        "class CM:\n"
        + "    def __enter__(self):\n"
        + "        return 42\n"
        + "    def __exit__(self, *a):\n"
        + "        pass\n"
        + "with CM() as x:\n"
        + "    result = x\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 42;
}

# ---------------- Band 6 slice 6: assert ----------------

test "layer9: band6 assert matches oracle" {
    src = "x = 1\nassert x == 1\nresult = x\n";
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 assert executes in ceval" {
    src = "x = 1\nassert x == 1\nresult = x\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

test "layer9: band6 assert failure matches oracle" {
    src = "x = 0\nassert x == 1, 'fail'\nresult = x\n";
    actual = product_exec(src);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    exp = expected as PyCode;
    assert isinstance(actual, PyCode);
    act = actual as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 assert failure raises AssertionError in ceval" {
    src = "x = 0\nassert x == 1, 'fail'\nresult = x\n";
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert is_error(out);
    err = out as PyError;
    assert err.exception.type_name == "AssertionError";
    assert err.exception.message == "fail";
}

# ---------------- Band 6 slice 7: multi-handler try/except[/else]/finally ----------------

def _layer9_parity(src: str) {
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.exceptiontable == exp.exceptiontable;
    assert act.stacksize == exp.stacksize;
}

test "layer9: band6 two handlers finally caught by first matches oracle" {
    _layer9_parity(
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

test "layer9: band6 two handlers finally caught by first executes in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
    assert expect_int(ns["marker"]) == 9;
}

test "layer9: band6 three handlers else finally no-exception matches oracle" {
    _layer9_parity(
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

test "layer9: band6 three handlers else finally no-exception executes in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 6;
}

test "layer9: band6 two handlers finally uncaught propagates in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert is_error(out);
    assert (out as PyError).exception.type_name == "TypeError";
    assert expect_int(ns["marker"]) == 9;
}

test "layer9: band6 try except as finally caught matches oracle" {
    _layer9_parity(
        "try:\n"
        + "    result = 10 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
}

test "layer9: band6 try except as finally caught executes in ceval" {
    src = (
        "try:\n"
        + "    result = 10 // 0\n"
        + "except ZeroDivisionError as e:\n"
        + "    result = str(e)\n"
        + "finally:\n"
        + "    marker = 9\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_str(ns["result"]) == "division by zero";
    assert expect_int(ns["marker"]) == 9;
}

# ---------------- Band 7 slice 1: generator yield ----------------

test "layer9: band7 generator yield matches oracle" {
    src = (
        "def gen():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "g = gen()\n"
        + "result = next(g) + next(g)\n"
    );
    assert_matches_oracle(src);
}

test "layer9: band7 generator yield executes in ceval" {
    src = (
        "def gen():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "g = gen()\n"
        + "result = next(g) + next(g)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

# ---------------- Band 7 slice 2: yield from ----------------

test "layer9: band7 yield from matches oracle" {
    src = (
        "def outer():\n"
        + "    yield from inner()\n"
        + "def inner():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "result = list(outer())\n"
    );
    assert_matches_oracle(src);
}

test "layer9: band7 yield from executes in ceval" {
    src = (
        "def outer():\n"
        + "    yield from inner()\n"
        + "def inner():\n"
        + "    yield 1\n"
        + "    yield 2\n"
        + "result = list(outer())\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    lst = ns["result"];
    assert expect_int(py_subscript(lst, PyInt(t="int", val=0))) == 1;
    assert expect_int(py_subscript(lst, PyInt(t="int", val=1))) == 2;
}

# ---------------- Band 7 slice 3: async def ----------------

test "layer9: band7 async def matches oracle" {
    src = "async def f():\n  return 1\n";
    assert_matches_oracle(src);
}

# ---------------- Band 7 slice 4: await ----------------

test "layer9: band7 await matches oracle" {
    src = (
        "async def f():\n"
        + "    return await g()\n"
        + "async def g():\n"
        + "    return 1\n"
    );
    assert_matches_oracle(src);
}

test "layer9: band7 await executes in ceval" {
    src = (
        "async def f():\n"
        + "    return await g()\n"
        + "async def g():\n"
        + "    return 1\n"
        + "c = f()\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
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

test "layer9: band7 async for matches oracle" {
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
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
}

test "layer9: band7 async for executes in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 42;
}

# ---------------- Band 7 slice 6: async with ----------------

test "layer9: band7 async with matches oracle" {
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
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
}

test "layer9: band7 async with executes in ceval" {
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
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    coro = ns["c"];
    assert coro.t == "coroutine";
    done = gen_send(coro as PyGenerator, py_none());
    assert is_error(done);
    finished = (done as PyError).exception;
    assert finished.type_name == "StopIteration";
    assert expect_int(finished.value as PyObj) == 42;
}

# ---------------- Band 8 slice 1–3: match ----------------

test "layer9: band8 match literal matches oracle" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
}

test "layer9: band8 match guard matches oracle" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1 if x > 0:\n"
        + "            return 'one'\n"
        + "        case _:\n"
        + "            return 'other'\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
}

test "layer9: band8 match sequence matches oracle" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case [a, b]:\n"
        + "            return a + b\n"
        + "        case _:\n"
        + "            return 0\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
    assert act_f.varnames == exp_f.varnames;
}

test "layer9: band8 match sequence executes in ceval" {
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
    co = product_exec(src);
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}

test "layer9: band8 match-or literal matches oracle" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1 | 2 | 3:\n"
        + "            return 'a'\n"
        + "        case _:\n"
        + "            return 'b'\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
}

test "layer9: band8 match-or guard matches oracle" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1 | 2 if x > 0:\n"
        + "            return 'a'\n"
        + "        case _:\n"
        + "            return 'b'\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    act_f = nested_code_by_name(actual as PyCode, "f");
    exp_f = nested_code_by_name(expected as PyCode, "f");
    assert act_f.co_code == exp_f.co_code;
    assert act_f.exceptiontable == exp_f.exceptiontable;
    assert act_f.stacksize == exp_f.stacksize;
}

test "layer9: band8 match-or executes in ceval" {
    src = (
        "def f(x):\n"
        + "    match x:\n"
        + "        case 1 | 2 | 3:\n"
        + "            return 'a'\n"
        + "        case _:\n"
        + "            return 'b'\n"
        + "\n"
        + "r1 = f(2)\n"
        + "r2 = f(3)\n"
        + "r3 = f(9)\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_str(ns["r1"]) == "a";
    assert expect_str(ns["r2"]) == "a";
    assert expect_str(ns["r3"]) == "b";
}

# ---------------- VM execution ----------------

test "layer9: side_effect chained assignment evaluates RHS once" {
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
    co = product_exec("x = y = side_effect()\n");
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 42;
    assert expect_int(ns["y"]) == 42;
    assert expect_int(ns["count"]) == 1;
}

test "layer9: x = 1 executes in ceval" {
    co = product_exec("x = 1\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert "x" in ns;
    assert expect_int(ns["x"]) == 1;
}

test "layer9: assignment chain executes in ceval" {
    co = product_exec("a = x\nb = y\nc = a + b\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=2), "y": PyInt(t="int", val=3),};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["a"]) == 2;
    assert expect_int(ns["b"]) == 3;
    assert expect_int(ns["c"]) == 5;
}

test "layer9: pass executes (returns None, no error)" {
    co = product_exec("pass\n");
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
}

test "layer9: name expr-statement executes (loads + discards)" {
    co = product_exec("x\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=42)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
}

test "layer9: name augassign executes in ceval" {
    co = product_exec("x += 3\n");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=4)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["x"]) == 7;
}

# ---------------- error path ----------------

test "layer9: parse error returns SyntaxError PyObj" {
    res = compile_source("x =\n", "<f>", "exec", 0);
    assert is_error(res);
    assert isinstance(res, PyError);
    assert (res as PyError).exception.type_name == "SyntaxError";
}

test "layer9: module return rejected at compile time" {
    res = compile_source("return 1\n", "<f>", "exec", 0);
    assert is_error(res);
    assert isinstance(res, PyError);
    assert (res as PyError).exception.type_name == "SyntaxError";
    assert (res as PyError).exception.message == "'return' outside function";
}

# Regression guard: eval mode is untouched by the statement expansion.
test "layer9: eval mode still byte-exact (regression)" {
    co = compile_source("1+1", "<f>", "eval", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
}

# ---------------- Band 5 slice 3: name mangling (__private) ----------------

test "layer9: class private attr product PyCode matches oracle" {
    src = (
        "class C:\n"
        + "    __x = 1\n"
        + "    def m(self):\n"
        + "        return self.__x\n"
        + "result = C().m()\n"
    );
    actual = product_exec(src);
    assert not is_error(actual);
    expected = oracle_exec(src, "<f>");
    assert isinstance(expected, PyCode);
    act = actual as PyCode;
    exp = expected as PyCode;
    assert act.co_code == exp.co_code;
    assert act.stacksize == exp.stacksize;
    cls = nested_code_by_name(act, "C");
    exp_cls = nested_code_by_name(exp, "C");
    assert cls.co_code == exp_cls.co_code;
    assert cls.stacksize == exp_cls.stacksize;
    m = nested_code_by_name(cls, "m");
    exp_m = nested_code_by_name(exp_cls, "m");
    assert m.co_code == exp_m.co_code;
    assert m.stacksize == exp_m.stacksize;
}

test "layer9: class private attr executes in ceval" {
    src = (
        "class C:\n"
        + "    __x = 1\n"
        + "    def m(self):\n"
        + "        return self.__x\n"
        + "result = C().m()\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 1;
}

# Band 11: function-local annotated assignment executes like a plain store in
# ceval (PEP 649 drops the annotation at local scope).
test "layer9: local AnnAssign stores and reads back in ceval" {
    src = (
        "def f():\n"
        + "    q: int = 3\n"
        + "    return q\n"
        + "result = f()\n"
    );
    co = product_exec(src);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert expect_int(ns["result"]) == 3;
}
