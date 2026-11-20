"""Named own archetype bindings move into containers: `append`, `insert`, a
dict store and a list literal each take the element, which drops exactly once
with its container or when handed back out (#8984 rule 3)."""

obj Box {
    has tag: int = 0;

    def drop { print("drop " + str(self.tag)); }
}

def sink(b: own Box) -> None {
    print("sink " + str(b.tag));
}

def run -> int {
    xs: list[own Box] = [];
    a: own Box = Box(tag=1);
    xs.append(a);
    b: own Box = Box(tag=2);
    xs.insert(0, b);
    c: own Box = Box(tag=3);
    m: dict[str, own Box] = {};
    m["c"] = c;
    d: own Box = Box(tag=4);
    m["d"] = d;
    e: own Box = Box(tag=5);
    ys: list[own Box] = [e];
    print("xs=" + str(xs[0].tag) + str(xs[1].tag));
    print("m=" + str(m["c"].tag) + str(m["d"].tag));
    print("ys=" + str(ys[0].tag));
    first: own Box = xs.pop();
    sink(first);
    got: own Box = m.pop("d");
    sink(got);
    del m["c"];
    last: own Box = ys.pop();
    sink(last);
    return xs[0].tag;
}

with entry { print(run()); print("done"); }
