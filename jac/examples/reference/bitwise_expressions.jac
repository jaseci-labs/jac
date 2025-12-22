# Bitwise Expressions

# Bitwise OR
with entry {
    print(5 | 3);
    print(12 | 7);

    # Bitwise XOR
    print(5 ^ 3);
    print(12 ^ 7);

    # Bitwise AND
    print(5 & 3);
    print(12 & 7);

    # Left shift
    print(5 << 1);
    print(5 << 2);

    # Right shift
    print(10 >> 1);
    print(10 >> 2);

    # Bitwise NOT (unary)
    print(~5);
    print(~0);
    print(~-1);

    # Combined bitwise operations
    print((8 | 4) & 12);
    print(5 ^ 3 & 7);

    # Chained operations
    print(15 & 7 | 8);
    print(5 << 1 >> 1);
}

# Complex expression
glob result = (12 | 5) & (7 ^ 3);

with entry {
    print(result);
}
