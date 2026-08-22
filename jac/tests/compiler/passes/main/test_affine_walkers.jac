"""Affine walkers (#7857 Phase D): spawn consumes an own walker.

A walker bound `own` is use-once computation: spawning it moves it into
the traversal, so a second spawn is E1301 and double-accumulation bugs
become compile errors. Unannotated walkers keep managed reuse semantics.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "second spawn of an own walker is E1301" {
    prog = compile_fixture("walker_double_spawn.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "single spawn of an own walker is clean" {
    prog = compile_fixture("walker_single_spawn_ok.jac");
    expect_ownership_codes(prog, []);
}

test "unannotated walker reuse is untouched" {
    prog = compile_fixture("walker_unannotated_spawns.jac");
    expect_ownership_codes(prog, []);
}
