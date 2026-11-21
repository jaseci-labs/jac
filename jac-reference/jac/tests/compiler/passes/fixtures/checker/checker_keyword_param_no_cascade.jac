"""Fixture for #6353 gap #3.

Using a Jac keyword (`by`) as a parameter name must report the keyword error
(E0013) once and must NOT cascade into spurious "too many positional arguments"
(E1051) at the call site. The parser keeps the offending parameter for error
recovery so the signature arity stays correct.
"""

def quad(ax: float, ay: float, az: float, bx: float, by: float, bz: float,
         cx: float, cy: float, cz: float, dx: float, dy: float, dz: float) -> float {
    return ax;
}

with entry {
    print(quad(1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0));
}
