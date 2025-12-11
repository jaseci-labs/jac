with entry {
    x = lambda  a: int , b: int: b + a;
    print(x(5, 4));
    y = lambda : 567 ;
    print(y());
}

with entry {
    f = lambda  x: Any: "even" if x % 2 == 0 else "odd";
    print(f(7));
}
