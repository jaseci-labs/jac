# Arithmetic Expressions

# Addition and subtraction
with entry {
    print(10 + 5);
    print(10 - 5);

    # Multiplication and division
    print(10 * 5);
    print(10 / 5);
    print(10 // 3);
    print(10 % 3);

    # Exponentiation (power)
    print(2 ** 3);
    print(2 ** 3 ** 2);
}

# Unary operators
glob x = 5;

with entry {
    print(+x);
    print(-x);
    print(~x);

    # Combined operations
    print(2 + 3 * 4);
    print((2 + 3) * 4);
    print(10 - 3 + 2);
    print(10 / 2 * 3);
}

# Complex expression
glob result = 2 + 3 * 4 ** 2 - 10 / 2;

with entry {
    print(result);

    # Chained operations
    print(100 - 50 + 25 - 10);
    print(2 * 3 * 4 / 2);

    # Modulo and floor division
    print(17 // 5);
    print(17 % 5);

    # Precedence demonstration
    print(2 + 3 * 4);
    print(2 ** 3 * 4);
    print(10 / 2 + 5);
}
