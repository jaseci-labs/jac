"""Storing a ref-loop variable into a field escapes its loop extent (E1306)."""

obj Res {
    has tag: int = 0;
}

obj Keep {
    has r: Res = Res();
}

def work -> int {
    xs: own list[Res] = [];
    xs.append(Res(tag=1));
    k = Keep();
    for x in &xs {
        k.r = x;
    }
    return k.r.tag;
}

with entry {
    print(work());
}
