with entry {
    x = lambda  a: int , b: int: b + a;
    print(x(5, 4));
    y = lambda : 567 ;
    print(y());
}

with entry {
    f = lambda  x: any: "even" if x % 2 == 0 else "odd";
    print(f(7));
}

with entry {
    g = lambda d: list[int] : d[0];
    print(g([10, 20]));
    h = lambda d: dict[str, int] : d["n"];
    print(h({"n": 42}));
    k = lambda v: int | str : v;
    print(k(7));
}
