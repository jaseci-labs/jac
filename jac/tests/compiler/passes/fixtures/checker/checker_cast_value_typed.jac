import from typing { cast }

obj Leaf {
    has v: int = 1;
}

obj Holder {
    has held: (Leaf | list[Leaf] | None) = None;
}

def pick(h: Holder) -> Leaf {
    return cast(Leaf, h.held or Leaf(v=5));
}

def pick_named(h: Holder) -> Leaf {
    return cast(typ=Leaf, val=h.held);
}
