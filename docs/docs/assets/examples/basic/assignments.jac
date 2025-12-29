glob a = b=16,
     c = 18;

with entry {
    print(a, b, c);
    a >>= 2;
    print(a);
    a <<= 2;
    print(a);
    c //= 4;
    print(c);
}
