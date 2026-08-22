"""The pass-tier tripwire: a sealed pass's bytecode body refuses to run.

Sealing wave 1 put four compiler passes into `NATIVE_SEAL_ROOTS`, so a
sealed image's manifest now claims their method bodies exist natively.
The parser already had the runtime half of that claim
(`_require_bootstrap_tier`: reaching the bytecode parser inside a sealed
image raises); these tests pin the pass equivalent,
`require_native_pass_tier`.

Its seat is `_PassConstruction.__call__`, the metaclass the pass base
inherits from `pass_rim` -- the rim, not the unit. It used to sit in
`BaseTransform.postinit`, which made the constructor of every compiler
pass reach the sealed-image registry and demote; #8288 M1 rung 2 moved
it out so `transform.jac` could seal. What did not move is which
constructions it guards: the metaclass runs on *every* pass
construction, `run_pass` and direct alike, so the tests below construct
directly and still trip it. A guard the sealer's own
`JcirGenPass(...)` could walk around would not be one.

The contract:

  - a pass class whose module the loaded image seals natively refuses to
    run its bytecode `transform`, loudly, naming the module and the
    remedy -- silently executing bytecode the image claims to serve
    natively is the #8178/#8139 failure mode;
  - registering the module in `_NATIVE_SERVED_PASSES` (what the
    pass-serving binder will do once it binds the artifact) lets the same
    class construct, without any cache invalidation dance;
  - passes from modules the image does not seal, and passes from outside
    jaclang, never consult the image verdict and run bytecode legally --
    dev trees and images without pass roots are untouched.

The sealed-image claim is faked by patching `native_artifact_for`, the
same seam the tripwire reads in production; the per-class memo is cleared
around each patch so every test states its own precondition.
"""

import dataclasses;
import jaclang;
import jaclang.jac0core.sealed as sealed;
import jaclang.jac0core.unitree as uni;
import from pathlib { Path }
import from jaclang.jac0core.passes.annex_pass { JacAnnexPass }
import from jaclang.jac0core.passes.pass_rim {
    _NATIVE_PASS_TIER_MEMO,
    _NATIVE_SERVED_PASSES,
    PassRim
}
import from jaclang.jac0core.passes.transform { BaseTransform, Transform }
import from jaclang.jac0core.program { JacProgram }

glob ANNEX_MODULE: str = "jaclang.jac0core.passes.annex_pass";

obj LocalPass(Transform) {
    def transform(ir_in: uni.Module) -> uni.Module {
        return ir_in;
    }
}

def _fake_artifact(fullname: str) -> (tuple | None) {
    if fullname == ANNEX_MODULE {
        return ("/nonexistent/libjac_annex_pass.so", {});
    }
    return None;
}

def _run_annex -> object {
    return JacAnnexPass(ir_in=uni.Module.make_stub(), prog=JacProgram());
}

"""The sealable unit's source, read from the installed tree it compiles from."""
def _unit_source -> str {
    return (
        Path(jaclang.__file__).parent / "jac0core" / "passes" / "transform.jac"
    ).read_text(
        encoding="utf-8"
    );
}

def _skip_if_sealed {
    if sealed.native_artifact_for(ANNEX_MODULE) is not None {
        testskip(
            "this runtime seals the pass roots for real: the tripwire and "
            "binder are exercised by every pass construction in this suite, "
            "and patching fake artifacts here would corrupt the live "
            "serving registry for the rest of the worker"
        );
    }
}


test "an unsealed tree runs a pass's bytecode body" {
    _skip_if_sealed();
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    inst = _run_annex();
    assert isinstance(inst.ir_out, uni.Module) , "annex pass did not run";
    assert _NATIVE_PASS_TIER_MEMO.get(JacAnnexPass) == "" , (
        "a clean verdict must be memoized so later constructions skip the "
        "image lookup"
    );
}


