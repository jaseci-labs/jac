"""Bug regression tests – migrated from tests/language/test_bugs.py."""

import os;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "impl match confusion issue" {
    mypass = JacProgram();
    mypass.compile(os.path.join(FIXTURES, "impl_match_confused.jac"));
    codes = [
        e.code.code
        for e in mypass.errors_had
        if e.code is not None
    ];
    assert codes.count("E2009") == 1 , codes;
}
