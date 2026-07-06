"""Native-codespace (.na.jac) test file that fails to import.

Its import references a module that does not exist, so importing the test
module raises. The collector must surface this as a collection error rather
than swallowing it into an empty (silently passing) result (issue #7150).
"""

import from jaclang.this_module_does_not_exist_7150 { nope }

test "unreachable" {
    assert nope() == 1;
}
