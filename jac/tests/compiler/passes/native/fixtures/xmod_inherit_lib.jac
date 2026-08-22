"""A hierarchy owned by another module, subclassed by its consumer (#8201).

`Base` and `Mid` lay out here, where `LayoutPass` sees the whole chain. The
consumer declares its own subclasses of both, so its layouts have to adopt
the field offsets this module assigned or the two units disagree about where
`tag` lives. `describe` reads its own fields through this module's offsets,
which is what makes an inherited method a check on the consumer's layout.
"""

obj Base {
    has tag: str = "base",
        depth: int = 0;

    def describe -> str {
        return f"{self.tag}/{self.depth}";
    }

    def bump(amount: int) -> int {
        self.depth = self.depth + amount;
        return self.depth;
    }
}

obj Mid(Base) {
    has mid: int = 0;

    def describe -> str {
        return f"mid({self.tag}/{self.depth}/{self.mid})";
    }
}

def make_base(t: str, d: int) -> Base {
    return Base(tag=t, depth=d);
}

def read_tag(b: Base) -> str {
    return b.tag;
}
