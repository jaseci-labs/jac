"""`__file__` lowers natively to the module's source path.

A native module is compiled from one source file, so `__file__` is that file's
real path, known at compile time, the way C's `__FILE__` is. It used to demote
every function that read it (and a module entry that printed it) to Python.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "__file__ names the module's source under every memory profile" {
    assert_native_identity(os.path.join(FIXTURES, "dunder_file.jac"));
}
