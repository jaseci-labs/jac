# D1 smoke: real Python programs, source -> native PyCode -> VM execution.
#
# This is the D1 milestone probe (hello / fib / pystone-class of programs):
# every program is compiled by the fully native front end (compile_source, no
# host compile/marshal on the product path) and executed on the JacPython VM
# (exec_code). Each program leaves its answer in a global `result` (or similar)
# that we read back out of the module namespace and assert.
#
# Builtins (range/len/print/...) currently resolve through the host `builtins`
# module inside the VM -- that is the still-open "self-contained" axis (P6), not
# the "native compiler can produce and the VM can run it" axis this file gates.
# A failure here is a real native-compiler-or-VM gap on the road to D1.

import from objects { PyObj, PyCode, PyInt, PyStr, expect_int, expect_str, is_error }
import from product_compile { compile_source }
import from pyc_first { exec_code }

def product_exec(source: str, filename: str = "<d1>") -> PyObj {
    return compile_source(source, filename, "exec", 0);
}

# Compile natively + run on the VM; return the resulting module namespace.
def run_module(source: str) -> dict[str, PyObj] {
    co = product_exec(source);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    ns: dict[str, PyObj] = {};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    return ns;
}

# ---------------- fib (recursion, if, arithmetic, comparison) ----------------

test "d1: recursive fib" {
    src = (
        "def fib(n):\n"
        + "    if n < 2:\n"
        + "        return n\n"
        + "    return fib(n - 1) + fib(n - 2)\n"
        + "result = fib(10)\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 55;
}

# ---------------- iterative fib (while, tuple-unpack assign) ----------------

test "d1: iterative fib via while" {
    src = (
        "a = 0\n"
        + "b = 1\n"
        + "i = 0\n"
        + "while i < 10:\n"
        + "    a, b = b, a + b\n"
        + "    i = i + 1\n"
        + "result = a\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 55;
}

# ---------------- for + range + augassign (host builtin range) ----------------

test "d1: sum over range" {
    src = (
        "total = 0\n"
        + "for i in range(100):\n"
        + "    total += i\n"
        + "result = total\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 4950;
}

# ---------------- class + __init__ + method + attr + augassign ----------------

test "d1: class counter (pystone-shaped)" {
    src = (
        "class Rec:\n"
        + "    def __init__(self, v):\n"
        + "        self.v = v\n"
        + "    def bump(self):\n"
        + "        self.v += 1\n"
        + "        return self.v\n"
        + "r = Rec(0)\n"
        + "acc = 0\n"
        + "for _ in range(50):\n"
        + "    acc = r.bump()\n"
        + "result = acc\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 50;
}

# ---------------- closures (nested def, free var) ----------------

test "d1: closure adder" {
    src = (
        "def make_adder(n):\n"
        + "    def add(x):\n"
        + "        return x + n\n"
        + "    return add\n"
        + "add5 = make_adder(5)\n"
        + "result = add5(37)\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 42;
}

# ---------------- try/except control flow ----------------

test "d1: try/except divide" {
    src = (
        "def safe_div(a, b):\n"
        + "    try:\n"
        + "        return a // b\n"
        + "    except ZeroDivisionError:\n"
        + "        return -1\n"
        + "result = safe_div(10, 0) + safe_div(10, 2)\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 4;
}

# ---------------- comprehension with multi-ref element (LOAD_FAST_BORROW) ----

test "d1: list comprehension squares" {
    # `x * x` references the loop var twice: the first reference consumes the
    # STORE_FAST_LOAD_FAST borrow, the second emits LOAD_FAST_BORROW.
    src = "sq = [x * x for x in range(10)]\n" + "result = sum(sq)\n";
    ns = run_module(src);
    assert expect_int(ns["result"]) == 285;
}

test "d1: dict/set comprehension multi-ref" {
    src = (
        "d = {x: x * x for x in range(5)}\n"
        + "s = {x * x for x in range(5)}\n"
        + "result = d[4] + sum(s)\n"
    );
    ns = run_module(src);
    assert expect_int(ns["result"]) == 46;
}

# ---------------- string methods (hello-world class) ----------------

test "d1: hello world string ops" {
    src = "msg = 'hello, ' + 'world'\n" + "result = msg.upper()\n";
    ns = run_module(src);
    assert expect_str(ns["result"]) == "HELLO, WORLD";
}
