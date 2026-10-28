import base64;
import csv;
import hashlib;
import io;
import json;
import os;
import zipfile;
import from typing { BinaryIO }

glob BUILD_DATA_FILE: str = "_jac_build.json";

def record_hash(data: bytes) -> str;

def record_text(rows: list[tuple[str, str, int]], record_path: str) -> str;

def write_wheel(
    out: BinaryIO,
    files: Iterable[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
);

def wheel_bytes(
    files: Iterable[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
) -> bytes;

def _read_file(path: str) -> bytes;

def get_requires_for_build_wheel(
    config_settings: dict[str, str] | None = None  # jac:ignore[W2003]
) -> list[str];

def build_wheel(
    wheel_directory: str,
    config_settings: dict[str, str] | None = None,  # jac:ignore[W2003]
    metadata_directory: str | None = None  # jac:ignore[W2003]
) -> str;

impl record_hash(data: bytes) -> str {
    digest = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).decode("ascii");
    return "sha256=" + digest.rstrip("=");
}

impl record_text(rows: list[tuple[str, str, int]], record_path: str) -> str {
    buf = io.StringIO();
    writer = csv.writer(buf, lineterminator="\n");
    for (path, digest, size) in rows {
        writer.writerow([path, digest, str(size)]);
    }
    writer.writerow([record_path, "", ""]);
    return buf.getvalue();
}

impl write_wheel(
    out: BinaryIO,
    files: Iterable[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
) {
    rows: list[tuple[str, str, int]] = [];
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as zf {
        def add(path: str, data: bytes) {
            info = zipfile.ZipInfo(path, date_time=timestamp);
            zf.writestr(info, data, compress_type=zf.compression);
        }
        for (path, data) in files {
            add(path, data);
            rows.append((path, record_hash(data), len(data)));
        }
        for (name, text) in dist_info_files {
            data = text.encode("utf-8");
            add(f"{dist_info}/{name}", data);
            rows.append((f"{dist_info}/{name}", record_hash(data), len(data)));
        }
        record_path = f"{dist_info}/RECORD";
        add(record_path, record_text(rows, record_path).encode("utf-8"));
    }
}

impl wheel_bytes(
    files: Iterable[tuple[str, bytes]],
    dist_info: str,
    dist_info_files: list[tuple[str, str]],
    timestamp: tuple[int, ...]
) -> bytes {
    buf = io.BytesIO();
    write_wheel(buf, files, dist_info, dist_info_files, timestamp);
    return buf.getvalue();
}

impl _read_file(path: str) -> bytes {
    with open(path, "rb") as source {
        return source.read();
    }
}

impl get_requires_for_build_wheel(
    config_settings: dict[str, str] | None = None
) -> list[str] {
    return [];
}

impl build_wheel(
    wheel_directory: str,
    config_settings: dict[str, str] | None = None,
    metadata_directory: str | None = None
) -> str {
    with open(BUILD_DATA_FILE, encoding="utf-8") as spec_file {
        spec = json.load(spec_file);
    }
    dist_info_files: list[tuple[str, str]] = [
        (name, text) for (name, text) in spec["dist_info_files"]
    ];
    wheel_name: str = spec["wheel_name"];
    with open(os.path.join(wheel_directory, wheel_name), "wb") as out {
        write_wheel(
            out,
            ((rel, _read_file(rel)) for rel in spec["files"]),
            spec["dist_info"],
            dist_info_files,
            tuple(spec["timestamp"])
        );
    }
    return wheel_name;
}
