"""Fixture for E4001: Circular import cycle.

This fixture is the entry point. It imports import_E4001_helper which
imports back to this module, creating a cycle.
"""

import from tests.compiler.passes.main.fixtures.new_diagnostics.import_E4001_helper { helper_func }
# <-- Error E4001: circular import cycle

with entry {
    helper_func();
}
