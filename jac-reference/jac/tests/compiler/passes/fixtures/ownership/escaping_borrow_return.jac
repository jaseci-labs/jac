obj Buffer { has n: int = 0; }

def borrow_and_return() -> Buffer {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    return v;
}

with entry {
    r = borrow_and_return();
}
