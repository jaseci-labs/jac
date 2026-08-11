"""Managed-mode parallel flow for stress: every task stores the same
captured string into its disjoint elements, so racing atomic retains
and releases hammer one shared header while element-disjoint overwrites
release distinct old values. Output must be identical across thread
widths and equal to the sequential cycles build."""

obj P {
    has tag: str = "",
        n: int = 0;
}

def build(n: int) -> list[P] {
    ps: list[P] = [];
    for i in range(n) {
        ps.append(P(tag=f"t{i}", n=i));
    }
    return ps;
}

def mkname -> str {
    return "shared-" + "tag";
}

with entry {
    ps = build(200);
    name = mkname();
    flow for m in &mut ps {
        m.tag = name;
        m.tag = name + "";
        m.n = m.n * 2;
    }
    total = 0;
    for i in range(len(ps)) {
        total = (total + len(ps[i].tag) * (i + 1) + ps[i].n) % 1000000007;
    }
    print(total);
    print("end");
}
