"""Test that walker traversal works on graphs deeper than Python's recursion limit.

Builds a linked list of 1500 nodes (exceeds default sys.getrecursionlimit=1000)
and walks it end-to-end. With recursive DFS this would hit RecursionError;
with iterative DFS it completes successfully.
"""

node Item {
    has value: int;
}

edge Next {}

walker Traverse {
    has count: int = 0;

    can start with Root entry {
        visit [-->];
    }

    can visit_item with Item entry {
        self.count += 1;
        visit [->:Next:->];
    }
}

with entry {
    LIST_SIZE = 1500;
    head = Item(value=0);
    root ++> head;

    prev = head;
    for i in range(1, LIST_SIZE) {
        curr = Item(value=i);
        prev +>: Next :+> curr;
        prev = curr;
    }

    result = root spawn Traverse();
    print(result.count);
    assert result.count == LIST_SIZE, f"Expected {LIST_SIZE} but visited {result.count}";
}
