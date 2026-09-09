"""E1407 pins the one place the error-slot lowering cannot propagate: an entry
block. A raising call the entry block handles is clean; one it does not handle
is a compile-time error naming the callee and the exception (#8984 rule 6)."""

import from tests.ownership_helpers { compile_fixture }

def enforced_codes(fixture: str) -> list[str] {
    prog = compile_fixture(fixture, enforce=True);
    codes: set[str] = set();
    for alert in list(prog.errors_had) {
        if alert.code is not None {
            codes.add(alert.code.code);
        }
    }
    return sorted(codes);
}

test "E1407: an entry block calls a raising function it does not handle" {
    assert enforced_codes("raise_unhandled_entry.jac") == ["E1407"];
}

test "a raising call handled by every frame up to the entry is clean" {
    assert enforced_codes("raise_handled_ok.jac") == [];
}
