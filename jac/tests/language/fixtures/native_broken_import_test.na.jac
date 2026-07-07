"""Native-codespace (.na.jac) test file that fails to import.

Its import references a module that does not exist, so the imported symbol
cannot be lowered and native codegen errors; the error gate (issue #7239)
then withholds the module's artifacts and the import raises with the
compiler diagnostics. The collector must surface this as a collection error
rather than swallowing it into an empty (silently passing) result (issue
#7150).
"""

import from jaclang.this_module_does_not_exist_7150 { nope }

test "unreachable" {
    assert nope() == 1;
}
