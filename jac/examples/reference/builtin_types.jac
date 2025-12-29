# Builtin Types

# str - string type
glob s: str = "hello";

with entry {
    print(s);
}

# int - integer type
glob i: int = 42;

with entry {
    print(i);
}

# float - floating point type
glob f: float = 3.14;

with entry {
    print(f);
}

# list - list type
glob lst: list = [1, 2, 3];

with entry {
    print(lst);
}

# tuple - tuple type
glob tup: tuple = (1, 2, 3);

with entry {
    print(tup);
}

# set - set type
glob st: set = {1,2,3};

with entry {
    print(st);
}

# dict - dictionary type
glob dct: dict = {"key": "value"};

with entry {
    print(dct);
}

# bool - boolean type
glob b: bool = True;

with entry {
    print(b);
}

# bytes - bytes type
glob byt: bytes = b"binary";

with entry {
    print(byt);
}

# any - any type (accepts anything)
glob a: any = "anything";

with entry {
    print(a);
}

glob a = 123;

with entry {
    print(a);
}

# type - type type (for type objects)
glob t: type = str;

with entry {
    print(t);
}

# Type annotations in functions
def typed_func(x: int, y: str) -> tuple {
    return (x, y);
}

glob result = typed_func(10, "test");

with entry {
    print(result);
}
