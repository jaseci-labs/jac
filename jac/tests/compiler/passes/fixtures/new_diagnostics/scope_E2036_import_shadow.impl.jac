"""Repeats the module's import, then binds `Other` to another module."""
import from scope_E2036_import_provider { Thing }
import from shlex { join as Other }  # <-- Error E2036: the module's import binds 'Other'

impl Thing -> int {
    return 7;
}
