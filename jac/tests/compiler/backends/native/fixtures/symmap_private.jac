"""Linked lists of objects with string fields: every node goes through the
runtime's private refcount helpers when the list is dropped."""

obj Node {
    has val: int = 0,
        label: str = "",
        next: Node | None = None;
}

def churn(rounds: int, width: int) -> int {
    labels: list[str] = ["alpha", "beta", "gamma", "delta"];
    total = 0;
    for r in range(rounds) {
        head: Node | None = None;
        for i in range(width) {
            head = Node(val=i, label=labels[i % 4], next=head);
        }
        cur = head;
        while cur is not None {
            total = total + cur.val + len(cur.label);
            cur = cur.next;
        }
    }
    return total;
}

with entry {
    print(churn(3, 100));
}
