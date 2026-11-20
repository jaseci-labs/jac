"""Binds libm's `sqrt`, as the bundled `_math_native` does for `math`."""
import from m { def sqrt(x: f64) -> f64;  }

def:pub c_sqrt(x: float) -> float {
    return sqrt(f64(x));
}
