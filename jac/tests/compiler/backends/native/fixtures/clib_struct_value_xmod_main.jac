"""Calls another module's by-value struct C functions through their C ABI."""

import from clib_struct_value_xmod_lib { make_pair, make_wide, pair_sum }

with entry {
    p = make_pair(1.5, 2.5);
    print("pair", p.real, p.imag, pair_sum(p));
    w = make_wide(7);
    print("wide", w.a, w.b, w.c);
}
