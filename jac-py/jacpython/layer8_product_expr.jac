# Layer 8 product eval slice (PLAN.md P0.13): source string -> PyCode.
#
# Closes the declared vertical slice. The SAME source the host
# `compile(..., "eval")` would compile is now compiled entirely by the native
# front end -- tokenizer -> parser -> codegen -> assembler -- via
# compile_source, with no host_oracle / marshal / host-ast on the product path.
#
# Differential against the host oracle (byte-exact PyCode) plus VM execution for
# the five expression fixtures exercised by the compiler slice: 1+1, -x,
# a*b+c, f(x,1), x<y<z.
#
# Test harness only: host_oracle is used solely to produce the expected PyCode.

import from objects { PyObj, PyCode, PyInt, PyBool, expect_int, is_error, PyError }
import from product_compile { compile_source }
import from host_oracle { host_compile_marshal }
import from pyc_first { unmarshal, exec_code }

# Oracle PyCode from the host compiler (marshal transport, test-only).
def oracle_eval(source: str, filename: str) -> PyObj {
    return unmarshal(host_compile_marshal(source, filename, "eval", 0));
}

# Product PyCode from the fully native front end.
def product_eval(source: str, filename: str = "<f>") -> PyObj {
    return compile_source(source, filename, "eval", 0);
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
# that lands -- same carve-out as compiler_slice.assert_matches_oracle.
def assert_matches_oracle(source: str, filename: str = "<f>") {
    actual = product_eval(source, filename);
    assert not is_error(actual);
    assert isinstance(actual, PyCode);
    expected = oracle_eval(source, filename);
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

test "layer8: 1+1 product PyCode matches oracle" {
    assert_matches_oracle("1+1");
}

test "layer8: -x product PyCode matches oracle" {
    assert_matches_oracle("-x");
}

test "layer8: a*b+c product PyCode matches oracle" {
    assert_matches_oracle("a*b+c");
}

test "layer8: f(x,1) product PyCode matches oracle" {
    assert_matches_oracle("f(x,1)");
}

test "layer8: x<y<z product PyCode matches oracle" {
    assert_matches_oracle("x<y<z");
}

# ---------------- VM execution ----------------

test "layer8: 1+1 executes in ceval" {
    co = product_eval("1+1");
    out = exec_code(co as PyCode, [], {});
    assert not is_error(out);
    assert isinstance(out, PyInt);
    assert expect_int(out) == 2;
}

test "layer8: -x executes in ceval" {
    co = product_eval("-x");
    ns: dict[str, PyObj] = {"x": PyInt(t="int", val=7)};
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyInt);
    assert expect_int(out) == -7;
}

test "layer8: a*b+c executes in ceval" {
    co = product_eval("a*b+c");
    ns: dict[str, PyObj] = {
        "a": PyInt(t="int", val=2),
        "b": PyInt(t="int", val=3),
        "c": PyInt(t="int", val=4),

    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyInt);
    assert expect_int(out) == 10;
}

test "layer8: f(x,1) executes in ceval" {
    setup = unmarshal(
        host_compile_marshal(
            "def f(x, y):\n    return x * 10 + y\n", "<setup>", "exec", 0
        )
    );
    ns: dict[str, PyObj] = {};
    setup_out = exec_code(setup, [], ns);
    assert not is_error(setup_out);
    ns["x"] = PyInt(t="int", val=3);
    co = product_eval("f(x,1)");
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyInt);
    assert expect_int(out) == 31;
}

test "layer8: x<y<z executes in ceval (true chain)" {
    co = product_eval("x<y<z");
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=2),
        "z": PyInt(t="int", val=3),

    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyBool);
    assert (out as PyBool).val;
}

test "layer8: x<y<z executes in ceval (short-circuit false)" {
    co = product_eval("x<y<z");
    ns: dict[str, PyObj] = {
        "x": PyInt(t="int", val=1),
        "y": PyInt(t="int", val=5),
        "z": PyInt(t="int", val=3),

    };
    out = exec_code(co as PyCode, [], ns);
    assert not is_error(out);
    assert isinstance(out, PyBool);
    assert not (out as PyBool).val;
}

# ---------------- error paths ----------------

test "layer8: parse error returns SyntaxError PyObj" {
    res = compile_source("1+", "<f>", "eval", 0);
    assert is_error(res);
    assert isinstance(res, PyError);
    assert (res as PyError).exception.type_name == "SyntaxError";
}
