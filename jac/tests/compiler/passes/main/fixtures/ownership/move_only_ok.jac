obj Buffer {}

with entry {
    a: own Buffer = Buffer();
    b = a;
    print(b);
}
