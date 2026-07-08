"""When a lambda argument's return type is genuinely unresolvable -- not
merely a bare-generic default -- E1054 should say so instead of the bare
"no matching overload found".

`mystery` is inferred from an empty `{}` literal with no surrounding
context, so its key/value types stay Unknown; indexing into it is a
distinct gap from the bare-`dict`-annotation case and is expected to
remain Unknown even after that fix lands.
"""

with entry {
    xs: list[int] = [3, 1, 2];
    mystery = {};

    a = sorted(xs, key=lambda x: int : mystery[x]);

    print(a);
}
