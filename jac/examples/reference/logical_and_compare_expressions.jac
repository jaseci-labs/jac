# Logical and Compare Expressions

# Comparison operators
with entry {
    print(5 > 4);
    print(5 >= 5);
    print(3 < 10);
    print(3 <= 3);
    print(5 == 5);
    print(5 != 3);
}

# Identity operators
glob a = [1, 2, 3],
     b = [1, 2, 3],
     c = a;

with entry {
    print(a is b);
    print(a is c);
    print(a is not b);

    # Membership operators
    print(3 in a);
    print(5 in a);
    print(5 not in a);

    # Logical AND
    print(True and True);
    print(True and False);
    print(False and False);

    # Logical OR
    print(True or False);
    print(False or False);
    print(True or True);

    # Logical NOT
    print(not True);
    print(not False);
}

# Chained comparisons
glob x = 15;

with entry {
    print(10 < x < 20);
    print(0 <= x <= 100);
    print(x > 20 or x < 5);

    # Complex expressions
    print((5 > 3) and (10 < 20));
    print((5 > 10) or (3 < 7));
    print(not (5 > 10));

    # Multiple comparisons
    print(1 < 2 < 3 < 4);
    print(10 >= 10 >= 10);

    # Combined logical operators
    print(True and True and True);
    print(False or False or True);
    print((True and False) or (False and True));
}
