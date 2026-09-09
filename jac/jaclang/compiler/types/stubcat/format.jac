import struct;

glob MAGIC: bytes = b"JSCAT004",
     FORMAT_VERSION: int = 4,
     HEADER_FMT: str = "<8sI6I8QII",
     HEADER_SIZE: int = 108,
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
     SYMF_INSTANCE_METHOD: int = 64;

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

def pack_header(h: Header) -> bytes {
    out = struct.pack(
        HEADER_FMT,
        MAGIC,
        FORMAT_VERSION,
        h.n_strings,
        h.n_modules,
        h.n_scopes,
        h.n_symbols,
        h.n_types,
        h.n_shared,
        h.off_strtab,
        h.off_strblob,
        h.off_modtab,
        h.off_scopetab,
        h.off_symtab,
        h.off_typetab,
        h.off_sharedtab,
        h.off_recblob,
        h.key_sid,
        h.ambient_sid
    );
    if len(out) != HEADER_SIZE {
        raise ValueError(f"stubcat header is {len(out)} bytes, expected {HEADER_SIZE}");
    }
    return out;
}

def unpack_header(buf: any) -> (Header | None) {
    if len(buf) < HEADER_SIZE {
        return None;
    }
    try {
        fields = struct.unpack_from(HEADER_FMT, buf, 0);
    } except struct.error {
        return None;
    }
    if bytes(fields[0]) != MAGIC or fields[1] != FORMAT_VERSION {
        return None;
    }
    return Header(
        n_strings=fields[2],
        n_modules=fields[3],
        n_scopes=fields[4],
        n_symbols=fields[5],
        n_types=fields[6],
        n_shared=fields[7],
        off_strtab=fields[8],
        off_strblob=fields[9],
        off_modtab=fields[10],
        off_scopetab=fields[11],
        off_symtab=fields[12],
        off_typetab=fields[13],
        off_sharedtab=fields[14],
        off_recblob=fields[15],
        key_sid=fields[16],
        ambient_sid=fields[17]
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
    has buf: any,
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
