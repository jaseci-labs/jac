"""Fixture: reads and writes through a generic archetype's erased slot.

A generic archetype gets one native struct, not one per instantiation, so a
`has` slot typed by the class's type parameter lowers to a raw pointer with
no class attached. The offset is still knowable -- it is the same slot for
every instantiation -- so what a read needs is the access site's static type
argument to say what came back. Every function below is a shape that has to
survive that retyping, and each returns a payload read off the far side so a
dropped or mistyped load cannot pass: directly off a local, through a
`| None` option, through a union arm reached by `isinstance`, out of a
method's `self`, out of a `{ getter; }` accessor (the waived shape itself,
and a different lowering path from a plain method), and back after a store
into the erased slot.

`kind` sits after the erased slot in the layout so a wrong offset shows up as
a wrong value rather than a crash, and the trailing `Other` union member is
laid out with `num` first so a union arm read at the wrong offset returns
`Other.num` instead of failing.
"""

enum Rank { LOW = "low", MID = "mid", HIGH = "high" }

obj Leaf {
    has num: int = 0,
        name: str = "";
}

obj Other {
    has num: int = 0;
}

obj Cell[T] {
    has slot: T,
        kind: int = 0;
}

obj Holder {
    has one: (Cell[Leaf] | None) = None,
        pick: (Cell[Leaf] | Other | None) = None;

    has rank: Rank { getter; }

    def one_num -> int;
    def one_name_len -> int;
}

impl Holder.one_num -> int {
    if self.one {
        return self.one.slot.num;
    }
    return -1;
}

impl Holder.one_name_len -> int {
    if self.one {
        return len(self.one.slot.name);
    }
    return -1;
}

impl Holder.rank.getter -> Rank {
    return Rank.HIGH
        if (self.one and (self.one.slot.name == "hi"))
        else Rank.MID if (self.one and (self.one.slot.name == "mid")) else Rank.LOW;
}

def make_cell(n: int) -> Cell[Leaf] {
    return Cell[Leaf](slot=Leaf(num=n, name="abcd"), kind=n + 1);
}

"""A field off the type argument, read straight off a local."""
def direct_num(k: int) -> int {
    c = Cell[Leaf](slot=Leaf(num=40 + k, name="ab"), kind=7);
    return c.slot.num;
}

"""The slot after the erased one still has to land at its own offset."""
def direct_kind(k: int) -> int {
    c = Cell[Leaf](slot=Leaf(num=40 + k, name="ab"), kind=7);
    return c.kind;
}

"""A str field through the erased slot -- a descriptor, not a word."""
def direct_name_len(k: int) -> int {
    c = Cell[Leaf](slot=Leaf(num=k, name="abcde"), kind=1);
    return len(c.slot.name);
}

"""Through a `Cell[Leaf] | None` slot on another archetype."""
def opt_num(k: int) -> int {
    h = Holder();
    if k > 0 {
        h.one = Cell[Leaf](slot=Leaf(num=10 + k, name="xy"), kind=2);
    }
    if h.one {
        return h.one.slot.num;
    }
    return -1;
}

"""The same option read from inside a method, off `self`."""
def method_num(k: int) -> int {
    h = Holder();
    if k > 0 {
        h.one = Cell[Leaf](slot=Leaf(num=20 + k, name="pqr"), kind=3);
    }
    return h.one_num();
}

"""A str field through the erased slot, off `self`."""
def method_name_len(k: int) -> int {
    h = Holder();
    if k > 0 {
        h.one = Cell[Leaf](slot=Leaf(num=k, name="pqrstu"), kind=3);
    }
    return h.one_name_len();
}

"""The waived shape itself: a `{ getter; }` accessor reading through the slot.

`AstAccessNode.access_type` is exactly this -- a property whose body compares a
str field reached through `SubTag[Token]` and answers with an enum member --
and it is a property, not a plain method, so it lowers through the accessor
call path rather than the method one.
"""
def rank_ord(k: int) -> int {
    h = Holder();
    if k == 1 {
        h.one = Cell[Leaf](slot=Leaf(num=1, name="hi"), kind=1);
    } elif k == 2 {
        h.one = Cell[Leaf](slot=Leaf(num=2, name="mid"), kind=2);
    }
    r = h.rank;
    if r == Rank.HIGH {
        return 3;
    }
    if r == Rank.MID {
        return 2;
    }
    return 1;
}

"""Through a union arm narrowed by `isinstance`."""
def union_num(k: int) -> int {
    h = Holder();
    if k == 1 {
        h.pick = Cell[Leaf](slot=Leaf(num=31, name="u"), kind=4);
    } elif k == 2 {
        h.pick = Other(num=55);
    }
    p = h.pick;
    if isinstance(p, Cell) {
        return p.slot.num;
    }
    if isinstance(p, Other) {
        return p.num;
    }
    return -1;
}

"""A store into the erased slot, read back through it."""
def store_num(k: int) -> int {
    c = Cell[Leaf](slot=Leaf(num=1, name="a"), kind=5);
    if k > 0 {
        c.slot = Leaf(num=60 + k, name="zz");
    }
    return c.slot.num;
}

"""A generic returned from another function keeps its type argument."""
def returned_num(k: int) -> int {
    c = make_cell(70 + k);
    return c.slot.num + c.kind;
}

"""The type argument reaches through a parameter annotation too."""
def param_num(k: int) -> int {
    return take_cell(Cell[Leaf](slot=Leaf(num=80 + k, name="q"), kind=6));
}

def take_cell(c: Cell[Leaf]) -> int {
    return c.slot.num + c.kind;
}

with entry {
    assert direct_num(2) == 42;
    assert direct_kind(0) == 7;
    assert direct_name_len(0) == 5;
    assert opt_num(1) == 11;
    assert opt_num(0) == -1;
    assert method_num(1) == 21;
    assert method_num(0) == -1;
    assert method_name_len(1) == 6;
    assert rank_ord(1) == 3;
    assert rank_ord(2) == 2;
    assert rank_ord(0) == 1;
    assert union_num(1) == 31;
    assert union_num(2) == 55;
    assert union_num(0) == -1;
    assert store_num(1) == 61;
    assert store_num(0) == 1;
    assert returned_num(0) == 141;
    assert param_num(0) == 86;
    print("ok");
}
