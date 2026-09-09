"""Views: an archetype holding a borrow and a list of borrows, both stack-scoped,
never owning what they point at (#8984 rule 5)."""

obj Item {
    has id: int = 0;

    def drop { print("drop item " + str(self.id)); }
}

obj Cursor {
    has items: &list[own Item],
        pos: int = 0;

    def next_id -> int {
        if self.pos >= len(self.items) { return -1; }
        v = self.items[self.pos].id;
        self.pos += 1;
        return v;
    }
}

def walk(xs: &list[own Item]) -> int {
    c = Cursor(items=xs);
    t = 0;
    while True {
        v = c.next_id();
        if v < 0 { break; }
        t = t * 10 + v;
    }
    return t;
}

def evens(xs: &list[own Item]) -> int {
    picked: list[&Item] = [];
    for it in &xs {
        if it.id % 2 == 0 { picked.append(it); }
    }
    s = 0;
    for p in &picked { s += p.id; }
    return s;
}

def run -> int {
    xs: list[own Item] = [];
    for i in range(1, 5) { xs.append(Item(id=i)); }
    return walk(&xs) * 100 + evens(&xs);
}

with entry { print(run()); print("done"); }
