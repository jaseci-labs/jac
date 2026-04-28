"""RECORD file (PEP 627 CSV with SHA-256 fingerprints) generator for jac publish."""

import from pathlib { Path }

"""A single row in a RECORD file (path, sha256 hash, and byte size)."""
obj RecordEntry {
    has path: str = "",
        hash_value: str = "",
        size: int = 0;
}

"""Return 'sha256=<urlsafe-base64>' fingerprint of data bytes (PEP 627 format)."""
def hash_bytes(data: bytes) -> str;

"""Build a RecordEntry for an in-memory file from its wheel-relative path and content bytes."""
def record_entry_from_bytes(path: str, data: bytes) -> RecordEntry;

"""Build a RecordEntry by reading a file from disk (path is wheel-relative, file_path is absolute)."""
def record_entry_from_file(path: str, file_path: Path) -> RecordEntry;

"""Generate a RECORD CSV string from a list of RecordEntry objects, with the self-entry appended last."""
def generate_record(entries: list[RecordEntry], record_path: str) -> str;

"""Parse a RECORD CSV string back to a list of RecordEntry objects."""
def parse_record(text: str) -> list[RecordEntry];
