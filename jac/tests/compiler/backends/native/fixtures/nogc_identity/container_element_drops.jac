"""Containers drop the elements they own when those elements leave."""

obj Item {
    has id: int = 0;

    def drop {
        print(f"drop {self.id}");
    }
}

def make(ids: &list[int]) -> own list[own Item] {
    out: own list[own Item] = [];
    for i in ids {
        out.append(Item(id=i));
    }
    return out;
}

def run {
    xs: own list[own Item] = make(&[1, 2, 3]);
    print("clear");
    xs.clear();
    ys: own list[own Item] = make(&[4, 5, 6, 7, 8]);
    print("del");
    del ys[0];
    print("slice");
    del ys[0:2];
    print("pop");
    ys.pop();
    print("set");
    ys[0] = Item(id=9);
    print("dict");
    d: own dict[str, own Item] = {};
    d["a"] = Item(id=10);
    d["b"] = Item(id=11);
    d["a"] = Item(id=12);
    d.clear();
    print("text");
    empty = "";
    full = "x";
    print(bool(empty), bool(full), "yes" if empty else "no", "yes" if full else "no");
    print("end");
}

with entry {
    run();
    print("done");
}
