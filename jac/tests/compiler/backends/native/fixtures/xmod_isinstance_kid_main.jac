"""Subclasses of an imported flat base that are also `isinstance` targets.

`CallEntry` and `SubEntry` are tested with `isinstance` here, which used to
keep a vtable slot in each, shifting every inherited field one slot past the
base's layout; each read of `key` or `hits` then refused with E5092
"inherited field access". The allocation header already carries the class
identity those tests need, so the slot is dropped and both units agree.
"""

import from xmod_isinstance_kid_lib { RotatingEntry, entry_key }

obj CallEntry(RotatingEntry) {
    has callcount: int = 0;

    def total -> int {
        return self.key * 100 + self.hits + self.callcount;
    }
}

obj SubEntry(RotatingEntry) {
    has recursive: int = 0;

    def total -> int {
        return self.key + self.recursive;
    }
}

def classify(e: RotatingEntry) -> int {
    if isinstance(e, CallEntry) {
        return e.total() + 1000;
    }
    if isinstance(e, SubEntry) {
        return e.total() + 2000;
    }
    return e.key;
}

with entry {
    c = CallEntry(key=5, callcount=2);
    c.bump(3);
    s = SubEntry(key=7, recursive=4);
    s.bump(1);
    b = RotatingEntry(key=9);
    print("call", c.total(), c.describe(), entry_key(c));
    print("sub", s.total(), s.describe(), entry_key(s));
    print("classify", classify(c), classify(s), classify(b));
    entries: list[RotatingEntry] = [c, s, b];
    for e in entries {
        print("kind", isinstance(e, CallEntry), isinstance(e, SubEntry), e.key, e.hits);
    }
}
