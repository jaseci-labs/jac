import from __future__ { annotations }

# W3003: consecutive globs - should be merged into one
glob a = 1;
glob b = 2;

# W3002: consecutive has - should be merged into one
obj MyNode {
    has x: int = 0;
    has y: int = 0;

    # W3005: empty parens - should be removed
    def get_val() -> int {
        return self.x;
    }
}

# W3024: ternary to or, W3001: with entry assignment to glob
with entry {
    n = MyNode();
    val = n.x if n.x else 0;
}
