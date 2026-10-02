"""Bundled native `string` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from string { ... }` binds CPython's `string` on the sv
(Python) backend and the bundled `na_stdlib/string.jac` Mechanism-B module on
the na (native LLVM) backend. Only the ASCII constant set, `capwords`, and the
`$`-`Template` subset (`substitute`, `safe_substitute`, `is_valid`,
`get_identifiers`) are exercised -- `Formatter`, brace-style templates, and
locale-aware behavior are outside the native module's scope.

`get_identifiers` returns a list, which the cross-backend harness reads as raw
i64, so it is probed via `len(...)` and element reads. `suberr`/`caperr` pin the
KeyError / ValueError paths; `lit*` pin `safe_substitute`'s literal preservation
of malformed placeholders. ES/JS opts out.
"""

import from string { capwords, digits, hexdigits, whitespace, Template }


def string_py -> dict[any, any] {
    suberr: str = "no raise";
    ma: dict[str, any] = {"a": "1"};
    try {
        Template("$nope").substitute(ma);
    } except KeyError {
        suberr = "KeyError";
    }
    caperr: str = "no raise";
    try {
        capwords("a b", "");
    } except ValueError {
        caperr = "ValueError";
    }
    ids: list[str] = Template("$a $b $a ${c} $$d").get_identifiers();
    m: dict[str, any] = {"n": 42};
    m1: dict[str, any] = {"name": "W", "x": "1"};
    m3: dict[str, any] = {"b": "z"};
    me: dict[str, any] = {};
    mu: dict[str, any] = {"w": "w\u00f6rld"};

    return {
        "cap4": capwords("h\u00e9llo w\u00f6rld"),
        "subu": Template("h\u00e9llo $w").substitute(mu),
        "idu": len(Template("\u00e9 $a \u00e9b").get_identifiers()),
        "digs": digits,
        "hexn": len(hexdigits),
        "wsn": len(whitespace),
        "cap1": capwords("hello world foo"),
        "cap2": capwords("a,b,,c", ","),
        "cap3": capwords("they're bill's"),
        "caperr": caperr,
        "sub1": Template("Hello $name, ${x}y $$ $missing").safe_substitute(m1),
        "sub2": Template("$n").substitute(m),
        "sub3": Template("A${b}C").substitute(m3),
        "suberr": suberr,
        "valid1": Template("a $b").is_valid(),
        "valid2": Template("a $").is_valid(),
        "valid3": Template("${").is_valid(),
        "ids0": ids[0],
        "ids1": ids[1],
        "idsn": len(ids),
        "lit1": Template("$").safe_substitute(me),
        "lit2": Template("${unclosed").safe_substitute(me),
        "lit3": Template("$1x").safe_substitute(me),
        "lit4": Template("x$y").safe_substitute(me)
    };
}


def string_cl -> dict[any, any] {
    return {};
}


def string_na -> dict[str, any] {
    suberr: str = "no raise";
    ma: dict[str, any] = {"a": "1"};
    try {
        Template("$nope").substitute(ma);
    } except KeyError {
        suberr = "KeyError";
    }
    caperr: str = "no raise";
    try {
        capwords("a b", "");
    } except ValueError {
        caperr = "ValueError";
    }
    ids: list[str] = Template("$a $b $a ${c} $$d").get_identifiers();
    m: dict[str, any] = {"n": 42};
    m1: dict[str, any] = {"name": "W", "x": "1"};
    m3: dict[str, any] = {"b": "z"};
    me: dict[str, any] = {};
    mu: dict[str, any] = {"w": "w\u00f6rld"};

    return {
        "cap4": capwords("h\u00e9llo w\u00f6rld"),
        "subu": Template("h\u00e9llo $w").substitute(mu),
        "idu": len(Template("\u00e9 $a \u00e9b").get_identifiers()),
        "digs": digits,
        "hexn": len(hexdigits),
        "wsn": len(whitespace),
        "cap1": capwords("hello world foo"),
        "cap2": capwords("a,b,,c", ","),
        "cap3": capwords("they're bill's"),
        "caperr": caperr,
        "sub1": Template("Hello $name, ${x}y $$ $missing").safe_substitute(m1),
        "sub2": Template("$n").substitute(m),
        "sub3": Template("A${b}C").substitute(m3),
        "suberr": suberr,
        "valid1": Template("a $b").is_valid(),
        "valid2": Template("a $").is_valid(),
        "valid3": Template("${").is_valid(),
        "ids0": ids[0],
        "ids1": ids[1],
        "idsn": len(ids),
        "lit1": Template("$").safe_substitute(me),
        "lit2": Template("${unclosed").safe_substitute(me),
        "lit3": Template("$1x").safe_substitute(me),
        "lit4": Template("x$y").safe_substitute(me)
    };
}
