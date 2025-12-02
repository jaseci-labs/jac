"""Expressions: Ternary conditional (if-else) and lambda expressions."""

with entry {
    # Ternary conditional: expression if condition else expression
    x = 1 if 5 / 2 == 1 else 2;
    status = "adult" if 20 >= 18 else "minor";
    grade = "A" if 85 >= 90 else ("B" if 85 >= 80 else "C");

    # Lambda expressions: lambda params -> return_type : expression
    square = lambda  x: int: x ** 2;
    add = lambda  a: int , b: int: a + b;

    # Lambda with full type annotations
    multiply = lambda  x: int , y: int  -> int: x * y;

    # Lambda without params
    get_five = lambda : 5 ;

    # Combining ternary and lambda
    abs_val = lambda  n: int: (n if n >= 0 else -n);

    print(
        x,
        status,
        grade,
        square(5),
        add(3, 4),
        multiply(6, 7),
        get_five(),
        abs_val(-10)
    );
}
