# na cliff: method/field on T|None receiver silently dropped. jac-py core site:
# find_cell/find_handler/deref_cell -> PyCell|None then .val. Memory:
# na-method-call-on-union-receiver.
obj Cell {
    has val: int;
}

def find_cell(hit: bool) -> Cell | None {
    if hit {
        return Cell(val=7);
    }
    return None;
}

def use -> int {
    c = find_cell(True);
    if c is None {
        return -1;
    }
    return c.val;
}

with entry {
    print(use());
}
