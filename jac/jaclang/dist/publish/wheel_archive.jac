import base64;
import csv;
import hashlib;
import io;
import json;
import os;
import zipfile;

glob BUILD_DATA_FILE: str = "_jac_build.json";

def record_hash(data: bytes) -> str {
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).decode("ascii");
    return "sha256=" + digest.rstrip("=");
}

def record_text(rows: list[tuple[str, str, int]], record_path: str) -> str {
    buf = io.StringIO();
    writer = csv.writer(buf, lineterminator="\n");
    for (path, digest, size) in rows {
        writer.writerow([path, digest, str(size)]);
    }
    writer.writerow([record_path, "", ""]);
    return buf.getvalue();
}

def wheel_bytes(
    files: list[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
) -> bytes {
    members = list(files);
    for (name, text) in dist_info_files {
        members.append((f"{dist_info}/{name}", text.encode("utf-8")));
    }
    record_path = f"{dist_info}/RECORD";
    rows = [(path, record_hash(data), len(data)) for (path, data) in members];
    members.append((record_path, record_text(rows, record_path).encode("utf-8")));
    buf = io.BytesIO();
    with zipfile.ZipFile(buf, "w", compression=zipfile.ZIP_DEFLATED) as zf {
        for (path, data) in members {
            info = zipfile.ZipInfo(path, date_time=timestamp);
            zf.writestr(info, data, compress_type=zf.compression);
        }
    }
    return buf.getvalue();
}

def get_requires_for_build_wheel(
    config_settings: dict[str, str] | None = None  # jac:ignore[W2003]
) -> list[str] {
    return [];
}

def build_wheel(
    wheel_directory: str,
    config_settings: dict[str, str] | None = None,  # jac:ignore[W2003]
    metadata_directory: str | None = None  # jac:ignore[W2003]
) -> str {
    with open(BUILD_DATA_FILE, encoding="utf-8") as spec_file {
        spec = json.load(spec_file);
    }
    files: list[tuple[str, bytes]] = [];
    for rel in spec["files"] {
        with open(rel, "rb") as source {
            files.append((rel, source.read()));
        }
    }
    dist_info_files: list[tuple[str, str]] = [
        (name, text) for (name, text) in spec["dist_info_files"]
    ];
    data = wheel_bytes(
        files, spec["dist_info"], dist_info_files, tuple(spec["timestamp"])
    );
    wheel_name: str = spec["wheel_name"];
    with open(os.path.join(wheel_directory, wheel_name), "wb") as out {
        out.write(data);
    }
    return wheel_name;
}
