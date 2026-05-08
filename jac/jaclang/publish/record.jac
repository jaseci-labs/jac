"""RECORD file (PEP 376 / PEP 427 CSV with SHA-256 fingerprints) generator for jac bundle."""

import from pathlib { Path }

"""A single row in a RECORD file (path, sha256 hash, and byte size)."""
obj RecordEntry {
    has path: str = "",
        hash_value: str = "",
        size: int = 0;
}

"""Build a RecordEntry for an in-memory file from its wheel-relative path and content bytes."""
def record_entry_from_bytes(path: str, data: bytes) -> RecordEntry;

"""Generate a RECORD CSV string from a list of RecordEntry objects, with the self-entry appended last."""
def generate_record(entries: list[RecordEntry], record_path: str) -> str;
