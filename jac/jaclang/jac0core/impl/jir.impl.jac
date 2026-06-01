"""Implementation of JIR class methods."""
import json;
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
impl JirHeader.to_bytes -> bytes {
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

impl JirHeader.is_compatible -> bool {
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

# --- write_program_jir ---
impl write_program_jir(
    modules: list[tuple[str, int, dict[int, bytes]]],
    manifest: dict[str, object],
    dep_graph: dict[str, list[str]],
    source_hash: int = 0
) -> bytes {
    # Build inner module table: for each module, write its sections as a
    # length-prefixed nested blob so read_sections' flat dict is safe.
    # Format: 4-byte count, then for each module:
    #   4-byte rel_path length + rel_path bytes
    #   8-byte content_hash
    #   4-byte inner_blob length + inner_blob (write_sections output)
    table_buf = bytearray();
    table_buf += struct.pack('<I', len(modules));
    for (rel_path, content_hash, mod_sections) in modules {
        path_bytes = rel_path.encode('utf-8');
        inner_blob = write_sections(mod_sections);
        table_buf += struct.pack('<I', len(path_bytes));
        table_buf += path_bytes;
        table_buf += struct.pack('<Q', content_hash);
        table_buf += struct.pack('<I', len(inner_blob));
        table_buf += inner_blob;
    }

    manifest_bytes = json.dumps(manifest, separators=(',', ':')).encode('utf-8');
    dep_bytes = json.dumps(dep_graph, separators=(',', ':')).encode('utf-8');

    sections = {
        SEC_MANIFEST: manifest_bytes,
        SEC_DEPGRAPH: dep_bytes,
        SEC_MODULE_TABLE: bytes(table_buf),

    };
    section_bytes = write_sections(sections);

    header = create_header(
        source_hash=source_hash,
        node_count=0,
        symbol_count=0,
        string_pool_size=0,
        flags=FLAG_PRECOMPILED | FLAG_PROGRAM,
    );
    header_bytes = header.to_bytes();
    empty_ast = zlib.compress(b'\x00');
    payload_len = struct.pack('<I', len(empty_ast));
    return header_bytes + payload_len + empty_ast + section_bytes;
}
