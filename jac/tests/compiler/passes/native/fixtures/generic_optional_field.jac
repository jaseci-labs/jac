"""Fixture: a generic archetype whose slot is `(T | None)` rather than `T`.

A generic archetype is laid out once for every instantiation, so a slot typed
by the class's type parameter is a bare pointer. `(T | None)` is the same
erased pointer with null spelling None, but it used to be classified as a
*foreign* optional -- the bucket for an option over a type native cannot model
at all -- and a foreign slot is one the constructor is not allowed to fill. So
`Ctx[Leaf](value=Leaf())` silently dropped its argument, the declared default
went with it, and the slot answered `is None` no matter what was written. A
later assignment to the same field worked, which is what made this a silent
miscompile rather than an obvious one.

Every function pairs the write with a read of the payload behind it, so a
dropped store cannot pass as a compile. `tag` sits after the erased slot so a
mis-sized option shows up as a wrong number rather than a crash, and the
non-generic `(int | None)` control holds the value `0` -- the one payload that
would alias a null-is-None encoding if the two representations were ever
confused.

The type argument is an archetype throughout. A generic archetype instantiated
at a scalar has no sound erasure at all, and is refused rather than lowered;
that refusal is pinned in the test file, not here.
"""

obj Leaf {
    has num: int = 0,
        name: str = "";
}

obj Ctx[T] {
    has value: (T | None) = None,
        tag: int = 0;
}

obj Holder {
    has cell: (Ctx[Leaf] | None) = None;

    def cell_num -> int;
}

impl Holder.cell_num -> int {
    if self.cell is not None and self.cell.value is not None {
        return self.cell.value.num;
    }
    return -1;
}

obj IntCtx {
    has value: (int | None) = None,
        tag: int = 0;
}

def build(n: int) -> Ctx[Leaf] {
    return Ctx[Leaf](value=Leaf(num=n, name="built"), tag=n + 1);
}

def take(c: Ctx[Leaf]) -> int {
    if c.value is not None {
        return c.value.num + c.tag;
    }
    return -1;
}

"""The constructor argument for the optional erased slot must survive."""
def ctor_num(k: int) -> int {
    c = Ctx[Leaf](value=Leaf(num=30 + k, name="ab"), tag=7);
    if c.value is not None {
        return c.value.num;
    }
    return -1;
}

"""The slot after the erased option keeps its own offset."""
def ctor_tag(k: int) -> int {
    c = Ctx[Leaf](value=Leaf(num=30 + k, name="ab"), tag=7);
    return c.tag;
}

"""A later assignment answers the same as the constructor did."""
def assign_num(k: int) -> int {
    c = Ctx[Leaf]();
    c.value = Leaf(num=30 + k, name="ab");
    if c.value is not None {
        return c.value.num;
    }
    return -1;
}

"""The declared `= None` default, left alone."""
def default_none(k: int) -> int {
    c = Ctx[Leaf]();
    if c.value is not None {
        return c.value.num;
    }
    return -1 - k;
}

"""An explicitly passed None is still None."""
def explicit_none(k: int) -> int {
    c = Ctx[Leaf](value=None, tag=k);
    if c.value is not None {
        return c.value.num;
    }
    return -1 - k;
}

"""A str payload through the erased option is a descriptor, not a word."""
def ctor_name_len(k: int) -> int {
    c = Ctx[Leaf](value=Leaf(num=k, name="abcde"), tag=1);
    if c.value is not None {
        return len(c.value.name);
    }
    return -1;
}

"""The same read off `self`, through a method on a non-generic holder."""
def method_num(k: int) -> int {
    h = Holder();
    if k > 0 {
        h.cell = Ctx[Leaf](value=Leaf(num=20 + k, name="pq"), tag=3);
    }
    return h.cell_num();
}

"""A store over a constructor-set slot is what the next read sees."""
def overwrite_num(k: int) -> int {
    c = Ctx[Leaf](value=Leaf(num=1, name="a"), tag=2);
    if k > 0 {
        c.value = Leaf(num=60 + k, name="zz");
    }
    if c.value is not None {
        return c.value.num;
    }
    return -1;
}

"""The option survives a return across a function boundary."""
def returned_num(k: int) -> int {
    c = build(70 + k);
    if c.value is not None {
        return c.value.num + c.tag;
    }
    return -1;
}

"""And reaches through a parameter annotation."""
def param_num(k: int) -> int {
    return take(Ctx[Leaf](value=Leaf(num=80 + k, name="q"), tag=6));
}

"""The non-generic control, holding the payload that aliases null."""
def nongen_zero(k: int) -> int {
    c = IntCtx(value=0, tag=k);
    if c.value is not None {
        return c.value;
    }
    return -1;
}

"""The non-generic control with a payload that does not alias null."""
def nongen_num(k: int) -> int {
    c = IntCtx(value=40 + k, tag=k);
    if c.value is not None {
        return c.value;
    }
    return -1;
}

with entry {
    assert ctor_num(2) == 32;
    assert ctor_num(0) == 30;
    assert ctor_tag(0) == 7;
    assert assign_num(2) == 32;
    assert default_none(0) == -1;
    assert explicit_none(1) == -2;
    assert ctor_name_len(0) == 5;
    assert method_num(1) == 21;
    assert method_num(0) == -1;
    assert overwrite_num(1) == 61;
    assert overwrite_num(0) == 1;
    assert returned_num(0) == 141;
    assert param_num(0) == 86;
    assert nongen_zero(0) == 0;
    assert nongen_num(1) == 41;
    print("ok");
}
