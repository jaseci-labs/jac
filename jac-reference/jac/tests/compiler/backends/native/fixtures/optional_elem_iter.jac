"""Iteration over optional containers, one shape per function (jac#8201 S3).

Every function is written twice in spirit: the slot it walks is declared
`T | None`, which lowers to a `JacOpt` wrapper, and the answer has to match
the sv run of the same source. A wrapper handed straight to the list helpers
used to raise out of the IR builder and cost the function its lowering.
"""

obj Item {
    has n: int = 0;
}

obj Holder {
    has parts: (list[Item] | None) = None,
        names: (list[str] | None) = None,
        tbl: (dict[str, int] | None) = None;
}

def _filled -> Holder {
    return Holder(
        parts=[Item(n=1), Item(n=2), Item(n=4)],
        names=["ab", "cde"],
        tbl={"a": 10, "bb": 20}
    );
}

def opt_list_direct_loop -> int {
    h = _filled();
    total = 0;
    for p in h.parts {
        total += p.n;
    }
    return total;
}

def opt_list_or_loop -> int {
    h = _filled();
    total = 0;
    for p in (h.parts or []) {
        total += p.n;
    }
    return total;
}

def opt_list_direct_compr -> int {
    h = _filled();
    return sum([p.n for p in h.parts]);
}

def opt_list_or_compr -> int {
    h = _filled();
    return sum([p.n for p in (h.parts or [])]);
}

def opt_list_filtered_compr -> int {
    h = _filled();
    return sum(
        [
            p.n
            for p in (h.parts or [])
            if p.n > 1
        ]
    );
}

def opt_str_list_loop -> int {
    h = _filled();
    total = 0;
    for s in (h.names or []) {
        total += len(s);
    }
    return total;
}

def opt_dict_direct_loop -> int {
    h = _filled();
    total = 0;
    for k in h.tbl {
        total += len(k);
    }
    return total;
}

def opt_dict_or_loop -> int {
    h = _filled();
    total = 0;
    for k in (h.tbl or {}) {
        total += len(k);
    }
    return total;
}

def empty_optional_or_loop -> int {
    h = Holder();
    total = 7;
    for p in (h.parts or []) {
        total += p.n;
    }
    return total;
}

def empty_optional_or_compr -> int {
    h = Holder();
    return 5 + sum([p.n for p in (h.parts or [])]);
}

def none_direct_loop_raises -> int {
    h = Holder();
    total = 0;
    try {
        for p in h.parts {
            total += p.n;
        }
    } except TypeError {
        return -1;
    }
    return total;
}

def annotated_local_loop -> int {
    h = _filled();
    xs: list[Item] = h.parts or [];
    total = 0;
    for p in xs {
        total += p.n;
    }
    return total;
}

def optional_local_loop -> int {
    xs: (list[Item] | None) = [Item(n=3), Item(n=5)];
    total = 0;
    for p in xs {
        total += p.n;
    }
    return total;
}

def opt_list_slice_len -> int {
    h = _filled();
    copy = h.parts[:];
    total = 0;
    for p in copy {
        total += p.n;
    }
    return total;
}

def opt_list_index -> int {
    h = _filled();
    return h.parts[1].n;
}

def none_slice_raises -> int {
    h = Holder();
    total = 0;
    try {
        for p in h.parts[:] {
            total += p.n;
        }
    } except TypeError {
        return -1;
    }
    return total;
}
