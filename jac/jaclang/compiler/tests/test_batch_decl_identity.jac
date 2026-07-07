"""Regression coverage for batch-check declaration identity (issue #7164).

`jac check` reuses a single ``JacProgram`` across every file in the batch. When
a module is first pulled into the hub as a *dependency* (symtab-IR only, its
type annotations still unresolved) and then re-encountered as an explicit batch
entry -- for example via its ``impl/`` annex resolving back to the base file --
the entry must reuse the cached module rather than reparse it into a *second*
declaration universe. Two live declarations of the same class make a type
compare unequal to itself, producing spurious ``X, expected X`` self-rejections
in whichever consumer is checked afterwards.

This pins the invariant: checking a decl file's dependency, its impl annex, and
a consumer in one program -- in the order that triggers the duplicate -- yields
zero self-type mismatches. Each file also checks clean individually and in every
pair; only the specific three-file batch regressed.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.bccache { discover_base_file }

glob BATCH_DIR = str(
         Path(jaclang.__file__).parent / "compiler" / "tests" / "fixtures" / "batch_decl_identity"
     );


"""Type-check `files` in one program the way `jac check` batches a run.

Mirrors the CLI's per-file loop: an impl annex is resolved back to its base
module, and every entry is compiled into the shared program with
`force_target_program` so they land in one hub. Returns the messages of every
error emitted across the batch.
"""
def check_batch(files: list[str]) -> list[str] {
    prog = JacProgram();
    for rel in files {
        file_path = os.path.join(BATCH_DIR, rel);
        base_path = discover_base_file(file_path);
        if base_path is not None {
            file_path = base_path;
        }
        prog.compile(
            file_path=file_path,
            options=CompileOptions(
                type_check=True, no_cgen=True, force_target_program=True
            )
        );
    }
    return [str(e) for e in prog.errors_had];
}


"""Keep only the self-type mismatches this issue is about (`X, expected X`)."""
def self_type_mismatches(errors: list[str]) -> list[str] {
    return [
        e
        for e in errors
        if "Cannot return Box" in e
    ];
}


test "batch check of dep + impl annex + consumer has no self-type mismatch" {
    errors = check_batch(
        ["entry1.jac", os.path.join("impl", "box.impl.jac"), "consumer.jac"]
    );
    assert self_type_mismatches(errors) == [] , errors;
}


test "consumer checks clean on its own" {
    assert self_type_mismatches(check_batch(["consumer.jac"])) == [];
}


test "each pair of the batch checks clean" {
    impl_rel = os.path.join("impl", "box.impl.jac");
    assert self_type_mismatches(check_batch(["entry1.jac", "consumer.jac"])) == [];
    assert self_type_mismatches(check_batch([impl_rel, "consumer.jac"])) == [];
    assert self_type_mismatches(check_batch(["entry1.jac", impl_rel])) == [];
}
