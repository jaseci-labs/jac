"""Leaf module for mixed transitive-duplicate link test.

Defines get_foo. fix_mixed_dup_lib_b imports this and also defines get_bar.
When the entry imports both A and B, B's IR carries get_foo transitively
but must still link get_bar after A is linked first.
"""

def:pub get_foo() -> int {
    return 10;
}
