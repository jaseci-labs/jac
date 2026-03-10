"""Bug regression tests – migrated from tests/language/test_bugs.py."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         str(Path(jaclang.__file__).parent.parent), "tests", "language", "fixtures"
     );

test "impl match confusion issue" {
    mypass = JacProgram();
    mypass.compile(os.path.join(FIXTURES, "impl_match_confused.jac"));
    assert len(mypass.errors_had) == 1;
}
