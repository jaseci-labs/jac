"""Native transformers - another .na.jac module for cross-module native imports.

This module is imported INSIDE an na {} block to test scoped native imports.
All functions here compile to native LLVM IR.
"""

# Add ten to a value - used inside native_add_one_to_doubled
def:pub add_ten(x: int) -> int {
    return x + 10;
}

# Negate a value - also exported for testing
def:pub negate(x: int) -> int {
    return 0 - x;
}
