# Literal-frontier differential tests (band-11 follow-up to the float-literal
# parser bug): full source -> parse -> codegen -> assemble vs the host oracle,
# recursively over nested code objects.
#
# Why this file exists: layer0/layer1 replay and p2/p3 probes feed HOST-compiled
# bytecode to jacpython's ceval, so parser bugs in literal lowering never reach
# them. These tests exercise OUR parser on real source text for every literal
# spelling family.
#
# Self-contained by design: importing compiler_slice / compiler_validate /
# compiler_symtable / pyc_first here would pull their test blocks into this
# file's collection graph. compile_source is the production entrypoint.
#
# Test harness only: may import host_oracle for expected PyCode bytes.

import from objects { PyObj, PyCode, PyInt, PyFloat, PyComplex, is_error }
import from product_compile { compile_source }
import from parser { parse_eval_expr }
import from ast_nodes { Constant }
import from host_oracle { host_compile_marshal }
import from marshal_reader { unmarshal }
import from ceval { to_host }

def oracle_source_exec(source: str) -> PyCode {
    o = unmarshal(host_compile_marshal(source, "<literals>", "exec", 0));
    assert isinstance(o, PyCode);
    return o as PyCode;
}

def compile_literal_source(source: str) -> PyCode {
    co = compile_source(source, "<literals>", "exec", 0);
    assert not is_error(co);
    assert isinstance(co, PyCode);
    return co as PyCode;
}

# PyObj equality is identity-based by design (ce3b042e9), so consts are
# compared through their host representations.
def const_leaf_equal(a: PyObj, b: PyObj) -> bool {
    return (to_host(a) == to_host(b)) as bool;
}

# Deep byte-exact comparison of a PyCode tree: co_code plus every nested code
# object reachable through consts (function bodies, lambdas, comprehensions).
def assert_code_tree_matches(actual: PyCode, expected: PyCode, label: str) {
    assert actual.co_code == expected.co_code, (
        label + ": co_code mismatch"
    );
    assert len(actual.consts) == len(expected.consts), (
        label + ": const table size " + str(len(actual.consts))
        + " vs " + str(len(expected.consts))
    );
    ai = 0;
    while ai < len(actual.consts) {
        av = actual.consts[ai];
        ev = expected.consts[ai];
        if isinstance(av, PyCode) {
            assert isinstance(ev, PyCode), (
                label + ": const " + str(ai) + " code-vs-noncode"
            );
            assert_code_tree_matches(
                av as PyCode, ev as PyCode, label + "/const" + str(ai)
            );
        } else {
            assert const_leaf_equal(av, ev), (
                label + ": const " + str(ai) + " value mismatch"
            );
        }
        ai = ai + 1;
    }
}

def assert_literal_parity(source: str, label: str) {
    actual = compile_literal_source(source);
    expected = oracle_source_exec(source);
    assert_code_tree_matches(actual, expected, label);
}

# ---------------- int spellings ----------------

test "literal frontier: small int matches oracle" {
    assert_literal_parity("x = 5\n", "small-int");
}

test "literal frontier: int > 255 matches oracle" {
    assert_literal_parity("x = 300\n", "int-gt255");
}

test "literal frontier: underscore int spelling matches oracle" {
    assert_literal_parity("x = 1_000\n", "int-underscore");
}

# ---------------- str/bool/None spellings ----------------

test "literal frontier: str literal matches oracle" {
    assert_literal_parity("s = 'abc'\n", "str");
}

test "literal frontier: bool and None match oracle" {
    assert_literal_parity("t = True\nf = False\nn = None\n", "bool-none");
}

# ---------------- function-body literals (nested code objects) ----------------

test "literal frontier: int literals in function body match oracle recursively" {
    assert_literal_parity(
        "def f():\n    a = 7\n    b = 900\n    return a + b\n",
        "fn-int-literals"
    );
}

# ---------------- number spelling parsing ----------------
#
# pa_number_from_token routes every NUMBER token through
# pa_py_number_from_spelling (parser_actions.jac): base-prefixed ints
# (0x/0o/0b, underscores stripped), floats ('.' or exponent marker), and
# imaginary literals (trailing j/J) -> PyComplex(0, imag).

test "number spelling: float literal parses to PyFloat" {
    e = parse_eval_expr("1.5", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyFloat);
    assert (c.value as PyFloat).val == 1.5;
}

test "number spelling: hex spelling parses to exact int" {
    e = parse_eval_expr("0xFF", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyInt);
    assert (c.value as PyInt).val == 255;
}

test "number spelling: octal spelling parses to exact int" {
    e = parse_eval_expr("0o17", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyInt);
    assert (c.value as PyInt).val == 15;
}

test "number spelling: binary spelling parses to exact int" {
    e = parse_eval_expr("0b1011", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyInt);
    assert (c.value as PyInt).val == 11;
}

test "number spelling: underscores stripped from int literal" {
    e = parse_eval_expr("10_000", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyInt);
    assert (c.value as PyInt).val == 10000;
}

test "number spelling: exponent form parses to PyFloat" {
    e = parse_eval_expr("1e-3", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyFloat);
    assert (c.value as PyFloat).val == 0.001;
}

test "number spelling: imaginary j suffix parses to pure PyComplex" {
    e = parse_eval_expr("1j", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyComplex);
    z = c.value as PyComplex;
    assert z.real == 0.0;
    assert z.imag == 1.0;
}

test "number spelling: fractional imaginary parses to PyComplex" {
    e = parse_eval_expr("0.5j", "<num>");
    assert isinstance(e, Constant);
    c = e as Constant;
    assert isinstance(c.value, PyComplex);
    z = c.value as PyComplex;
    assert z.real == 0.0;
    assert z.imag == 0.5;
}
