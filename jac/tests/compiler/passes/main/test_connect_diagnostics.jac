"""Tests for intent-aware error diagnostics on malformed node connection operators.
These tests cover five diagnostic codes:
  E0027 — forward typed connection (+>: Type) missing closing :+>
  E0028 — backward typed connection (<+: Type) missing closing :<+ or :+>
  E0029 — simple ++> used as if it accepts an edge type
  E0035 — simple <++ used as if it accepts an edge type
  E0036 — bare +> is not a valid connection operator
All error-detection tests MUST FAIL until the implementation is complete.
All positive (valid-syntax) tests MUST PASS both before and after implementation.
"""
import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     CONNECT_FIXTURES = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "connect_diagnostics"
     );

"""Compile a Jac source string and return the program object."""
def compile_snippet(source: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(use_str=source, file_path="test.jac");
    return prog;
}

"""Compile a fixture file by name (relative to CONNECT_FIXTURES dir)."""
def compile_fixture(name: str) -> JacProgram {
    prog = JacProgram();
    prog.compile(os.path.join(CONNECT_FIXTURES, name));
    return prog;
}

"""Return True if any error in the program has the given code string."""
def has_error(prog: JacProgram, code: str) -> bool {
    for e in prog.errors_had {
        if e.code is not None and e.code.code == code {
            return True;
        }
    }
    return False;
}

"""Return the total number of errors with the given code string."""
def count_errors(prog: JacProgram, code: str) -> int {
    n = 0;
    for e in prog.errors_had {
        if e.code is not None and e.code.code == code {
            n += 1;
        }
    }
    return n;
}

# ═══════════════════════════════════════════════════════════════════════
# E0027 — forward typed connection missing :+>
#   Pattern:  node1 +>: EdgeType <anything other than :+>
#   Correct:  node1 +>: EdgeType :+> node2
# ═══════════════════════════════════════════════════════════════════════
test "E0027: +>: type followed by identifier instead of :+>" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 +>: Friend n2; }');
    assert has_error(prog, "E0027") , "E0027 must fire when :+> is missing and an identifier follows the edge type";
}

test "E0027: +>: type followed by semicolon instead of :+>" {
    prog = compile_snippet('with entry { n1 = None; n1 +>: Friend; }');
    assert has_error(prog, "E0027") , "E0027 must fire when :+> is missing and a semicolon terminates the statement";
}

test "E0027: +>: type followed by EOF instead of :+>" {
    prog = compile_snippet('with entry { n1 = None; n1 +>: Friend');
    assert has_error(prog, "E0027") , "E0027 must fire when :+> is missing and the source ends unexpectedly";
}

test "E0027: +>: type with colon prefix on node instead of :+>" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 +>: Friend :n2; }');
    assert has_error(prog, "E0027") , "E0027 must fire for n1 +>: Friend :n2 (missing +> after the colon)";
}

test "E0027: E0027 is emitted as the first error" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 +>: Friend n2; }');
    assert has_error(prog, "E0027") , "E0027 must be emitted";
    assert prog.errors_had[0].code.code == "E0027" , "E0027 must be the first error so the developer sees it first";
}

test "E0027: fixture — complex forward connection missing :+>" {
    prog = compile_fixture("connect_forward_missing_close.jac");
    assert has_error(prog, "E0027") , "E0027 must fire in the fixture file for forward typed connection without :+>";
}

# ═══════════════════════════════════════════════════════════════════════
# E0028 — backward typed connection missing :<+ or :+>
#   Pattern:  node1 <+: EdgeType <anything other than :<+ or :+>
#   Correct:  node1 <+: EdgeType :<+ node2   (backward, IN direction)
#             node1 <+: EdgeType :+> node2   (bidirectional, ANY direction)
# ═══════════════════════════════════════════════════════════════════════
test "E0028: <+: type followed by identifier instead of :<+" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 <+: Friend n2; }');
    assert has_error(prog, "E0028") , "E0028 must fire when :<+ is missing and an identifier follows the edge type";
}

