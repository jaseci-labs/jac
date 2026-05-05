"""Tests for intent-aware error diagnostics on malformed node connection operators.
These tests cover two diagnostic codes:
  E0027 — forward typed connection (+>: Type) missing closing :+>
  E0028 — backward typed connection (<+: Type) missing closing :<+ or :+>
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

test "E0028: <+: type followed by EOF instead of :<+" {
    prog = compile_snippet('with entry { n1 = None; n1 <+: Friend');
    assert has_error(prog, "E0028") , "E0028 must fire when :<+ is missing and the source ends unexpectedly";
}

test "E0028: E0028 is emitted as the first error" {
    prog = compile_snippet('with entry { n1 = None; n2 = None; n1 <+: Friend n2; }');
    assert prog.errors_had[0].code.code == "E0028" , "E0028 must be the first error so the developer sees it first";
}

test "E0028: fixture — complex backward connection missing :<+" {
    prog = compile_fixture("connect_backward_missing_close.jac");
    assert has_error(prog, "E0028") , "E0028 must fire in the fixture file for backward typed connection without :<+";
}

# ═══════════════════════════════════════════════════════════════════════
# POSITIVE TESTS — valid syntax that must NOT trigger any of the new codes.
# These must PASS both before and after implementation.
# ═══════════════════════════════════════════════════════════════════════
test "valid: simple ++> connection between two nodes" {
    prog = compile_snippet('node N {} with entry { n1 = N(); n2 = N(); n1 ++> n2; }');
    assert not has_error(prog, "E0027") , "++> without type must not trigger E0027";
}

test "valid: simple <++ connection between two nodes" {
    prog = compile_snippet('node N {} with entry { n1 = N(); n2 = N(); n1 <++ n2; }');
    assert not has_error(prog, "E0028") , "<++ without type must not trigger E0028";
}

test "valid: bidirectional <++> connection" {
    prog = compile_snippet('node N {} with entry { n1 = N(); n2 = N(); n1 <++> n2; }');
    assert not has_error(prog, "E0027") , "<++> must not trigger E0027";
    assert not has_error(prog, "E0028") , "<++> must not trigger E0028";
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
    assert not prog.errors_had , "++> get_n() must parse cleanly";
}

test "valid: ++> where right-hand node is an attribute access" {
    prog = compile_snippet(
        'node N { has child: N = N(); } with entry { n1 = N(); n2 = N(); n1 ++> n2.child; }'
    );
    assert not prog.errors_had , "++> obj.attr must parse cleanly";
}

test "valid: <++ where right-hand node is a function call" {
    prog = compile_snippet(
        'node N {} def get_n() -> N { return N(); } with entry { n1 = N(); n1 <++ get_n(); }'
    );
    assert not prog.errors_had , "<++ get_n() must parse cleanly";
}

test "valid: <++ where right-hand node is an attribute access" {
    prog = compile_snippet(
        'node N { has child: N = N(); } with entry { n1 = N(); n2 = N(); n1 <++ n2.child; }'
    );
    assert not prog.errors_had , "<++ obj.attr must parse cleanly";
}
