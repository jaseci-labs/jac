"""Tests for the OwnershipCheckPass region-escape rule (Phase 3 P2.1 — E1307).

A `region {}` arena owns everything allocated inside it and frees the whole
arena at the closing brace. A value/reference rooted inside the region must not
escape it: it may not be returned, stored into a location outside the region, or
handed to a `flow`/`wait` concurrency boundary. Each test pins the COMPLETE set
of E13xx codes its fixture emits.

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

test "E1307: a region-local returned from its function escapes the arena" {
    expect(compile_fixture("region_escape_return.jac"), ["E1307"]);
}

test "E1307: a region-local stored into an outer object escapes the arena" {
    expect(compile_fixture("region_escape_store.jac"), ["E1307"]);
}

test "E1307: a region-local handed to a `flow` boundary escapes the arena" {
    expect(compile_fixture("region_escape_flow.jac"), ["E1307"]);
}

test "E1307: a region-local assigned to an enclosing-scope binding escapes" {
    expect(compile_fixture("region_escape_outer.jac"), ["E1307"]);
}

test "a region-local used only inside its region is clean" {
    expect(compile_fixture("region_ok.jac"), []);
}
