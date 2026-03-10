"""Bug #8: DictVal, TupleVal, SetVal have no type inference — return UnknownType.

There are no cases for these collection literal types in
_get_type_of_expression_core, so they fall through to UnknownType.
This means type errors involving dict/tuple/set literals go undetected.

Expected: dict literals should infer as dict, tuple as tuple, set as set.
"""

with entry {
    # Dict literal should be dict[str, int]
    d = {"a": 1, "b": 2};
    check_d: dict = d;  # <-- Should be Ok (dict -> dict)
    check_d_wrong: str = d;  # <-- Should be Error (dict not assignable to str)

    # Tuple literal should be tuple[int, str, ...]
    t = (1, "hello", 3.14);
    check_t: tuple = t;  # <-- Should be Ok
    check_t_wrong: str = t;  # <-- Should be Error (tuple not assignable to str)

    # Set literal should be set[int]
    s = {1, 2, 3};
    check_s_wrong: str = s;  # <-- Should be Error (set not assignable to str)
}
