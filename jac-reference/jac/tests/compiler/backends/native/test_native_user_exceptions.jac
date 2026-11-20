"""User exception classes on the native backend match the Python backend.

`raise ConfigError("m")` for a class with no fields used to raise the bare
message, and the handler then read that string as the class's object, so
`str(e)` printed an object repr. Handlers matched on the raised class's id
only, so `except Base` missed a user subclass, both within a module and across
an import (the sqlite3 bundle's `except sqlite3.ProgrammingError` shape).
Every assertion compares the native binary's stdout with the Python
backend's for the same fixture.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "user exceptions carry their message and are caught through their bases" {
    out = assert_native_identity(os.path.join(FIXTURES, "user_exceptions.jac"));
    assert "base: config 2\n" in out , f"got {out!r}";
    assert "cross base: Error binding parameter 2\n" in out , f"got {out!r}";
}

# Nogc builds carry no allocation header to read an object's class from, so a
# subclass raised through a base-typed value is matched on the rc and managed
# profiles, where the runtime class-name check is available.
test "a subclass raised through a base-typed value is caught by its own handler" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "user_exceptions_dynamic.jac"),
        profiles=["rc", "managed"]
    );
    assert out.startswith("dynamic: picked\n") , f"got {out!r}";
}
