"""Bundled native `csv` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from csv { reader }` binds CPython's `csv.reader` on the sv
(Python) backend and the bundled `na_stdlib/csv.na.jac` Mechanism-B module on the
na (native LLVM) backend. CPython's `reader` is a lazy iterator (materialized
here with `list(...)`); the native `reader` is eager and returns the same
`list[list[str]]`. Rows marshal as raw i64 across the harness, so every parsed
record is probed through scalar cell reads and `len(...)`. Covers mid-field
literal quotes, quote-after-close, unterminated quotes, embedded
delimiter+newline inside a quoted field, and NUL pass-through (CPython >= 3.14
parses NUL as an ordinary character -- the sv runtime is 3.14; <= 3.13 raised
`csv.Error("line contains NUL")`). The NUL row is probed by field count and its
NUL-free cell only: native strings drop an embedded NUL byte on concatenation
(and the ctypes harness truncates at NUL), so NUL-bearing field CONTENT is a
documented na divergence. ES/JS opts out.
"""

import from csv { reader }


def csv_py -> dict {
    r1: list = list(reader(["a,b,c", "1,2,3"]));
    r2: list = list(reader(["\"a,b\",c", "\"x\"\"y\",z"]));
    r3: list = list(reader(["a, b ,c"]));
    r4: list = list(reader(["a,,c", ",x,"]));
    r5: list = list(reader([""]));
    r6: list = list(reader(["a\"b,c"]));
    r7: list = list(reader(["\"a\"b,c"]));
    r8: list = list(reader(["\"abc"]));
    r9: list = list(reader(["\"a,b\nc\""]));
    r10: list = list(reader(["a" + chr(0) + "b,c"]));
    r11: list = list(reader(["a,b\n", "\n", "c,d\n"]));
    r12: list = list(reader(["x,\r\n"]));
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
        "emptyrowlen": len(r5[0]),
        "mq0": r6[0][0],
        "mq1": r6[0][1],
        "mqn": len(r6[0]),
        "qa0": r7[0][0],
        "qa1": r7[0][1],
        "ut0": r8[0][0],
        "utn": len(r8[0]),
        "nl0": r9[0][0],
        "nln": len(r9[0]),
        "nul1": r10[0][1],
        "nuln": len(r10[0]),
        "tnrows": len(r11),
        "t0a": r11[0][0],
        "t0n": len(r11[0]),
        "t1n": len(r11[1]),
        "t2d": r11[2][1],
        "crlf0": r12[0][0],
        "crlf1": r12[0][1],
        "crlfn": len(r12[0])
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
        r6: list[list[str]] = reader(["a\"b,c"]);
        r7: list[list[str]] = reader(["\"a\"b,c"]);
        r8: list[list[str]] = reader(["\"abc"]);
        r9: list[list[str]] = reader(["\"a,b\nc\""]);
        r10: list[list[str]] = reader(["a" + chr(0) + "b,c"]);
        r11: list[list[str]] = reader(["a,b\n", "\n", "c,d\n"]);
        r12: list[list[str]] = reader(["x,\r\n"]);
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
            "emptyrowlen": len(r5[0]),
            "mq0": r6[0][0],
            "mq1": r6[0][1],
            "mqn": len(r6[0]),
            "qa0": r7[0][0],
            "qa1": r7[0][1],
            "ut0": r8[0][0],
            "utn": len(r8[0]),
            "nl0": r9[0][0],
            "nln": len(r9[0]),
            "nul1": r10[0][1],
            "nuln": len(r10[0]),
            "tnrows": len(r11),
            "t0a": r11[0][0],
            "t0n": len(r11[0]),
            "t1n": len(r11[1]),
            "t2d": r11[2][1],
            "crlf0": r12[0][0],
            "crlf1": r12[0][1],
            "crlfn": len(r12[0])
        };
    }
}
