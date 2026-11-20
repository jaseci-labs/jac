"""Growing the iterated container inside a ref loop conflicts with the loan."""

obj Res {
    has tag: int = 0;
}

def work -> int {
    xs: own list[Res] = [];
    xs.append(Res(tag=1));
    t = 0;
    for x in &xs {
        t = t + x.tag;
        xs.append(Res(tag=9));
    }
    return t;
}

with entry {
    print(work());
}
