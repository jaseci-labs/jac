"""Regression fixture for issue #6688: `os.getenv(key, default)` must return
`default` when the variable is UNSET, not a NULL pointer.

The native lowering of `os.getenv` ignored the default argument and returned
NULL for an unset variable. Any downstream string use of that NULL -- `len`,
`+`, `!=` -- then `strlen`'d a NULL pointer and segfaulted. In the quakepassion
native engine this surfaced as a startup crash on `os.getenv("QP_SMOKE", "")
!= ""` whenever `QP_SMOKE` was unset (i.e. the normal `./main` run), which was
misread as a per-frame render-loop use-after-free.

`GETENV_UNSET_6688` is never set in the test environment, so `getenv` returns
NULL and the default must be substituted. Returns the default's length (8 for
"fallback", 0 for ""); before the fix these calls segfaulted on `strlen(NULL)`."""

import os;

def getenv_unset_string_default() -> int {
    v = os.getenv("GETENV_UNSET_6688", "fallback");
    return len(v);
}

def getenv_unset_empty_default() -> int {
    v = os.getenv("GETENV_UNSET_6688", "");
    return len(v);
}

def getenv_unset_concat() -> int {
    # Mirrors the quakepassion `"area: " + cur_name` style use of the result.
    v = os.getenv("GETENV_UNSET_6688", "abc");
    line = "x:" + v;
    return len(line);
}
