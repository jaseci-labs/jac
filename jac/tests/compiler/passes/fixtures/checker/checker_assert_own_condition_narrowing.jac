"""An assert's condition is checked with what was known before the assert.

Bug: an operand of a multi-part assert condition has the assert itself as a
flow predecessor, and the assert's own predicate was applied to it. Finding
that predicate classifies every operand, so `not chart.connected(...)` had its
callee typed while `chart` was still being narrowed for an earlier operand,
with the declared `Chart | None`: E1099 on `connected`, inside an assert that
follows `assert chart is not None`.
"""

obj Chart {
    has revision: int = 0;

    def connected(first: int, second: int) -> bool {
        return first == second;
    }
}

def make(flag: bool) -> Chart | None {
    return Chart() if flag else None;
}

def after_two_asserts -> int {
    chart = make(True);
    assert chart is not None;
    assert chart.revision == 0;
    assert chart.revision == 0 and not chart.connected(1, 2);
    return chart.revision;
}

def after_assignments -> bool {
    chart = make(True);
    assert chart is not None and chart.revision == 0;
    joined = chart.connected(1, 1);
    apart = chart.revision == 0 and not chart.connected(1, 2);
    assert chart.revision == 0 and not chart.connected(1, 2);
    return joined and apart and chart.connected(2, 2);
}

def or_condition -> int {
    chart = make(True);
    assert chart is not None;
    assert chart.revision == 0;
    assert chart.revision > 0 or not chart.connected(1, 2);
    return chart.revision;
}

def narrows_within_and_after(chart: Chart | None) -> int {
    assert chart is not None and not chart.connected(1, 2);
    assert chart.revision == 0 and not chart.connected(3, 4);
    return chart.revision;
}

with entry {
    chart = make(True);
    assert chart is not None and chart.revision == 0;
    a = chart.connected(1, 1);
    b = not chart.connected(1, 2);
    assert chart.revision == 0 and not chart.connected(1, 2);
    print(a, b, chart.revision);
}
