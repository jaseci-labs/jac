"""Marshalled-view surfaces over runtime-class-canonical views (#8093).

`BaseN`/`SubN` alias one instance behind two declared types to pin
per-pointer canonicalization; `Box[T]` carries a foreign scratch slot and
an opaque generic value slot; `Bag` carries list fields whose annotations
(optional, union elements) exercise the layout's element keys; `Crate`
has a field literally named `items`.
"""

obj Pad {
    has note: int = 5;
}

obj BaseN {
    has tag: int = 1;
    has kind: int { getter; }
}

obj SubN(BaseN) {
    has kind: int { getter; }
}

impl BaseN.kind.getter -> int {
    return 1;
}

impl SubN.kind.getter -> int {
    return 2;
}

obj Holder {
    has as_base: BaseN,
        as_sub: SubN;
}

obj Box[T] {
    has held: T,
        scratch: (T | None) = None;
}

obj Bag {
    has opt_pads: (list[Pad] | None) = None,
        mixed: list[(BaseN | Pad)] = [];
}

obj Crate {
    has items: list[Pad] = [],
        n: int = 0;
}

def make_holder -> Holder {
    s = SubN();
    return Holder(as_base=s, as_sub=s);
}

def make_box -> Box {
    return Box(held=Pad());
}

def make_box_scratch -> Box {
    return Box(held=Pad(), scratch=Pad());
}

def make_bag -> Bag {
    b = Bag();
    b.opt_pads = [Pad(), Pad()];
    b.mixed = [BaseN(), Pad()];
    return b;
}

def make_crate -> Crate {
    c = Crate();
    c.items = [Pad(), Pad(), Pad()];
    c.n = 3;
    return c;
}

with entry {
    h = make_holder();
    assert h.as_base.kind == 2;
    b = make_bag();
    assert b.opt_pads is not None;
    c = make_crate();
    assert c.n == 3;
}
