"""Glob-return ownership test (issue #7320 Cluster 1, items 1d/1e).

A def that returns an imported glob (heap string or list cache) must hand
the caller its own +1 reference. Before the fix the return transferred the
glob's only reference, so the caller's release freed the module global:
the second scan saw a dead list (len 0 / garbage) and the second app_name
read freed memory.

Each def:pub below encodes first-use and second-use results into one i64
so the ctypes harness can assert both in a single call.
"""

import from rc_glob_return_lib { app_name, cmd_defs }

def:pub scan_total -> int {
    total = 0;
    for c in cmd_defs() {
        total += len(c);
    }
    return total;
}

def:pub scan_twice -> int {
    # help+quit+model = 4+4+5 = 13 per scan; expect 13013.
    a = scan_total();
    b = scan_total();
    return a * 1000 + b;
}

def:pub name_len_twice -> int {
    # len("jactui") = 6 per read; expect 6006.
    a = len(app_name());
    b = len(app_name());
    return a * 1000 + b;
}

def:pub defs_len_inline -> int {
    # The accessor called inline inside len() twice; expect 3003.
    return len(cmd_defs()) * 1000 + len(cmd_defs());
}
# Empty entry block so jac_entry() is emitted; tests call it first to run
# __jac_glob_init for this module and the imported lib.
with entry {
    scan_total();
}
