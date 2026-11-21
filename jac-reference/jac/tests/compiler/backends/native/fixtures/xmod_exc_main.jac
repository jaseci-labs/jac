"""Catches a cross-module OSError raised in xmod_exc_raiser (issue #7013).

A `raise` in the imported module must unwind to this module's `try`/`except`
handler. The fix shares the exception handler stack (`@__jac_current_handler`,
now `weak` linkage) and gives every module the same stable exception type ID
for a given name, so the `longjmp`-based dispatch matches across the boundary.

Prints `XMOD_CAUGHT` from the handler and `DONE_OK` after the block, then exits
cleanly. Pre-fix the process aborts before either marker is printed.
"""

import from xmod_exc_raiser { do_raise }

with entry {
    try {
        v = do_raise(-3);
        print("NO_RAISE", v);
    } except OSError as e {
        print("XMOD_CAUGHT");
    }
    print("DONE_OK");
}
