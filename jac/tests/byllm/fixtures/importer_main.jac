"""Fixture that imports a function from another module."""

import from import_dir.importable_schema { get_imported_data, verify_mtir_retrieval }

# This file doesn't define any GenAI functions itself,
# just imports and uses them

with entry {
    # First verify that MTIR can be retrieved at runtime
    mtir_ok = verify_mtir_retrieval();
    print(f"MTIR retrieval test: {'PASSED' if mtir_ok else 'FAILED'}");

    # Then call the actual function
    data = get_imported_data("My name is Jayanaka.");
    print("Imported data value:", data.name);
}
