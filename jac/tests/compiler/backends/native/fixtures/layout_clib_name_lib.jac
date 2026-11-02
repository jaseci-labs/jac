"""Defines its own `sqrt` while importing a module that binds C's `sqrt`.

The shape of the bundled `math` over `_math_native`: the unit sees the
imported module's C extern named `sqrt` and must still publish its own
`sqrt` in its native layout.
"""
import from layout_clib_name_ffi { c_sqrt }

def:pub sqrt(x: float) -> float {
    return c_sqrt(x) + 0.0;
}
