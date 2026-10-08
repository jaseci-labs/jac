"""The native share can only go up.

`tests/tier_census.jac` runs every program of the corpus on both tiers and
classes the native run. This holds the result to `tests/tier_census.json`:
a program that moves to a worse class fails the test, and so does a census
that has drifted from the file, in either direction, so an improvement is
recorded in the same change that makes it.

The file is the Linux result. Elsewhere a program may be skipped or classed
differently for reasons of the machine, so only a regression fails there."""
import sys;
import from tests.tier_census {
    compare,
    corpus_programs,
    read_baseline,
    summarize,
    take_census
}

test "no program runs worse on the native tier than the census records" {
    census = take_census(corpus_programs());
    (worse, stale) = compare(census, read_baseline());
    detail = "\n".join(
        [f"WORSE  {line}" for line in worse] + [f"STALE  {line}" for line in stale]
    );
    assert not worse , (
        "programs moved to a worse class on the native tier:\n"
        + detail
        + "\n\n"
        + summarize(census)
    );
    if sys.platform == "linux" {
        assert not stale , (
            "the census no longer matches tests/tier_census.json; run "
            "`jac run tests/tier_census.jac --update` and commit the result:\n"
            + detail
            + "\n\n"
            + summarize(census)
        );
    }
}
