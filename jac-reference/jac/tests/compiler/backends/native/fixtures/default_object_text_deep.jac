"""Default object text has no nesting limit, and still stops at a cycle."""

obj Link {
    has label: int,
        after: Link | None = None;
}

def chain(length: int) -> Link {
    head = Link(label=0);
    tail = head;
    for i in range(1, length) {
        nxt = Link(label=i);
        tail.after = nxt;
        tail = nxt;
    }
    return head;
}

def last(head: Link) -> Link {
    at = head;
    while at.after is not None {
        at = at.after;
    }
    return at;
}

def nth(head: Link, n: int) -> Link {
    at = head;
    for i in range(n) {
        if at.after is not None {
            at = at.after;
        }
    }
    return at;
}

with entry {
    straight = chain(80);
    text = str(straight);
    print(len(text), text.count("Link("), text.count("..."));
    looped = chain(80);
    last(looped).after = nth(looped, 70);
    text = str(looped);
    print(len(text), text.count("Link("), text.count("..."));
    print(text[-60:]);
    again = str(straight);
    print(again == str(straight), len(again));
}
