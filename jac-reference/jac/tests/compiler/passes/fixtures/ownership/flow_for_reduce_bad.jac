"""unlicensed accumulator shapes stay E1308: the plain re-assign form,
a float accumulator, and an accumulator that is also read outside its
reduction statement (plus the outer container growth that read rides
in)."""

glob out: list[int] = [],
     xs = [1, 2, 3];

with entry {
    t = 0;
    f = 0.0;
    m = 0;
    flow for v in &xs {
        t = t + v;
        f += v;
        m += v;
        out.append(m);
    }
    print(t);
}
