import from jaclang.dist.publish.wheel_archive { record_hash, record_text }

impl record_entry_from_bytes(path: str, data: bytes) -> RecordEntry {
    return RecordEntry(path=path, hash_value=record_hash(data), size=len(data));
}

impl generate_record(entries: list[RecordEntry], record_path: str) -> str {
    return record_text(
        [(item.path, item.hash_value, item.size) for item in entries], record_path
    );
}
