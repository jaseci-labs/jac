"""Leaf module for transitive-import fix test (FIX 1).

This module is imported by fix_transitive_mid, which is in turn imported by
fix_transitive_entry.  Before the fix the linker only walked direct imports
and never linked this module into the JIT, causing unresolved symbols.
"""

def:pub get_leaf() -> int {
    return 99;
}
