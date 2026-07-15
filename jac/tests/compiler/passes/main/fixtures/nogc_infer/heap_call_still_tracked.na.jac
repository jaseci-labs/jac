"""Positive control for the scalar skip: a HEAP call-result local must still
be auto-own-stamped under --enforce-nogc, so a real use-after-move on it is
still reported."""

obj Box {
    has n: int = 0;
}

def mk -> Box {
    b: own Box = Box(n=1);
    return b;
}

def g -> int {
    x = mk();
    y = x;
    return x.n;
}

with entry {
    print(g());
}
