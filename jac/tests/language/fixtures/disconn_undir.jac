"""Undirected edge disconnect regression: `a <++> b` must be removable by
`del -->` from either endpoint (disconnect previously ignored is_undirected)."""

node P {
    has v: int = 0;
}

with entry {
    a = P(v=1);
    b = P(v=2);
    a <++> b;
    print("before:", len([a-->]), len([b-->]));
    b del --> a;
    print("after:", len([a-->]), len([b-->]));
    a <++> b;
    print("re:", len([a-->]));
    a del --> b;
    print("final:", len([a-->]), len([b-->]));
    print("redel:", a del --> b);
}
