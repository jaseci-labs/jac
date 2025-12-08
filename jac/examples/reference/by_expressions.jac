# By as an operator
with entry {
    # Simple by expression
    result = "hello" by "world";
    print("Simple by:", result);

    # Chained by expressions (right-associative)
    result2 = "a" by "b" by "c";
    print("Chained by:", result2);

    # By with arithmetic expressions
    result3 = (1 + 2) by (3 * 4);
    print("Arithmetic by:", result3);

    # By in variable assignment
    x = "input" by "output";
    print("Assignment with by:", x);
}
