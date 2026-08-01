"""Operator-overload dispatch on archetypes (#7626 B3).

`a + b` / `a * k` / `k * a` on archetype operands statically dispatch to
the operand's dunder through the same MRO walk class patterns use: the
left operand's magic method first, then the right operand's reflected
form. Inherited dunders resolve through the parent chain.
"""

obj Tag {
    has t: int = 1;
}

obj Vec {
    has x: int = 0,
        y: int = 0;

    def __add__(other: Vec) -> Vec {
        return Vec(x=self.x + other.x, y=self.y + other.y);
    }

    def __mul__(k: int) -> Vec {
        return Vec(x=self.x * k, y=self.y * k);
    }

    def __radd__(other: Tag) -> Vec {
        return Vec(x=self.x + other.t, y=self.y + other.t);
    }
}

obj Vec3(Vec) {}

def add_vecs -> int {
    v = Vec(x=1, y=2) + Vec(x=30, y=40);
    return v.x * 100 + v.y;
}

def mul_vec -> int {
    w = Vec(x=3, y=4) * 5;
    return w.x * 100 + w.y;
}

def radd_vec -> int {
    # The left operand's archetype has no __add__, so dispatch falls
    # through to the right operand's reflected __radd__ with swapped
    # operands. (A builtin left operand, e.g. `5 * vec`, is still
    # rejected by the checker's overload resolution before lowering.)
    r = Tag(t=10) + Vec(x=3, y=4);
    return r.x * 100 + r.y;
}

def inherited_add -> int {
    s = Vec3(x=7, y=8) + Vec(x=1, y=1);
    return s.x * 100 + s.y;
}
