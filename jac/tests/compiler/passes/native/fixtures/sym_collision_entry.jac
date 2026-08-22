"""Entry fixture for symbol-collision detection regression test.

Imports fn_a / collision_fn from sym_collision_lib_a, and fn_b from
sym_collision_lib_b.  Both lib_a and lib_b define `collision_fn` with
external LLVM linkage.  When the native compiler links lib_b it must
detect that `collision_fn` is already defined (from lib_a) and emit E5026
rather than calling link_in() and producing a silent SIGSEGV binary.
"""

import from sym_collision_lib_a { fn_a, collision_fn }
import from sym_collision_lib_b { fn_b }

with entry {
    print(fn_a());
    print(fn_b());
}
