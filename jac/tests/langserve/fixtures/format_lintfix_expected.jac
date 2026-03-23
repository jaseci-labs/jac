
# W3003: consecutive globs - should be merged into one
glob a = 1,
     b = 2;

# W3002: consecutive has - should be merged into one
obj MyNode {
    has x: int = 0,
        y: int = 0;

    # W3005: empty parens - should be removed
    def get_val -> int {
        return self.x;
    }
}

# W3024: ternary to or, W3001: with entry assignment to glob
glob n = MyNode(),
     val = n.x or 0;
