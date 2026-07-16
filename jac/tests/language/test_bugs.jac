"""Bug regression tests – migrated from tests/language/test_bugs.py."""

import io;
import os;
import sys;
import from tests.support { JAC_ROOT }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.runtime { JacRuntime }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "impl match confusion issue" {
    mypass = JacProgram();
    mypass.compile(os.path.join(FIXTURES, "impl_match_confused.jac"));
    assert len(mypass.errors_had) == 1;
}

test "backticked root entry trigger executes at runtime" {
    old_stdout = sys.stdout;
    buf = io.StringIO();
    sys.stdout = buf;
    try {
        JacRuntime.jac_import(
            target="backtick_root_trigger", base_path=FIXTURES, override_name="__main__"
        );
    } finally {
        sys.stdout = old_stdout;
    }
    assert "['hit']" in buf.getvalue();
}
