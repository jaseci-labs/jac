obj fruit {
    has name: str,
        color: str;
}

glob a: list[fruit] = [
    fruit(name="apple", color="red"),
    fruit(name="banana", color="yellow"),
    fruit(name="grape", color="purple")
];

glob b: dict[str, fruit] = {
    "a": fruit(name="apple", color="red"),
    "b": fruit(name="banana", color="yellow"),
    "c": fruit(name="grape", color="purple")
};

def foo(a: list[fruit]) -> list[fruit] {
    return a[0:2];
}

with entry {
    fruit_1 = a[0];
    clr_1 = a[0].color;
    clr_1 = b["a"].color;
    f_clr = foo(a);
    f_clrw = foo(a)[0];
    f_clrw2 = foo(a)[0:1][0].color;
    # print(foo(a)[0].color);
}
