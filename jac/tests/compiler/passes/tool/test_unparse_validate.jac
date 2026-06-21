"""Unparse validation tests – migrated from test_unparse_validate.py.

Tests that Jac files can be unparsed consistently.
Parametrized roundtrip tests are in tests/compiler/test_micro_suite.jac.
"""

import os;
import from difflib { unified_diff }
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob LANG_FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "double unparse" {
    code_gen_pure = JacProgram().compile(os.path.join(LANG_FIXTURES, "circle.jac"));
    x = code_gen_pure.unparse();
    y = code_gen_pure.unparse();
    assert x == y , "Double unparse produced different results:\n" + "\n".join(
        unified_diff(x.splitlines(), y.splitlines())
    );
}

test "filter compr unparses to bracket syntax" {
    code_gen = JacProgram().compile(
        use_str='with entry { x(?:Foo, a==5); }', file_path="t.jac"
    );
    unparsed = code_gen.unparse();
    assert "[?" in unparsed , "Old (?:...) should unparse as [?:...] but got: " + unparsed;
    assert "(?" not in unparsed , "Old (?:...) syntax should not appear in unparsed output: " + unparsed;
}

test "bracket filter unparse roundtrip" {
    code_gen = JacProgram().compile(
        use_str='with entry { x[?:Foo, a==5]; }', file_path="t.jac"
    );
    first = code_gen.unparse();
    code_gen2 = JacProgram().compile(use_str=first, file_path="t.jac");
    second = code_gen2.unparse();
    assert first == second , "Bracket filter unparse roundtrip failed:\n" + "\n".join(
        unified_diff(first.splitlines(), second.splitlines())
    );
}

test "typed enum base unparse roundtrip" {
    # `enum X: T { ... }` shorthand must round-trip through unparse.
    src = "enum Color: int { RED=0, GREEN=1 } enum Tag: str { OPEN='open' }";
    first = JacProgram().compile(use_str=src, file_path="t.jac").unparse();
    second = JacProgram().compile(use_str=first, file_path="t.jac").unparse();
    assert first == second , "Typed enum unparse roundtrip failed:\n" + "\n".join(
        unified_diff(first.splitlines(), second.splitlines())
    );
    assert ": int" in first , (
        "Unparse should emit the `: T` shorthand, not the parenthesized "
        "form; got:\n" + first
    );
    assert ": str" in first , (
        "Unparse should emit the `: str` shorthand; got:\n" + first
    );
}
