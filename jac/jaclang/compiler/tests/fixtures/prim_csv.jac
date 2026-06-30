"""Bundled native `csv` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from csv { reader }` binds CPython's `csv.reader` on the sv
(Python) backend and the bundled `na_stdlib/csv.na.jac` Mechanism-B module on the
na (native LLVM) backend. CPython's `reader` is a lazy iterator (materialized
here with `list(...)`); the native `reader` is eager and returns the same
`list[list[str]]`. Rows marshal as raw i64 across the harness, so every parsed
record is probed through scalar cell reads and `len(...)`. ES/JS opts out.
"""

import from csv { reader }


def csv_py -> dict {
    r1: list = list(reader(["a,b,c", "1,2,3"]));
    r2: list = list(reader(["\"a,b\",c", "\"x\"\"y\",z"]));
    r3: list = list(reader(["a, b ,c"]));
    r4: list = list(reader(["a,,c", ",x,"]));
    r5: list = list(reader([""]));
    return {
        "n1": len(r1),
        "r0c0": r1[0][0],
        "r0c2": r1[0][2],
        "r1c1": r1[1][1],
        "q00": r2[0][0],
        "q01": r2[0][1],
        "q10": r2[1][0],
        "q11": r2[1][1],
        "sp1": r3[0][1],
        "spn": len(r3[0]),
        "e01": r4[0][1],
        "e10": r4[1][0],
        "e12": r4[1][2],
        "e4n": len(r4[1]),
        "emptyrowlen": len(r5[0])
    };
}


cl def csv_cl -> dict {
    return {};
}


na {
    def csv_na -> dict[str, any] {
        r1: list[list[str]] = reader(["a,b,c", "1,2,3"]);
        r2: list[list[str]] = reader(["\"a,b\",c", "\"x\"\"y\",z"]);
        r3: list[list[str]] = reader(["a, b ,c"]);
        r4: list[list[str]] = reader(["a,,c", ",x,"]);
        r5: list[list[str]] = reader([""]);
        return {
            "n1": len(r1),
            "r0c0": r1[0][0],
            "r0c2": r1[0][2],
            "r1c1": r1[1][1],
            "q00": r2[0][0],
            "q01": r2[0][1],
            "q10": r2[1][0],
            "q11": r2[1][1],
            "sp1": r3[0][1],
            "spn": len(r3[0]),
            "e01": r4[0][1],
            "e10": r4[1][0],
            "e12": r4[1][2],
            "e4n": len(r4[1]),
            "emptyrowlen": len(r5[0])
        };
    }
}
