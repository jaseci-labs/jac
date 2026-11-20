"""Owned lists of fresh archetype elements: move-in, index reads, element drops."""

obj Res {
    has tag: int = 0;

    def drop {
        print(f"drop {self.tag}");
    }
}

def work {
    xs: list[Res] = [];
    for i in range(3) {
        xs.append(Res(tag=i));
    }
    print(xs[1].tag);
    print(len(xs));
}

with entry {
    work();
    print("end");
}
