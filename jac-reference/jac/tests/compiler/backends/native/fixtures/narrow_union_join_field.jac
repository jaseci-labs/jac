"""N4: reading and iterating a field off a union-joined narrow.

`UniScopeNode._fix_store_ctx` wants one arm for the two node kinds that carry
a `values` list:

    } elif isinstance(item, (TupleVal, ListVal)) {
        for i in item.values { ... }

The narrow here is not a single class -- it is the union `TupleVal | ListVal`
-- and the consumer is a field read whose result is then iterated. The
workaround split the arm in two and hoisted the loop into a helper taking
`Sequence[UniNode]`, which turns the question back into a single-class narrow
plus an ordinary parameter.

The loop body's own dispatch is kept because it is where a dropped element
type shows up: each element is narrowed again and a wrong answer is a wrong
sum, not a compile failure.
"""

obj Item {
    has n: int = 0;
}


obj Named(Item) {
    has extra: int = 0;
}


obj TupleVal {
    has values: list[Item] = [];
}


obj ListVal {
    has values: list[Item] = [];
}


obj UnaryExpr {
    has operand: Item;
}


"""1 -> tuple, 2 -> list, 3 -> unary, 4 -> a tuple of `Named`, else unset."""
def mk_item(pick: int) -> TupleVal | ListVal | UnaryExpr | None {
    if pick == 1 {
        return TupleVal(values=[Item(n=1), Item(n=2)]);
    }
    if pick == 2 {
        return ListVal(values=[Item(n=10), Item(n=20), Item(n=30)]);
    }
    if pick == 3 {
        return UnaryExpr(operand=Item(n=7));
    }
    if pick == 4 {
        return TupleVal(values=[Named(n=100, extra=5), Item(n=1)]);
    }
    return None;
}


"""`_fix_store_ctx` as it wants to be written: one arm over the joined union."""
def fix_store_joined(pick: int) -> int {
    item = mk_item(pick);
    total = 0;
    if isinstance(item, UnaryExpr) {
        total += item.operand.n;
    } elif isinstance(item, (TupleVal, ListVal)) {
        for i in item.values {
            if isinstance(i, Named) {
                total += i.extra;
            }
            total += i.n;
        }
    }
    return total;
}


"""The same answer with the union split and the loop in a helper (workaround)."""
def _fix_store_items(items: list[Item]) -> int {
    total = 0;
    for i in items {
        if isinstance(i, Named) {
            total += i.extra;
        }
        total += i.n;
    }
    return total;
}


def fix_store_split(pick: int) -> int {
    item = mk_item(pick);
    total = 0;
    if isinstance(item, UnaryExpr) {
        total += item.operand.n;
    } elif isinstance(item, TupleVal) {
        total += _fix_store_items(`list(item.values));
    } elif isinstance(item, ListVal) {
        total += _fix_store_items(`list(item.values));
    }
    return total;
}


"""A bare field read off the joined narrow, with no loop in the way."""
def joined_field_len(pick: int) -> int {
    item = mk_item(pick);
    if isinstance(item, (TupleVal, ListVal)) {
        return len(item.values);
    }
    return -1;
}


"""The joined narrow reached through the `and` of the same condition."""
def joined_field_and(pick: int) -> int {
    item = mk_item(pick);
    if isinstance(item, (TupleVal, ListVal)) and item.values {
        return item.values[0].n;
    }
    return -1;
}
