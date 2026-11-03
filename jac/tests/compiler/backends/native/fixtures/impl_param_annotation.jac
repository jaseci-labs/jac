"""An impl body may annotate a parameter wider than its declaration.

`Probe.width` declares `b: Box | None` and its impl takes `b: any`; the body
reads the slot as `any`, so the incoming optional object is boxed on entry.
"""
obj Box {
    has n: int = 0;
}

obj Probe {
    def width(b: Box | None) -> int;
}

impl Probe.width(b: any) -> int {
    if not b {
        return -1;
    }
    return 7;
}

def chk -> int {
    p = Probe();
    return p.width(Box(n=3)) * 10 + p.width(None);
}

with entry {
    print(chk());
}
