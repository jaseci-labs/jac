"""Native math utilities - a .na.jac module for cross-module native imports.

This module is imported by na_py_interop_multi.jac to test NATIVE→NATIVE linking.
All functions here compile to native LLVM IR.
"""

# Triple a value - used as a module-level native import
def:pub triple(x: int) -> int {
    return x * 3;
}

# Square a value - also exported for testing
def:pub square(x: int) -> int {
    return x * x;
}
