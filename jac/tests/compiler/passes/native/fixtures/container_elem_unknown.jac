"""Genuinely un-inferable list element types (jac#7967 N5, honest-failure half).

`x = []; x.append(7); x.append("seven");` has no single element type, so the
checker widens it to `any` and the backend stores tagged `{tag, payload}`
values. That is a legitimate outcome -- what is not legitimate is comparing one
of those tagged elements against an unboxed value (here `Box.n`, a plain i64
field) and getting a wrong answer or invalid IR. Either both sides go through
the tagged representation, or the compile fails loudly.

Ordering gets no free ride from boxing the way equality does: a mismatched tag
simply compares unequal, but there is no sensible order between a string and an
int. CPython raises `TypeError: '<' not supported between instances of 'str'
and 'int'`, so the `mixed_ord_*` cases pin that native raises the same exception
type at runtime rather than ordering on whatever bit pattern the payload holds.
`mixed_ord_float_vs_int` is the case a raw payload unbox reads backwards: 2.5
boxes as the double's bit pattern, which as an i64 is a large positive number,
so an unchecked `< 9` answers False where the true answer is True.
"""

obj Box {
    has n: int = 0;
}

def mixed_elem_eq -> int {
    b = Box(n=7);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] == b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_eq_miss -> int {
    b = Box(n=3);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] == b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_ne -> int {
    b = Box(n=3);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] != b.n {
        return 1;
    }
    return 0;
}

def mixed_elem_lt -> int {
    b = Box(n=9);
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] < b.n {
        return 1;
    }
    return 0;
}

def mixed_ord_str_vs_int -> int {
    x = [];
    x.append(7);
    x.append("seven");
    try {
        if x[1] < 9 {
            return 1;
        }
        return 0;
    } except TypeError {
        return -1;
    } except Exception {
        return -2;
    }
}

def mixed_ord_str_vs_float -> int {
    x = [];
    x.append(7);
    x.append("seven");
    try {
        if x[1] < 9.5 {
            return 1;
        }
        return 0;
    } except TypeError {
        return -1;
    } except Exception {
        return -2;
    }
}

def mixed_ord_int_vs_int -> int {
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] < 9 {
        return 1;
    }
    return 0;
}

def mixed_ord_int_vs_float -> int {
    x = [];
    x.append(7);
    x.append("seven");
    if x[0] < 9.5 {
        return 1;
    }
    return 0;
}

def mixed_ord_float_vs_int -> int {
    y = [];
    y.append(2.5);
    y.append("two");
    if y[0] < 9 {
        return 1;
    }
    return 0;
}

def mixed_ord_float_vs_int_false -> int {
    y = [];
    y.append(20.5);
    y.append("two");
    if y[0] < 9 {
        return 1;
    }
    return 0;
}

def mixed_elem_str_eq -> int {
    x = [];
    x.append(7);
    x.append("seven");
    if x[1] == "seven" {
        return 1;
    }
    return 0;
}
