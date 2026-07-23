"""Literal-name reflection on declared archetype fields is static (#7685).

`getattr`/`setattr`/`hasattr` with a string-literal name naming a declared
`has` field lower on the native pathway to the equivalent field load/store/
const -- Python parity at zero cost. The 3-arg `getattr` honors the default
expression when the literal name does not name a declared field. The Python
reference pins the semantics; `require=["na"]` in the test makes the native
backend a hard regression guard.
"""

obj P {
    has x: int = 7;
    has s: str = "abc";
}

def reflect_py() -> dict {
    p = P();
    before: int = getattr(p, "x");
    setattr(p, "x", 41);
    after: int = getattr(p, "x");
    withdef: int = getattr(p, "x", 99);
    missing: int = getattr(p, "nope", 123);
    hasx: bool = hasattr(p, "x");
    sval: str = getattr(p, "s");
    setattr(p, "s", "xyz");
    return {
        "before": before,
        "after": after,
        "withdef": withdef,
        "missing": missing,
        "hasx": hasx,
        "sval": sval,
        "supd": p.s
    };
}

na {
    def reflect_na() -> dict[str, any] {
        p = P();
        before: int = getattr(p, "x");
        setattr(p, "x", 41);
        after: int = getattr(p, "x");
        withdef: int = getattr(p, "x", 99);
        missing: int = getattr(p, "nope", 123);
        hasx: bool = hasattr(p, "x");
        sval: str = getattr(p, "s");
        setattr(p, "s", "xyz");
        return {
            "before": before,
            "after": after,
            "withdef": withdef,
            "missing": missing,
            "hasx": hasx,
            "sval": sval,
            "supd": p.s
        };
    }
}
