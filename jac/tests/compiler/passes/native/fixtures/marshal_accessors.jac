"""Accessor fields read and written through the marshalling bridge (#8092).

`#8074` removed accessor-only fields' data slots and emits their bodies as
`Cls.field.__get__`-style native methods, so a Python-side read of such a
field cannot be a struct-slot load: the bridge has to call the emitted body
and marshal its result exactly as a data field of that type would marshal.
`Part` covers the return shapes that matter: a computed primitive with no
backing slot (`doubled`), an accessor over a backing slot with a setter
(`width` over `_width`), a str-returning accessor (`title`), an optional
str accessor that is None on one side (`nick`), and an archetype-returning
accessor (`origin`). `Tagged`/`Renamed` pin virtual dispatch: the factory
returns a `Tagged`-typed value whose runtime class overrides the getter.
"""

obj Anchor {
    has x: int = 4,
        y: int = 9;
}

obj Part {
    has head: int = 7,
        _width: int = 3,
        name: str = "gear",
        _anchor: Anchor = Anchor();

    has doubled: int { getter; }
    has width: int { getter; setter(value: int); }
    has title: str { getter; }
    has nick: (str | None) { getter; }
    has origin: Anchor { getter; }
    has tail: int = 11;
}

impl Part.doubled.getter -> int {
    return self.head * 2;
}

impl Part.width.getter -> int {
    return self._width;
}

impl Part.width.setter(value: int) {
    self._width = value * 10;
}

impl Part.title.getter -> str {
    return "part:" + self.name;
}

impl Part.nick.getter -> (str | None) {
    return self.name if self.head > 0 else None;
}

impl Part.origin.getter -> Anchor {
    return self._anchor;
}

obj Tagged {
    has base: int = 100;
    has label: int { getter; }
}

obj Renamed(Tagged) {
    has label: int { getter; }
}

impl Tagged.label.getter -> int {
    return self.base + 1;
}

impl Renamed.label.getter -> int {
    return self.base + 2;
}

def make_part(head: int) -> Part {
    p = Part();
    p.head = head;
    return p;
}

def make_tagged(pick: int) -> Tagged {
    t: Tagged = Tagged() if pick == 0 else Renamed();
    return t;
}

with entry {
    p = make_part(9);
    assert p.doubled == 18;
    assert p.width == 3;
    assert p.title == "part:gear";
    assert p.nick == "gear";
    assert make_part(0).nick is None;
    assert p.origin.x == 4 and p.origin.y == 9;
    p.width = 4;
    assert p.width == 40;
    assert p.tail == 11;
    assert make_tagged(0).label == 101;
    assert make_tagged(1).label == 102;
    print("ok");
}
