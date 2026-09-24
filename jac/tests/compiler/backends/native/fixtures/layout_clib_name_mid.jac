"""Calls the library's `sqrt`; lowered after the library in a cold build."""
import from layout_clib_name_lib { sqrt }

def:pub hyp(a: float, b: float) -> float {
    return sqrt(a * a + b * b);
}
