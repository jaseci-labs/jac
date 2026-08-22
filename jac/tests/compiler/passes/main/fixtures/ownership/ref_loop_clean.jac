"""Reference-yielding loops: reads inside, owner reusable after, all clean."""

obj Res {
    has tag: int = 0;
}

def work -> int {
    xs: own list[Res] = [];
    xs.append(Res(tag=1));
    t = 0;
    for x in &xs {
        t = t + x.tag;
    }
    for m in &mut xs {
        m.tag = m.tag * 2;
    }
    return t + len(xs);
}

with entry {
    print(work());
}
