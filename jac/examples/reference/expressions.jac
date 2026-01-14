"""Expressions: Ternary conditional (if-else) and lambda expressions."""

# Ternary conditional: expression if condition else expression
glob x = 1
     if 5 / 2 == 1
     else 2,
     status = "adult" if 20 >= 18 else "minor",
     grade = "A" if 85 >= 90 else ("B" if 85 >= 80 else "C"),
     square = lambda x: int : x ** 2,
     add = lambda a: int , b: int : a + b,
     multiply = lambda x: int , y: int  -> int : x * y,
     get_five = lambda : 5 ,
     abs_val = lambda n: int : (n if n >= 0 else -n);

with entry {
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
# Lambda expressions: lambda params -> return_type : expression

# Lambda with full type annotations

# Lambda without params

# Combining ternary and lambda