test "E0028: <+: type followed by semicolon instead of :<+" {
    prog = compile_snippet('with entry { n1 = None; n1 <+: Friend; }');
    assert has_error(prog, "E0028") , "E0028 must fire when :<+ is missing and a semicolon terminates the statement";
}

test "E0028: E0028 is emitted as the first error" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 <+: Friend n2; }');
    assert has_error(prog, "E0028") , "E0028 must be emitted";
    assert prog.errors_had[0].code.code == "E0028" , "E0028 must be the first error so the developer sees it first";
}

test "E0028: fixture — complex backward connection missing :<+" {
    prog = compile_fixture("connect_backward_missing_close.jac");
    assert has_error(prog, "E0028") , "E0028 must fire in the fixture file for backward typed connection without :<+";
}

# ═══════════════════════════════════════════════════════════════════════
# E0029 — ++> used as if it takes an edge type
#   Pattern:  node1 ++> EdgeType node2
#   Correct:  node1 ++> node2          (simple, no type)
#             node1 +>: EdgeType :+> node2  (typed form)
# ═══════════════════════════════════════════════════════════════════════
test "E0029: ++> followed by edge type name and right node" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 ++> Friend n2; }');
    assert has_error(prog, "E0029") , "E0029 must fire when ++> is followed by an edge type name (use +>: EdgeType :+> instead)";
}

test "E0029: fixture — ++> with edge type" {
    prog = compile_fixture("connect_simple_op_with_type.jac");
    assert has_error(prog, "E0029") , "E0029 must fire in the fixture file for ++> used with an edge type";
}

test "E0029: E0029 is emitted as the first error" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 ++> Friend n2; }');
    assert has_error(prog, "E0029") , "E0029 must be emitted";
    assert prog.errors_had[0].code.code == "E0029" , "E0029 must be the first error so the developer sees it first";
}

# ═══════════════════════════════════════════════════════════════════════
# E0035 — <++ used as if it takes an edge type
#   Pattern:  node1 <++ EdgeType node2
#   Correct:  node1 <++ node2          (simple, no type)
#             node1 <+: EdgeType :<+ node2  (typed form)
# ═══════════════════════════════════════════════════════════════════════
test "E0035: <++ followed by edge type name and right node" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 <++ Friend n2; }');
    assert has_error(prog, "E0035") , "E0035 must fire when <++ is followed by an edge type name (use <+: EdgeType :<+ instead)";
}

test "E0035: fixture — <++ with edge type" {
    prog = compile_fixture("connect_backward_simple_op_with_type.jac");
    assert has_error(prog, "E0035") , "E0035 must fire in the fixture file for <++ used with an edge type";
}

test "E0035: E0035 is emitted as the first error" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 <++ Friend n2; }');
    assert has_error(prog, "E0035") , "E0035 must be emitted";
    assert prog.errors_had[0].code.code == "E0035" , "E0035 must be the first error so the developer sees it first";
}

# ═══════════════════════════════════════════════════════════════════════
# E0036 — +> alone is not a valid connection operator
#   Pattern:  node1 +> node2
#   Correct:  node1 ++> node2   (simple forward connection)
# ═══════════════════════════════════════════════════════════════════════
test "E0036: +> used instead of ++>" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 +> n2; }');
    assert has_error(prog, "E0036") , "E0036 must fire when +> is used instead of ++>";
}

test "E0036: E0036 is emitted as the first error" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 +> n2; }');
    assert has_error(prog, "E0036") , "E0036 must be emitted";
    assert prog.errors_had[0].code.code == "E0036" , "E0036 must be the first error so the developer sees it first";
}

# ═══════════════════════════════════════════════════════════════════════
# POSITIVE TESTS — valid syntax that must NOT trigger any of the new codes.
# These must PASS both before and after implementation.
# ═══════════════════════════════════════════════════════════════════════
test "valid: simple ++> connection between two nodes" {
    prog = compile_snippet('node N {} with entry { n1 = N(); n2 = N(); n1 ++> n2; }');
    assert not has_error(prog, "E0027") , "++> without type must not trigger E0027";
    assert not has_error(prog, "E0029") , "++> without type must not trigger E0029";
}

