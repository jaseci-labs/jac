"""Augmented assignment on module-level variables, and bool values (#10556)."""

import math;

glob gf: float = 10.0;

def half(x: float) -> float {
    return x / 2;
}

def local_rows -> list[str] {
    lf = 10.0;
    lf /= 4;
    lf += True;
    s = {1, 2, 3};
    t = {4};
    s |= t;
    ll = [1];
    alias = ll;
    ll += [2];
    ll *= 2;
    return [f"local {lf} {sorted(s)} {sorted(t)} {alias}", f"local {bool(3)}"];
}

with entry {
    ef = 9.0;
    ei = 7;
    ec = complex(1, 2);
    es = {1, 2, 3};
    eb = bytearray(b"ab");
    eb += b"cd";
    el = [1];
    alias = el;
    gf += 2;
    gf -= 0.5;
    gf *= 4;
    gf /= 2;
    gf //= 2;
    gf %= 4;
    gf **= 2;
}

with entry {
    ef /= 2;
    ef %= 2.0;
    ef += bool(1);
    ei += 2;
    ei -= 1;
    ei *= 6;
    ei //= 4;
    ei %= 7;
    ei **= 3;
    ei <<= 3;
    ei >>= 1;
    ei |= 5;
    ei &= 60;
    ei ^= 6;
    ec *= 2;
    ec -= complex(0, 1);
    ec /= 2;
    es |= {4};
    es -= {1};
    es &= {2, 3, 4};
    es ^= {5};
    el += [2];
    el *= 2;
    rows = [
        f"float {gf} {ef} int {ei} complex {ec.real} {ec.imag}",
        f"seq {sorted(es)} {len(eb)} {alias}",
        f"bool {bool(0)} {bool(2.5)} {bool('')} {bool(math.nan)} {str(bool(0))}",
        f"count {True * 'ab'} {[1] * True} {divmod(True, 1)} {round(True)}",
        f"float {half(True)} {1.5 + bool(1)} {float(bool(1))} {round(bool(0), 2)}",
        *local_rows()
    ];
    for row in rows {
        print(row);
    }
}
