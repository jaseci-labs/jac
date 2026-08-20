"""A subclass reaches slots its base declares, across a module boundary.

The pass base chain entering every root's closure exposed four refusals that
all named the same thing: an access to a slot the archetype inherits rather
than declares. `UniPass.transform` stored `ir_out`, `UniPass.traverse` stored
`cur_node`, `JsxIntrinsicGuardPass.before_pass` read `ir_in`, and
`UniPass.__post_init__` called `super.__post_init__`. Constructing a pass
inside a native root lowered; running one did not.

The cause is a phase ordering, and it is #8253's family one configuration
over. A module the consumer imports is compiled `symtab_ir_only`, so its
layout pass runs but its own `adopt_imported_bases` never does, and its
`class_parents` knows only the parents its own file declares. Its
linearization therefore stops one hop up -- `ModuleCodegenPass` reaches
`Transform` and not `BaseTransform` -- and `_register_imported_hierarchy`
copies that truncated answer into the consumer verbatim. Adoption then walks
`lay.mro`, sees no `BaseTransform`, and never brings `ir_out` across. Over a
five-deep chain crossing four module boundaries the truncation compounds:
every layout below `Transform` was missing all three slots.

`extended_mro` repairs it where the registry is finally complete, continuing
each recorded chain through its ancestors' own recorded chains. What it may
not do is trust a bare name: the registry holds one layout per name, so
`type_utils`'s `class PropertyWriteKind(Enum)` -- Python's enum -- resolves
to unitree's `Enum` archetype, and an unguarded repair walked straight into
unitree's scope methods. Provenance is the guard: `parent_mods` records,
while the symbol is in hand, which module each parent reference resolved
to, and the splice happens only where that matches the ancestor layout's
own `decl_mod`.

Pinned here two ways. The fixtures measure the mechanism directly, so a
regression names itself here rather than as a seam count in a coverage report. The
flat-header configuration over the same fixtures is owned by
`test_inherited_slot_headers.jac` (#8343), where `relax_vtable_header`
made the pair agree; this file measures the linearization repair.
"""

import os;
import jaclang;
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image }

glob FIXTURES = os.path.join(
         os.path.dirname(os.path.dirname(os.path.realpath(jaclang.__file__))),
         "tests",
         "compiler",
         "passes",
         "native",
         "fixtures"
     ),
     _MEMO: dict[(str, dict)] = {};

"""Seams the native coverage records for `rel`, keyed by callable."""
def _seams(rel: str) -> dict[(str, str)] {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    if rel in _MEMO {
        return _MEMO[rel];
    }
    path = os.path.join(FIXTURES, rel);
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(
            file_path=path,
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(os.path.realpath(path));
    assert rec is not None and rec["outcome"] == "native" , (
        f"{rel} never compiled as a native root, so nothing below measures " "anything"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    _MEMO[rel] = found;
    return found;
}


"""Two module boundaries from the slot, which is where the truncation bit."""
test "a leaf reaches a slot its grandparent declares, across two modules" {
    seams = _seams("deep_chain_leaf.jac");
    for meth in ("DeepLeaf.store_grandparent_slot", "DeepLeaf.read_grandparent_slot") {
        assert meth not in seams , (
            f"{meth} refused again: {seams.get(meth, '')}. `DeepMid`'s "
            "recorded linearization stopped at itself, so `slot_a` was "
            "invisible from the leaf -- the same truncation that took "
            "`UniPass.transform` and `UniPass.traverse` down, where a pass "
            "could be constructed natively but not run"
        );
    }
}


"""The chain the compiler's own passes form, measured on the real thing."""
test "the pass chain's traversal methods lower" {
    if _jaclang_image() is not None {
        testskip("a sealed image measures its trust boundary, not this");
    }
    pkg = os.path.dirname(os.path.realpath(jaclang.__file__));
    prog = JacProgram();
    na_coverage_begin();
    try {
        prog.compile(
            file_path=os.path.join(pkg, "jac0core", "passes", "uni_pass.jac"),
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    rec = coverage.get(
        os.path.realpath(os.path.join(pkg, "jac0core", "passes", "uni_pass.jac"))
    );
    assert rec is not None , "uni_pass.jac never entered the coverage";
    names: set[str] = set();
    for seam in (rec["seams"] or []) {
        names.add(str(seam).partition(": ")[0]);
    }
    for meth in ("UniPass.transform", "UniPass.traverse") {
        assert meth not in names , (
            f"{meth} demoted again. This is the seam that decides whether a "
            "natively constructed pass can walk a tree, and the fused prefix "
            "root is gated on it"
        );
    }
}


"""The flat-header case this file used to pin as refused now lowers.

The old test here held the refusal: a flat imported ancestor under a
vtable-carrying child had no slot assignment satisfying both units, so
`SlotChild.store_inherited` stayed a seam. #8343's `relax_vtable_header`
answered it at the root -- a vtable nothing dispatches through is a habit,
not a requirement -- and `test_inherited_slot_headers.jac` owns that
measurement now, both header agreement and the store lowering. What
remains pinned here is the half that suite does not touch: the
linearization repair above, which is #8320's half of the same arrival.
"""
test "the relaxed flat-base store lowers, and its seam stays gone" {
    seams = _seams("inherited_slot_child.jac");
    why = seams.get("SlotChild.store_inherited", "");
    assert not why , (
        f"SlotChild.store_inherited refused again: {why}. The header "
        "relaxation (#8343) made the flat pair agree; a returning seam "
        "means the header decision regressed -- look at "
        "relax_vtable_header and vtable_by_dispatch before re-waiving "
        "anything"
    );
}
