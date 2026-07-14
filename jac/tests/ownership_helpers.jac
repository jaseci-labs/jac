"""Shared test helpers for the ownership compiler passes.

Provides `compile_fixture`, `ownership_codes`, `render_alerts`, and
`expect_ownership_codes` so every ownership test file imports once instead
of copying the same definitions across four files.
"""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures", "ownership"
     ),
     OWNERSHIP_PREFIX = "E13";

"""Compile a fixture with type checking. Returns the JacProgram."""
def compile_fixture(fixture_name: str) -> JacProgram {
    path = os.path.join(FIXTURES, fixture_name);
    program = JacProgram();
    program.compile(path, type_check=True);
    return program;
}

"""Return the sorted multiset of E13xx ownership codes a program emits."""
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

"""Render every alert (code + message) for readable failure output."""
def render_alerts(program: JacProgram) -> str {
    parts: list[str] = [];
    for alert in (list(program.errors_had) + list(program.warnings_had)) {
        code = alert.code.code if alert.code is not None else "<no-code>";
        parts.append(f"{code}: {alert.msg}");
    }
    return "\n  ".join(parts);
}

"""Assert a program emits exactly the given E13xx ownership codes (any order)."""
def expect_ownership_codes(program: JacProgram, expected: list[str]) {
    actual = ownership_codes(program);
    wanted = sorted(expected);
    assert actual == wanted , f"expected E13xx codes {wanted}, got {actual}; all alerts:\n  {render_alerts(
        program
    )}";
}
