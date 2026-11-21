"""licensed reduction idiom inside flow for: `+=` and min/max folds on
outer int accumulators are index-disjoint per-task partials with a
combine at the join -- no diagnostics."""

glob xs = [3, 1, 4, 1, 5, 9, 2, 6];

with entry {
    total = 100;
    lo = 1000000;
    hi = -1000000;
    flow for v in &xs {
        total += v;
        lo = min(lo, v);
        hi = max(hi, v);
    }
    print(total);
    print(lo);
    print(hi);
}
