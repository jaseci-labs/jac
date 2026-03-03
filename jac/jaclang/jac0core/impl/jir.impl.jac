"""Implementation of JIR class methods."""
import struct;
import sys;
import zlib;

# --- StringPool methods ---
impl StringPool.init(self: StringPool) -> None {
    self._strings: list[str] = [];
    self._index: dict[str, int] = {};
}

impl StringPool.intern(self: StringPool, s: str) -> int {
    idx = self._index.get(s);
    if idx is not None {
        return idx;
    }
    idx = len(self._strings);
    self._strings.append(s);
    self._index[s] = idx;
    return idx;
}

impl StringPool.get(self: StringPool, idx: int) -> str {
    return self._strings[idx];
}

impl StringPool.__len__(self: StringPool) -> int {
    return len(self._strings);
}

impl StringPool.serialize(self: StringPool) -> bytes {
    buf = bytearray();
    write_varint(buf, len(self._strings));
    for s in self._strings {
        encoded = s.encode('utf-8');
        write_varint(buf, len(encoded));
        buf.extend(encoded);
    }
    return bytes(buf);
}

# --- JirHeader methods ---
impl JirHeader.to_bytes(self: JirHeader) -> bytes {
    return struct.pack(
        HEADER_FMT,
        self.magic,
        self.format_version,
        self.python_version,
        self.jaclang_version_hash,
        self.source_content_hash,
        self.node_count,
        self.symbol_count,
        self.string_pool_size,
        self.flags
    );
}

impl JirHeader.is_compatible(self: JirHeader) -> bool {
    expected_py = (sys.version_info.major << 8) | sys.version_info.minor;
    if self.python_version != expected_py {
        return False;
    }
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
    expected_jac = zlib.crc32(jac_ver.encode()) & 0xFFFFFFFF;
    if self.jaclang_version_hash != expected_jac {
        return False;
    }
    return True;
}
