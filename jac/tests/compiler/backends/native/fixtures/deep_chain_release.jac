"""Deep-release stack-safety fixture (7446a).

Builds a very long singly-linked chain and then lets it drop at scope exit.
Releasing the head recursively releases each `nxt` field, so a naive inline
recursive destructor would consume one C-stack frame per node and overflow the
stack on teardown. The iterative deep-release worklist keeps that teardown
O(1)-stack, so this program must run to completion even under a tiny stack
limit (the test harness runs it with a reduced RLIMIT_STACK).

The outer loop rebuilds and drops the chain repeatedly so that, without a GC,
every iteration's chain leaks and peak RSS balloons — while with the GC on the
chain is fully reclaimed each iteration and RSS stays flat.
"""

obj Node {
    has nxt: Node | None = None;
    has val: int = 0;
}

def build(n: int) -> Node {
    head: Node = Node();
    i: int = 1;
    while i < n {
        nn: Node = Node(val=i);
        nn.nxt = head;
        head = nn;
        i += 1;
    }
    return head;
}

def chain_len(h: Node) -> int {
    c: int = 0;
    cur: Node | None = h;
    while cur is not None {
        c += 1;
        cur = cur.nxt;
    }
    return c;
}

with entry {
    total: int = 0;
    r: int = 0;
    while r < 400 {
        h: Node = build(300000);
        total += chain_len(h);
        r += 1;
    }
    print("OK deep_chain_release total =", total);
}
