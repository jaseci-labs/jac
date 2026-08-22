"""Fixture: an enum invoked as a constructor, in both of Jac's spellings.

`Flags` is `types.jac`'s shape -- a `class X(IntEnum)` whose members are bit
values, re-tagged by masking one bit off and OR-ing another on, then handed
back through the constructor. `Level` is the declared-enum spelling of the
same question. CPython raises `ValueError` for a value no member carries, and
`Flags` is an `IntEnum` rather than an `IntFlag`, so a combination of two bits
is exactly such a value.
"""

import from enum { IntEnum }


class Flags(IntEnum) {
    with entry {
        Null = 0;
        Instantiable = 1 << 0;
        Instance = 1 << 1;
        Ambiguous = 1 << 2;
    }
}


enum Level { LOW = 2, MID = 25, HIGH = 40 }


def as_instance(flags: int) -> int {
    stripped = Flags((flags & ~Flags.Instantiable));
    return int(Flags((stripped | Flags.Instance)));
}


def as_class(flags: int) -> int {
    stripped = Flags((flags & ~Flags.Instance));
    return int(Flags((stripped | Flags.Instantiable)));
}


def level_of(v: int) -> int {
    return int(Level(v));
}


def guarded(v: int) -> str {
    try {
        return str(int(Flags(v)));
    } except ValueError {
        return "rejected";
    }
}


def run -> int {
    print(as_instance(1));
    print(as_class(2));
    print(level_of(25));
    print(guarded(int(Flags.Ambiguous)));
    print(guarded(3));
    print(guarded(7));
    print(int(Flags(int(Flags.Null))));
    return 0;
}


with entry {
    run();
}
