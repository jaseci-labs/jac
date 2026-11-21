"""Helper for E4001 circular import test."""

import from tests.compiler.passes.fixtures.new_diagnostics.import_E4001_circular { }

def helper_func() -> None {
    print("helper");
}
