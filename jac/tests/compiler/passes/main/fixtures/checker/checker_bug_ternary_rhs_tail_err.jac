"""Genuine type errors reached through a ternary-assigned union (#8059).

The counterpart to checker_bug_ternary_rhs_tail.jac: the guard narrows the
union, but the narrowed union is still wrong for the call it feeds, so both
appends must be reported. `dropped_else_arm` is the shape the missing edge
silenced outright -- the else arm's write never reached the join, so the walk
saw only the then arm's Leaf2 and the call checked clean.
"""

obj Node2 {
    has a: int = 1;
}

obj Leaf2(Node2) {
    has b: int = 2;
}

obj Tok3 {
    has t: int = 3;
}

obj Q {
    def leaf -> Leaf2 {
        return Leaf2();
    }

    def tok -> Tok3 {
        return Tok3();
    }

    def chk(i: int) -> bool {
        return i > 0;
    }

    def dropped_else_arm -> int {
        value: (Leaf2 | Tok3 | None) = None;
        leaves: list[Leaf2] = [];
        if self.chk(1) {
            value = self.leaf();
        } else {
            value = self.leaf() if self.chk(2) else self.tok();
        }
        if value is not None {
            leaves.append(value);
        }
        return len(leaves);
    }

    def then_arm -> int {
        value: (Leaf2 | Tok3 | None) = None;
        leaves: list[Leaf2] = [];
        if self.chk(1) {
            value = self.leaf() if self.chk(2) else self.tok();
        }
        if value is not None {
            leaves.append(value);
        }
        return len(leaves);
    }
}
