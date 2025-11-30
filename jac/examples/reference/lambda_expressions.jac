# Lambda Expressions
with entry {
    # Lambda with parameters and return hint
    add = lambda  a: int , b: int  -> int: a + b;
    print(add(5, 3));

    # Lambda without parameters
    get_value = lambda : 42 ;
    print(get_value());

    # Lambda without return hint
    multiply = lambda  x: int , y: int: x * y;
    print(multiply(4, 5));

    # Lambda with only return hint
    get_default = lambda   -> int: 100 ;
    print(get_default());

    # Lambda with default parameters
    power = lambda  x: int = 2 , y: int = 3: x ** y;
    print(power());
    print(power(5));
    print(power(5, 2));

    # Lambda as argument to function
    numbers = [1, 2, 3, 4, 5];
    squared = list(map(lambda  x: int: x ** 2, numbers));
    print(squared);

    # Lambda in filter
    evens = list(filter(lambda  x: int: x % 2 == 0, numbers));
    print(evens);

    # Lambda with conditional expression
    max_val = lambda  a: int , b: int: a if a > b else b;
    print(max_val(10, 20));
    print(max_val(30, 15));

    # Lambda returning lambda
    make_adder = lambda  x: int: (lambda  y: int: x + y);
    add_five = make_adder(5);
    print(add_five(10));

    # Lambda in sort key
    words = ["apple", "pie", "a", "cherry"];
    sorted_words = sorted(words, key=lambda  s: str: len(s));
    print(sorted_words);
}
