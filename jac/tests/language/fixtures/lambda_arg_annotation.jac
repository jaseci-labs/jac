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
    print("g:" + str(g([10, 20])));
    h = lambda d: dict[str, int] : d["n"];
    print("h:" + str(h({"n": 42})));
    k = lambda v: int | str : v;
    print("k:" + str(k(7)));
}

# Regression: bodies containing arithmetic, calls, subscripts, or unary ops
# must NOT be misread as type annotations.
with entry {
    # arithmetic body — `x * 2` must not be read as a type
    r1 = sorted([30, 10, 20], key=lambda x: x * 2);
    print(r1[0]);

    # function call + comparison body — `len(s) > 2` must not be read as a type
    r2 = list(filter(lambda s: len(s) > 2, ["a", "bb", "ccc", "dddd"]));
    print(r2[0]);

    # subscript body — `d["active"]` must not be read as a type
    rows: list[dict[str, any]] = [{"active": True, "n": 99}, {"active": False, "n": 2}];
    r3 = list(filter(lambda d: d["active"], rows));
    print(r3[0]["n"]);

    # unary body — `-x` must not be read as a type
    r4 = list(map(lambda x: -x, [5, 6, 7]));
    print(r4[0]);

    # list of lambdas — scan must not cross sibling lambda boundary
    fns: list = [lambda x: x * 2, lambda y: y + 3];
    print(fns[0](4));
    print(fns[1](4));
}
