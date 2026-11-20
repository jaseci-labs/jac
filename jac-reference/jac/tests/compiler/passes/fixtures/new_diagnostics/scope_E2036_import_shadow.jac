"""Fixture for E2036: a local definition reuses a name an import binds."""
import from scope_E2036_import_provider { Thing, Other, Setting as Knob }

def Thing -> int;  # <-- Error E2036: the import binds 'Thing'

impl Thing -> int {
    return 7;
}

obj Other {}  # <-- Error E2036: the import binds 'Other'

glob Knob: int = 1;  # <-- Error E2036: the import binds 'Knob'

def Setting -> int {
    return 2;
}

with entry {
    result: int = Thing() + Setting() + Knob;
}
