"""`sorted`/`.sort` with an inline `key=lambda d: dict : ...` over
`list[dict]` must type-check.

A bare `dict` param annotation has no type args, so `d["n"]` used to
resolve to Unknown (nothing was ever substituted for the unbound `_VT`
type var), which made the lambda's return type Unknown and killed every
`sorted`/`.sort` overload. The W1036 warning already claims bare generics
"default to dict[any]" -- this fixture is the case where that claim needs
to actually hold, since `any` satisfies the `SupportsRichComparison`
overload constraint while Unknown does not.
"""

with entry {
    rows: list[dict] = [{"n": 2}, {"n": 1}];

    by_key = sorted(rows, key=lambda d: dict : d["n"]);

    rows.sort(key=lambda d: dict : d["n"]);

    print(by_key, rows);
}
