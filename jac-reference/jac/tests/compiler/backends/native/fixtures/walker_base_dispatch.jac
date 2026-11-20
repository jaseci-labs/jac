import from .walker_base_library { Base, Item }

walker Derived(Base) {
    can inspect with Item entry {
        self.count = self.count * 10 + 2;
    }
}

walker Override(Base) {
    can first with Item entry {
        self.count = 9;
    }
}

def probe -> int {
    item = Item();
    return Derived().run(item) * 10 + item.visited;
}

def override_probe -> int {
    item = Item();
    return Override().run(item) * 10 + item.visited;
}

with entry {
    assert probe() == 121;
    assert override_probe() == 91;
}
