"""Fixture: every `del` form the ECMAScript backend lowers, per #8774.

One rule: `del` destroys every graph object the target denotes, then releases
the location as Python would. A plain container entry is a reference removal;
an entry holding a node destroys the node and then removes the entry.
"""

node N {
    has t: int;
}

edge E {}

def del_forms -> dict[any, any] {
    d = {"k": 1, "j": 2};
    del d["k"];
    seq = [1, 2, 3];
    del seq[0];
    span = [1, 2, 3];
    del span[0:2];
    strided = [1, 2, 3, 4, 5];
    del strided[::2];
    a = N(1);
    b = N(2);
    a +>:E:+> b;
    a +>:E:+> b;
    del [edge a->:E:->];
    c = N(3);
    e = N(4);
    c +>:E:+> e;
    holder = [e];
    del holder[0];
    p = N(5);
    q = N(6);
    p +>:E:+> q;
    for edg in [edge p->:E:->] {
        del edg;
    }
    x = 7;
    del x;
    calls = [0];
    picked = {"k": N(8)};

    def pick() -> dict[any, any] {
        calls[0] = calls[0] + 1;
        return picked;
    }
    del pick()["k"];
    return {
        "d": d,
        "seq": seq,
        "span": span,
        "strided": strided,
        "edges": len([edge a->:E:->]),
        "kept": len([edge c->:E:->]),
        "holder": len(holder),
        "named": len([edge p->:E:->]),
        "x": x,
        "picked": len(picked),
        "calls": calls[0]
    };
}
