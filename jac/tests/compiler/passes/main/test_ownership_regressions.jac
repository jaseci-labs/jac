"""Regression tests for ownership-checker fixes found while building the
ownbench suite (jac/examples/ownbench), 2026-07-17.

Covers, at the checker level (fast, no codegen):
  - E1402 diagnostic names the sealed VALUE, not the storage container root.
  - Scalar-typed reads off an owned root (`v = xs.pop()`, `len(xs)`) do not
    consume the owner; the loop-move heuristic shares _call_move_gen's
    builtin exempt list.
  - Enforcement container fences skip type-annotation contexts (a
    `list[float]` return type is not a container literal) and classify path
    expressions (`prog[pc]`) by their own type, not their root's type.

The end-to-end counterparts (headerless codegen correctness) live in
tests/compiler/passes/native/test_ownbench_differential.jac.
"""

import os;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from tests.support { JAC_ROOT }

glob FIXTURES = os.path.join(
         JAC_ROOT,
         "tests",
         "compiler",
         "passes",
         "main",
         "fixtures",
         "ownership_regress"
     );

"""Compile a fixture as a headerless nogc-enforced module; return the program."""
def compile_enforced(fixture: str) -> JacProgram {
    path = os.path.join(FIXTURES, fixture);
    prog = JacProgram();
    opts = CompileOptions(
        aot_mode=True, type_check=True, na_gc_mode="none", nogc_enforce_all=True
    );
    prog.compile(file_path=path, options=opts);
    return prog;
}

"""Sorted unique E13xx/E14xx codes emitted by a program."""
def ownership_codes(prog: JacProgram) -> list[str] {
    codes: set[str] = set();
    for alert in (list(prog.errors_had) + list(prog.warnings_had)) {
        if alert.code is not None
        and (alert.code.code.startswith("E13") or alert.code.code.startswith("E14")) {
            codes.add(alert.code.code);
        }
    }
    return sorted(codes);
}

"""Render alerts for readable assertion failures."""
def render(prog: JacProgram) -> str {
    parts: list[str] = [];
    for alert in (list(prog.errors_had) + list(prog.warnings_had)) {
        code = alert.code.code if alert.code is not None else "<no-code>";
        parts.append(f"{code}: {alert.msg}");
    }
    return "\n  ".join(parts);
}

test "E1402 names the sealed value, not the storage container" {
    prog = compile_enforced("e1402_names_value.na.jac");
    msgs = [
        alert.msg
        for alert in list(prog.errors_had)
        if alert.code is not None and alert.code.code == "E1402"
    ];
    assert msgs , f"expected an E1402; got:\n  {render(prog)}";
    for msg in msgs {
        assert "'shared'" in msg , (
            f"E1402 should name the sealed value 'shared', got: {msg}"
        );
    }
}

test "scalar reads off an owned root do not consume it" {
    prog = compile_enforced("scalar_reads_keep_owner.na.jac");
    codes = ownership_codes(prog);
    assert codes == [] , f"expected no ownership diagnostics, got {codes}:\n  {render(
        prog
    )}";
}

test "scalar-element container shapes pass the enforcement fences" {
    prog = compile_enforced("scalar_container_shapes.na.jac");
    codes = ownership_codes(prog);
    assert codes == [] , f"expected no ownership diagnostics, got {codes}:\n  {render(
        prog
    )}";
}
