"""Fixture: a postinit's capability violation, siblings clean (#8234).

`Boxed.postinit` imports `collections` -- a Python-only module the native
pathway statically refuses (E5090 from the capability authority, not an
emit-time failure). Granular demotion must turn exactly that constructor
into a seam, keep the class layout and every sibling method natively
lowered, and leave the module holding its IR.
"""

obj Boxed {
    has n: int = 0;

    def postinit {
        import collections;
        self.n = len(collections.OrderedDict());
    }

    def good(x: int) -> int {
        return x * 2;
    }
}

obj Plain {
    def fine(x: int) -> int {
        return x + 1;
    }
}

with entry {
    print(Plain().fine(3));
}
