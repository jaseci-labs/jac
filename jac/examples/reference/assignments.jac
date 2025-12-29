# Assignments

# Simple assignment
glob x = 10;

with entry {
    print(x);
}

# Chain assignment
glob a = b=c=20;

with entry {
    print(f"{a} {b} {c}");
}

# Let keyword
glob value = 100;

with entry {
    print(value);
}

# Type annotation with value
glob age: int = 25,
     name: str = "Alice";

with entry {
    print(f"{age} {name}");

    # Type annotation without initial value
    result: str;
}

glob result = "computed";

with entry {
    print(result);
}

# Let with type
glob count: int = 5;

with entry {
    print(count);
}

# Augmented arithmetic assignments
glob num = 10;

with entry {
    num += 5;
    num -= 3;
    num *= 2;
    num /= 4;
    num %= 5;
    num **= 2;
    num //= 3;
    print(num);
}

# Augmented bitwise assignments
glob bits = 12;

with entry {
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
