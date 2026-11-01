impl u16_at(data: bytes, pos: int) -> int {
    return data[pos] | (data[pos + 1] << 8);
}

impl u32_at(data: bytes, pos: int) -> int {
    return data[pos]
        | (data[pos + 1] << 8)
        | (data[pos + 2] << 16)
        | (data[pos + 3] << 24);
}

impl read_jir_head(data: bytes) -> (JirHead | None) {
    if len(data) < JIR_HEADER_SIZE {
        return None;
    }
    magic = data[:4];
    format_version = u16_at(data, 4);
    if magic != JIR_MAGIC or format_version != JIR_FORMAT_VERSION {
        return None;
    }
    return JirHead(
        magic=magic,
        format_version=format_version,
        python_version=u16_at(data, 6),
        jaclang_version_hash=u32_at(data, 8),
        source_content_hash=u32_at(data, 12),
        node_count=u32_at(data, 16),
        symbol_count=u32_at(data, 20),
        string_pool_size=u32_at(data, 24),
        flags=u32_at(data, 28)
    );
}

impl sections_start(data: bytes) -> int {
    pos = data.find(JIR_SECTIONS_MAGIC, JIR_HEADER_SIZE);
    return pos + len(JIR_SECTIONS_MAGIC) if pos >= 0 else -1;
}

impl decode_sections(data: bytes, start_pos: int) -> dict[int, bytes] {
    result: dict[int, bytes] = {};
    pos = start_pos;
    while pos < len(data) {
        sec_type = data[pos];
        pos += 1;
        if sec_type == JIR_SEC_TERMINATOR or pos + 4 > len(data) {
            break;
        }
        sec_len = u32_at(data, pos);
        pos += 4;
        if pos + sec_len > len(data) {
            break;
        }
        result[sec_type] = data[pos:pos + sec_len];
        pos += sec_len;
    }
    return result;
}

impl section_bytes(data: bytes, sec_type: int) -> (bytes | None) {
    start = sections_start(data);
    if start < 0 {
        return None;
    }
    return decode_sections(data, start).get(sec_type);
}

impl key_section(data: bytes, sec_type: int) -> (str | None) {
    raw = section_bytes(data, sec_type);
    return raw.decode("utf-8") if raw is not None else None;
}

impl stamp_record(data: (bytes | None)) -> (tuple[list[str], bytes] | None) {
    if data is None or len(data) < 8 or data[:4] != JIR_STAMP_MAGIC {
        return None;
    }
    head_len = u32_at(data, 4);
    if len(data) < 8 + head_len {
        return None;
    }
    parts = data[8:8 + head_len].decode("utf-8").split(JIR_STAMP_SEP);
    if len(parts) != JIR_STAMP_FIELDS {
        return None;
    }
    return (parts, data[8 + head_len:]);
}

impl variant_records(data: (bytes | None)) -> dict[str, bytes] {
    variants: dict[str, bytes] = {};
    if data is None or len(data) < 8 or data[:4] != JIR_VARIANTS_MAGIC {
        return variants;
    }
    count = u32_at(data, 4);
    pos = 8;
    for _ in range(count) {
        if pos + 4 > len(data) {
            return {};
        }
        size = u32_at(data, pos);
        pos += 4;
        if size > len(data) - pos {
            return {};
        }
        record = data[pos:pos + size];
        found = stamp_record(record);
        if found is None {
            return {};
        }
        key = JIR_STAMP_SEP.join(found[0]);
        if key in variants {
            return {};
        }
        variants[key] = record;
        pos += size;
    }
    return variants if pos == len(data) else {};
}

impl tab_rows(text: str) -> list[list[str]] {
    rows: list[list[str]] = [];
    for line in text.split("\n") {
        if "\t" in line {
            rows.append(line.split("\t"));
        }
    }
    return rows;
}

impl path_roots_of(data: (bytes | None)) -> JirPathRoots {
    if not data {
        return JirPathRoots();
    }
    payload = json.loads(data.decode("utf-8"));
    if not isinstance(payload, dict) {
        raise ValueError("JIR path-root section is not an object");
    }
    roots: list[str] = [];
    for root in payload.get("roots", []) {
        roots.append(str(root));
    }
    return JirPathRoots(
        roots=roots,
        base=str(payload.get("base", "")),
        subdir=str(payload.get("subdir", ""))
    );
}
