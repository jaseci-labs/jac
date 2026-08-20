"""The narrowing-key walk CFGBuildPass calls is native-clean (#8201).

`collect_narrowing_symbols` and `collect_assigned_symbols` used to live in
`jaclang/compiler/symbol_utils.jac`, which imports the Python-side compiler
infrastructure. CFGBuildPass reaches them from `enter_node` and from every
branch visitor, so seven of the pass's eleven own seams were one family: a
live, unwaivable call into a Python-only module. The bodies now live in
`jaclang/compiler/expr_keys.jac`, whose only imports are `unitree` and
`constant`; `symbol_utils` re-exports them so its other consumers are
unchanged.

The measurement is one coverage run, asserted three ways. `expr_keys` has to
compile natively, produce IR and carry zero seams -- a zero-seam coverage
without IR would mean "not reached", not "clean" -- and no seam of
`cfg_build_pass` may name either function, because the reason string is
what a sealed build turns into an `abort()` stub.

The residue is left honest rather than asserted away. `cfg_build_pass`
still carries four own seams: `_find_next_cfg_stmt_after` reads
`parent?.body` on a base-typed `UniNode` (no common base declares `body`,
so the backend has no static offset), and `CoalesceBBPass.enter_node`,
`CoalesceBBPass._node_label` and `cfg_dot_from_file` are the dot-graph
tooling family, reachable only from `jac tool` through `lang_tools`.

One coverage run, one test, deliberately. Each native root compile holds the
whole closure's IR, and `jac test` spreads tests across worker processes with
no shared memo, so a file of N tests over one root is N full compiles in up
to N workers. The compiler suite runs on a 16GB runner that already loses
communication when this accumulates.
"""

import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { native_artifact_for }

glob PKG_PATH = Path(jaclang.__file__).parent,
     CFG_ROOT: str = "compiler/passes/main/cfg_build_pass.jac",
     KEYS_MOD: str = "compiler/expr_keys.jac",
     HOISTED: tuple = ("collect_narrowing_symbols", "collect_assigned_symbols");

"""Compile one root the way seal_native_artifacts does, up to the coverage."""
def _root_coverage(rel: str) -> tuple {
    if native_artifact_for("jaclang." + rel[:-4].replace("/", ".")) is not None {
        testskip(
            f"{rel} is served from this runtime's native seal; the coverage "
            "gated the build via seal_demotion_report"
        );
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=str(PKG_PATH / rel),
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
    has_ir = ir is not None and ir.gen.llvm_ir is not None;
    errors = [str(e) for e in prog.errors_had];
    return (coverage, has_ir, errors, );
}

"""The coverage record for one package-relative module in a root's closure."""
def _record_for(coverage: dict, member: str) -> (dict | None) {
    for (path, rec) in coverage.items() {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        if where == member {
            return rec;
        }
    }
    return None;
}


test "the hoisted narrowing walk lowers, and no cfg seam names it" {
    (coverage, has_ir, errors) = _root_coverage(CFG_ROOT);
    assert not errors , (
        f"{CFG_ROOT} compile errors (a coverage report below would be 'not reached', "
        f"not 'clean'): {errors[:5]}"
    );
    assert has_ir , f"no LLVM IR for {CFG_ROOT}: the compile aborted before codegen";

    keys = _record_for(coverage, KEYS_MOD);
    assert keys is not None , (
        f"{KEYS_MOD} is not in {CFG_ROOT}'s native closure; CFGBuildPass no "
        "longer reaches the hoisted narrowing walk, or it reaches it through "
        "a module that does not lower"
    );
    assert keys["outcome"] == "native" , (
        f"{KEYS_MOD} did not lower natively: [{keys['code']}] {keys['detail']}"
    );
    assert not (keys["seams"] or []) , (
        f"{KEYS_MOD} grew native seams, so CFGBuildPass would demote again: "
        f"{keys['seams']}"
    );

    cfg = _record_for(coverage, CFG_ROOT);
    assert cfg is not None , f"{CFG_ROOT} is missing from its own coverage";
    offenders: list[str] = [];
    for seam in (cfg["seams"] or []) {
        for name in HOISTED {
            if name in str(seam) {
                offenders.append(str(seam));
            }
        }
    }
    assert not offenders , (
        "a cfg seam still names the hoisted narrowing walk, so the family "
        f"came back through a Python-side module: {offenders}"
    );
}
