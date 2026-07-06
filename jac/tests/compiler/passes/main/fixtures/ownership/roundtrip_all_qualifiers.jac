obj Buffer {
    has n: int = 0;
}

def use_shared(v: &Buffer) -> None {}

def use_mut(m: &mut Buffer) -> None {}

with entry {
    a: own Buffer = Buffer();
    v: &Buffer = &a;
    use_shared(v);
    b: own Buffer = Buffer();
    m: &mut Buffer = &mut b;
    use_mut(m);
    w: val Buffer = Buffer();
}
