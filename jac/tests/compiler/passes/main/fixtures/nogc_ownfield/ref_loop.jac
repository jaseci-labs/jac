obj Res {
    has tag: int = 0;
}

def work {
    xs: list[Res] = [];
    for i in range(3) {
        xs.append(Res(tag=i));
    }
    t = 0;
    for x in &xs {
        t = t + x.tag;
    }
    print(t);
    for m in &mut xs {
        m.tag = m.tag * 2;
    }
    print(xs[2].tag);
}

with entry {
    work();
    print("end");
}
