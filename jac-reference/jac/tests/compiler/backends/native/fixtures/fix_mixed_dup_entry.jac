"""Entry for mixed transitive-duplicate link test.

Imports A before B so get_foo is in symbol_origins when B is linked.
B carries a transitive get_foo definition plus unique get_bar — the linker
must demote the duplicate and still link bar.
"""

import from fix_mixed_dup_lib_a { get_foo }
import from fix_mixed_dup_lib_b { get_bar, call_foo }

def:pub run_mixed_dup_test() -> int {
    return get_foo() + get_bar() + call_foo();
}

with entry {}
