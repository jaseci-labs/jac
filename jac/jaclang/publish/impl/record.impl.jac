"""Implementation of the RECORD file generator."""

import hashlib;
import base64;
import csv;
import io;

def hash_bytes(data: bytes) -> str {
    # URL-safe base64, strip trailing '=' padding — PEP 376 requirement
    b64 = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=");
    return f"sha256={b64.decode('ascii')}";
}

impl record_entry_from_bytes(path: str, data: bytes) -> RecordEntry {
    return RecordEntry(path=path, hash_value=hash_bytes(data), size=len(data));
}

impl generate_record(entries: list[RecordEntry], record_path: str) -> str {
    buf = io.StringIO();
    # RECORD files use Unix line endings per the wheel spec
    writer = csv.writer(buf, lineterminator="\n");

    for entry in entries {
        writer.writerow([entry.path, entry.hash_value, str(entry.size)]);
    }

    # The RECORD file's own row always has empty hash and size
    writer.writerow([record_path, "", ""]);

    return buf.getvalue();
}
