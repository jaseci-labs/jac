"""Regression fixture (#7850, #7871 D): __float_bits / __bits_float lower as
registry intrinsics even with user stub declarations in scope; the colliding
stubs draw W6008 warnings.  The stub bodies return deliberately wrong values
(0 / 0.0), so a caller that reaches them instead of the intrinsic produces
results every test assertion can distinguish."""

def __float_bits(f: f64) -> i64 {
    return 0;
}

def __bits_float(b: i64) -> f64 {
    return 0.0;
}

def bits_of(x: f64) -> i64 {
    return __float_bits(x);
}

def float_of(b: i64) -> f64 {
    return __bits_float(b);
}

def round_trip(x: f64) -> f64 {
    return __bits_float(__float_bits(x));
}

def bits_round_trip(b: i64) -> i64 {
    return __float_bits(__bits_float(b));
}
