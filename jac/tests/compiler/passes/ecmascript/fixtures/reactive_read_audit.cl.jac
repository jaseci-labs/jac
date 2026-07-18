"""Audit fixture for the reactive value-read seam (contract §4.1.1).

Exercises every site that may consume `exit_name` output for a name that is also
a reactive field (`count`). Under a signals-style backend (read -> `count()`),
value positions MUST wrap and non-value positions (write target, property key,
string literal, member property) MUST NOT. Under React/Preact the read seam is a
no-op, so this fixture is also a plain bare-identifier fixture.
"""

cl {
    def:pub audit_app(items: list) -> JsxElement {
        has count: int = 0;

        # value positions — must wrap under signals
        doubled = count + count;
        info = {"count": count};
        nested = [count, count + 1];

        # write target — must lower to setter, never `count() = ...`
        count = count + 1;

        # member property named like the reactive var — property key untouched
        first = items[0].count;

        # JSX child read; attribute string literal untouched
        return <div data-count="count">{count}</div>;
    }
}
