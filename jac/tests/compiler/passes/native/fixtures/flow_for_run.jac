"""flow for runtime semantics: per-element body over lent collections,
join at the closing brace. Element writes through `&mut` are visible
after the join, and the join is a barrier -- every line one region
prints lands before the next region starts. Bodies run genuinely
parallel under `--gc rc`, so the order *within* a region is unspecified;
the values and the region boundaries are not. The two printing regions
emit disjoint value sets so a line that crossed a join is detectable."""

obj P {
    has x: int = 0;
}

with entry {
    ps: list[P] = [P(x=1), P(x=2), P(x=3)];
    flow for m in &mut ps {
        m.x = m.x * 10;
    }
    flow for m in &ps {
        print(m.x);
    }
}

glob xs = [4, 5],
     k = 3;

with entry {
    flow for v in &xs {
        print(v * k);
    }
    print("end");
}
