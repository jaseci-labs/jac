impl put_u32(out: bytearray, value: int) {
    out.extend(value.to_bytes(4, "little"));
}

impl put_u64(out: bytearray, value: int) {
    out.extend(value.to_bytes(8, "little"));
}

impl u32_at(buf: bytes, pos: int) -> int {
    end = pos + 4;
    if pos < 0 or end > len(buf) {
        raise IndexError(f"stubcat read of 4 bytes at {pos} is out of range");
    }
    return int.from_bytes(buf[pos:end], "little");
}

impl u64_at(buf: bytes, pos: int) -> int {
    end = pos + 8;
    if pos < 0 or end > len(buf) {
        raise IndexError(f"stubcat read of 8 bytes at {pos} is out of range");
    }
    return int.from_bytes(buf[pos:end], "little");
}

impl pack_header(h: Header) -> bytes {
    out = bytearray(MAGIC);
    put_u32(out, FORMAT_VERSION);
    put_u32(out, h.n_strings);
    put_u32(out, h.n_modules);
    put_u32(out, h.n_scopes);
    put_u32(out, h.n_symbols);
    put_u32(out, h.n_types);
    put_u32(out, h.n_shared);
    put_u64(out, h.off_strtab);
    put_u64(out, h.off_strblob);
    put_u64(out, h.off_modtab);
    put_u64(out, h.off_scopetab);
    put_u64(out, h.off_symtab);
    put_u64(out, h.off_typetab);
    put_u64(out, h.off_sharedtab);
    put_u64(out, h.off_recblob);
    put_u32(out, h.key_sid);
    put_u32(out, h.ambient_sid);
    if len(out) != HEADER_SIZE {
        raise ValueError(f"stubcat header is {len(out)} bytes, expected {HEADER_SIZE}");
    }
    return bytes(out);
}

impl unpack_header(buf: bytes) -> (Header | None) {
    if len(buf) < HEADER_SIZE {
        return None;
    }
    if buf[0:8] != MAGIC or u32_at(buf, 8) != FORMAT_VERSION {
        return None;
    }
    return Header(
        n_strings=u32_at(buf, 12),
        n_modules=u32_at(buf, 16),
        n_scopes=u32_at(buf, 20),
        n_symbols=u32_at(buf, 24),
        n_types=u32_at(buf, 28),
        n_shared=u32_at(buf, 32),
        off_strtab=u64_at(buf, 36),
        off_strblob=u64_at(buf, 44),
        off_modtab=u64_at(buf, 52),
        off_scopetab=u64_at(buf, 60),
        off_symtab=u64_at(buf, 68),
        off_typetab=u64_at(buf, 76),
        off_sharedtab=u64_at(buf, 84),
        off_recblob=u64_at(buf, 92),
        key_sid=u32_at(buf, 100),
        ambient_sid=u32_at(buf, 104)
    );
}

impl put_uvar(out: bytearray, value: int) {
    v = value;
    if v < 0 {
        raise ValueError(f"unsigned varint cannot encode {v}");
    }
    while v >= 0x80 {
        out.append((v & 0x7F) | 0x80);
        v >>= 7;
    }
    out.append(v);
}

impl put_ref(out: bytearray, ref: int) {
    put_uvar(out, ref + 1);
}

impl put_svar(out: bytearray, value: int) {
    if value >= 0 {
        put_uvar(out, value * 2);
    } else {
        put_uvar(out, (-value) * 2 - 1);
    }
}

impl put_refs(out: bytearray, refs: list[int]) {
    put_uvar(out, len(refs));
    for r in refs {
        put_ref(out, r);
    }
}

impl Cursor.u -> int {
    shift = 0;
    result = 0;
    while True {
        b = self.buf[self.pos];
        self.pos += 1;
        result |= (b & 0x7F) << shift;
        if b < 0x80 {
            break;
        }
        shift += 7;
    }
    return result;
}

impl Cursor.ref -> int {
    return self.u() - 1;
}

impl Cursor.s -> int {
    zz = self.u();
    if (zz & 1) == 0 {
        return zz >> 1;
    }
    return -((zz + 1) >> 1);
}

impl Cursor.refs -> list[int] {
    n = self.u();
    out: list[int] = [];
    for i in range(n) {
        out.append(self.ref());
    }
    return out;
}
