"""The pass base chain is monomorphic, and its constructor lowers (#8288 M1).

`BaseTransform[T_in, T_out]` and `Transform[T: UniNode, R: UniNode]` were
generic, and a slot typed by a class type parameter lowers to a bare
erased pointer carrying no class. `BaseTransform.postinit` reads exactly
such a slot -- `self.ir_out = self.timed_transform(ir_in=self.ir_in)` --
so `Transform.__post_init__` demoted, and a pass constructed natively
could not have run its transform even if construction had otherwise
worked. That is the M1 ladder's rung 1, and this file is its acceptance.

The parameters bought nothing to lose. Thirty-nine subclasses
instantiate them, thirty-eight at `Module -> Module`, and the
thirty-ninth (`PyastBuildPass`, at `PythonModuleAst`) is an `EmptyToken`
and therefore a `UniNode` like the rest. Ten already redeclared `ir_in`
concretely. `run_pass` takes `(type, any)` and returns `any`, so the
driver never saw them either.

What replaces them is one concrete redeclaration at `ModuleCodegenPass`,
the seat every `UniPass` descends from. That is what keeps the checker
whole: its diagnostics over the pass sources are unchanged, which is the
measurement the base classes' typing was there to protect.

Pinned here: the chain carries no type parameters, and the constructor
lowers. The seams that remain on the unit are inventoried once, in
`test_transform_diagnostics_census.jac`, which pins them two-way with
the mechanism that clears each -- so a constructor that demoted again
would fail there as an un-waived seam and fail here by name.
"""

import os;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_census_begin, na_census_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }

glob PASSES_DIR = Path(jaclang.__file__).parent / "jac0core" / "passes",
     TRANSFORM_UNIT = "jaclang.jac0core.passes.transform",
     _MEMO: list = [];

"""Seams the native census recorded inside transform.jac, keyed by method."""
def _transform_seams -> dict[(str, str)] {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image, so the census would "
            "read the image's trust boundary rather than this unit's own "
            "coupling"
        );
    }
    if native_artifact_for(TRANSFORM_UNIT) is not None {
        testskip("transform is served from this runtime's native seal");
    }
    if _MEMO {
        return _MEMO[0];
    }
    path = str(PASSES_DIR / "transform.jac");
    prog = JacProgram();
    na_census_begin();
    try {
        ir = prog.compile(
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
        census = na_census_end();
    }
    assert ir is not None , "transform.jac produced no module";
    rec = census.get(os.path.realpath(path));
    assert rec is not None , "transform.jac never entered the native census";
    assert rec["outcome"] == "native" , (
        f"transform.jac did not stay native ({rec['outcome']}: {rec['detail']})"
    );
    found: dict[(str, str)] = {};
    for seam in (rec["seams"] or []) {
        (name, sep, why) = str(seam).partition(": ");
        found[name if sep else str(seam)] = why if sep else "";
    }
    # The unit exports no LLVM IR and no layout of its own -- it is in no
    # closure, which is section 11.1's symptom rather than its disease --
    # so the census record is the whole measurement. It is guarded against
    # vacuity from the other side: the seam set is pinned both ways below,
    # and an unreached compile would empty it and fail on the stale half.
    assert found , (
        "the census recorded no seam at all for transform.jac, which on "
        "this unit means the compile was never reached rather than that it "
        "is clean"
    );
    _MEMO.append(found);
    return found;
}


test "the pass base chain declares no type parameters" {
    text = (PASSES_DIR / "transform.jac").read_text(encoding="utf-8");
    assert "obj BaseTransform(ABC)" in text , (
        "BaseTransform took type parameters again; a slot typed by one "
        "lowers to an erased pointer and takes the constructor down with it"
    );
    assert "obj Transform(BaseTransform)" in text , (
        "Transform took type parameters again"
    );
}


test "the pass constructor lowers natively" {
    seams = _transform_seams();
    assert "Transform.__post_init__" not in seams , (
        "the pass constructor demoted again: "
        + seams.get("Transform.__post_init__", "")
        + ". Until it lowers, a natively constructed pass is a hollow "
        "object whose transform never ran, which is the whole of M1 rung 1"
    );
}
