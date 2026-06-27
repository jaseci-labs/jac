import from pathlib { Path }

obj RecordEntry {
    has path: str = "",
        hash_value: str = "",
        size: int = 0;
}

def record_entry_from_bytes(path: str, data: bytes) -> RecordEntry;

def generate_record(entries: list[RecordEntry], record_path: str) -> str;
