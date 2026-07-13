with entry {
    # A single expression statement is the implicit return.
    x = lambda (a: int, b: int) { b + a; };
    print(x(5, 4));
    # No-param single-expression lambda.
    y = lambda { 567; };
    print(y());
    # Multi-statement body -> value needs an explicit return.
    w = lambda (n: int) { m = n * 2; return m + 1; };
    print(w(3));
    # Multi-statement body with no return -> None.
    v = lambda (n: int) { a = n; b = n; };
    print(v(1));
}
