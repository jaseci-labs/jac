"""Fixture for a Jac `def` colliding with a clib extern of the same name.

`import from c { getpid }` declares the libc extern in this module's LLVM
module; a local `def getpid` used to trip a duplicate-symbol error (or be
shadowed by the extern in the bare-name symtab). The Jac def is emitted
under a module-mangled symbol instead, and unqualified calls bind it.
"""

import from c { def getpid() -> i32;  }


def getpid -> int {
    return 4242;
}


def:pub call_local -> int {
    return getpid();
}
