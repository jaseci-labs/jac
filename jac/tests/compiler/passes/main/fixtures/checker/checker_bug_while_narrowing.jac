"""Bug: while-loop guard does not narrow the condition variable.

Root cause: _get_type_from_flow_node had no WhileStmt predecessor handler.
When walking the CFG backwards from inside the loop body, the checker
had no way to know that the loop body is the "true branch" of the while
condition. So `while item {` did not narrow `item` from `Item | None`
to `Item` inside the body.

Fix: Added a WhileStmt predecessor handler in _get_type_from_flow_node
(type_evaluator.impl.jac) that applies the condition predicate to the
first node of the loop body, mirroring the IfStmt true-branch handler.

All functions below should produce 0 errors after the fix.
"""

obj Item {
    has count: int = 0,
        prev: Item | None = None;
}

obj Wrapper {
    has label: str = "",
        next: Wrapper | None = None;
}

# Basic while truthiness: `while cur` narrows cur from Item|None to Item.
def sum_chain(start: Item | None) -> int {
    total = 0;
    cur = start;
    while cur {
        total += cur.count;   # cur: Item (not Item | None)
        cur = cur.prev;
    }
    return total;
}

# While is-not-None: explicit guard should narrow the same way.
def collect_labels(head: Wrapper | None) -> list[str] {
    result: list[str] = [];
    cur = head;
    while cur is not None {
        result.append(cur.label);  # cur: Wrapper
        cur = cur.next;
    }
    return result;
}
