"""Accessor (`{ getter; setter; }`) fields under the native backend (#8074).

A property carries no instance storage -- exactly as `property` does on the
Python side -- so every read has to run the getter and every write the setter.
`Box` covers the two shapes the compiler itself uses: a computed accessor with
no backing field at all (`doubled`, `span`, mirroring `CodeLocInfo.first_line`)
and an accessor over an explicitly-declared backing slot (`width` over `_width`,
mirroring `UniNode.gen` over `_gen`). `Tagged`/`Renamed` pin that an accessor
overridden in a subclass dispatches on the runtime class.

`tail` is declared after the accessors on purpose: if a property took a data
slot, every field after it would shift and `tail` would read a neighbour.
"""

obj Box {
    has head: int = 7,
        _width: int = 3;

    has doubled: int { getter; }
    has width: int { getter; setter(value: int); }
    has tail: int = 11;

    def sum_via_accessors -> int {
        return self.doubled + self.width + self.head + self.tail;
    }
}

obj Tagged {
    has base: int = 100;
    has label: int { getter; }
}

obj Renamed(Tagged) {
    has label: int { getter; }
}

impl Box.doubled.getter -> int {
    return self.head * 2;
}

impl Box.width.getter -> int {
    return self._width;
}

impl Box.width.setter(value: int) {
    self._width = value * 10;
}

impl Tagged.label.getter -> int {
    return self.base + 1;
}

impl Renamed.label.getter -> int {
    return self.base + 2;
}

def read_computed(head: int) -> int {
    b = Box();
    b.head = head;
    return b.doubled;
}

def read_backed -> int {
    b = Box();
    return b.width;
}

def write_through_setter(value: int) -> int {
    b = Box();
    b.width = value;
    return b._width;
}

def roundtrip_setter(value: int) -> int {
    b = Box();
    b.width = value;
    return b.width;
}

def neighbour_fields_intact -> int {
    b = Box();
    return b.head * 1000 + b.tail;
}

def accessors_from_method -> int {
    b = Box();
    b.width = 5;
    return b.sum_via_accessors();
}

def inherited_accessor(pick: int) -> int {
    t: Tagged = Tagged() if pick == 0 else Renamed();
    return t.label;
}

with entry {
    assert read_computed(9) == 18;
    assert read_backed() == 3;
    assert write_through_setter(4) == 40;
    assert roundtrip_setter(4) == 40;
    assert neighbour_fields_intact() == 7011;
    assert accessors_from_method() == 82;
    assert inherited_accessor(0) == 101;
    assert inherited_accessor(1) == 102;
    print("ok");
}
