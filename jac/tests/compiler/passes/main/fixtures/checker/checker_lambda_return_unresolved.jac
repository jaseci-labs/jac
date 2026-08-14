"""When a lambda argument's return type is genuinely unresolvable -- not
merely a bare-generic default -- E1054 should say so instead of the bare
"no matching overload found".

`Foo` is a plain, non-generic class with no `__getitem__` at all, so
`foo[x]` has no valid magic-method overload to resolve against and stays
Unknown for real. This is a distinct gap from the bare-`dict`-annotation
case (fixed by build_type_var_solution trusting a bare generic's
unresolved type params as `any`) -- `Foo` has no type params to default,
so that fix doesn't touch this path.
"""

obj Foo {}

with entry {
    xs: list[int] = [3, 1, 2];
    foo = Foo();

    a = sorted(xs, key=lambda x: int : foo[x]);

    print(a);
}
