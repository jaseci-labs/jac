"""Bug regression tests – migrated from tests/language/test_bugs.py."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "impl match confusion issue" {
    mypass = JacProgram();
    mypass.compile(os.path.join(FIXTURES, "impl_match_confused.jac"));
    assert len(mypass.errors_had) == 1;
}
