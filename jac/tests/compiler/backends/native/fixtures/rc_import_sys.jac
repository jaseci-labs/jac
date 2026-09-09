"""`import sys` + a non-default gc mode is the filed repro for issue #7466
bug 3: sys.argv materializes a heap-element (str) list whose release helper
tripped the duplicate __rc_debug emission under --memory rc / plain --memory nogc."""

import sys;

def argc_minus_one -> int {
    return len(sys.argv) - 1;
}
