obj Item { has id: int = 0; }

def evens(xs: &list[own Item]) -> list[&Item] {
    picked: list[&Item] = [];
    for it in &xs {
        if it.id % 2 == 0 { picked.append(it); }
    }
    return picked;
}

def build -> list[&Item] {
    xs: list[own Item] = [];
    xs.append(Item(id=2));
    return evens(&xs);
}

with entry { print(len(build())); }
