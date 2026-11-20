"""A store into an own-typed field still consumes the source binding."""

obj Buffer {
    has n: int = 0;
}

obj Holder {
    has ref: own Buffer = Buffer();
}

with entry {
    a: own Buffer = Buffer();
    h: own Holder = Holder();
    h.ref = a;
    print(a);
}
