"""Properties read through the vtable off a temporary receiver.

`k.private.vals` reads `vals` from the object `k.private` returned. With a
subclass in play the getter is dispatched through the vtable, and that call
released the temporary receiver on top of the release the property read makes
once it is done with it, so each read freed a reference `k` still held.
"""

obj Box {
    has items: list[int] = [],
        _cache: (list[int] | None) = None;
    has vals: list[int] { getter; }
}

impl Box.vals.getter -> list[int] {
    if self._cache is None {
        self._cache = list(self.items);
    }
    return self._cache;
}

obj TaggedBox(Box) {}

obj Holder {
    has box: Box = Box();
    has private: Box { getter; }
}

impl Holder.private.getter -> Box {
    return self.box;
}

obj TaggedHolder(Holder) {}

node Cell {
    has items: list[int] = [];
    has vals: list[int] { getter; }
}

impl Cell.vals.getter -> list[int] {
    return self.items;
}

node Room {
    has cell: Cell = Cell();
    has inner: Cell { getter; }
}

impl Room.inner.getter -> Cell {
    return self.cell;
}

with entry {
    holders: list[Holder] = [];
    rooms: list[Room] = [];
    for i in range(200) {
        if i % 2 {
            holders.append(TaggedHolder(box=TaggedBox(items=[i, 1])));
        } else {
            holders.append(Holder(box=Box(items=[i, 1])));
        }
        rooms.append(Room(cell=Cell(items=[i, 2])));
    }
    total = 0;
    for _ in range(10) {
        for h in holders {
            total += sum(h.private.vals[:]);
        }
        for r in rooms {
            total += sum(r.inner.vals[:]);
        }
    }
    print("total", total);
    print("first", holders[1].private.vals, rooms[3].inner.vals);
}
