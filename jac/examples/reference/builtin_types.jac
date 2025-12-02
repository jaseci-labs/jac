# Builtin Types
with entry {
    # str - string type
    s: str = "hello";
    print(s);

    # int - integer type
    i: int = 42;
    print(i);

    # float - floating point type
    f: float = 3.14;
    print(f);

    # list - list type
    lst: list = [1, 2, 3];
    print(lst);

    # tuple - tuple type
    tup: tuple = (1, 2, 3);
    print(tup);

    # set - set type
    st: set = {1,2,3};
    print(st);

    # dict - dictionary type
    dct: dict = {"key": "value"};
    print(dct);

    # bool - boolean type
    b: bool = True;
    print(b);

    # bytes - bytes type
    byt: bytes = b"binary";
    print(byt);

    # any - any type (accepts anything)
    a: any = "anything";
    print(a);
    a = 123;
    print(a);

    # type - type type (for type objects)
    t: type = str;
    print(t);

    # Type annotations in functions
    def typed_func(x: int, y: str) -> tuple {
        return (x, y);
    }

    result = typed_func(10, "test");
    print(result);
}
