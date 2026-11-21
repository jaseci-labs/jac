"""Middle module for mixed transitive-duplicate link test.

Imports get_foo from fix_mixed_dup_lib_a and defines its own get_bar.
Its cached IR carries get_foo as a definition; link_in must not drop bar
when A was already linked into the entry module.
"""

import from fix_mixed_dup_lib_a { get_foo }

def:pub get_bar() -> int {
    return 42;
}

def:pub call_foo() -> int {
    return get_foo();
}
