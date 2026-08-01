"""Cross-module variadic callee for the varargs behavioral suite.

The importer's call site must materialize the pack against this module's
declared native signature (a single List pointer slot).
"""

def lib_sum(*nums: int) -> int {
    acc = 0;
    for n in nums {
        acc += n;
    }
    return acc;
}
