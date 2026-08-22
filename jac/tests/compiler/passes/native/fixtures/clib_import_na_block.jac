"""Test fixture: C library import inside na {} block in a regular .jac file."""

import from "/usr/lib/libm.so.6" {
    def ceil(x: f64) -> f64;  def floor(x: f64) -> f64;
}

def round_up(x: float) -> float {
    return ceil(x);
}
