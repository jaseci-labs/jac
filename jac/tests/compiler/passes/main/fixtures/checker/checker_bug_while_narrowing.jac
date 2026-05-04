obj Item {
    has count: int = 0,
        prev: Item | None = None;
}

obj Wrapper {
    has label: str = "",
        next: Wrapper | None = None;
}

def sum_chain(start: Item | None) -> int {
    total = 0;
    cur = start;
    while cur {
        total += cur.count;   # cur: Item (not Item | None)
        cur = cur.prev;
    }
    return total;
}

def collect_labels(head: Wrapper | None) -> list[str] {
    result: list[str] = [];
    cur = head;
    while cur is not None {
        result.append(cur.label);  # cur: Wrapper
        cur = cur.next;
    }
    return result;
}
