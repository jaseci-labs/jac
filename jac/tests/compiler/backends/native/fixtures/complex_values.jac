"""Complex numbers as native values: construction, parts, arithmetic, the
Annex G recovery of infinite products and quotients, and the bundled cmath."""

import cmath;

def show(label: str, z: complex) {
    print(label, z.real, z.imag);
}

def scaled(z: complex, k: float) -> complex {
    return z * k;
}

def maybe(z: (complex | None) = None) -> float {
    if z is None {
        return -1.0;
    }
    return z.real + z.imag;
}

with entry {
    a = complex(1.5, -2.0);
    b = complex(3.0, 4.0);
    show("make", a);
    show("one", complex(2.0));
    show("zero", complex());
    show("add", a + b);
    show("sub", a - b);
    show("mul", a * b);
    show("div", a / b);
    show("radd", 2.0 + a);
    show("rsub", 2.0 - a);
    show("rmul", 2 * a);
    show("rdiv", 2.0 / b);
    show("divr", a / 2.0);
    show("neg", -a);
    show("scaled", scaled(b, 0.5));
    print("eq", a == complex(1.5, -2.0), a != b, complex(2.0, 0.0) == 2.0);
    print("truth", bool(complex()), bool(a));
    print("opt", maybe(), maybe(b));
    inf = float("inf");
    show("inf mul", complex(inf, 0.0) * complex(0.0, 1.0));
    show("inf div", complex(inf, inf) / complex(1.0, 2.0));
    show("div inf", complex(1.0, 2.0) / complex(inf, 0.0));
    show("rdiv inf", 3.0 / complex(0.0, inf));
    try {
        show("zero div", a / complex(0.0, 0.0));
    } except ZeroDivisionError as err {
        print("zero div", err);
    }
    show("sqrt", cmath.sqrt(complex(-4.0, 0.0)));
    show("exp", cmath.exp(complex(0.0, 1.0)));
    show("log", cmath.log(complex(8.0, 0.0), complex(2.0, 0.0)));
    print("phase", cmath.phase(complex(0.0, 1.0)));
    print("isclose", cmath.isclose(complex(1.0, 1.0), complex(1.0, 1.0 + 1e-12)));
    show("infj", cmath.infj);
}
