"""`==` through a user `__eq__` when the comparison owns an operand.

A property read and a call both hand the comparison a reference it owns. The
comparison releases it once; the `__eq__` call it makes must not release it
too, or an object that outlives the comparison is freed while still held."""
obj Kind {
    has name: str = "";

    def __eq__(other: object) -> bool {
        return isinstance(other, Kind) and other.name == self.name;
    }
}

obj Holder {
    has _kept: (Kind | None) = None;
    has kept: Kind { getter; }

    def fresh -> Kind {
        return Kind(name="kept");
    }

    def same_as_kept(k: Kind) -> bool {
        return k == self.kept;
    }

    def kept_same_as(k: Kind) -> bool {
        return self.kept == k;
    }

    def same_as_fresh(k: Kind) -> bool {
        return k == self.fresh();
    }
}

impl Holder.kept.getter -> Kind {
    if self._kept is None {
        raise RuntimeError("unset");
    }
    return self._kept;
}

with entry {
    h = Holder();
    h._kept = Kind(name="kept");
    other = Kind(name="other");
    twin = Kind(name="kept");
    hits = 0;
    for i in range(300) {
        if h.same_as_kept(other) {
            hits += 1;
        }
        if h.same_as_kept(twin) {
            hits += 1;
        }
        if h.kept_same_as(twin) {
            hits += 1;
        }
        if h.same_as_fresh(twin) {
            hits += 1;
        }
    }
    print("hits", hits);
    print("kept", h.kept.name);
}