test "valid: simple <++ connection between two nodes" {
    prog = compile_snippet('node N {} with entry { n1 = N(); n2 = N(); n1 <++ n2; }');
    assert not has_error(prog, "E0028") , "<++ without type must not trigger E0028";
    assert not has_error(prog, "E0035") , "<++ without type must not trigger E0035";
}

test "valid: bidirectional <++> connection" {
    prog = compile_snippet('node N {} with entry { n1 = N(); n2 = N(); n1 <++> n2; }');
    assert not has_error(prog, "E0027") , "<++> must not trigger E0027";
    assert not has_error(prog, "E0028") , "<++> must not trigger E0028";
    assert not has_error(prog, "E0029") , "<++> must not trigger E0029";
    assert not has_error(prog, "E0035") , "<++> must not trigger E0035";
}

test "valid: complete forward typed connection +>: EdgeType :+>" {
    prog = compile_snippet(
        'node N {} edge F {} with entry { n1 = N(); n2 = N(); n1 +>: F :+> n2; }'
    );
    assert not has_error(prog, "E0027") , "Complete +>: F :+> must not trigger E0027";
}

test "valid: complete backward typed connection <+: EdgeType :<+" {
    prog = compile_snippet(
        'node N {} edge F {} with entry { n1 = N(); n2 = N(); n1 <+: F :<+ n2; }'
    );
    assert not has_error(prog, "E0028") , "Complete <+: F :<+ must not trigger E0028";
}

test "valid: bidirectional typed connection <+: EdgeType :+>" {
    prog = compile_snippet(
        'node N {} edge F {} with entry { n1 = N(); n2 = N(); n1 <+: F :+> n2; }'
    );
    assert not has_error(prog, "E0027") , "<+: F :+> must not trigger E0027";
    assert not has_error(prog, "E0028") , "<+: F :+> must not trigger E0028";
}

test "valid: typed connection with no spaces" {
    prog = compile_snippet(
        'node N {} edge F {} with entry { n1=N(); n2=N(); n1+>:F:+>n2; }'
    );
    assert not has_error(prog, "E0027") , "Compact n1+>:F:+>n2 (no spaces) must not trigger E0027";
}

test "valid: typed connection with field assignment" {
    prog = compile_snippet(
        'node N {} edge F { has w: int = 0; } with entry { n1=N(); n2=N(); n1 +>: F(w=5) :+> n2; }'
    );
    assert not has_error(prog, "E0027") , "Typed connection with field assignment must not trigger E0027";
}

test "valid: ++> where right-hand node is a function call" {
    prog = compile_snippet(
        'node N {} def get_n() -> N { return N(); } with entry { n1 = N(); n1 ++> get_n(); }'
    );
    assert not has_error(prog, "E0029") , "++> get_n() must not trigger E0029 (NAME LPAREN is a valid node expression)";
}

test "valid: ++> where right-hand node is an attribute access" {
    prog = compile_snippet(
        'node N { has child: N = N(); } with entry { n1 = N(); n2 = N(); n1 ++> n2.child; }'
    );
    assert not has_error(prog, "E0029") , "++> obj.attr must not trigger E0029 (NAME DOT is a valid node expression)";
}

test "valid: <++ where right-hand node is a function call" {
    prog = compile_snippet(
        'node N {} def get_n() -> N { return N(); } with entry { n1 = N(); n1 <++ get_n(); }'
    );
    assert not has_error(prog, "E0035") , "<++ get_n() must not trigger E0035 (NAME LPAREN is a valid node expression)";
}

test "valid: <++ where right-hand node is an attribute access" {
    prog = compile_snippet(
        'node N { has child: N = N(); } with entry { n1 = N(); n2 = N(); n1 <++ n2.child; }'
    );
    assert not has_error(prog, "E0035") , "<++ obj.attr must not trigger E0035 (NAME DOT is a valid node expression)";
}
