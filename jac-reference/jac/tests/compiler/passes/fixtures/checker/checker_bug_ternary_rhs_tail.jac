"""Assignments whose RHS is a ternary, sitting at the tail of a block.

Reduced from Parser.parse_assignment_with_target (#8059): every `is not None`
guard on `value` failed while the same guard shape narrows everywhere else.
Each `value = ... if ... else ...;` below ends the block it is in (an if arm,
an elif arm, a while body, a try body), which is exactly where the write went
missing from the flow walk.
"""

obj Expr2 {
    has a: int = 1;
}

obj Yield2(Expr2) {
    has b: int = 2;
}

obj Tok2 {
    has t: int = 3;
}

obj P {
    def pe -> Expr2 {
        return Expr2();
    }

    def py -> Yield2 {
        return Yield2();
    }

    def chk(i: int) -> bool {
        return i > 0;
    }

    def mk -> Tok2 {
        return Tok2();
    }

    def run(target: Expr2) -> int {
        value: (Expr2 | Yield2 | None) = None;
        aug_op: (Tok2 | None) = None;
        targets: list[Expr2] = [target];
        eq_unis: list[Tok2] = [];
        if self.chk(1) {
            eq_unis.append(self.mk());
            value = self.py() if self.chk(2) else self.pe();
            while self.chk(3) and not self.chk(4) {
                eq_unis.append(self.mk());
                if value is not None {
                    targets.append(value);
                }
                value = self.py() if self.chk(5) else self.pe();
            }
        } elif self.chk(6) {
            aug_op = self.mk();
            value = self.py() if self.chk(7) else self.pe();
        }
        kid: list[(Expr2 | Tok2)] = [];
        eq_idx = 0;
        for (ti, tgt) in enumerate(targets) {
            kid.append(tgt);
            if ti < len(targets) - 1 {
                kid.append(eq_unis[eq_idx]);
                eq_idx += 1;
            }
        }
        if aug_op is not None {
            kid.append(aug_op);
            if value is not None {
                kid.append(value);
            }
        } elif value is not None {
            kid.append(eq_unis[eq_idx] if eq_idx < len(eq_unis) else eq_unis[-1]);
            kid.append(value);
        }
        return len(kid);
    }

    def in_try -> int {
        value: (Expr2 | Yield2 | None) = None;
        kid: list[Expr2] = [];
        try {
            value = self.py() if self.chk(8) else self.pe();
        } except Exception {
            value = None;
        }
        if value is not None {
            kid.append(value);
        }
        return len(kid);
    }

    def with_short_circuit_rhs -> int {
        ready: (bool | None) = None;
        if self.chk(9) {
            ready = self.chk(10) and self.chk(11);
        }
        if ready is not None {
            settled: bool = ready;
            return 1 if settled else 0;
        }
        return 0;
    }
}
