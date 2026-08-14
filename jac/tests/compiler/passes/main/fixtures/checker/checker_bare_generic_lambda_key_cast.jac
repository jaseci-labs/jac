"""`sorted` with an inline `key=lambda d: dict : (d["n"] as int)` -- the
explicit-cast variant of the bare-generic lambda key repro -- must keep
type-checking.

This already passes before the primary fix lands: an explicit `as int`
cast makes the lambda's return type a real `int` ClassType, not the
internal `any` that the bare-generic-default bug turns on, so it never
hits the strict-mode `assign_type` rejection the other fixtures in this
group exercise. It's pinned here as a plain regression check, since the
fix touches the shared `assign_type`/`AnyType` machinery broadly enough
that it's worth confirming this sibling case doesn't regress.
"""

with entry {
    rows: list[dict] = [{"n": 2}, {"n": 1}];

    by_key = sorted(rows, key=lambda d: dict : (d["n"] as int));

    print(by_key);
}
