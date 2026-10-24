"""The move-at-last-use fixture with an RC live-object dump at exit."""

obj Node {
    has v: int = 0,
        next: Node | None = None;
}

def append(head: Node, extra: Node) -> int {
    extra.next = None;
    p: Node = head;
    nxt = p.next;
    while nxt is not None {
        p = nxt;
        nxt = p.next;
    }
    p.next = extra;
    return p.v;
}

def cut(head: Node) -> int {
    p: Node = head;
    nxt = p.next;
    while nxt is not None {
        if nxt.next is None {
            p.next = None;
            return nxt.v;
        }
        p = nxt;
        nxt = p.next;
    }
    return -1;
}

def rotate(n: int) -> int {
    a = Node(v=1);
    b = Node(v=2);
    c = Node(v=3);
    total = 0;
    for i in range(n) {
        t = a;
        a = b;
        b = c;
        c = t;
        total += a.v * (i + 1);
    }
    return total + a.v * 100 + b.v * 10 + c.v;
}

def weigh(x: Node) -> int {
    return x.v * 2;
}

def after_call(n: int) -> int {
    a = Node(v=n);
    w = weigh(a);
    b = a;
    return w + b.v;
}

def after_field(n: int) -> int {
    h = Node(v=100);
    a = Node(v=n);
    h.next = a;
    b = a;
    b.v += 1;
    nx = h.next;
    if nx is None {
        return -1;
    }
    return nx.v + b.v;
}

def keep_after(n: int) -> int {
    a = Node(v=n);
    b = a;
    a.v += 1;
    return a.v + b.v;
}

def in_try(n: int) -> int {
    a = Node(v=n);
    try {
        b = a;
        if n % 2 == 0 {
            raise ValueError("even");
        }
        return b.v;
    } except ValueError {
        return a.v * 10;
    }
}

def run -> int {
    head = Node(v=0);
    cur = head;
    for k in range(1, 20) {
        nd = Node(v=k);
        cur.next = nd;
        cur = nd;
    }
    extra = Node(v=99);
    total = 0;
    for s in range(30) {
        total += append(head, extra) + cut(head);
    }
    total += rotate(50);
    for i in range(6) {
        total += keep_after(i) + in_try(i) + after_call(i) + after_field(i);
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
