import base64;
import csv;
import hashlib;
import io;

impl record_entry_from_bytes(path: str, data: bytes) -> RecordEntry {
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).decode("ascii");
    return RecordEntry(
        path=path, hash_value="sha256=" + digest.rstrip("="), size=len(data)
    );
}

impl generate_record(entries: list[RecordEntry], record_path: str) -> str {
    buf = io.StringIO();
    writer = csv.writer(buf, lineterminator="\n");
    for item in entries {
        writer.writerow([item.path, item.hash_value, str(item.size)]);
    }
    writer.writerow([record_path, "", ""]);
    return buf.getvalue();
}
