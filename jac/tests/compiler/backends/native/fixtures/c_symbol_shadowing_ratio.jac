"""A user `floor(float) -> float` beside the backend's own libm `floor`.

`float.as_integer_ratio` lowers to a loop over libm `floor`. With the user
definition emitted as plain `floor`, the backend's extern lookup bound to
it instead, so the loop ran on the user's arithmetic: this identity `floor`
ends it at once with the wrong ratio, a constant one never ends it.
"""

def floor(x: float) -> float {
    return x;
}

def ratio_probe -> int {
    x = 2.5;
    (numerator, denominator) = x.as_integer_ratio();
    return numerator * 10 + denominator;
}

def user_floor_probe -> float {
    return floor(1.5);
}
