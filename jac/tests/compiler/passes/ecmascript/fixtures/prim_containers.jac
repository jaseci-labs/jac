"""Container operator primitives: list, str, tuple, dict operators."""

def containers_py() -> dict {
    a: list = [1, 2];
    b: list = [3, 4];
    s: str = "hello";
    t: tuple = (10, 20);
    d1: dict = {"x": 1};
    d2: dict = {"y": 2};

    # list operators
    list_concat: list = a + b;
    list_in: bool = 1 in a;
    list_nin: bool = 5 not in a;

    # str operators
    str_concat: str = s + "world";
    str_repeat: str = s * 3;
    str_in: bool = "ell" in s;
    str_nin: bool = "xyz" not in s;

    # tuple operators
    tuple_concat: list = list(t + (30,));
    tuple_in: bool = 10 in t;
    tuple_nin: bool = 99 not in t;

    # dict operators
    dict_merge: dict = d1 | d2;
    dict_in: bool = "x" in d1;
    dict_nin: bool = "z" not in d1;

    # dict |= (in-place merge)
    d3: dict = {"a": 1, "b": 2};
    d3 |= {"b": 99, "c": 3};

    # augmented assignment
    c: list = [10, 20];
    c += [30, 40];

    return {
        "list_concat": list_concat,
        "list_in": list_in,
        "list_nin": list_nin,
        "str_concat": str_concat,
        "str_repeat": str_repeat,
        "str_in": str_in,
        "str_nin": str_nin,
        "tuple_concat": tuple_concat,
        "tuple_in": tuple_in,
        "tuple_nin": tuple_nin,
        "dict_merge": dict_merge,
        "dict_in": dict_in,
        "dict_nin": dict_nin,
        "dict_ior": d3,
        "list_iadd": c
    };
}

cl def containers_cl() -> dict {
    a: list = [1, 2];
    b: list = [3, 4];
    s: str = "hello";
    t: tuple = (10, 20);
    d1: dict = {"x": 1};
    d2: dict = {"y": 2};

    # list operators
    list_concat: list = a + b;
    list_in: bool = 1 in a;
    list_nin: bool = 5 not in a;

    # str operators
    str_concat: str = s + "world";
    str_repeat: str = s * 3;
    str_in: bool = "ell" in s;
    str_nin: bool = "xyz" not in s;

    # tuple operators
    tuple_concat: list = list(t + (30,));
    tuple_in: bool = 10 in t;
    tuple_nin: bool = 99 not in t;

    # dict operators
    dict_merge: dict = d1 | d2;
    dict_in: bool = "x" in d1;
    dict_nin: bool = "z" not in d1;

    # dict |= (in-place merge)
    d3: dict = {"a": 1, "b": 2};
    d3 |= {"b": 99, "c": 3};

    # augmented assignment
    c: list = [10, 20];
    c += [30, 40];

    return {
        "list_concat": list_concat,
        "list_in": list_in,
        "list_nin": list_nin,
        "str_concat": str_concat,
        "str_repeat": str_repeat,
        "str_in": str_in,
        "str_nin": str_nin,
        "tuple_concat": tuple_concat,
        "tuple_in": tuple_in,
        "tuple_nin": tuple_nin,
        "dict_merge": dict_merge,
        "dict_in": dict_in,
        "dict_nin": dict_nin,
        "dict_ior": d3,
        "list_iadd": c
    };
}
