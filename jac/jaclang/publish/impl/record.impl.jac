"""Implementation of the RECORD file generator."""

import hashlib;
import base64;
import csv;
import io;
import from pathlib { Path }

# ===============================================================================
# hash_bytes
# ===============================================================================
impl hash_bytes(data: bytes) -> str {
    digest = hashlib.sha256(data).digest();
    # URL-safe base64, strip trailing '=' padding — PEP 376 requirement
    b64 = base64.urlsafe_b64encode(digest).rstrip(b"=");
    return f"sha256={b64.decode('ascii')}";
}

# ===============================================================================
# record_entry_from_bytes
# ===============================================================================
impl record_entry_from_bytes(path: str, data: bytes) -> RecordEntry {
    return RecordEntry(path=path, hash_value=hash_bytes(data), size=len(data));
}

# ===============================================================================
# record_entry_from_file
# ===============================================================================
impl record_entry_from_file(path: str, file_path: Path) -> RecordEntry {
    data = file_path.read_bytes();
    return RecordEntry(path=path, hash_value=hash_bytes(data), size=len(data));
}

# ===============================================================================
# generate_record
# ===============================================================================
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

# ===============================================================================
# parse_record
# ===============================================================================
impl parse_record(text: str) -> list[RecordEntry] {
    entries: list[RecordEntry] = [];
    reader = csv.reader(io.StringIO(text));

    for row in reader {
        if not row {
            continue;
        }
        path = row[0] if len(row) > 0 else "";
        hash_val = row[1] if len(row) > 1 else "";
        size_str = row[2] if len(row) > 2 else "";
        size = int(size_str) if size_str else 0;
        entries.append(RecordEntry(path=path, hash_value=hash_val, size=size));
    }

    return entries;
}
