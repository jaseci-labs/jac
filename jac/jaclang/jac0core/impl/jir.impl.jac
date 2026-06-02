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

# --- read_program_jir ---
impl read_program_jir(
    data: bytes
) -> (tuple[dict[str, object], dict[str, list[str]],
          list[tuple[str, int, dict[int, bytes]]]] | None) {
    # Validate header: must be a FLAG_PROGRAM JIR.
    header = parse_header(data);
    if header is None {
        return None;
    }
    if (header.flags & FLAG_PROGRAM) == 0 {
        return None;
    }

    # Skip the AST payload: 4-byte compressed length + compressed data.
    pos = HEADER_SIZE;
    if pos + 4 > len(data) {
        return None;
    }
    (payload_len, ) = struct.unpack_from('<I', data, pos);
    pos += 4 + payload_len;

    # Find SECTIONS_MAGIC and read top-level sections.
    magic_bytes: any = SECTIONS_MAGIC;
    sec_pos = data.find(magic_bytes, pos);
    if sec_pos < 0 {
        return None;
    }
    sections = read_sections(data, sec_pos + len(magic_bytes));

    # Parse manifest.
    manifest_bytes = sections.get(SEC_MANIFEST);
    if manifest_bytes is None {
        return None;
    }
    manifest = json.loads(manifest_bytes.decode('utf-8'));

    # Parse dep graph.
    dep_bytes = sections.get(SEC_DEPGRAPH);
    dep_graph: dict[str, list[str]] = {};
    if dep_bytes is not None {
        dep_graph = json.loads(dep_bytes.decode('utf-8'));
    }

    # Parse module table.
    table_bytes = sections.get(SEC_MODULE_TABLE);
    modules: list[tuple[str, int, dict[int, bytes]]] = [];
    if table_bytes is not None {
        p = 0;
        (count, ) = struct.unpack_from('<I', table_bytes, p);
        p += 4;
        for _ in range(count) {
            (plen, ) = struct.unpack_from('<I', table_bytes, p);
            p += 4;
            rel_path = table_bytes[p:p + plen].decode('utf-8');
            p += plen;
            (content_hash, ) = struct.unpack_from('<Q', table_bytes, p);
            p += 8;
            (blen, ) = struct.unpack_from('<I', table_bytes, p);
            p += 4;
            inner = table_bytes[p:p + blen];
            p += blen;
            # Parse inner sections (nested write_sections blob).
            ipos = inner.find(magic_bytes);
            inner_secs: dict[int, bytes] = {};
            if ipos >= 0 {
                inner_secs = read_sections(inner, ipos + len(magic_bytes));
            }
            modules.append((rel_path, content_hash, inner_secs));
        }
    }

    return (manifest, dep_graph, modules);
}
