"""Growing the container after the loop ends is clean: the loan died with the loop."""

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
    xs.append(Res(tag=9));
    return t + len(xs);
}

with entry {
    print(work());
}
