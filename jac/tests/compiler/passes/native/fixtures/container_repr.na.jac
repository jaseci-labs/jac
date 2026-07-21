"""Container repr fixtures (#7593 item 5): str/print/f-string of containers
must produce CPython-exact repr text."""

def list_int_str -> str {
    x: list[int] = [1, 2, 3];
    return str(x);
}

def list_empty_str -> str {
    x: list[int] = [];
    return str(x);
}

def nested_list_str -> str {
    x: list[list[int]] = [[1, 2], [3]];
    return str(x);
}

def list_str_quoting -> str {
    x: list[str] = ["a", "b'c", 'd"e'];
    return str(x);
}

def dict_str -> str {
    d: dict[str, int] = {"a": 1, "b": 2};
    return str(d);
}

def set_str -> str {
    s: set[int] = {1, 2, 3};
    return str(s);
}

def tuple_str -> str {
    t: tuple[int, str] = (1, "x");
    return str(t);
}

def one_tuple_str -> str {
    t: tuple[int] = (1, );
    return str(t);
}

def bool_list_str -> str {
    x: list[bool] = [True, False];
    return str(x);
}

def opt_str_list -> str {
    x: list[str | None] = ["a", None];
    return str(x);
}

def float_list_str -> str {
    x: list[float] = [1.0, 2.5, 1e300];
    return str(x);
}

def fstr_container -> str {
    x: list[int] = [1, 2];
    return f"v={x}";
}

obj P {
    has n: int;

    def __repr__ -> str {
        return f"P({self.n})";
    }
}

obj Plain {
    has n: int;
}

def obj_elem_repr -> str {
    return str([P(n=1)]);
}

def obj_elem_default -> str {
    return str([Plain(n=1)]);
}

with entry {
    x: list[int] = [1, 2, 3];
    print(x);
    print((1, 2));
}
