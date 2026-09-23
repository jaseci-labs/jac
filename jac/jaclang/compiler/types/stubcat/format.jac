glob MAGIC: bytes = b"JSCAT005",
     FORMAT_VERSION: int = 5,
     HEADER_SIZE: int = 108,
     IFACE_HASH_LEN: int = 64,
     TY_UNKNOWN: int = 0,
     TY_NEVER: int = 1,
     TY_ANY: int = 2,
     TY_MODULE: int = 3,
     TY_TYPEVAR: int = 4,
     TY_CLASS: int = 5,
     TY_FUNCTION: int = 6,
     TY_OVERLOAD: int = 7,
     TY_UNION: int = 8,
     TY_ENUM_MEMBER: int = 9,
     SC_MODULE: int = 0,
     SC_CLASS: int = 1,
     SC_FUNCTION: int = 2,
     SC_OTHER: int = 3,
     ARCH_NONE: int = 0,
     ARCH_CLASS: int = 1,
     ARCH_OBJ: int = 2,
     ARCH_ENUM: int = 3,
     MOD_TYPESHED: int = 1,
     MOD_JAC_INTERNAL: int = 2,
     MOD_EXTERNAL: int = 4,
     LIT_NONE: int = 0,
     LIT_STR: int = 1,
     LIT_INT: int = 2,
     LIT_BOOL: int = 3,
     SH_BUILTIN: int = 1,
     SH_STDLIB: int = 2,
     SH_DATACLASS: int = 4,
     SH_NAMEDTUPLE: int = 8,
     SH_TYPEDDICT: int = 16,
     SH_ROOT: int = 32,
     SH_ENUM: int = 64,
     SH_XREF: int = 128,
     TV_COVARIANT: int = 1,
     TV_CONTRAVARIANT: int = 2,
     TV_SELF: int = 4,
     TV_PARAM_SPEC: int = 8,
     TV_CLASS_PARAM: int = 16,
     PM_SELF: int = 1,
     PM_CLS: int = 2,
     PM_HAS_DEFAULT: int = 4,
     PM_COMPTIME: int = 8,
     ACCESS_PUBLIC: int = 0,
     ACCESS_PRIVATE: int = 1,
     ACCESS_PROTECTED: int = 2,
     SYMF_PARAM_REBOUND: int = 1,
     SYMF_NA_ESCAPES: int = 2,
     SYMF_NA_REGION_HANDLE: int = 4,
     SYMF_NA_STACK_OK: int = 8,
     SYMF_HAS_DEFAULT: int = 16,
     SYMF_DEFER: int = 32,
     SYMF_INSTANCE_METHOD: int = 64,
     SYMF_FINAL: int = 128,
     SYMF_READONLY: int = 256;

obj Header {
    has n_strings: int = 0,
        n_modules: int = 0,
        n_scopes: int = 0,
        n_symbols: int = 0,
        n_types: int = 0,
        n_shared: int = 0,
        off_strtab: int = 0,
        off_strblob: int = 0,
        off_modtab: int = 0,
        off_scopetab: int = 0,
        off_symtab: int = 0,
        off_typetab: int = 0,
        off_sharedtab: int = 0,
        off_recblob: int = 0,
        key_sid: int = 0,
        ambient_sid: int = 0;
}

def put_u32(out: bytearray, value: int) {
    out.extend(value.to_bytes(4, "little"));
}

def put_u64(out: bytearray, value: int) {
    out.extend(value.to_bytes(8, "little"));
}

def u32_at(buf: bytes, pos: int) -> int {
    end = pos + 4;
    if pos < 0 or end > len(buf) {
        raise IndexError(f"stubcat read of 4 bytes at {pos} is out of range");
    }
    return int.from_bytes(buf[pos:end], "little");
}

def u64_at(buf: bytes, pos: int) -> int {
    end = pos + 8;
    if pos < 0 or end > len(buf) {
        raise IndexError(f"stubcat read of 8 bytes at {pos} is out of range");
    }
    return int.from_bytes(buf[pos:end], "little");
}

def pack_header(h: Header) -> bytes {
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

def unpack_header(buf: bytes) -> (Header | None) {
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

def put_uvar(out: bytearray, value: int) {
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

def put_ref(out: bytearray, ref: int) {
    put_uvar(out, ref + 1);
}

def put_svar(out: bytearray, value: int) {
    if value >= 0 {
        put_uvar(out, value * 2);
    } else {
        put_uvar(out, (-value) * 2 - 1);
    }
}

def put_refs(out: bytearray, refs: list[int]) {
    put_uvar(out, len(refs));
    for r in refs {
        put_ref(out, r);
    }
}

obj Cursor {
    has buf: bytes,
        pos: int = 0;

    def u -> int {
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

    def ref -> int {
        return self.u() - 1;
    }

    def s -> int {
        zz = self.u();
        if (zz & 1) == 0 {
            return zz >> 1;
        }
        return -((zz + 1) >> 1);
    }

    def refs -> list[int] {
        n = self.u();
        out: list[int] = [];
        for i in range(n) {
            out.append(self.ref());
        }
        return out;
    }
}
