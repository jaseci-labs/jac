"""C functions defined in Jac that take and return a struct by value."""

import from c {
    obj pair_value {
        has real: f64 = 0.0,
            imag: f64 = 0.0;
    }  obj wide_value {
        has a: i64 = 0,
            b: i64 = 0,
            c: i64 = 0;
    }  def make_pair(real: f64, imag: f64) -> pair_value {
        return pair_value(real=real, imag=imag);
    }  def pair_sum(value: pair_value) -> f64 {
        return value.real + value.imag;
    }  def make_wide(seed: i64) -> wide_value {
        return wide_value(a=seed, b=seed * 2, c=seed * 3);
    }
}
