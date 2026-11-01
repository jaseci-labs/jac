"""Bug regression tests – migrated from tests/language/test_bugs.py."""

import os;
import from tests.support { JAC_ROOT, error_codes, kernel_check_file }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures");

test "impl match confusion issue" {
    codes = error_codes(
        kernel_check_file(os.path.join(FIXTURES, "impl_match_confused.jac"))
    );
    assert codes.count("E2009") == 1 , codes;
}
