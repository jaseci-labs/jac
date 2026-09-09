"""The canonical owned singly linked list: push through a `&mut` parameter with
`take()` moving the old head, reverse in place with `take()` and `swap()`, walk
by recursive borrow (#8984 A1b, rule 3)."""

obj Node { has v: int = 0, next: own Node | None = None; }
obj List { has head: own Node | None = None; }

def push_front(l: &mut List, v: int) {
    l.head = Node(v=v, next=take(l.head));
}

def reverse(l: &mut List) {
    prev: own Node | None = None;
    cur: own Node | None = take(l.head);
    while cur is not None {
        nxt = take(cur.next);
        cur.next = prev;
        prev = cur;
        cur = nxt;
    }
    l.head = prev;
}

def first_v(l: &List) -> int {
    return l.head.v if l.head is not None else -1;
}

def sum_rec(n: &Node | None) -> int {
    if n is None { return 0; }
    return n.v + sum_rec(&n.next);
}

def run -> int {
    l: own List = List();
    for i in range(5) { push_front(&mut l, i); }
    total = sum_rec(&l.head);
    head_before = first_v(&l);
    reverse(&mut l);
    head_after = first_v(&l);
    other: own List = List();
    push_front(&mut other, 9);
    swap(&mut l.head, &mut other.head);
    return total * 1000 + head_before * 100 + head_after * 10 + first_v(&l);
}

with entry { print(run()); }
