"""Container repr cross-backend equivalence fixture (#7593 item 5).

Pins CPython repr text for containers against the native repr family.
Set fixtures use ascending small ints so CPython's hash order coincides
with native insertion order. ES/JS opts out.
"""

def repr_py -> dict {
    lst: list[int] = [1, 2, 3];
    empty: list[int] = [];
    nested: list[list[int]] = [[1, 2], [3]];
    quoting: list[str] = ["a", "b'c"];
    dct: dict[str, int] = {"a": 1, "b": 2};
    st: set[int] = {1, 2, 3};
    tup: tuple[int, str] = (1, "x");
    bools: list[bool] = [True, False];
    floats: list[float] = [1.0, 2.5];
    fs: list[int] = [1, 2];
    return {
        "lst": str(lst),
        "empty": str(empty),
        "nested": str(nested),
        "quoting": str(quoting),
        "dct": str(dct),
        "st": str(st),
        "tup": str(tup),
        "bools": str(bools),
        "floats": str(floats),
        "fstr": f"v={fs}",
    };
}

cl def repr_cl -> dict {
    return {};
}

na {
    def repr_na -> dict[str, any] {
        lst: list[int] = [1, 2, 3];
        empty: list[int] = [];
        nested: list[list[int]] = [[1, 2], [3]];
        quoting: list[str] = ["a", "b'c"];
        dct: dict[str, int] = {"a": 1, "b": 2};
        st: set[int] = {1, 2, 3};
        tup: tuple[int, str] = (1, "x");
        bools: list[bool] = [True, False];
        floats: list[float] = [1.0, 2.5];
        fs: list[int] = [1, 2];
        return {
            "lst": str(lst),
            "empty": str(empty),
            "nested": str(nested),
            "quoting": str(quoting),
            "dct": str(dct),
            "st": str(st),
            "tup": str(tup),
            "bools": str(bools),
            "floats": str(floats),
            "fstr": f"v={fs}",
        };
    }
}
