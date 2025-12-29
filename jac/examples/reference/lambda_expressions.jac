# Lambda Expressions

# Lambda with parameters and return hint
glob add = lambda  a: int , b: int  -> int:
         a + b;

with entry {
    print(add(5, 3));
}

# Lambda without parameters
glob get_value = lambda : 42 ;

with entry {
    print(get_value());
}

# Lambda without return hint
glob multiply = lambda  x: int , y: int: x * y;

with entry {
    print(multiply(4, 5));
}

# Lambda with only return hint
glob get_default = lambda   -> int: 100 ;

with entry {
    print(get_default());
}

# Lambda with default parameters
glob power = lambda  x: int = 2 , y: int = 3:
         x ** y;

with entry {
    print(power());
    print(power(5));
    print(power(5, 2));
}

# Lambda as argument to function
glob numbers = [1, 2, 3, 4, 5],
     squared = list(map(lambda  x: int: x ** 2, numbers));

with entry {
    print(squared);
}

# Lambda in filter
glob evens = list(filter(lambda  x: int: x % 2 == 0, numbers));

with entry {
    print(evens);
}

# Lambda with conditional expression
glob max_val = lambda  a: int , b: int:
         a if a > b else b;

with entry {
    print(max_val(10, 20));
    print(max_val(30, 15));
}

# Lambda returning lambda
glob make_adder = lambda  x: int: (lambda  y: int: x + y),
     add_five = make_adder(5);

with entry {
    print(add_five(10));
}

# Lambda in sort key
glob words = ["apple", "pie", "a", "cherry"],
     sorted_words = sorted(words, key=lambda  s: str: len(s));

with entry {
    print(sorted_words);
}
