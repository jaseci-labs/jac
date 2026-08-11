"""shared mutation smuggled into a flow for body: accumulator write and
outer container growth are both E1308."""

glob xs = [1, 2],
     out: list[int] = [];

with entry {
    t = 0;
    flow for v in &xs {
        t = t + v;
        out.append(v);
    }
    print(t);
}
