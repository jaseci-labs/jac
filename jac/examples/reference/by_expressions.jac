# By as an operator

# Simple by expression
glob result = "hello" by "world";

with entry {
    print("Simple by:", result);
}

# Chained by expressions (right-associative)
glob result2 = "a" by "b" by "c";

with entry {
    print("Chained by:", result2);
}

# By with arithmetic expressions
glob result3 = (1 + 2) by (3 * 4);

with entry {
    print("Arithmetic by:", result3);
}

# By in variable assignment
glob x = "input" by "output";

with entry {
    print("Assignment with by:", x);
}
