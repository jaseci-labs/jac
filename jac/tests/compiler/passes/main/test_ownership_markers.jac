"""Tests for the OwnershipCheckPass `val`/`linear` markers (Phase 3 P2.3).

`val` marks a deep-immutable binding: reassigning it, writing one of its fields,
or taking a `&mut` through it is a mutation and raises E1309. Reading it is fine.

`linear` marks a must-use-exactly-once binding. Never consuming it leaks the
resource (E1305); consuming it more than once is a use-after-move (E1301), since
a `linear` value is affine-move-checked exactly like `own`. Each test pins the
COMPLETE set of E13xx codes its fixture emits.

Self-contained (helpers copied, not imported) to keep merges clean.
"""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "ownership"
     ),
     OWNERSHIP_PREFIX = "E13";

def compile_fixture(fixture_name: str) -> JacProgram {
    path = os.path.join(FIXTURES, fixture_name);
    program = JacProgram();
    program.compile(path, type_check=True);
    return program;
}

def ownership_codes(program: JacProgram) -> list[str] {
    codes: list[str] = [];
    for alert in (list(program.errors_had) + list(program.warnings_had)) {
        if alert.code is not None and alert.code.code.startswith(OWNERSHIP_PREFIX) {
            codes.append(alert.code.code);
        }
    }
    codes.sort();
    return codes;
}

def render_alerts(program: JacProgram) -> str {
    parts: list[str] = [];
    for alert in (list(program.errors_had) + list(program.warnings_had)) {
        code = alert.code.code if alert.code is not None else "<no-code>";
        parts.append(f"{code}: {alert.msg}");
    }
    return "\n  ".join(parts);
}

def expect(program: JacProgram, expected: list[str]) {
    actual = ownership_codes(program);
    wanted = sorted(expected);
    assert actual == wanted , f"expected E13xx codes {wanted}, got {actual}; all alerts:\n  {render_alerts(
        program
    )}";
}

test "E1309: reassigning a `val` binding is a mutation" {
    expect(compile_fixture("marker_val_reassign.jac"), ["E1309"]);
}

test "E1309: writing a field of a `val` binding is a mutation" {
    expect(compile_fixture("marker_val_field_write.jac"), ["E1309"]);
}

test "E1309: taking a `&mut` through a `val` binding is a mutation" {
    expect(compile_fixture("marker_val_mut_borrow.jac"), ["E1309"]);
}

test "reading a `val` binding (field read, passthrough) is clean" {
    expect(compile_fixture("marker_val_read_ok.jac"), []);
}

test "E1305: a `linear` binding that is never consumed leaks" {
    expect(compile_fixture("marker_linear_leak.jac"), ["E1305"]);
}

test "a `linear` binding consumed exactly once is clean" {
    expect(compile_fixture("marker_linear_consumed_ok.jac"), []);
}

test "E1301: consuming a `linear` binding twice is a use-after-move" {
    expect(compile_fixture("marker_linear_double_use.jac"), ["E1301"]);
}
