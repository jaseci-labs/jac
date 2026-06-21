"""Output writer for generated test files.

Renders TestGenResult objects into a committed .jac test file with
spec-hash markers for staleness detection.
"""
import from byllm.test_gen.code_generator { TestGenResult }

"""Write generated test blocks to a .jac file.

The output file is a valid Jac module that can be run with `jac test`.
It includes a header with metadata and spec hashes for staleness detection.

Args:
    results: List of TestGenResult objects (one per function).
    source_file: Absolute path to the source .jac file (for header comment + import).
    output_path: Destination .jac file path.
"""
def write_test_file(
    results: list[TestGenResult],
    source_file: str,
    output_path: str
) -> None;

"""Read existing spec hashes from a previously generated test file.

Returns a dict mapping function name to hash string.
Used to skip regeneration for functions whose spec has not changed.
"""
def read_existing_hashes(output_path: str) -> dict[str, str];
