"""Unparse validation tests – migrated from test_unparse_validate.py.

Tests that Jac files can be unparsed consistently.
Parametrized roundtrip tests are in tests/compiler/test_micro_suite.jac.
"""

import os;
import from difflib { unified_diff }
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob EXAMPLES = os.path.join(str(Path(jaclang.__file__).parent.parent), "examples");

test "double unparse" {
    code_gen_pure = JacProgram().compile(
        os.path.join(EXAMPLES, "manual_code", "circle.jac")
    );
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
