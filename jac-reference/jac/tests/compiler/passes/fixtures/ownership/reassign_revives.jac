obj Buffer {}

with entry {
    a: own Buffer = Buffer();
    b = a;
    a = Buffer();
    print(a);
}
