"""Negative control for the bare-generic-defaults-to-any fix.

Defaulting a bare `dict`'s unbound type args to `any` must only rescue
cases where the *value type* was the missing piece (e.g. `d["n"]`). It
must not paper over a genuine protocol mismatch: `dict` itself never
satisfies `SupportsRichComparison` (no `__lt__`), no matter what its type
args are, so using the whole dict as a sort key must keep failing.
"""

with entry {
    rows: list[dict] = [{"n": 2}, {"n": 1}];

    bad = sorted(rows, key=lambda d: dict : d);

    print(bad);
}
