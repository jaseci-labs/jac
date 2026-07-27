obj Buffer {}

with entry {
    a: own Buffer = Buffer();
    if len("x") > 0 {
        b = a;
    }
    print(a);
}
