# Assignments
with entry {
    # Simple assignment
    x = 10;
    print(x);

    # Chain assignment
    a = b=c=20;
    print(f"{a} {b} {c}");

    # Let keyword
    let value = 100;
    print(value);

    # Type annotation with value
    age: int = 25;
    name: str = "Alice";
    print(f"{age} {name}");

    # Type annotation without initial value
    result: str;
    result = "computed";
    print(result);

    # Let with type
    let count: int = 5;
    print(count);

    # Augmented arithmetic assignments
    num = 10;
    num += 5;
    num -= 3;
    num *= 2;
    num /= 4;
    num %= 5;
    num **= 2;
    num //= 3;
    print(num);

    # Augmented bitwise assignments
    bits = 12;
    bits &= 7;
    bits |= 3;
    bits ^= 5;
    bits <<= 2;
    bits >>= 1;
    print(bits);

    # Tuple unpacking
    (x, y) = (10, 20);
    print(f"{x} {y}");

    # Swap
    (x, y) = (y, x);
    print(f"{x} {y}");

    # List unpacking
    [p, q, r] = [1, 2, 3];
    print(f"{p} {q} {r}");

    # Nested unpacking
    (m, (n, o)) = (5, (6, 7));
    print(f"{m} {n} {o}");

    # Extended unpacking with *
    (first, *rest) = [1, 2, 3, 4, 5];
    print(f"{first} {rest}");

    (head, *middle, tail) = [10, 20, 30, 40, 50];
    print(f"{head} {middle} {tail}");

    (*beginning, last) = [100, 200, 300];
    print(f"{beginning} {last}");
}
