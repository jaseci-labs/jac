"""Class-based enum iteration should yield enum-instance type, not Unknown.

Mirrors the real-world pattern in jac/jaclang/jac0core/impl/constant.impl.jac:
a `class Foo(IntEnum) { with entry { A = 0; ... } }` enum iterated inside a
list comprehension, with attribute access on the iteration variable. The
type evaluator must materialize the iteration variable as an enum instance
so that `.name` resolves to `str` and `.value` resolves to the enum value
type — instead of falling through to `UnknownType` and emitting cascading
E1032 / W1051 diagnostics.

Expected: 0 errors. Every iteration variable below is an enum instance.
"""
import from enum { Enum, IntEnum, IntFlag, StrEnum }

class JacSemTokenType(IntEnum) {
    with entry {
        NAMESPACE = 0;
        TYPE = 1;
        CLASS = 2;
    }
}

class JacSemTokenModifier(IntFlag) {
    with entry {
        DECLARATION = 1 << 0;
        DEFINITION = 1 << 1;
        READONLY = 1 << 2;
    }
}

class TokenStr(StrEnum) {
    with entry {
        OPEN = "open";
        CLOSE = "close";
    }
}

class Plain(Enum) {
    with entry {
        FIRST = 1;
        SECOND = 2;
    }
}

with entry {
    # Case 1: list comprehension over IntEnum with .name access (the
    # real-world failing pattern from constant.impl.jac).
    type_names: list[str] = [
        i.name.lower()
        for i in JacSemTokenType
        if i.name
    ];

    # Case 2: same pattern over IntFlag.
    mod_names: list[str] = [
        i.name.lower()
        for i in JacSemTokenModifier
        if i.name
    ];

    # Case 3: comprehension over StrEnum, .value yields str.
    open_strs: list[str] = [t.value for t in TokenStr];

    # Case 4: comprehension over plain Enum, .name yields str.
    plain_names: list[str] = [p.name for p in Plain];

    # Case 5: simple for-loop with .name / .value access in body.
    for tok in JacSemTokenType {
        n: str = tok.name;
        v: int = tok.value;
        print(n, v);
    }

    # Case 6: nested generator expression / membership pattern.
    has_open = any(t.name == "OPEN" for t in TokenStr);
    print(has_open);
}
