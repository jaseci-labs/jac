"""The bare-generic-default-any fix must land in the shared `assign_type`
strict-mode rule, not just in `sorted`/`.sort`'s Callable-return checking.

This is the same underlying failure as the `sorted`/`.sort` lambda-key bug
(bare `dict`'s `_VT` defaults to `any`, but strict-mode `assign_type`
refuses to trust that `any` against a non-TypeVar destination), reached
through a plain direct call instead of an overloaded Callable parameter.
Confirms the fix isn't scoped narrowly enough to make `sorted` pass while
leaving every other strict-mode call site broken.
"""

def needs_int(x: int) -> int {
    return x;
}

with entry {
    rows: list[dict] = [{"n": 1}];
    d: dict = rows[0];

    result = needs_int(d["n"]);

    print(result);
}
