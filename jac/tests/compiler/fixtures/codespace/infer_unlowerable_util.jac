"""Markerless helper whose match uses a pattern the client backend cannot lower.

Only `shape_of` is unlowerable; `scale_by` is plain arithmetic.
"""

def scale_by(n: float) -> float {
    return n * 2.0;
}

def shape_of(v: any) -> str {
    match v {
        case [ x ] | ( x , ):
            return str(x);

        case _:
            return "other";

    }
}
