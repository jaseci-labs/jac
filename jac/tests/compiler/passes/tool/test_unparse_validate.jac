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
