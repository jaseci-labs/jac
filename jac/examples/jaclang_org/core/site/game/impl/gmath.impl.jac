impl jcos(a: float) -> float {
    while a > PI {
        a -= TWO_PI;
    }
    while a < -PI {
        a += TWO_PI;
    }
    x2 = a * a;
    x4 = x2 * x2;
    x6 = x4 * x2;
    x8 = x4 * x4;
    x10 = x8 * x2;
    x12 = x8 * x4;
    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0
        + x12 / 479001600.0;
}

impl jsqrt(v: float) -> float {
    if v <= 0.0 {
        return 0.0;
    }
    guess = v if v > 1.0 else 1.0;
    i = 0;
    while i < 9 {
        guess = 0.5 * (guess + v / guess);
        i += 1;
    }
    return guess;
}

impl clampf(v: float, lo: float, hi: float) -> float {
    if v < lo {
        return lo;
    }
    if v > hi {
        return hi;
    }
    return v;
}

impl rand01(r: &mut Rng) -> float {
    r.state = (r.state * 1103515245 + 12345) % 2147483648;
    return float(r.state) / 2147483648.0;
}