test "a natively sealed pass refuses its bytecode body" {
    _skip_if_sealed();
    real = sealed.native_artifact_for;
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    sealed.native_artifact_for = _fake_artifact;
    try {
        with testraises(RuntimeError, `match=ANNEX_MODULE) {
            _run_annex();
        }
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
        with testraises(RuntimeError, `match="bytecode body") {
            _run_annex();
        }
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
        with testraises(RuntimeError, `match="rebuild the payload") {
            _run_annex();
        }
    } finally {
        sealed.native_artifact_for = real;
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    }
}


test "the memoized verdict still refuses on the next construction" {
    _skip_if_sealed();
    real = sealed.native_artifact_for;
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    sealed.native_artifact_for = _fake_artifact;
    try {
        with testraises(RuntimeError) {
            _run_annex();
        }
        assert _NATIVE_PASS_TIER_MEMO.get(JacAnnexPass) == ANNEX_MODULE;
    } finally {
        sealed.native_artifact_for = real;
    }
    try {
        with testraises(RuntimeError) {
            _run_annex();
        }
    } finally {
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    }
}


test "registering the served pass lifts the refusal without cache games" {
    _skip_if_sealed();
    real = sealed.native_artifact_for;
    _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    sealed.native_artifact_for = _fake_artifact;
    try {
        with testraises(RuntimeError) {
            _run_annex();
        }
        _NATIVE_SERVED_PASSES.add(ANNEX_MODULE);
        inst = _run_annex();
        assert isinstance(inst.ir_out, uni.Module) , (
            "a served pass must run even though the refusing verdict is "
            "already memoized"
        );
    } finally {
        _NATIVE_SERVED_PASSES.discard(ANNEX_MODULE);
        sealed.native_artifact_for = real;
        _NATIVE_PASS_TIER_MEMO.pop(JacAnnexPass, None);
    }
}


test "unsealed and non-jaclang passes never trip while another is sealed" {
    _skip_if_sealed();
    real = sealed.native_artifact_for;
    sealed.native_artifact_for = _fake_artifact;
    try {
        inst = LocalPass(ir_in=uni.Module.make_stub(), prog=JacProgram());
        assert isinstance(inst.ir_out, uni.Module) , (
            "a pass from an unsealed module was blocked by another module's " "artifact"
        );
    } finally {
        sealed.native_artifact_for = real;
        _NATIVE_PASS_TIER_MEMO.pop(LocalPass, None);
    }
}


test "the guard's seat is the rim, and the sealable unit names none of it" {
    assert issubclass(BaseTransform, PassRim) , (
        "the pass base stopped inheriting the rim, so nothing intercepts "
        "construction and the tripwire has no seat at all"
    );
    assert isinstance(BaseTransform, type(PassRim)) , (
        "the rim's metaclass is not on the pass base -- the construction "
        "seam is bypassed and passes construct unguarded"
    );
    text = _unit_source();
    for name in (
        "_NATIVE_PASS_TIER_MEMO",
        "_NATIVE_SERVED_PASSES",
        "_require_native_pass_tier",
        "jac0core.sealed",
        "pass_serve"
    ) {
        assert name not in text , (
            f"transform.jac names `{name}` again. The tier check consults "
            "the sealed-image registry and triggers the serving binder, "
            "host-side machinery no native unit can host; naming it from "
            "the unit demotes whichever callable does, and the constructor "
            "is the one that used to"
        );
    }
}


test "the program handle is stamped by the rim, not declared by the unit" {
    fields = {f.name for f in dataclasses.fields(BaseTransform)};
    assert "prog" not in fields , (
        "`prog` is a declared field again. A `JacProgram`-typed slot has "
        "no native layout, and it is the module-fatal gap that kept "
        "transform.jac out of every sealed closure"
    );
    assert "prog" not in _unit_source() , (
        "transform.jac names `prog` again -- the handle belongs to the "
        "driver rim, which stamps it at construction"
    );
    prog = JacProgram();
    inst = LocalPass(ir_in=uni.Module.make_stub(), prog=prog);
    assert inst.prog is prog , (
        "the rim did not stamp the program handle; every unsealed pass "
        "body reads `self.prog`"
    );
}


test "a pass constructed without a program handle refuses" {
    with testraises(TypeError, `match="constructing a pass requires") {
        LocalPass(ir_in=uni.Module.make_stub());
    }
}
