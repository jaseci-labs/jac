"""Freeing objects that sit in the cycle collector's root buffer.

Each round passes nodes of a type that can form cycles through a field, so
their releases leave them alive and buffer them as possible roots, then drops
the list: every node's last release frees an object in the buffer, which
clears its slot there. Some rounds also build real cycles, which only the
collector can free, so collections run between the frees and the buffer is
reused.
"""

obj Node {
    has v: int = 0,
        next: Node | None = None;
}

obj Holder {
    has cur: Node | None = None;
}

def churn(rounds: int, width: int) -> int {
    h = Holder();
    total = 0;
    for r in range(rounds) {
        nodes: list[Node] = [];
        for i in range(width) {
            nodes.append(Node(v=i));
        }
        for i in range(width) {
            h.cur = nodes[i];
            total += nodes[i].v;
        }
        if r % 3 == 0 {
            for i in range(0, width - 1, 2) {
                nodes[i].next = nodes[i + 1];
                nodes[i + 1].next = nodes[i];
            }
        }
        h.cur = None;
        nodes = [];
    }
    return total;
}

with entry {
    print(churn(60, 300));
    print(churn(7, 4100));
}
