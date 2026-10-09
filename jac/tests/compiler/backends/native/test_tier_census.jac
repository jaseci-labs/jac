"""The native share can only go up.

`tests/tier_census.jac` runs every program of the corpus on both tiers and
classes the native run. This holds the result to `tests/tier_census.json`:
a program that moves to a worse class fails the test, and so does a census
that has drifted from the file, in either direction, so an improvement is
recorded in the same change that makes it.

The file is the Linux result. Elsewhere a program may be skipped or classed
differently for reasons of the machine, so only a regression fails there."""
import sys;
import tests.tier_census as census_tool;
import from unittest.mock { patch }
import from tests.tier_census {
    Run,
    classify,
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

"""A program is a reference only when the Python tier prints the same thing
twice. A second run that does not finish has printed nothing to compare."""
test "a reference run that times out the second time is no reference" {
    runs = [
        Run(code=0, out="", err=""),
        Run(code=0, out="", err="", timed_out=True),
        Run(code=0, out="", err="")
    ];
    with patch.object(census_tool, "run_tier", side_effect=runs) {
        outcome = classify("examples/quiet.jac");
    }
    assert outcome.kind == "skipped" , outcome.record();
    assert outcome.reason == "the Python tier is not repeatable" , outcome.record();
}

"""Everything a program prints is compared. Nothing the tool writes while it
prepares a run goes to standard output, so no line is set aside as noise: a
program that prints `Compiling ...` is held to it like any other line."""
test "program output that looks like tool progress is still compared" {
    runs = [
        Run(code=0, out="Compiling a\nRestoring 1\n", err=""),
        Run(code=0, out="Compiling a\nRestoring 1\n", err=""),
        Run(code=0, out="Compiling b\nRestoring 2\n", err="")
    ];
    with patch.object(census_tool, "run_tier", side_effect=runs) {
        outcome = classify("examples/talks_like_the_tool.jac");
    }
    assert outcome.kind == "differs" , outcome.record();
}
